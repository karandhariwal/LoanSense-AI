from decimal import Decimal
import logging
from typing import List, Optional
import numpy_financial as npf

logger = logging.getLogger(__name__)

class LoanCalculator:
    """
    Dedicated calculation engine for loan analytics.
    Handles amortization, interest computation, APR solver, and rule-based safety scoring.
    """

    @staticmethod
    def calculate_emi(principal: Decimal, annual_rate: float, tenure_months: int) -> Decimal:
        """
        Calculate Equated Monthly Installment (EMI) using the standard formula:
        EMI = P * r * (1 + r)^n / ((1 + r)^n - 1)
        """
        try:
            if principal <= 0 or tenure_months <= 0:
                return Decimal("0.00")
            if annual_rate <= 0:
                return Decimal(round(principal / tenure_months, 2))

            r = (annual_rate / 12.0) / 100.0
            p = float(principal)
            n = tenure_months

            emi = p * r * ((1 + r) ** n) / (((1 + r) ** n) - 1)
            return Decimal(f"{emi:.2f}")
        except Exception as e:
            logger.error(f"Error calculating EMI: {e}")
            return Decimal("0.00")

    @staticmethod
    def calculate_total_payment(
        principal: Decimal,
        total_interest: Decimal,
        processing_fee: Optional[Decimal] = None,
        documentation_fee: Optional[Decimal] = None,
        insurance_fee: Optional[Decimal] = None
    ) -> Decimal:
        """
        Calculate the total payment over the loan tenure including all fees.
        Total Payment = Principal + Total Interest + processing_fee + documentation_fee + insurance_fee
        """
        total = principal + total_interest
        if processing_fee:
            total += processing_fee
        if documentation_fee:
            total += documentation_fee
        if insurance_fee:
            total += insurance_fee
        return Decimal(f"{total:.2f}")

    @staticmethod
    def calculate_total_interest(
        principal: Decimal,
        tenure_months: int,
        emi: Decimal
    ) -> Decimal:
        """
        Calculate total interest payable.
        Total Interest = (EMI * tenure) - Principal
        """
        if principal <= 0 or tenure_months <= 0 or emi <= 0:
            return Decimal("0.00")
        total_interest = (emi * tenure_months) - principal
        return Decimal(f"{max(Decimal('0.00'), total_interest):.2f}")

    @staticmethod
    def calculate_effective_apr(
        principal: Decimal,
        emi: Decimal,
        tenure_months: int,
        processing_fee: Optional[Decimal] = None,
        documentation_fee: Optional[Decimal] = None,
        insurance_fee: Optional[Decimal] = None,
        nominal_rate: Optional[float] = None
    ) -> float:
        """
        Calculate the Effective Annual Percentage Rate (APR) by solving for the
        internal rate of return (IRR) using numpy-financial.

        Cash flow convention (borrower's perspective):
          Period 0 : +net_principal  (positive — money received after upfront fees)
          Periods 1..n: -emi         (negative — money paid out each month)

        npf.rate(nper, pmt, pv) convention:
          pv  = present value of the loan (positive, as money received by borrower)
          pmt = periodic payment (negative, as cash outflow)
          fv  = 0 (loan is fully repaid)

        Monthly rate r is then annualized as: APR = ((1 + r)^12 - 1) * 100
        """
        try:
            if principal <= 0 or tenure_months <= 0 or emi <= 0:
                return float(nominal_rate) if nominal_rate else 0.0

            # Net amount actually received by borrower (upfront fees deducted)
            upfront_fees = Decimal("0.00")
            if processing_fee and processing_fee > 0:
                upfront_fees += processing_fee
            if documentation_fee and documentation_fee > 0:
                upfront_fees += documentation_fee
            if insurance_fee and insurance_fee > 0:
                upfront_fees += insurance_fee

            net_principal = float(principal - upfront_fees)
            if net_principal <= 0:
                return float(nominal_rate) if nominal_rate else 0.0

            monthly_emi = float(emi)

            # Solve for monthly rate:
            #   pv  = net_principal  (positive: loan amount received)
            #   pmt = -monthly_emi   (negative: monthly outflow)
            monthly_rate = npf.rate(
                nper=tenure_months,
                pmt=-monthly_emi,
                pv=net_principal,
                fv=0.0
            )

            if monthly_rate is None or np.isnan(monthly_rate) or monthly_rate <= 0:
                # Solver failed or returned nonsense; fall back to simple APR
                total_cost = float(emi * tenure_months - principal + upfront_fees)
                tenure_years = tenure_months / 12.0
                simple_apr = (total_cost / float(principal)) / tenure_years * 100.0
                apr = round(float(simple_apr), 2)
            else:
                # Compound annualization: EAR = (1 + monthly_rate)^12 - 1
                apr = round(float(((1 + monthly_rate) ** 12 - 1) * 100), 2)

            # Sanity check: APR should not be implausibly far from nominal rate.
            # If it is, fall back to the nominal rate to prevent downstream failures.
            if nominal_rate and nominal_rate > 0:
                if apr < (nominal_rate * 0.5) or apr > (nominal_rate * 3.0):
                    logger.warning(
                        f"Calculated APR ({apr}%) is implausible vs nominal rate "
                        f"({nominal_rate}%). Falling back to nominal rate."
                    )
                    return round(float(nominal_rate), 2)

            return apr

        except Exception as e:
            logger.error(f"Error calculating Effective APR: {e}")
            return round(float(nominal_rate), 2) if nominal_rate else 0.0

    @staticmethod
    def calculate_safety_score(
        risks: List[dict],
        base_score: float = 10.0
    ) -> float:
        """
        Heuristic calculator to compute a rule-based safety score.
        Deducts points based on risk levels of clauses:
          HIGH risk: -1.5 points each
          MEDIUM risk: -0.75 points each
          LOW risk: -0.25 points each
        Caps the final score between 0.0 and 10.0.
        """
        score = base_score
        for risk in risks:
            # risk can be a dictionary or a RiskClause object
            risk_level = risk.get("risk_level") if isinstance(risk, dict) else getattr(risk, "risk_level", None)
            if not risk_level:
                continue
            
            # RiskLevel Enum comparison (handle string or Enum)
            level_str = risk_level.value if hasattr(risk_level, "value") else str(risk_level)
            level_upper = level_str.upper()

            if level_upper == "HIGH":
                score -= 1.5
            elif level_upper == "MEDIUM":
                score -= 0.75
            elif level_upper == "LOW":
                score -= 0.25

        return max(0.0, min(10.0, round(score, 1)))

# Let's import numpy to check for NaN in numpy_financial results
import numpy as np
