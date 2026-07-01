import logging
import asyncio
from typing import Literal, Dict, Any, List, Optional
from pydantic import BaseModel, Field
from langchain_nvidia_ai_endpoints import ChatNVIDIA
from langchain_core.prompts import ChatPromptTemplate
from app.core.config import settings
from app.models.loan_analysis import LoanAnalysisResponse
from app.services.calculations import LoanCalculator
from app.models.loan_comparison import (
    LoanComparisonResponse,
    RecommendedLoanInfo,
    ExecutiveSummary,
    FinancialComparisonItem,
    FinancialBreakdown,
    RiskComparisonItem,
    RiskComparison,
    LoanScores,
    LoanScoreInfo,
    AIRecommendationReasonItem,
    ClauseComparisonItem,
    ChartsData,
    FinalDecisionCard,
)

logger = logging.getLogger(__name__)

class LLMComparisonOutput(BaseModel):
    """Structured LLM output for comparing two loan agreements."""
    winner_lender_name: str = Field(..., description="Lender name of the recommended loan, or 'None'")
    recommendation_score: float = Field(..., description="Recommendation score out of 10")
    recommendation_reason: str = Field(..., description="Direct AI reason for recommendation")
    
    better_loan: str = Field(..., description="Which loan is overall better (e.g. 'Loan A' or 'Loan B')")
    why_better: str = Field(..., description="Brief summary of why it is better")
    biggest_differences: str = Field(..., description="Biggest key differences between the two")
    main_risks: str = Field(..., description="Main risks associated with the choices")
    overall_recommendation: str = Field(..., description="Overall summary recommendation")
    
    financial_explanations: Dict[str, str] = Field(
        ...,
        description="Map of parameter name to a brief comparison explanation. Keys MUST include: "
                    "'principal_amount', 'interest_rate', 'interest_type', 'processing_fee', "
                    "'documentation_fee', 'insurance_cost', 'tenure', 'emi', 'total_interest', "
                    "'total_repayment', 'effective_apr'"
    )
    
    hidden_charges_exp: str = Field(..., description="AI comparison of hidden charges")
    hidden_charges_better: str = Field(..., description="Which is better: 'loan_a', 'loan_b', or 'none'")
    
    foreclosure_penalties_exp: str = Field(..., description="AI comparison of foreclosure penalties")
    foreclosure_penalties_better: str = Field(..., description="Which is better: 'loan_a', 'loan_b', or 'none'")
    
    prepayment_charges_exp: str = Field(..., description="AI comparison of prepayment charges")
    prepayment_charges_better: str = Field(..., description="Which is better: 'loan_a', 'loan_b', or 'none'")
    
    bounce_charges_exp: str = Field(..., description="AI comparison of bounce charges")
    bounce_charges_better: str = Field(..., description="Which is better: 'loan_a', 'loan_b', or 'none'")
    
    late_payment_fees_exp: str = Field(..., description="AI comparison of late payment fees")
    late_payment_fees_better: str = Field(..., description="Which is better: 'loan_a', 'loan_b', or 'none'")
    
    floating_rate_clauses_exp: str = Field(..., description="AI comparison of floating rate clauses")
    floating_rate_clauses_better: str = Field(..., description="Which is better: 'loan_a', 'loan_b', or 'none'")
    
    legal_discretion_clauses_exp: str = Field(..., description="AI comparison of legal discretion clauses")
    legal_discretion_clauses_better: str = Field(..., description="Which is better: 'loan_a', 'loan_b', or 'none'")
    
    mandatory_insurance_exp: str = Field(..., description="AI comparison of mandatory insurance requirements")
    mandatory_insurance_better: str = Field(..., description="Which is better: 'loan_a', 'loan_b', or 'none'")
    
    recommendation_reasons: List[Dict[str, str]] = Field(
        ...,
        description="Insights list. Each item has 'title' (e.g., 'Lower processing fee') and 'insight'."
    )
    
    clause_comparison: List[Dict[str, Any]] = Field(
        ...,
        description="Clause comparison items. Each item has: clause_a_title, clause_a_text, clause_a_page, clause_b_title, clause_b_text, clause_b_page, ai_explanation, risk_difference, recommendation, confidence_score"
    )
    
    final_key_reasons: List[str] = Field(..., description="Bullet points of key reasons to choose recommendation")
    final_potential_concerns: List[str] = Field(..., description="Bullet points of potential concerns with recommended loan")
    final_action_recommendation: str = Field(..., description="Next steps recommendations")
    
    confidence_score: float = Field(..., description="AI confidence score between 0.0 and 1.0")

