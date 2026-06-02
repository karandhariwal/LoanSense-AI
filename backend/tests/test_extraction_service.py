import unittest
import asyncio
from unittest.mock import AsyncMock, MagicMock, patch
from decimal import Decimal
from datetime import date
from pydantic import ValidationError

from app.models.loan_metadata import LoanMetadata
from app.models.risk_clause import RiskClause, RiskLevel, RiskCategory
from app.models.loan_score import LoanSafetyScore, SafetyRating
from app.models.loan_analysis import LoanAnalysisResponse

from app.services.calculations import LoanCalculator
from app.services.ai.risk_detector import RiskDetector, RiskClauseList
from app.services.ai.summary_generator import SummaryGenerator
from app.services.ai.safety_scorer import SafetyScorer
from app.services.ai.extraction_service import (
    LoanExtractionService,
    EmptyDocumentError,
    LLMTimeoutError,
    SchemaValidationError
)

class TestExtractionServiceAndCalculations(unittest.TestCase):

    def setUp(self):
        # 1. Setup mock metadata dict
        self.mock_metadata_dict = {
            "lender_name": "Apex Finance Corp",
            "loan_type": "Home Loan",
            "principal_amount": Decimal("5000000.00"),
            "sanctioned_amount": Decimal("5000000.00"),
            "interest_rate": 8.75,
            "interest_type": "floating",
            "tenure_months": 240,
            "emi_amount": Decimal("44186.00"),
            "processing_fee": Decimal("10000.00"),
            "documentation_fee": Decimal("2500.00"),
            "insurance_fee": Decimal("15000.00"),
            "foreclosure_charges": Decimal("2.00"),
            "prepayment_charges": Decimal("1.50"),
            "bounce_charges": Decimal("500.00"),
            "late_payment_fee": Decimal("24.00"),
            "disbursal_amount": Decimal("4972500.00"),
            "repayment_frequency": "monthly",
            "loan_start_date": date(2026, 6, 1),
            "maturity_date": date(2046, 6, 1),
        }
        self.metadata_obj = LoanMetadata(**self.mock_metadata_dict)

        # 2. Setup mock risk dict
        self.mock_risk_dict = {
            "clause_id": "clause_interest_rate_hike",
            "clause_title": "Unilateral Floating Rate Adjustment",
            "clause_text": "The Lender reserves the absolute right to modify the margin and/or the Benchmark Rate...",
            "risk_level": RiskLevel.HIGH,
            "category": RiskCategory.INTEREST_RATE_RISK,
            "explanation": "Allows the lender to increase interest rates unilaterally...",
            "page_number": 12,
            "recommendation": "Negotiate to require at least a 30-day prior written notice...",
        }
        self.risk_obj = RiskClause(**self.mock_risk_dict)

        # 3. Setup mock safety score dict
        self.mock_score_dict = {
            "score": 7.8,
            "rating": SafetyRating.GOOD,
            "strengths": ["Zero prepayment penalty after 12 months"],
            "weaknesses": ["High late payment penalty rate of 24% per annum"],
            "explanation": "Transparent structure with average risk exposure.",
        }
        self.score_obj = LoanSafetyScore(**self.mock_score_dict)

    # =====================================================================
    # 1. CALCULATIONS ENGINE TESTS
    # =====================================================================

    def test_calculate_emi(self):
        """Test EMI calculations matching standard formula."""
        emi = LoanCalculator.calculate_emi(Decimal("100000.00"), 12.0, 12)
        # Amortization check for 12% annual rate on 100k principal over 12 months is ~8884.88
        self.assertAlmostEqual(float(emi), 8884.88, places=1)

        # Check boundary/error values
        self.assertEqual(LoanCalculator.calculate_emi(Decimal("0.00"), 10.0, 24), Decimal("0.00"))
        self.assertEqual(LoanCalculator.calculate_emi(Decimal("10000.00"), 0.0, 10), Decimal("1000.00"))

    def test_calculate_total_interest(self):
        """Test total interest payable calculation."""
        interest = LoanCalculator.calculate_total_interest(
            principal=Decimal("100000.00"),
            tenure_months=12,
            emi=Decimal("8884.88")
        )
        # Expected: 8884.88 * 12 - 100000 = 6618.56
        self.assertEqual(interest, Decimal("6618.56"))

    def test_calculate_total_payment(self):
        """Test total payments calculation including fees."""
        total = LoanCalculator.calculate_total_payment(
            principal=Decimal("100000.00"),
            total_interest=Decimal("6618.56"),
            processing_fee=Decimal("1000.00"),
            documentation_fee=Decimal("500.00"),
            insurance_fee=Decimal("1500.00")
        )
        # Expected: 100000 + 6618.56 + 1000 + 500 + 1500 = 109618.56
        self.assertEqual(total, Decimal("109618.56"))

    def test_calculate_effective_apr(self):
        """Test effective APR with fees is greater than nominal rate."""
        # Principal: 100000, EMI: 8884.88, Tenure: 12, Upfront fees: 3000
        apr = LoanCalculator.calculate_effective_apr(
            principal=Decimal("100000.00"),
            emi=Decimal("8884.88"),
            tenure_months=12,
            processing_fee=Decimal("1000.00"),
            documentation_fee=Decimal("500.00"),
            insurance_fee=Decimal("1500.00")
        )
        # APR should be significantly higher than nominal 12% because of $3000 fees upfront
        self.assertTrue(apr > 12.0)

    def test_calculate_safety_score_heuristic(self):
        """Test safety score deductions."""
        # Base is 10.0
        # High risk (-1.5), Medium risk (-0.75), Low risk (-0.25)
        risks = [
            {"risk_level": "HIGH"},
            {"risk_level": "MEDIUM"},
            {"risk_level": "LOW"}
        ]
        score = LoanCalculator.calculate_safety_score(risks)
        # 10.0 - 1.5 - 0.75 - 0.25 = 7.5
        self.assertEqual(score, 7.5)

    # =====================================================================
    # 2. RISK DETECTOR TESTS
    # =====================================================================

    @patch("app.services.ai.risk_detector.RiskDetector.__init__", return_value=None)
    def test_risk_detector_empty_text(self, mock_init):
        detector = RiskDetector()
        res = asyncio.run(detector.detect_risks(""))
        self.assertEqual(res, [])

    @patch("app.services.ai.risk_detector.RiskDetector.__init__", return_value=None)
    def test_risk_detector_success(self, mock_init):
        detector = RiskDetector()
        # Mock structured chain
        mock_response = RiskClauseList(risks=[self.risk_obj])
        detector.chain = AsyncMock()
        detector.chain.ainvoke.return_value = mock_response

        res = asyncio.run(detector.detect_risks("Sample Text"))
        self.assertEqual(len(res), 1)
        self.assertEqual(res[0].clause_id, "clause_interest_rate_hike")

    # =====================================================================
    # 3. SAFETY SCORER TESTS WITH ERROR RECOVERY
    # =====================================================================

    @patch("app.services.ai.safety_scorer.SafetyScorer.__init__", return_value=None)
    def test_safety_scorer_pydantic_validation_recovery(self, mock_init):
        """Test safety scorer triggers raw recovery when validation fails (e.g. score rating mismatch)."""
        scorer = SafetyScorer()
        scorer.chain = AsyncMock()
        # Throw ValidationError to simulate score rating mismatch
        scorer.chain.ainvoke.side_effect = ValidationError.from_exception_data(
            title="LoanSafetyScore",
            line_errors=[]
        )

        # Mock the recovery method
        mock_recovered_score = LoanSafetyScore(
            score=2.0,
            rating=SafetyRating.HIGH_RISK,  # Fixed rating aligned with 2.0 score
            strengths=[],
            weaknesses=["High default fee"],
            explanation="Recovered successfully."
        )
        scorer._recover_safety_score_raw = AsyncMock(return_value=mock_recovered_score)

        res = asyncio.run(scorer.generate_safety_score("Sample context", "Extracted metadata", []))
        
        self.assertEqual(res.score, 2.0)
        self.assertEqual(res.rating, SafetyRating.HIGH_RISK)
        scorer._recover_safety_score_raw.assert_called_once()

    # =====================================================================
    # 4. EXTRACTION SERVICE ORCHESTRATION TESTS
    # =====================================================================

    @patch("app.services.ai.extraction_service.ChatNVIDIA")
    def test_extraction_service_empty_document(self, mock_chat_nvidia):
        service = LoanExtractionService()
        
        with self.assertRaises(EmptyDocumentError):
            asyncio.run(service.analyze_document("   "))

    def test_extraction_service_full_pipeline_success(self):
        """Test that the full orchestration executes correctly with all subsystems mocked."""
        # 1. Instantiate Mocks
        mock_llm = MagicMock()
        mock_detector = MagicMock(spec=RiskDetector)
        mock_summary = MagicMock(spec=SummaryGenerator)
        mock_scorer = MagicMock(spec=SafetyScorer)
        mock_calculator = MagicMock(spec=LoanCalculator)

        # 2. Setup AsyncMock returns
        mock_detector.detect_risks = AsyncMock(return_value=[self.risk_obj])
        mock_summary.generate_summary = AsyncMock(return_value="Detailed friendly summary of 180 words.")
        mock_scorer.generate_safety_score = AsyncMock(return_value=self.score_obj)

        # 3. Setup calculator returns
        mock_calculator.calculate_total_interest.return_value = Decimal("5604640.00")
        mock_calculator.calculate_total_payment.return_value = Decimal("10604640.00")
        mock_calculator.calculate_effective_apr.return_value = 8.92

        # 4. Setup metadata chain mock in extraction service init
        with patch.object(LoanExtractionService, "_extract_metadata", new_callable=AsyncMock) as mock_extract_meta:
            mock_extract_meta.return_value = self.metadata_obj

            service = LoanExtractionService(
                llm=mock_llm,
                calculator=mock_calculator,
                risk_detector=mock_detector,
                summary_generator=mock_summary,
                safety_scorer=mock_scorer
            )

            # 5. Execute Pipeline
            response = asyncio.run(service.analyze_document("This is sample loan agreement text."))
            
            # 6. Verify Results
            self.assertIsInstance(response, LoanAnalysisResponse)
            self.assertEqual(response.metadata.lender_name, "Apex Finance Corp")
            self.assertEqual(len(response.risks), 1)
            self.assertEqual(response.effective_apr, 8.92)
            self.assertEqual(response.confidence_score, 1.0)  # All metadata present + no validation errors
            self.assertTrue(len(response.recommendations) > 0)


if __name__ == "__main__":
    unittest.main()
