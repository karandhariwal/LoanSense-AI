import logging
import json
from pydantic import ValidationError
from langchain_core.language_models import BaseChatModel
from langchain_nvidia_ai_endpoints import ChatNVIDIA
from app.core.config import settings
from app.services.configuration_service import config_service
from app.models.loan_score import LoanSafetyScore, SafetyRating
from app.services.ai.prompt_templates import LOAN_SAFETY_SCORE_PROMPT
from app.services.calculations import LoanCalculator

logger = logging.getLogger(__name__)

class SafetyScorer:
    """
    Sub-service for evaluating the safety score of a loan agreement.
    Uses ChatNVIDIA with structured output and fallback validation correction.
    """
    def __init__(self, llm: BaseChatModel = None):
        if llm is not None:
            self.llm = llm
        else:
            self.llm = ChatNVIDIA(
                model=settings.NVIDIA_LLM_MODEL,
                nvidia_api_key=settings.NVIDIA_API_KEY,
                temperature=0
            )
        # Using structured output matching the LoanSafetyScore schema
        self.structured_llm = self.llm.with_structured_output(LoanSafetyScore)
        self.chain = LOAN_SAFETY_SCORE_PROMPT | self.structured_llm

    def _determine_correct_rating(self, score: float) -> SafetyRating:
        """Helper to get correct rating based on configurable score ranges."""
        thresholds = config_service.safety_thresholds
        
        # Use configuration-driven thresholds instead of hardcoded values
        if thresholds.excellent_min <= score <= thresholds.excellent_max:
            return SafetyRating.EXCELLENT
        elif thresholds.good_min <= score < thresholds.good_max:
            return SafetyRating.GOOD
        elif thresholds.moderate_min <= score < thresholds.moderate_max:
            return SafetyRating.MODERATE
        elif thresholds.risky_min <= score < thresholds.risky_max:
            return SafetyRating.RISKY
        else:
            return SafetyRating.HIGH_RISK

    async def generate_safety_score(
        self,
        document_context: str,
        extracted_metadata: str,
        detected_risks: list
    ) -> LoanSafetyScore:
        """
        Run the safety score chain and handle potential validation errors by correcting them.
        """
        logger.info("Executing Safety Score Evaluation...")
        try:
            if not document_context or not document_context.strip():
                logger.warning("Empty document context provided to SafetyScorer.")
                return LoanSafetyScore(
                    score=5.0,
                    rating=SafetyRating.MODERATE,
                    strengths=[],
                    weaknesses=[],
                    explanation="Empty document content. Defaulting to moderate score."
                )

            # Invoke the structured chain (LLM provides qualitative output only)
            score_response = await self.chain.ainvoke({
                "document_context": document_context,
                "extracted_metadata": extracted_metadata,
                "detected_risks": str(detected_risks)
            })

            # ── Deterministic score override ────────────────────────────────────
            # The LLM sets score=0.0 as a placeholder. We always replace it with
            # the rule-based calculation so the same document always gets the
            # same numeric score, regardless of LLM non-determinism.
            deterministic_score = LoanCalculator.calculate_safety_score(detected_risks)
            deterministic_rating = self._determine_correct_rating(deterministic_score)
            logger.info(
                f"Overriding LLM placeholder score with deterministic score: "
                f"{deterministic_score} ({deterministic_rating.value})"
            )
            return LoanSafetyScore(
                score=deterministic_score,
                rating=deterministic_rating,
                strengths=score_response.strengths,
                weaknesses=score_response.weaknesses,
                explanation=score_response.explanation
            )
            # ───────────────────────────────────────────────────────────────────

        except ValidationError as val_err:
            logger.warning(f"Pydantic Validation Error during safety score extraction: {val_err}. Attempting recovery...")
            return await self._recover_safety_score_raw(document_context, extracted_metadata, detected_risks)
        except Exception as e:
            logger.error(f"Error during safety score evaluation: {e}. Falling back to rule-based scorer.", exc_info=True)
            return self._generate_fallback_score(detected_risks)

    async def _recover_safety_score_raw(
        self,
        document_context: str,
        extracted_metadata: str,
        detected_risks: list
    ) -> LoanSafetyScore:
        """
        Recovery routine that calls the raw LLM, parses the JSON dict,
        fixes any rating-to-score inconsistency, and instantiates the Pydantic model.
        """
        try:
            # Re-query the raw LLM
            raw_chain = LOAN_SAFETY_SCORE_PROMPT | self.llm
            raw_response = await raw_chain.ainvoke({
                "document_context": document_context,
                "extracted_metadata": extracted_metadata,
                "detected_risks": str(detected_risks)
            })
            
            raw_text = raw_response.content if hasattr(raw_response, 'content') else str(raw_response)
            
            # Clean up markdown code blocks if the LLM outputted them
            if "```json" in raw_text:
                raw_text = raw_text.split("```json")[1].split("```")[0].strip()
            elif "```" in raw_text:
                raw_text = raw_text.split("```")[1].split("```")[0].strip()
            
            data = json.loads(raw_text)

            # ── Deterministic score override ────────────────────────────────────
            # Compute the rule-based score from detected risks (same as primary path)
            deterministic_score = LoanCalculator.calculate_safety_score(detected_risks)
            correct_rating = self._determine_correct_rating(deterministic_score)

            logger.info(
                f"Recovered safety score with deterministic override: "
                f"score={deterministic_score}, rating={correct_rating}"
            )
            return LoanSafetyScore(
                score=deterministic_score,
                rating=correct_rating,
                strengths=data.get("strengths", []),
                weaknesses=data.get("weaknesses", []),
                explanation=data.get("explanation", "Recovered safety evaluation from raw JSON model output.")
            )
            # ───────────────────────────────────────────────────────────────────
        except Exception as recovery_err:
            logger.error(f"Failed to recover safety score via raw JSON fallback: {recovery_err}. Using rule-based scorer.")
            return self._generate_fallback_score(detected_risks)

    def _generate_fallback_score(self, detected_risks: list) -> LoanSafetyScore:
        """
        Rule-based safety score generator used as a last resort.
        """
        try:
            calculated_score = LoanCalculator.calculate_safety_score(detected_risks)
            rating = self._determine_correct_rating(calculated_score)
            
            strengths = []
            weaknesses = [r.get("clause_title", "Risky Clause") if isinstance(r, dict) else getattr(r, "clause_title", "Risky Clause") for r in detected_risks]
            
            if not weaknesses:
                strengths.append("No critical risk clauses identified in the agreement.")
            
            return LoanSafetyScore(
                score=calculated_score,
                rating=rating,
                strengths=strengths,
                weaknesses=weaknesses,
                explanation=f"A rule-based safety evaluation was performed based on {len(detected_risks)} detected risk clauses."
            )
        except Exception as e:
            logger.critical(f"Critical failure in rule-based fallback scorer: {e}")
            return LoanSafetyScore(
                score=5.0,
                rating=SafetyRating.MODERATE,
                strengths=[],
                weaknesses=[],
                explanation="Default safety evaluation score due to system errors."
            )
