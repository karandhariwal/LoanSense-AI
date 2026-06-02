import logging
import asyncio
from typing import List, Optional
from decimal import Decimal
from datetime import date
from pydantic import ValidationError

from langchain_core.language_models import BaseChatModel
from langchain_nvidia_ai_endpoints import ChatNVIDIA

from app.core.config import settings
from app.models.loan_metadata import LoanMetadata
from app.models.risk_clause import RiskClause
from app.models.loan_score import LoanSafetyScore, SafetyRating
from app.models.loan_analysis import LoanAnalysisResponse

from app.services.calculations import LoanCalculator
from app.services.ai.risk_detector import RiskDetector
from app.services.ai.summary_generator import SummaryGenerator
from app.services.ai.safety_scorer import SafetyScorer
from app.services.ai.prompt_templates import LOAN_METADATA_EXTRACTION_PROMPT
from app.services.ai.pdf_processor import MAX_METADATA_CHARS, MAX_RISK_CHARS

logger = logging.getLogger(__name__)

# =====================================================================
# CUSTOM EXCEPTIONS FOR AI PIPELINE
# =====================================================================

class ExtractionServiceError(Exception):
    """Base exception for LoanExtractionService."""
    pass

class EmptyDocumentError(ExtractionServiceError):
    """Raised when the document text input is empty."""
    pass

class LLMTimeoutError(ExtractionServiceError):
    """Raised when an LLM service call times out."""
    pass

class SchemaValidationError(ExtractionServiceError):
    """Raised when extracted data fails schema validation checks."""
    pass


# =====================================================================
# CORE AI EXTRACTION & ORCHESTRATION SERVICE
# =====================================================================

