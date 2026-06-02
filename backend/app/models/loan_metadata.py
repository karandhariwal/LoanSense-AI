from datetime import date
from decimal import Decimal
from typing import Optional, Literal, Annotated
from pydantic import BaseModel, Field, model_validator, ConfigDict, WithJsonSchema

CustomDecimal = Annotated[
    Decimal,
    WithJsonSchema({"type": "number", "description": "Decimal value represented as a number"})
]



class LoanMetadata(BaseModel):
    """
    Schema for detailed loan agreement metadata extraction.
    Captures financial terms, fees, penalty structures, and key dates.
    """

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "lender_name": "Apex Finance Corp",
                "loan_type": "Home Loan",
                "principal_amount": "5000000.00",
                "sanctioned_amount": "5000000.00",
                "interest_rate": 8.75,
                "interest_type": "floating",
                "tenure_months": 240,
                "emi_amount": "44186.00",
                "processing_fee": "10000.00",
                "documentation_fee": "2500.00",
                "insurance_fee": "15000.00",
                "foreclosure_charges": "2.00",
                "prepayment_charges": "1.50",
                "bounce_charges": "500.00",
                "late_payment_fee": "24.00",
                "disbursal_amount": "4972500.00",
                "repayment_frequency": "monthly",
                "loan_start_date": "2026-06-01",
                "maturity_date": "2046-06-01",
            }
        }
    )

    lender_name: str = Field(
        ...,
        description="The name of the financial institution or lender issuing the loan agreement.",
        min_length=2,
    )

    loan_type: str = Field(
        ...,
        description="The classification of the loan (e.g., Home, Personal, Auto, Education, Business).",
    )

    principal_amount: CustomDecimal = Field(
        ...,
        gt=0,
        description="The principal loan amount requested/agreed upon by the borrower.",
    )

    sanctioned_amount: CustomDecimal = Field(
        ...,
        gt=0,
        description="The total loan amount officially approved/sanctioned by the lender.",
    )

    interest_rate: float = Field(
        ...,
        ge=0.0,
        le=100.0,
        description="The nominal annual interest rate expressed as a percentage (e.g. 8.75).",
    )

    interest_type: Literal["fixed", "floating", "hybrid"] = Field(
        ...,
        description="Mechanism of interest computation: 'fixed' (remains constant), 'floating' (linked to benchmark rates), or 'hybrid'.",
    )

    tenure_months: int = Field(
        ...,
        gt=0,
        description="The amortization period or repayment period of the loan in months.",
    )

    emi_amount: CustomDecimal = Field(
        ...,
        gt=0,
        description="Equated Monthly Installment (EMI) to be paid by the borrower.",
    )

    processing_fee: Optional[CustomDecimal] = Field(
        None,
        ge=0,
        description="Fee charged by the lender for processing the loan application (absolute value or percentage).",
    )

    documentation_fee: Optional[CustomDecimal] = Field(
        None,
        ge=0,
        description="Fee charged for legal verification and loan documentation processing.",
    )

    insurance_fee: Optional[CustomDecimal] = Field(
        None,
        ge=0,
        description="Insurance premium charged for loan coverage/credit shielding.",
    )

    foreclosure_charges: Optional[CustomDecimal] = Field(
        None,
        ge=0,
        description="Penalty charges levied if the borrower pays off the entire loan before maturity.",
    )

    prepayment_charges: Optional[CustomDecimal] = Field(
        None,
        ge=0,
        description="Penalty charges for partial prepayment of the principal amount.",
    )

    bounce_charges: Optional[CustomDecimal] = Field(
        None,
        ge=0,
        description="Flat penalty charge applied when an EMI auto-debit (ACH/ECS) or cheque bounces.",
    )

    late_payment_fee: Optional[CustomDecimal] = Field(
        None,
        ge=0,
        description="Penalty rate or fee applied to overdue EMI payments (could be absolute or annual percentage rate).",
    )

    disbursal_amount: Optional[CustomDecimal] = Field(
        None,
        gt=0,
        description="The actual net amount disbursed to the borrower after deducting processing and insurance fees.",
    )

    repayment_frequency: Literal["monthly", "quarterly", "semi-annually", "annually", "bullet"] = Field(
        "monthly",
        description="The frequency at which loan payments/installments must be paid.",
    )

    loan_start_date: Optional[date] = Field(
        None,
        description="The date of first disbursement or start of the loan repayment timeline.",
    )

    maturity_date: Optional[date] = Field(
        None,
        description="The date on which the final loan payment is due and the loan agreement matures.",
    )

    @model_validator(mode="after")
    def validate_dates_and_amounts(self) -> "LoanMetadata":
        # 1. Date Validation: maturity_date must be after loan_start_date
        if self.loan_start_date and self.maturity_date:
            if self.maturity_date <= self.loan_start_date:
                raise ValueError("Maturity date must be after the loan start date.")

        # 2. Amount Validation: disbursal_amount should not exceed sanctioned_amount
        if self.disbursal_amount and self.sanctioned_amount:
            if self.disbursal_amount > self.sanctioned_amount:
                raise ValueError("Disbursal amount cannot exceed the sanctioned amount.")

        # 3. Principal vs Sanctioned Check (warning/rule)
        if self.principal_amount > self.sanctioned_amount:
            raise ValueError("Requested principal amount cannot exceed the sanctioned amount.")

        return self