class LoanComparisonService:
    def __init__(self, llm=None, timeout_seconds: float = 180.0):
        self.llm = llm
        self.timeout_seconds = timeout_seconds
        self.structured_llm = None

    def _ensure_runtime(self) -> None:
        """Initialize NVIDIA clients lazily so import/startup stays resilient."""
        if self.structured_llm is not None:
            return

        if self.llm is None:
            self.llm = ChatNVIDIA(
                model=settings.NVIDIA_LLM_MODEL,
                nvidia_api_key=settings.NVIDIA_API_KEY,
                temperature=0
            )
        self.structured_llm = self.llm.with_structured_output(LLMComparisonOutput)

    async def compare_loans(
        self,
        loan_a: LoanAnalysisResponse,
        loan_b: LoanAnalysisResponse
    ) -> LoanComparisonResponse:
        """Compare two loan analyses and generate comparison results using LLM."""
        logger.info("Executing comprehensive side-by-side loan comparison...")
        self._ensure_runtime()

        # Gather file-related data
        lender_a = loan_a.metadata.lender_name
        lender_b = loan_b.metadata.lender_name

        # Programmatically determine better financial side
        def get_better_side(val_a, val_b, lower_is_better=True):
            if val_a is None and val_b is None:
                return "none"
            if val_a is None:
                return "loan_b" if lower_is_better else "none"
            if val_b is None:
                return "loan_a" if lower_is_better else "none"
            try:
                a_num, b_num = float(val_a), float(val_b)
                if a_num == b_num:
                    return "none"
                if lower_is_better:
                    return "loan_a" if a_num < b_num else "loan_b"
                else:
                    return "loan_a" if a_num > b_num else "loan_b"
            except:
                return "none"

        p_fee_a = loan_a.metadata.processing_fee or 0
        p_fee_b = loan_b.metadata.processing_fee or 0
        d_fee_a = loan_a.metadata.documentation_fee or 0
        d_fee_b = loan_b.metadata.documentation_fee or 0
        i_fee_a = loan_a.metadata.insurance_fee or 0
        i_fee_b = loan_b.metadata.insurance_fee or 0

        financial_better = {
            "principal_amount": "none",
            "interest_rate": get_better_side(loan_a.metadata.interest_rate, loan_b.metadata.interest_rate),
            "interest_type": "none" if loan_a.metadata.interest_type == loan_b.metadata.interest_type else ("loan_a" if loan_a.metadata.interest_type == "fixed" else "loan_b"),
            "processing_fee": get_better_side(p_fee_a, p_fee_b),
            "documentation_fee": get_better_side(d_fee_a, d_fee_b),
            "insurance_cost": get_better_side(i_fee_a, i_fee_b),
            "tenure": get_better_side(loan_a.metadata.tenure_months, loan_b.metadata.tenure_months, lower_is_better=True),
            "emi": get_better_side(loan_a.metadata.emi_amount, loan_b.metadata.emi_amount),
            "total_interest": get_better_side(loan_a.total_interest, loan_b.total_interest),
            "total_repayment": get_better_side(loan_a.total_payment, loan_b.total_payment),
            "effective_apr": get_better_side(loan_a.effective_apr, loan_b.effective_apr),
        }

        # Format details for LLM prompt
        risks_a_str = "\n".join([f"- {r.clause_title} (Page {r.page_number or 'N/A'}, Severity: {r.risk_level.value}): {r.explanation}\n  Text: {r.clause_text}" for r in loan_a.risks]) or "No significant risks detected."
        risks_b_str = "\n".join([f"- {r.clause_title} (Page {r.page_number or 'N/A'}, Severity: {r.risk_level.value}): {r.explanation}\n  Text: {r.clause_text}" for r in loan_b.risks]) or "No significant risks detected."

        prompt_context = f"""
Loan A (Lender: {lender_a}):
- Principal: {loan_a.metadata.principal_amount}
- Interest Rate: {loan_a.metadata.interest_rate}% ({loan_a.metadata.interest_type})
- Tenure: {loan_a.metadata.tenure_months} months
- EMI: {loan_a.metadata.emi_amount}
- Total Payment: {loan_a.total_payment}
- Total Interest: {loan_a.total_interest}
- Effective APR: {loan_a.effective_apr}%
- Processing Fee: {p_fee_a}
- Documentation Fee: {d_fee_a}
- Insurance Cost: {i_fee_a}
- Foreclosure Charges: {loan_a.metadata.foreclosure_charges}
- Prepayment Charges: {loan_a.metadata.prepayment_charges}
- Bounce Charges: {loan_a.metadata.bounce_charges}
- Late Payment Fees: {loan_a.metadata.late_payment_fee}
- Safety Score: {loan_a.loan_score.score}/10 ({loan_a.loan_score.rating.value})
- Key Clauses & Detected Risks:
{risks_a_str}

Loan B (Lender: {lender_b}):
- Principal: {loan_b.metadata.principal_amount}
- Interest Rate: {loan_b.metadata.interest_rate}% ({loan_b.metadata.interest_type})
- Tenure: {loan_b.metadata.tenure_months} months
- EMI: {loan_b.metadata.emi_amount}
- Total Payment: {loan_b.total_payment}
- Total Interest: {loan_b.total_interest}
- Effective APR: {loan_b.effective_apr}%
- Processing Fee: {p_fee_b}
- Documentation Fee: {d_fee_b}
- Insurance Cost: {i_fee_b}
- Foreclosure Charges: {loan_b.metadata.foreclosure_charges}
- Prepayment Charges: {loan_b.metadata.prepayment_charges}
- Bounce Charges: {loan_b.metadata.bounce_charges}
- Late Payment Fees: {loan_b.metadata.late_payment_fee}
- Safety Score: {loan_b.loan_score.score}/10 ({loan_b.loan_score.rating.value})
- Key Clauses & Detected Risks:
{risks_b_str}
"""

        template = """You are a senior financial risk analyst and consumer protection attorney.
Compare the following two loan agreements side-by-side, evaluating interest structures, hidden costs, legal clauses, and penalties.

{details}

Task: Compare and analyze the agreements. Fill out ALL required fields in the schema:
1. executive_summary: Which is better, why, differences, risks, overall recommendation.
2. financial_explanations: Brief explanation comparing each financial term.
3. risk_comparison: Hidden charges, foreclosure, prepayment, bounce charges, late payment fees, floating clauses, legal discretion clauses, and mandatory insurance (better_side MUST be 'loan_a', 'loan_b', or 'none').
4. recommendation_reasons: A list of 4-6 specific actionable Insights/Reasons (e.g. 'Lower processing fee').
5. clause_comparison: Match specific clauses side-by-side (e.g. foreclosure clauses in Loan A vs Loan B), explain the legal risk difference, and provide recommendation.
6. final_decision: Key reasons, concerns, overall score (out of 10), and action recommendations.
"""
        prompt = ChatPromptTemplate.from_template(template)
        chain = prompt | self.structured_llm

        try:
            comparison_ai = await asyncio.wait_for(
                chain.ainvoke({"details": prompt_context}),
                timeout=self.timeout_seconds
            )
            if comparison_ai is None:
                logger.warning("AI loan comparison returned None (model failed to produce structured output). Executing heuristic fallback...")
                ai_data = self._generate_fallback(loan_a, loan_b, financial_better)
            else:
                logger.info("AI loan comparison executed successfully.")
                ai_data = comparison_ai
        except asyncio.TimeoutError:
            logger.error(f"AI loan comparison timed out after {self.timeout_seconds}s. Executing heuristic fallback...")
            ai_data = self._generate_fallback(loan_a, loan_b, financial_better)
        except Exception as e:
            logger.error(f"AI loan comparison failed: {e}. Executing heuristic fallback...")
            ai_data = self._generate_fallback(loan_a, loan_b, financial_better)

        # Build Response structure
        rec_loan_val = "Loan A" if ai_data.better_loan.lower().endswith("a") else ("Loan B" if ai_data.better_loan.lower().endswith("b") else "None")
        rec_lender = lender_a if rec_loan_val == "Loan A" else (lender_b if rec_loan_val == "Loan B" else "None")

        # ── Deterministic winner score ─────────────────────────────────────────
        # Use the actual safety score from analysis — never the LLM's subjective
        # recommendation_score — so the score is identical to the analysis screen.
        winner_safety_score = (
            loan_a.loan_score.score if rec_loan_val == "Loan A"
            else loan_b.loan_score.score
        )
        # ──────────────────────────────────────────────────────────────────────

        rec_info = RecommendedLoanInfo(
            lender_name=rec_lender,
            recommendation_score=round(winner_safety_score, 1),
            recommendation_reason=ai_data.recommendation_reason,
            confidence_score=ai_data.confidence_score
        )

        exec_summary = ExecutiveSummary(
            better_loan=ai_data.better_loan,
            why_better=ai_data.why_better,
            biggest_differences=ai_data.biggest_differences,
            main_risks=ai_data.main_risks,
            overall_recommendation=ai_data.overall_recommendation
        )

        financial_breakdown = FinancialBreakdown(
            principal_amount=FinancialComparisonItem(
                value_a=f"INR {loan_a.metadata.principal_amount:,.2f}",
                value_b=f"INR {loan_b.metadata.principal_amount:,.2f}",
                better_side=financial_better["principal_amount"],
                explanation=ai_data.financial_explanations.get("principal_amount", "Principal amount is identical.")
            ),
            interest_rate=FinancialComparisonItem(
                value_a=f"{loan_a.metadata.interest_rate}%",
                value_b=f"{loan_b.metadata.interest_rate}%",
                better_side=financial_better["interest_rate"],
                explanation=ai_data.financial_explanations.get("interest_rate", f"{lender_a} nominal rate vs {lender_b} nominal rate.")
            ),
            interest_type=FinancialComparisonItem(
                value_a=loan_a.metadata.interest_type.capitalize(),
                value_b=loan_b.metadata.interest_type.capitalize(),
                better_side=financial_better["interest_type"],
                explanation=ai_data.financial_explanations.get("interest_type", "Fixed rate shields against rate hikes.")
            ),
            processing_fee=FinancialComparisonItem(
                value_a=f"INR {p_fee_a:,.2f}",
                value_b=f"INR {p_fee_b:,.2f}",
                better_side=financial_better["processing_fee"],
                explanation=ai_data.financial_explanations.get("processing_fee", "Upfront administration processing fee.")
            ),
            documentation_fee=FinancialComparisonItem(
                value_a=f"INR {d_fee_a:,.2f}",
                value_b=f"INR {d_fee_b:,.2f}",
                better_side=financial_better["documentation_fee"],
                explanation=ai_data.financial_explanations.get("documentation_fee", "Document legal review charges.")
            ),
            insurance_cost=FinancialComparisonItem(
                value_a=f"INR {i_fee_a:,.2f}",
                value_b=f"INR {i_fee_b:,.2f}",
                better_side=financial_better["insurance_cost"],
                explanation=ai_data.financial_explanations.get("insurance_cost", "Mandatory or bundled insurance coverage.")
            ),
            tenure=FinancialComparisonItem(
                value_a=f"{loan_a.metadata.tenure_months} Months",
                value_b=f"{loan_b.metadata.tenure_months} Months",
                better_side=financial_better["tenure"],
                explanation=ai_data.financial_explanations.get("tenure", "Length of amortization period.")
            ),
            emi=FinancialComparisonItem(
                value_a=f"INR {loan_a.metadata.emi_amount:,.2f}",
                value_b=f"INR {loan_b.metadata.emi_amount:,.2f}",
                better_side=financial_better["emi"],
                explanation=ai_data.financial_explanations.get("emi", "Equated Monthly Installment.")
            ),
            total_interest=FinancialComparisonItem(
                value_a=f"INR {loan_a.total_interest:,.2f}",
                value_b=f"INR {loan_b.total_interest:,.2f}",
                better_side=financial_better["total_interest"],
                explanation=ai_data.financial_explanations.get("total_interest", "Total interest accumulated over tenure.")
            ),
            total_repayment=FinancialComparisonItem(
                value_a=f"INR {loan_a.total_payment:,.2f}",
                value_b=f"INR {loan_b.total_payment:,.2f}",
                better_side=financial_better["total_repayment"],
                explanation=ai_data.financial_explanations.get("total_repayment", "Sum of principal, interest, and mandatory fees.")
            ),
            effective_apr=FinancialComparisonItem(
                value_a=f"{loan_a.effective_apr}%",
                value_b=f"{loan_b.effective_apr}%",
                better_side=financial_better["effective_apr"],
                explanation=ai_data.financial_explanations.get("effective_apr", "Effective borrowing annual rate.")
            ),
        )

        risk_breakdown = RiskComparison(
            hidden_charges=RiskComparisonItem(
                value_a=f"INR {p_fee_a + d_fee_a + i_fee_a:,.2f}",
                value_b=f"INR {p_fee_b + d_fee_b + i_fee_b:,.2f}",
                better_side=ai_data.hidden_charges_better,
                explanation=ai_data.hidden_charges_exp
            ),
            foreclosure_penalties=RiskComparisonItem(
                value_a=f"{loan_a.metadata.foreclosure_charges}%" if loan_a.metadata.foreclosure_charges else "NIL",
                value_b=f"{loan_b.metadata.foreclosure_charges}%" if loan_b.metadata.foreclosure_charges else "NIL",
                better_side=ai_data.foreclosure_penalties_better,
                explanation=ai_data.foreclosure_penalties_exp
            ),
            prepayment_charges=RiskComparisonItem(
                value_a=f"{loan_a.metadata.prepayment_charges}%" if loan_a.metadata.prepayment_charges else "NIL",
                value_b=f"{loan_b.metadata.prepayment_charges}%" if loan_b.metadata.prepayment_charges else "NIL",
                better_side=ai_data.prepayment_charges_better,
                explanation=ai_data.prepayment_charges_exp
            ),
            bounce_charges=RiskComparisonItem(
                value_a=f"INR {loan_a.metadata.bounce_charges or 0:,.2f}",
                value_b=f"INR {loan_b.metadata.bounce_charges or 0:,.2f}",
                better_side=ai_data.bounce_charges_better,
                explanation=ai_data.bounce_charges_exp
            ),
            late_payment_fees=RiskComparisonItem(
                value_a=f"{loan_a.metadata.late_payment_fee}%" if loan_a.metadata.late_payment_fee else "NIL",
                value_b=f"{loan_b.metadata.late_payment_fee}%" if loan_b.metadata.late_payment_fee else "NIL",
                better_side=ai_data.late_payment_fees_better,
                explanation=ai_data.late_payment_fees_exp
            ),
            floating_rate_clauses=RiskComparisonItem(
                value_a="Floating" if loan_a.metadata.interest_type == "floating" else "Fixed",
                value_b="Floating" if loan_b.metadata.interest_type == "floating" else "Fixed",
                better_side=ai_data.floating_rate_clauses_better,
                explanation=ai_data.floating_rate_clauses_exp
            ),
            legal_discretion_clauses=RiskComparisonItem(
                value_a=f"{len([r for r in loan_a.risks if 'legal' in r.category.lower() or 'arbitrary' in r.category.lower()])} risks found",
                value_b=f"{len([r for r in loan_b.risks if 'legal' in r.category.lower() or 'arbitrary' in r.category.lower()])} risks found",
                better_side=ai_data.legal_discretion_clauses_better,
                explanation=ai_data.legal_discretion_clauses_exp
            ),
            mandatory_insurance=RiskComparisonItem(
                value_a="Mandatory" if i_fee_a > 0 else "Optional/None",
                value_b="Mandatory" if i_fee_b > 0 else "Optional/None",
                better_side=ai_data.mandatory_insurance_better,
                explanation=ai_data.mandatory_insurance_exp
            ),
        )

        # ── Consistent loan scores using analysis safety scores ────────────────
        # Use the SAME scores that analysis computed (rule-based, deterministic).
        # Use LoanCalculator.get_safety_rating_label() so the label matches
        # analysis screen exactly (Excellent / Good / Moderate / Risky / High Risk).
        loan_scores = LoanScores(
            loan_a=LoanScoreInfo(
                score=loan_a.loan_score.score,
                rating=LoanCalculator.get_safety_rating_label(loan_a.loan_score.score),
                explanation=loan_a.loan_score.explanation
            ),
            loan_b=LoanScoreInfo(
                score=loan_b.loan_score.score,
                rating=LoanCalculator.get_safety_rating_label(loan_b.loan_score.score),
                explanation=loan_b.loan_score.explanation
            )
        )
        # ──────────────────────────────────────────────────────────────────────

        reasons = [
            AIRecommendationReasonItem(
                title=item.get("title", "Insight"),
                insight=item.get("insight", "Details of the insight"),
                is_expandable=True
            ) for item in ai_data.recommendation_reasons
        ]

        clauses = [
            ClauseComparisonItem(
                clause_a_title=item.get("clause_a_title", "Clause A"),
                clause_a_text=item.get("clause_a_text", ""),
                clause_a_page=item.get("clause_a_page"),
                clause_b_title=item.get("clause_b_title", "Clause B"),
                clause_b_text=item.get("clause_b_text", ""),
                clause_b_page=item.get("clause_b_page"),
                ai_explanation=item.get("ai_explanation", ""),
                risk_difference=item.get("risk_difference", ""),
                recommendation=item.get("recommendation", ""),
                confidence_score=item.get("confidence_score", 0.9)
            ) for item in ai_data.clause_comparison
        ]

        # Dynamic charts data calculation
        tenure_a = int(loan_a.metadata.tenure_months)
        tenure_b = int(loan_b.metadata.tenure_months)
        emi_a = float(loan_a.metadata.emi_amount)
        emi_b = float(loan_b.metadata.emi_amount)

        # EMI curve over months (up to 18 points)
        points_count = min(18, max(tenure_a, tenure_b))
        emi_series = []
        for i in range(points_count):
            month = int(max(1, (i + 1) * (max(tenure_a, tenure_b) / points_count)))
            val_a = emi_a if month <= tenure_a else 0.0
            val_b = emi_b if month <= tenure_b else 0.0
            emi_series.append({"month": month, "loan_a_emi": val_a, "loan_b_emi": val_b})

        high_a = len([r for r in loan_a.risks if r.risk_level.value == "HIGH"])
        med_a = len([r for r in loan_a.risks if r.risk_level.value == "MEDIUM"])
        low_a = len([r for r in loan_a.risks if r.risk_level.value == "LOW"])

        high_b = len([r for r in loan_b.risks if r.risk_level.value == "HIGH"])
        med_b = len([r for r in loan_b.risks if r.risk_level.value == "MEDIUM"])
        low_b = len([r for r in loan_b.risks if r.risk_level.value == "LOW"])

        charts = ChartsData(
            emi_comparison={"series": emi_series},
            total_repayment_comparison={
                "loan_a": float(loan_a.total_payment),
                "loan_b": float(loan_b.total_payment)
            },
            interest_comparison={
                "loan_a": float(loan_a.total_interest),
                "loan_b": float(loan_b.total_interest)
            },
            cost_breakdown_loan_a={
                "principal": float(loan_a.metadata.principal_amount),
                "interest": float(loan_a.total_interest),
                "fees": float(p_fee_a + d_fee_a + i_fee_a)
            },
            cost_breakdown_loan_b={
                "principal": float(loan_b.metadata.principal_amount),
                "interest": float(loan_b.total_interest),
                "fees": float(p_fee_b + d_fee_b + i_fee_b)
            },
            risk_distribution={
                "loan_a": {"high": high_a, "medium": med_a, "low": low_a},
                "loan_b": {"high": high_b, "medium": med_b, "low": low_b}
            }
        )

        # ── Deterministic final decision score ────────────────────────────────
        # overall_score = safety score of the recommended loan (same as analysis).
        # This eliminates the LLM's subjective recommendation_score entirely.
        final_overall_score = (
            loan_a.loan_score.score if rec_loan_val == "Loan A"
            else loan_b.loan_score.score
        )
        # ──────────────────────────────────────────────────────────────────────

        final_dec = FinalDecisionCard(
            recommended_loan=ai_data.better_loan,
            overall_score=round(final_overall_score, 1),
            confidence=ai_data.confidence_score,
            key_reasons=ai_data.final_key_reasons,
            potential_concerns=ai_data.final_potential_concerns,
            action_recommendation=ai_data.final_action_recommendation
        )

        return LoanComparisonResponse(
            loan_a_lender=lender_a,
            loan_b_lender=lender_b,
            recommended_loan=rec_info,
            comparison_summary=exec_summary,
            financial_breakdown=financial_breakdown,
            risk_breakdown=risk_breakdown,
            loan_scores=loan_scores,
            recommendation_reasons=reasons,
            clause_comparison=clauses,
            charts_data=charts,
            final_decision=final_dec,
            confidence_score=ai_data.confidence_score
        )

    def _generate_fallback(
        self,
        loan_a: LoanAnalysisResponse,
        loan_b: LoanAnalysisResponse,
        financial_better: Dict[str, str]
    ) -> LLMComparisonOutput:
        """Deterministic heuristic fallback when ChatNVIDIA model execution fails or times out."""
        logger.info("Running deterministic loan comparison fallback...")
        score_a = loan_a.loan_score.score
        score_b = loan_b.loan_score.score
        
        # Decide better loan
        if score_a > score_b + 0.2:
            better = "Loan A"
            why = f"Loan A has a higher safety score of {score_a:.1f}/10 compared to {score_b:.1f}/10 for Loan B."
            rec_reason = "Loan A has lower legal risks and fewer hidden penalty clauses."
        elif score_b > score_a + 0.2:
            better = "Loan B"
            why = f"Loan B has a higher safety score of {score_b:.1f}/10 compared to {score_a:.1f}/10 for Loan A."
            rec_reason = "Loan B is qualitatively safer and has a more consumer-friendly contract."
        else:
            cost_a = float(loan_a.total_payment)
            cost_b = float(loan_b.total_payment)
            if cost_a < cost_b:
                better = "Loan A"
                why = f"Loan A is financially cheaper with a total repayment of INR {cost_a:,.2f} vs INR {cost_b:,.2f} for Loan B."
                rec_reason = "Loan A is chosen for its superior financial metrics and lower interest costs."
            else:
                better = "Loan B"
                why = f"Loan B is financially cheaper with a total repayment of INR {cost_b:,.2f} vs INR {cost_a:,.2f} for Loan A."
                rec_reason = "Loan B is chosen for its lower total interest cost over the tenure."

        exp_financials = {
            "principal_amount": "Both loans have identical requested principal amounts.",
            "interest_rate": f"Loan A interest rate is {loan_a.metadata.interest_rate}% vs Loan B is {loan_b.metadata.interest_rate}%.",
            "interest_type": f"Loan A uses {loan_a.metadata.interest_type} interest computation, Loan B uses {loan_b.metadata.interest_type}.",
            "processing_fee": "Processing fees are charged during loan initialization.",
            "documentation_fee": "Administration fee for documentation verification.",
            "insurance_cost": "Cost of credit shielding insurance policy.",
            "tenure": f"Loan A tenure is {loan_a.metadata.tenure_months} months, Loan B is {loan_b.metadata.tenure_months} months.",
            "emi": "Equated Monthly Installment comparing monthly liquidity drain.",
            "total_interest": "Accumulated interest paid directly to the lender.",
            "total_repayment": "Total borrowing cost summing all components.",
            "effective_apr": "Direct annual cost including upfront fees and nominal rate."
        }

        # Build fallback output
        return LLMComparisonOutput(
            winner_lender_name=loan_a.metadata.lender_name if better == "Loan A" else loan_b.metadata.lender_name,
            recommendation_score=max(score_a, score_b),
            recommendation_reason=rec_reason,
            better_loan=better,
            why_better=why,
            biggest_differences="The primary differences lie in nominal interest rates and contract penalty clauses.",
            main_risks="Floating rate fluctuations and default penalty clauses are the main risks.",
            overall_recommendation=f"We recommend proceeding with {better} due to safer contractual parameters and better pricing.",
            financial_explanations=exp_financials,
            hidden_charges_exp="Hidden fees are administrative processing and document costs.",
            hidden_charges_better=financial_better["processing_fee"],
            foreclosure_penalties_exp="Foreclosure penalties apply if you pay off the loan early.",
            foreclosure_penalties_better="loan_a" if (loan_a.metadata.foreclosure_charges or 0) <= (loan_b.metadata.foreclosure_charges or 0) else "loan_b",
            prepayment_charges_exp="Prepayment fees apply to extra principal payments.",
            prepayment_charges_better="loan_a" if (loan_a.metadata.prepayment_charges or 0) <= (loan_b.metadata.prepayment_charges or 0) else "loan_b",
            bounce_charges_exp="Bounce charges apply to rejected auto-debit payments.",
            bounce_charges_better="loan_a" if (loan_a.metadata.bounce_charges or 0) <= (loan_b.metadata.bounce_charges or 0) else "loan_b",
            late_payment_fees_exp="Late fees apply to overdue monthly payments.",
            late_payment_fees_better="loan_a" if (loan_a.metadata.late_payment_fee or 0) <= (loan_b.metadata.late_payment_fee or 0) else "loan_b",
            floating_rate_clauses_exp="Floating rate clauses expose you to benchmark index increases.",
            floating_rate_clauses_better="loan_a" if loan_a.metadata.interest_type == "fixed" else ("loan_b" if loan_b.metadata.interest_type == "fixed" else "none"),
            legal_discretion_clauses_exp="Legal discretion clauses allow unilateral lender updates.",
            legal_discretion_clauses_better="loan_a" if len(loan_a.risks) <= len(loan_b.risks) else "loan_b",
            mandatory_insurance_exp="Mandatory insurance increases overall borrowing costs.",
            mandatory_insurance_better="loan_a" if (loan_a.metadata.insurance_fee or 0) <= (loan_b.metadata.insurance_fee or 0) else "loan_b",
            recommendation_reasons=[
                {"title": "Lower Processing Fee", "insight": f"One loan offers a lower processing charge, saving upfront cash flow."},
                {"title": "Better Safety Score", "insight": "Higher safety score indicates fewer predatory penalty terms."}
            ],
            clause_comparison=[
                {
                    "clause_a_title": "Interest Clause",
                    "clause_a_text": f"Interest rate of {loan_a.metadata.interest_rate}%",
                    "clause_a_page": 1,
                    "clause_b_title": "Interest Clause",
                    "clause_b_text": f"Interest rate of {loan_b.metadata.interest_rate}%",
                    "clause_b_page": 1,
                    "ai_explanation": "Comparing nominal interest rates side-by-side.",
                    "risk_difference": "Interest rate differential determines lifetime interest cost.",
                    "recommendation": "Choose the loan with the lower nominal and effective interest rates.",
                    "confidence_score": 0.95
                }
            ],
            final_key_reasons=[why, "Fewer overall risk flags identified in the contract."],
            final_potential_concerns=["Verify floating rate index linkages prior to signing."],
            final_action_recommendation="Compare current benchmark rates, discuss processing fee waivers, and request a fixed-rate switch.",
            confidence_score=0.90
        )

comparison_service = LoanComparisonService()
