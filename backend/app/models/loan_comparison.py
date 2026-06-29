from typing import List, Optional, Literal, Dict, Any
from pydantic import BaseModel, Field, ConfigDict
from .loan_metadata import LoanMetadata

class RecommendedLoanInfo(BaseModel):
    """Winner card info."""
    lender_name: str = Field(..., description="Lender name of the recommended loan")
    recommendation_score: float = Field(..., description="Recommendation score out of 10")
    recommendation_reason: str = Field(..., description="Direct AI reason for recommendation")
    confidence_score: float = Field(..., description="AI confidence score between 0.0 and 1.0")

class ExecutiveSummary(BaseModel):
    """AI Executive Summary."""
    better_loan: str = Field(..., description="Name/Lender of the better loan")
    why_better: str = Field(..., description="Summary of why it is better")
    biggest_differences: str = Field(..., description="Biggest key differences between the two")
    main_risks: str = Field(..., description="Main risks associated with the choices")
    overall_recommendation: str = Field(..., description="Overall summary recommendation")

class FinancialComparisonItem(BaseModel):
    """Single financial parameter comparison."""
    value_a: str = Field(..., description="Value for Loan A")
    value_b: str = Field(..., description="Value for Loan B")
    better_side: str = Field(..., description="Which loan is better for this parameter: 'loan_a', 'loan_b', or 'none'")
    explanation: str = Field(..., description="Brief explanation of the comparison")

class FinancialBreakdown(BaseModel):
    """Side-by-side financial breakdown."""
    principal_amount: FinancialComparisonItem
    interest_rate: FinancialComparisonItem
    interest_type: FinancialComparisonItem
    processing_fee: FinancialComparisonItem
    documentation_fee: FinancialComparisonItem
    insurance_cost: FinancialComparisonItem
    tenure: FinancialComparisonItem
    emi: FinancialComparisonItem
    total_interest: FinancialComparisonItem
    total_repayment: FinancialComparisonItem
    effective_apr: FinancialComparisonItem

class RiskComparisonItem(BaseModel):
    """Single risk parameter comparison."""
    value_a: str = Field(..., description="Risk details for Loan A")
    value_b: str = Field(..., description="Risk details for Loan B")
    better_side: str = Field(..., description="Which loan has lower risk: 'loan_a', 'loan_b', or 'none'")
    explanation: str = Field(..., description="Brief comparison or risk analysis")

class RiskComparison(BaseModel):
    """Comparison of key risk factors."""
    hidden_charges: RiskComparisonItem
    foreclosure_penalties: RiskComparisonItem
    prepayment_charges: RiskComparisonItem
    bounce_charges: RiskComparisonItem
    late_payment_fees: RiskComparisonItem
    floating_rate_clauses: RiskComparisonItem
    legal_discretion_clauses: RiskComparisonItem
    mandatory_insurance: RiskComparisonItem

class LoanScoreInfo(BaseModel):
    """Score summary of a single loan."""
    score: float = Field(..., description="Safety score out of 10")
    rating: str = Field(..., description="Classification: 'Low', 'Medium', or 'High'")
    explanation: str = Field(..., description="Short explanation of score")

class LoanScores(BaseModel):
    """Side-by-side safety scores."""
    loan_a: LoanScoreInfo
    loan_b: LoanScoreInfo

class AIRecommendationReasonItem(BaseModel):
    """An AI generated recommendation insight."""
    title: str = Field(..., description="Short title of the insight (e.g., 'Lower processing fee')")
    insight: str = Field(..., description="Detailed description of the insight")
    is_expandable: bool = Field(default=True, description="Whether the UI should allow expanding the insight")

class ClauseComparisonItem(BaseModel):
    """Comparison details for a specific clause pair."""
    clause_a_title: str = Field(..., description="Title of the clause in Loan A")
    clause_a_text: str = Field(..., description="Extract of the clause in Loan A")
    clause_a_page: Optional[int] = Field(None, description="Page reference in Loan A")
    clause_b_title: str = Field(..., description="Title of the clause in Loan B")
    clause_b_text: str = Field(..., description="Extract of the clause in Loan B")
    clause_b_page: Optional[int] = Field(None, description="Page reference in Loan B")
    ai_explanation: str = Field(..., description="Side by side comparison explanation")
    risk_difference: str = Field(..., description="Comparison of risk level of the clauses")
    recommendation: str = Field(..., description="AI action recommendation for the borrower")
    confidence_score: float = Field(..., description="AI confidence score for this comparison")

class ChartsData(BaseModel):
    """Structured data required to render charts."""
    emi_comparison: Dict[str, Any] = Field(..., description="Data points comparing monthly EMI payments")
    total_repayment_comparison: Dict[str, Any] = Field(..., description="Data comparing total repayment costs")
    interest_comparison: Dict[str, Any] = Field(..., description="Data comparing total interest payable")
    cost_breakdown_loan_a: Dict[str, Any] = Field(..., description="Detailed cost breakdown for Loan A")
    cost_breakdown_loan_b: Dict[str, Any] = Field(..., description="Detailed cost breakdown for Loan B")
    risk_distribution: Dict[str, Any] = Field(..., description="Distribution of risks by severity")

class FinalDecisionCard(BaseModel):
    """Final summary recommendation checklist."""
    recommended_loan: str = Field(..., description="Recommended loan")
    overall_score: float = Field(..., description="Final overall comparison score")
    confidence: float = Field(..., description="Final confidence level")
    key_reasons: List[str] = Field(..., description="Bullet points of key reasons to choose recommendation")
    potential_concerns: List[str] = Field(..., description="Bullet points of potential concerns with recommended loan")
    action_recommendation: str = Field(..., description="Next steps recommendations")

class LoanComparisonResponse(BaseModel):
    """Full side-by-side comparison report schema."""
    loan_a_lender: str = Field(..., description="Lender name of Loan A")
    loan_b_lender: str = Field(..., description="Lender name of Loan B")
    recommended_loan: RecommendedLoanInfo
    comparison_summary: ExecutiveSummary
    financial_breakdown: FinancialBreakdown
    risk_breakdown: RiskComparison
    loan_scores: LoanScores
    recommendation_reasons: List[AIRecommendationReasonItem]
    clause_comparison: List[ClauseComparisonItem]
    charts_data: ChartsData
    final_decision: FinalDecisionCard
    confidence_score: float

from decimal import Decimal
class LoanComparisonResult(BaseModel):
    """Legacy model containing computed differences for test compatibility."""
    cost_difference: Decimal
    interest_difference: Decimal
    risk_difference: str
    recommended_loan: str
    recommendation_reason: str

class LoanComparison(BaseModel):
    """Legacy consolidated model representing side-by-side comparison for test compatibility."""
    loan_a: LoanMetadata
    loan_b: LoanMetadata
    comparison_results: LoanComparisonResult
