import logging
import asyncio
from typing import Literal
from pydantic import BaseModel, Field
from langchain_nvidia_ai_endpoints import ChatNVIDIA
from langchain_core.prompts import ChatPromptTemplate
from app.core.config import settings
from app.models.loan_analysis import LoanAnalysisResponse
from app.models.loan_comparison import LoanComparison, LoanComparisonResult

logger = logging.getLogger(__name__)

class LoanComparisonOutputSchema(BaseModel):
    """Structured LLM output for comparing two loan agreements."""
    risk_difference: str = Field(
        ...,
        description="Qualitative explanation of the difference in risk profiles and hidden clauses."
    )
    recommended_loan: Literal["Loan A", "Loan B", "None"] = Field(
        ...,
        description="The recommended choice: 'Loan A', 'Loan B', or 'None'."
    )
    recommendation_reason: str = Field(
        ...,
        description="Detailed explanation justifying the AI recommendation based on costs and safety."
    )

class LoanComparisonService:
    def __init__(self, llm=None, timeout_seconds: float = 30.0):
        self.llm = llm or ChatNVIDIA(
            model=settings.NVIDIA_LLM_MODEL,
            nvidia_api_key=settings.NVIDIA_API_KEY,
            temperature=0
        )
        self.timeout_seconds = timeout_seconds
        self.structured_llm = self.llm.with_structured_output(LoanComparisonOutputSchema)

    async def compare_loans(
        self,
        loan_a: LoanAnalysisResponse,
        loan_b: LoanAnalysisResponse
    ) -> LoanComparison:
        """Compare two loan analyses and generate comparison results using LLM."""
        logger.info("Executing side-by-side loan comparison...")

        # Calculate exact differences programmatically
        cost_diff = loan_a.total_payment - loan_b.total_payment
        interest_diff = loan_a.total_interest - loan_b.total_interest

        # Format details for LLM prompt
        risks_a_str = "\n".join([f"- {r.clause_title} ({r.risk_level.value}): {r.explanation}" for r in loan_a.risks]) or "No significant risks detected."
        risks_b_str = "\n".join([f"- {r.clause_title} ({r.risk_level.value}): {r.explanation}" for r in loan_b.risks]) or "No significant risks detected."

        prompt_context = f"""
Loan A Details:
- Lender: {loan_a.metadata.lender_name}
- Principal: {loan_a.metadata.principal_amount}
- Interest Rate: {loan_a.metadata.interest_rate}% ({loan_a.metadata.interest_type})
- Tenure: {loan_a.metadata.tenure_months} months
- EMI: {loan_a.metadata.emi_amount}
- Total Payment: {loan_a.total_payment}
- Total Interest: {loan_a.total_interest}
- Safety Score: {loan_a.loan_score.score}/10 ({loan_a.loan_score.rating.value})
- Key Risks:
{risks_a_str}

Loan B Details:
- Lender: {loan_b.metadata.lender_name}
- Principal: {loan_b.metadata.principal_amount}
- Interest Rate: {loan_b.metadata.interest_rate}% ({loan_b.metadata.interest_type})
- Tenure: {loan_b.metadata.tenure_months} months
- EMI: {loan_b.metadata.emi_amount}
- Total Payment: {loan_b.total_payment}
- Total Interest: {loan_b.total_interest}
- Safety Score: {loan_b.loan_score.score}/10 ({loan_b.loan_score.rating.value})
- Key Risks:
{risks_b_str}
"""

        template = """You are a senior financial risk analyst and consumer protection attorney.
Compare the following two loan offers and determine which is better for the borrower, considering both financial costs and risk exposure.

{details}

Requirements:
1. Provide a qualitative, plain-English summary comparing their risks, hidden fees, or flexibility issues (risk_difference).
2. Choose the recommended loan: 'Loan A' or 'Loan B' (or 'None' if they are equally risky or identical).
3. Provide a clear, structured explanation justifying your recommendation (recommendation_reason).
"""
        prompt = ChatPromptTemplate.from_template(template)
        chain = prompt | self.structured_llm

        try:
            comparison_ai = await asyncio.wait_for(
                chain.ainvoke({"details": prompt_context}),
                timeout=self.timeout_seconds
            )
            logger.info("AI loan comparison executed successfully.")
            
            result = LoanComparisonResult(
                cost_difference=cost_diff,
                interest_difference=interest_diff,
                risk_difference=comparison_ai.risk_difference,
                recommended_loan=comparison_ai.recommended_loan,
                recommendation_reason=comparison_ai.recommendation_reason
            )
        except Exception as e:
            logger.error(f"AI loan comparison failed or timed out: {e}. Falling back to heuristic comparison.")
            # Heuristic Fallback
            rec_loan = "None"
            if loan_a.loan_score.score > loan_b.loan_score.score + 0.5:
                rec_loan = "Loan A"
                why = f"Loan A has a significantly better safety score ({loan_a.loan_score.score}) than Loan B ({loan_b.loan_score.score})."
            elif loan_b.loan_score.score > loan_a.loan_score.score + 0.5:
                rec_loan = "Loan B"
                why = f"Loan B has a significantly better safety score ({loan_b.loan_score.score}) than Loan A ({loan_a.loan_score.score})."
            else:
                if cost_diff < 0:
                    rec_loan = "Loan A"
                    why = f"Loan A is financially cheaper than Loan B by {-cost_diff} in total repayment."
                elif cost_diff > 0:
                    rec_loan = "Loan B"
                    why = f"Loan B is financially cheaper than Loan A by {cost_diff} in total repayment."
                else:
                    why = "Both loans are financially and qualitatively equivalent."

            result = LoanComparisonResult(
                cost_difference=cost_diff,
                interest_difference=interest_diff,
                risk_difference=f"Loan A safety score is {loan_a.loan_score.score} vs Loan B safety score is {loan_b.loan_score.score}.",
                recommended_loan=rec_loan,
                recommendation_reason=why
            )

        return LoanComparison(
            loan_a=loan_a.metadata,
            loan_b=loan_b.metadata,
            comparison_results=result
        )

comparison_service = LoanComparisonService()
