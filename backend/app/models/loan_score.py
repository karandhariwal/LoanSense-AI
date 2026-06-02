from enum import Enum
from typing import List
from pydantic import BaseModel, Field, model_validator, ConfigDict


class SafetyRating(str, Enum):
    """Qualitative ratings reflecting the safety of the loan agreement terms."""

    EXCELLENT = "Excellent"
    GOOD = "Good"
    MODERATE = "Moderate"
    RISKY = "Risky"
    HIGH_RISK = "High Risk"


class LoanSafetyScore(BaseModel):
    """
    Dedicated model for scoring and rating the overall safety and borrower-friendliness of the loan agreement.
    """

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "score": 7.8,
                "rating": "Good",
                "strengths": [
                    "Zero prepayment penalty after 12 months",
                    "Interest rate tied directly to repo rate",
                ],
                "weaknesses": [
                    "High late payment penalty rate of 24% per annum",
                    "Mandatory arbitration clause in lender's home city",
                ],
                "explanation": "The loan has transparent interest rate mechanisms and fair prepayment terms, but contains high penalty fees for delayed payments and a restrictive legal jurisdiction clause.",
            }
        }
    )

    score: float = Field(
        ...,
        ge=0.0,
        le=10.0,
        description="Numerical safety score ranging from 0.0 (highly risky/unfavorable) to 10.0 (completely safe/favorable).",
    )

    rating: SafetyRating = Field(
        ...,
        description="Qualitative rating mapped from the safety score.",
    )

    strengths: List[str] = Field(
        default_factory=list,
        description="List of positive, consumer-friendly aspects or clauses extracted from the loan agreement.",
    )

    weaknesses: List[str] = Field(
        default_factory=list,
        description="List of restrictive, expensive, or high-risk features extracted from the loan agreement.",
    )

    explanation: str = Field(
        ...,
        description="Comprehensive analysis explanation justifying the score and rating mapping.",
    )

    @model_validator(mode="after")
    def validate_score_rating_consistency(self) -> "LoanSafetyScore":
        # Ensure the score corresponds to the rating range to guarantee data consistency
        s = self.score
        r = self.rating

        expected_rating = None
        if 8.5 <= s <= 10.0:
            expected_rating = SafetyRating.EXCELLENT
        elif 7.0 <= s < 8.5:
            expected_rating = SafetyRating.GOOD
        elif 5.0 <= s < 7.0:
            expected_rating = SafetyRating.MODERATE
        elif 3.0 <= s < 5.0:
            expected_rating = SafetyRating.RISKY
        else:
            expected_rating = SafetyRating.HIGH_RISK

        # If the LLM generates a slightly different rating but close, we can just allow it,
        # but if it violates basic sanity, we throw a value error.
        # Let's verify that the rating isn't wildly off (e.g. score of 9.0 and rating of High Risk).
        if r != expected_rating:
            # We can print a warning or raise a ValueError for strict alignment
            # Let's enforce strict validation for production quality
            raise ValueError(
                f"Rating '{r.value}' does not match the safety score range for score {s}. "
                f"Expected rating for this score is '{expected_rating.value}'."
            )

        return self