class LoanExtractionService:
    """
    Orchestration layer that executes metadata extraction, risk detection,
    summary generation, safety scoring, and financial calculation steps.
    """

    def __init__(
        self,
        llm: Optional[BaseChatModel] = None,
        calculator: Optional[LoanCalculator] = None,
        risk_detector: Optional[RiskDetector] = None,
        summary_generator: Optional[SummaryGenerator] = None,
        safety_scorer: Optional[SafetyScorer] = None,
        timeout_seconds: float = 120.0
    ):
        # Configure Core LLM and Timeout
        self.llm = llm or ChatNVIDIA(
            model=settings.NVIDIA_LLM_MODEL,
            nvidia_api_key=settings.NVIDIA_API_KEY,
            temperature=0
        )
        self.timeout_seconds = timeout_seconds
        
        # Inject Calculations Engine
        self.calculator = calculator or LoanCalculator()

        # Inject/Instantiate Sub-services
        self.risk_detector = risk_detector or RiskDetector(llm=self.llm)
        self.summary_generator = summary_generator or SummaryGenerator(llm=self.llm)
        self.safety_scorer = safety_scorer or SafetyScorer(llm=self.llm)

        # Initialize Metadata extraction chain
        self.metadata_llm = self.llm.with_structured_output(LoanMetadata)
        self.metadata_chain = LOAN_METADATA_EXTRACTION_PROMPT | self.metadata_llm

    async def analyze_document(self, text: str) -> LoanAnalysisResponse:
        """
        Main public API for analyzing a loan document's text.
        Executes the analysis stages in parallel where possible:
          - Stage 1 (parallel): metadata extraction + risk detection
          - Stage 2 (parallel): summary generation + safety scoring
        """
        logger.info("Loan Extraction Pipeline started.")

        # 1. Input Check
        if not text or not text.strip():
            logger.error("Analysis failed: Empty document text provided.")
            raise EmptyDocumentError("The document text provided is empty.")

        # --- Text truncation strategy ---
        # LLM API latency scales directly with token count. The key financial
        # parameters (principal, rate, tenure, fees) and most risk clauses are
        # concentrated in the first 10-13 pages of any loan agreement.
        # Truncating before each LLM call reduces token counts by 60-80%.
        metadata_text = text[:MAX_METADATA_CHARS]   # ~10 pages for structured fields
        risk_text = text[:MAX_RISK_CHARS]            # ~13 pages — risk clauses can appear later
        truncated_text = text[:6000]                 # summary/safety: already get structured context

        # Pipeline validation and fallback flags
        metadata_validation_success = True
        safety_score_validation_success = True

        # ── STAGE 1: Parallel — metadata extraction + risk detection ──────────
        logger.info(
            f"Stage 1: Running metadata extraction ({len(metadata_text)} chars) "
            f"and risk detection ({len(risk_text)} chars) in parallel..."
        )

        async def _safe_extract_metadata():
            try:
                return await self._extract_metadata(metadata_text), True
            except Exception as e:
                logger.error(f"Metadata extraction failed: {e}")
                return self._get_fallback_metadata(), False

        async def _safe_detect_risks():
            try:
                return await self._detect_risks(risk_text)
            except Exception as e:
                logger.error(f"Risk detection failed: {e}")
                return []

        (metadata, meta_ok), risks = await asyncio.gather(
            _safe_extract_metadata(),
            _safe_detect_risks(),
        )
        if not meta_ok:
            metadata_validation_success = False

        # ── STAGE 2: Parallel — summary generation + safety scoring ───────────
        logger.info("Stage 2: Running summary generation and safety scoring in parallel...")

        async def _safe_generate_summary():
            try:
                return await self._generate_summary(truncated_text, metadata, risks)
            except Exception as e:
                logger.error(f"Summary generation failed: {e}")
                return "Executive loan summary is unavailable due to an extraction pipeline issue."

        async def _safe_generate_safety_score():
            nonlocal safety_score_validation_success
            try:
                return await self._generate_safety_score(truncated_text, metadata, risks)
            except Exception as e:
                logger.error(f"Safety score evaluation failed: {e}")
                safety_score_validation_success = False
                return self.safety_scorer._generate_fallback_score(risks)

        summary, safety_score = await asyncio.gather(
            _safe_generate_summary(),
            _safe_generate_safety_score(),
        )

        # ── STAGE 3: Aggregate, calculate financials, build response ───────────
        try:
            response = self._build_analysis_response(
                metadata=metadata,
                risks=risks,
                summary=summary,
                safety_score=safety_score,
                metadata_ok=metadata_validation_success,
                safety_ok=safety_score_validation_success
            )
            logger.info("Loan Extraction Pipeline completed successfully.")
            return response
        except ValidationError as val_err:
            logger.error(f"Pydantic Validation Error building final LoanAnalysisResponse: {val_err}")
            raise SchemaValidationError(f"Final LoanAnalysisResponse validation failed: {val_err}")
        except Exception as e:
            logger.error(f"Unexpected error assembling LoanAnalysisResponse: {e}")
            raise ExtractionServiceError(f"Failed to assemble final response: {e}")


    # =====================================================================
    # PRIVATE PIPELINE METHODS
    # =====================================================================

    async def _extract_metadata(self, text: str) -> LoanMetadata:
        """
        Extract structured loan metadata from the agreement text.
        """
        logger.info("Extracting loan metadata...")
        try:
            # Wrap in timeout to prevent hanging on NVIDIA NIM
            response = await asyncio.wait_for(
                self.metadata_chain.ainvoke({"document_context": text}),
                timeout=self.timeout_seconds
            )
            logger.info("Loan metadata extracted successfully.")
            return response
        except asyncio.TimeoutError:
            logger.error(f"Metadata extraction timed out after {self.timeout_seconds}s.")
            raise LLMTimeoutError("Metadata extraction timed out.")
        except Exception as e:
            logger.error(f"Error during metadata extraction: {e}")
            raise SchemaValidationError(f"Metadata schema validation failed: {e}")

    async def _detect_risks(self, text: str) -> List[RiskClause]:
        """
        Identify high-risk clauses in the loan agreement.
        """
        logger.info("Detecting risky clauses...")
        try:
            return await asyncio.wait_for(
                self.risk_detector.detect_risks(text),
                timeout=self.timeout_seconds
            )
        except asyncio.TimeoutError:
            logger.error(f"Risk clause detection timed out after {self.timeout_seconds}s.")
            return []

    async def _generate_summary(self, text: str, metadata: LoanMetadata, risks: List[RiskClause]) -> str:
        """
        Generate a consumer-friendly textual summary of the loan agreement.
        """
        logger.info("Generating executive summary...")
        metadata_str = metadata.model_dump_json(indent=2)
        risks_str = "\n".join([r.model_dump_json(indent=2) for r in risks])
        
        try:
            return await asyncio.wait_for(
                self.summary_generator.generate_summary(
                    document_context=text,
                    extracted_metadata=metadata_str,
                    detected_risks=risks_str
                ),
                timeout=self.timeout_seconds
            )
        except asyncio.TimeoutError:
            logger.error("Summary generation timed out.")
            return "Loan summary could not be generated due to a timeout."

    async def _generate_safety_score(self, text: str, metadata: LoanMetadata, risks: List[RiskClause]) -> LoanSafetyScore:
        """
        Generate safety score and rating.
        """
        logger.info("Evaluating safety score...")
        metadata_str = metadata.model_dump_json(indent=2)
        
        try:
            return await asyncio.wait_for(
                self.safety_scorer.generate_safety_score(
                    document_context=text,
                    extracted_metadata=metadata_str,
                    detected_risks=risks
                ),
                timeout=self.timeout_seconds
            )
        except asyncio.TimeoutError:
            logger.error("Safety scoring timed out.")
            return self.safety_scorer._generate_fallback_score(risks)

    def _build_analysis_response(
        self,
        metadata: LoanMetadata,
        risks: List[RiskClause],
        summary: str,
        safety_score: LoanSafetyScore,
        metadata_ok: bool,
        safety_ok: bool
    ) -> LoanAnalysisResponse:
        """
        Combine all stages, calculate financial metrics, and validate output schema.
        """
        logger.info("Assembling LoanAnalysisResponse...")

        # 1. Financial Amortization Calculations via injected calculator
        total_interest = self.calculator.calculate_total_interest(
            principal=metadata.principal_amount,
            tenure_months=metadata.tenure_months,
            emi=metadata.emi_amount
        )
        
        total_payment = self.calculator.calculate_total_payment(
            principal=metadata.principal_amount,
            total_interest=total_interest,
            processing_fee=metadata.processing_fee,
            documentation_fee=metadata.documentation_fee,
            insurance_fee=metadata.insurance_fee
        )

        effective_apr = self.calculator.calculate_effective_apr(
            principal=metadata.principal_amount,
            emi=metadata.emi_amount,
            tenure_months=metadata.tenure_months,
            processing_fee=metadata.processing_fee,
            documentation_fee=metadata.documentation_fee,
            insurance_fee=metadata.insurance_fee,
            nominal_rate=metadata.interest_rate  # used as fallback if solver fails
        )

        # 2. Recommendations Engine
        recommendations = self._generate_recommendations(metadata, risks, safety_score)

        # 3. Confidence Score Engine
        confidence = self._calculate_confidence_score(metadata, risks, metadata_ok, safety_ok)

        # 4. Construct final response model (validated automatically by Pydantic v2)
        return LoanAnalysisResponse(
            metadata=metadata,
            risks=risks,
            ai_summary=summary,
            loan_score=safety_score,
            confidence_score=confidence,
            total_interest=total_interest,
            total_payment=total_payment,
            effective_apr=effective_apr,
            recommendations=recommendations
        )

    # =====================================================================
    # RECOMMENDATION AND CONFIDENCE ENGINES
    # =====================================================================

    def _generate_recommendations(
        self,
        metadata: LoanMetadata,
        risks: List[RiskClause],
        safety_score: LoanSafetyScore
    ) -> List[str]:
        """
        Programmatic engine that reviews loan terms, safety score, and risk clauses
        to suggest negotiations, clarifications, and warnings.
        """
        recommendations = []

        # Gather recommendations from extracted risk clauses
        for risk in risks:
            if risk.recommendation and risk.recommendation not in recommendations:
                recommendations.append(risk.recommendation)

        # Heuristic rules based on metadata parameters
        if metadata.processing_fee and metadata.processing_fee > (metadata.principal_amount * Decimal("0.01")):
            recommendations.append("The processing fee exceeds 1% of principal. Request a waiver or standard processing cap.")

        if metadata.interest_type == "floating":
            recommendations.append("Confirm the benchmark link for the floating rate. External benchmarks (e.g. Repo Rate/MCLR) are safer than internal PLR.")

        if metadata.foreclosure_charges and metadata.foreclosure_charges > 0:
            recommendations.append("Negotiate for zero foreclosure charges, especially if funding from own resources (complying with RBI retail guidelines).")

        if metadata.insurance_fee and metadata.insurance_fee > (metadata.principal_amount * Decimal("0.02")):
            recommendations.append("Loan insurance premium is high. Check if this is optional or if you can purchase coverage from third-party insurers.")

        if safety_score.score < 5.0:
            recommendations.append("This agreement has a lower safety rating. We advise legal counsel review before finalizing terms.")

        # Ensure we return at least a default set of advice if list is empty
        if not recommendations:
            recommendations.append("Request an amortization schedule showing the exact principal-interest split for each month.")
            recommendations.append("Verify payment grace periods and advance notification procedures for interest rate changes.")

        return recommendations[:6]  # Limit to top 6 actionable items

    def _calculate_confidence_score(
        self,
        metadata: LoanMetadata,
        risks: List[RiskClause],
        metadata_ok: bool,
        safety_ok: bool
    ) -> float:
        """
        Compute confidence score based on metadata completeness, extraction pipeline success,
        and risk clause consistency.
        """
        score = 0.85  # Starting base confidence

        # 1. Metadata completeness ratio
        optional_fields = [
            metadata.processing_fee,
            metadata.documentation_fee,
            metadata.insurance_fee,
            metadata.foreclosure_charges,
            metadata.prepayment_charges,
            metadata.bounce_charges,
            metadata.late_payment_fee,
            metadata.disbursal_amount,
            metadata.loan_start_date,
            metadata.maturity_date
        ]
        completed_fields_count = sum(1 for field in optional_fields if field is not None)
        # Add up to 0.10 for optional metadata coverage
        coverage_bonus = (completed_fields_count / len(optional_fields)) * 0.10
        score += coverage_bonus

        # 2. Pipeline Success checks
        if metadata_ok and safety_ok:
            score += 0.05
        else:
            # Deduct if fallbacks were triggered
            score -= 0.15

        # 3. Guard bounds [0.0 - 1.0]
        return float(max(0.0, min(1.0, round(score, 2))))

    def _get_fallback_metadata(self) -> LoanMetadata:
        """
        Construct default metadata structure in case extraction fails entirely.
        """
        from datetime import timedelta
        logger.warning("Generating default/fallback metadata block.")
        start = date.today()
        maturity = start + timedelta(days=365)  # Must be strictly after start_date
        return LoanMetadata(
            lender_name="Unknown Lender",
            loan_type="Unclassified Loan",
            principal_amount=Decimal("100000.00"),
            sanctioned_amount=Decimal("100000.00"),
            interest_rate=12.0,
            interest_type="fixed",
            tenure_months=12,
            emi_amount=Decimal("8884.88"),  # calculated EMI for 12% on 100k
            processing_fee=Decimal("0.00"),
            documentation_fee=Decimal("0.00"),
            insurance_fee=Decimal("0.00"),
            foreclosure_charges=Decimal("0.00"),
            prepayment_charges=Decimal("0.00"),
            bounce_charges=Decimal("500.00"),
            late_payment_fee=Decimal("24.00"),
            disbursal_amount=Decimal("100000.00"),
            repayment_frequency="monthly",
            loan_start_date=start,
            maturity_date=maturity
        )
