from decimal import Decimal
import logging
from typing import List, Optional
import numpy_financial as npf
from app.services.configuration_service import config_service

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
        base_score: Optional[float] = None
    ) -> float:
        """
        Deterministic safety score calculator.

        Scoring model:
          1. Each risk clause has a base penalty by severity:
               HIGH   → -1.5  (configurable via RISK_PENALTY_HIGH)
               MEDIUM → -0.75 (configurable via RISK_PENALTY_MEDIUM)
               LOW    → -0.25 (configurable via RISK_PENALTY_LOW)

          2. The base penalty is multiplied by a category severity factor:
               Legal Discretion  → ×1.5  (unilateral term changes / loan recall)
               Interest Rate Risk → ×1.3  (benchmark manipulation)
               Repayment Risk    → ×1.2  (amortization tricks)
               Hidden Charges    → ×1.1  (vague fee clauses)
               Penalty Charges   → ×1.0  (standard)
               Foreclosure Risk  → ×0.9  (prepayment lock-in)
               Insurance Risk    → ×0.8  (mandatory insurance)

          3. Final score = base_score + sum(penalty × category_multiplier)
             Clamped to [minimum_score, base_score].

        This formula is fully deterministic: same document → same risks → same score.
        """
        # Category severity multipliers
        CATEGORY_MULTIPLIERS = {
            "legal discretion": 1.5,
            "interest rate risk": 1.3,
            "repayment risk": 1.2,
            "hidden charges": 1.1,
            "penalty charges": 1.0,
            "foreclosure risk": 0.9,
            "insurance risk": 0.8,
        }

        # Load configuration
        weights = config_service.risk_weights
        if base_score is None:
            base_score = weights.base_score

        score = base_score
        for risk in risks:
            # Support both dict and RiskClause object
            risk_level = (
                risk.get("risk_level") if isinstance(risk, dict)
                else getattr(risk, "risk_level", None)
            )
            category = (
                risk.get("category", "") if isinstance(risk, dict)
                else getattr(risk, "category", "")
            )
            if not risk_level:
                continue

            level_str = risk_level.value if hasattr(risk_level, "value") else str(risk_level)
            level_upper = level_str.upper()
            category_lower = (category or "").lower().strip()

            # Base penalty by severity level
            if level_upper == "HIGH":
                base_penalty = weights.high_risk_penalty      # negative, e.g. -1.5
            elif level_upper == "MEDIUM":
                base_penalty = weights.medium_risk_penalty    # negative, e.g. -0.75
            elif level_upper == "LOW":
                base_penalty = weights.low_risk_penalty       # negative, e.g. -0.25
            else:
                continue

            # Apply category severity multiplier
            multiplier = CATEGORY_MULTIPLIERS.get(category_lower, 1.0)
            score += base_penalty * multiplier

        # Clamp between minimum and base (maximum)
        return max(weights.minimum_score, min(weights.base_score, round(score, 1)))

    @staticmethod
    def get_safety_rating_label(score: float) -> str:
        """
        Return the safety rating label for a given score using the same
        thresholds as SafetyScorer._determine_correct_rating().
        This ensures consistent labels across analysis and comparison screens.

        Returns: 'Excellent', 'Good', 'Moderate', 'Risky', or 'High Risk'
        """
        thresholds = config_service.safety_thresholds
        if thresholds.excellent_min <= score <= thresholds.excellent_max:
            return "Excellent"
        elif thresholds.good_min <= score < thresholds.good_max:
            return "Good"
        elif thresholds.moderate_min <= score < thresholds.moderate_max:
            return "Moderate"
        elif thresholds.risky_min <= score < thresholds.risky_max:
            return "Risky"
        else:
            return "High Risk"

# Let's import numpy to check for NaN in numpy_financial results
import numpy as np
