from enum import Enum
from pydantic import BaseModel, Field, ConfigDict


class RiskLevel(str, Enum):
    """Enumeration of loan risk severity levels."""

    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"


class RiskCategory(str, Enum):
    """Enumeration of clause categories subject to risk evaluation."""

    INTEREST_RATE_RISK = "Interest Rate Risk"
    FORECLOSURE_RISK = "Foreclosure Risk"
    INSURANCE_RISK = "Insurance Risk"
    HIDDEN_CHARGES = "Hidden Charges"
    PENALTY_CHARGES = "Penalty Charges"
    LEGAL_DISCRETION = "Legal Discretion"
    REPAYMENT_RISK = "Repayment Risk"


class RiskClause(BaseModel):
    """
    Model representing a specific high-risk clause identified in the loan agreement.
    Provides citation details, AI explanation, and recommendations.
    """

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "clause_id": "clause_interest_rate_hike",
                "clause_title": "Unilateral Floating Rate Adjustment",
                "clause_text": "The Lender reserves the absolute right to modify the margin and/or the Benchmark Rate at any time without prior notice to the Borrower, and such revision shall be binding on the Borrower.",
                "risk_level": "HIGH",
                "category": "Interest Rate Risk",
                "explanation": "This clause allows the lender to increase interest rates arbitrarily and unilaterally without notifying you. This can result in a significant spike in EMI size or loan tenure.",
                "page_number": 12,
                "recommendation": "Negotiate to require at least a 30-day prior written notice before any rate change, and link rate hikes to an objective external benchmark like RBI repo rate.",
            }
        }
    )

    clause_id: str = Field(
        ...,
        description="A unique alphanumeric identifier for the risk clause (e.g. clause_interest_rate_01).",
    )

    clause_title: str = Field(
        ...,
        description="A short, descriptive title of the risk identified in the clause.",
        min_length=3,
    )

    clause_text: str = Field(
        ...,
        description="The exact verbatim text extracted from the loan agreement document.",
        min_length=10,
    )

    risk_level: RiskLevel = Field(
        ...,
        description="The severity level of the risk associated with this clause (LOW, MEDIUM, HIGH).",
    )

    category: RiskCategory = Field(
        ...,
        description="The category of risk this clause falls under.",
    )

    explanation: str = Field(
        ...,
        description="AI-generated explanation detailing why this clause is risky and its potential financial impact.",
    )

    page_number: int = Field(
        ...,
        ge=1,
        description="The 1-indexed page number in the PDF document where the clause resides.",
    )

    recommendation: str = Field(
        ...,
        description="Actionable mitigation strategies or advice for negotiating or handling this clause.",
    )
