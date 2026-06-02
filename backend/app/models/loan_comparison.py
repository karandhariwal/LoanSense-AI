from decimal import Decimal
from typing import Literal
from pydantic import BaseModel, Field, ConfigDict
from .loan_metadata import LoanMetadata


class LoanComparisonResult(BaseModel):
    """
    Model containing the computed financial and risk comparison differences between two loans.
    """

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "cost_difference": "-250000.00",
                "interest_difference": "-240000.00",
                "risk_difference": "Loan A has lower late payment fees (18% vs 24% in Loan B) and zero foreclosure charges, whereas Loan B has a 2% foreclosure penalty.",
                "recommended_loan": "Loan A",
                "recommendation_reason": "Loan A is financially cheaper by $250,000 in total cost and presents a significantly lower penalty risk profile.",
            }
        }
    )

    cost_difference: Decimal = Field(
        ...,
        description="The net difference in total cost between Loan A and Loan B (Total Cost A - Total Cost B). A negative value means Loan A is cheaper.",
    )

    interest_difference: Decimal = Field(
        ...,
        description="The net difference in total interest payable between Loan A and Loan B. A negative value means Loan A is cheaper in interest.",
    )

    risk_difference: str = Field(
        ...,
        description="A qualitative explanation of the difference in risk profiles and hidden clauses between the two loans.",
        min_length=10,
    )

    recommended_loan: Literal["Loan A", "Loan B", "None"] = Field(
        ...,
        description="The loan recommended by the AI: 'Loan A', 'Loan B', or 'None' if they are equivalent or both risky.",
    )

    recommendation_reason: str = Field(
        ...,
        description="Detailed explanation justifying the AI recommendation based on costs, fees, and clause safety.",
        min_length=15,
    )


class LoanComparison(BaseModel):
    """
    Consolidated model representing a side-by-side comparison between Loan A and Loan B.
    """

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "loan_a": {
                    "lender_name": "Apex Finance Corp",
                    "loan_type": "Home Loan",
                    "principal_amount": "5000000.00",
                    "sanctioned_amount": "5000000.00",
                    "interest_rate": 8.75,
                    "interest_type": "floating",
                    "tenure_months": 240,
                    "emi_amount": "44186.00",
                },
                "loan_b": {
                    "lender_name": "Summit Credits",
                    "loan_type": "Home Loan",
                    "principal_amount": "5000000.00",
                    "sanctioned_amount": "5000000.00",
                    "interest_rate": 9.25,
                    "interest_type": "fixed",
                    "tenure_months": 240,
                    "emi_amount": "45820.00",
                },
                "comparison_results": {
                    "cost_difference": "-392160.00",
                    "interest_difference": "-392160.00",
                    "risk_difference": "Loan A is floating rate, while Loan B is a fixed rate. Loan A offers lower overall interest but exposes the borrower to interest rate fluctuation risks.",
                    "recommended_loan": "Loan A",
                    "recommendation_reason": "Loan A is cheaper by $392,160 over the tenure, although it has a floating rate. Recommend Loan A if the interest rate market is stable.",
                },
            }
        }
    )

    loan_a: LoanMetadata = Field(
        ...,
        description="Metadata of the first loan (Loan A).",
    )

    loan_b: LoanMetadata = Field(
        ...,
        description="Metadata of the second loan (Loan B).",
    )

    comparison_results: LoanComparisonResult = Field(
        ...,
        description="Computed cost and risk differences between the two loans.",
    )
