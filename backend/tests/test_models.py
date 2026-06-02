import unittest
from datetime import date
from decimal import Decimal
from pydantic import ValidationError

from app.models.loan_metadata import LoanMetadata
from app.models.risk_clause import RiskClause, RiskLevel, RiskCategory
from app.models.loan_score import LoanSafetyScore, SafetyRating
from app.models.chat_citation import ChatCitation, CitationType, RAGResponse
from app.models.loan_analysis import LoanAnalysisResponse
from app.models.loan_comparison import LoanComparison, LoanComparisonResult
from app.models.api_schemas import (
    AnalysisResponse,
    RisksResponse,
    CompareRequest,
    CompareResponse,
    ChatRequest,
    ChatResponse,
)


class TestLoanSenseModels(unittest.TestCase):
    def setUp(self):
        # Default valid inputs for reusing in tests
        self.valid_metadata_dict = {
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

        self.valid_risk_dict = {
            "clause_id": "clause_interest_rate_hike",
            "clause_title": "Unilateral Floating Rate Adjustment",
            "clause_text": "The Lender reserves the absolute right to modify the margin and/or the Benchmark Rate...",
            "risk_level": RiskLevel.HIGH,
            "category": RiskCategory.INTEREST_RATE_RISK,
            "explanation": "Allows the lender to increase interest rates unilaterally...",
            "page_number": 12,
            "recommendation": "Negotiate to require at least a 30-day prior written notice...",
        }

        self.valid_score_dict = {
            "score": 7.8,
            "rating": SafetyRating.GOOD,
            "strengths": ["Zero prepayment penalty after 12 months"],
            "weaknesses": ["High late payment penalty rate of 24% per annum"],
            "explanation": "Transparent structure with average risk exposure.",
        }

        self.valid_analysis_dict = {
            "metadata": self.valid_metadata_dict,
            "risks": [self.valid_risk_dict],
            "ai_summary": "This is a standard 20-year home loan of $5,000,000 at a floating rate of 8.75%.",
            "loan_score": self.valid_score_dict,
            "confidence_score": 0.94,
            "total_interest": Decimal("5604640.00"),
            "total_payment": Decimal("10604640.00"),
            "effective_apr": 8.92,
            "recommendations": ["Request waiver of foreclosure charges"],
        }

    def test_loan_metadata_valid(self):
        """Test metadata parses correctly with valid data."""
        metadata = LoanMetadata(**self.valid_metadata_dict)
        self.assertEqual(metadata.lender_name, "Apex Finance Corp")
        self.assertEqual(metadata.principal_amount, Decimal("5000000.00"))
        self.assertEqual(metadata.interest_rate, 8.75)

    def test_loan_metadata_invalid_dates(self):
        """Test metadata fails validation when maturity date is before start date."""
        bad_data = self.valid_metadata_dict.copy()
        bad_data["loan_start_date"] = date(2026, 6, 1)
        bad_data["maturity_date"] = date(2025, 6, 1)
        with self.assertRaises(ValidationError):
            LoanMetadata(**bad_data)

    def test_loan_metadata_disbursal_exceeds_sanctioned(self):
        """Test metadata fails validation when disbursal exceeds sanctioned amount."""
        bad_data = self.valid_metadata_dict.copy()
        bad_data["sanctioned_amount"] = Decimal("100000.00")
        bad_data["disbursal_amount"] = Decimal("150000.00")
        with self.assertRaises(ValidationError):
            LoanMetadata(**bad_data)

    def test_loan_metadata_principal_exceeds_sanctioned(self):
        """Test metadata fails validation when requested principal exceeds sanctioned amount."""
        bad_data = self.valid_metadata_dict.copy()
        bad_data["principal_amount"] = Decimal("6000000.00")
        bad_data["sanctioned_amount"] = Decimal("5000000.00")
        with self.assertRaises(ValidationError):
            LoanMetadata(**bad_data)

    def test_risk_clause_valid(self):
        """Test risk clause parses correctly with valid data."""
        risk = RiskClause(**self.valid_risk_dict)
        self.assertEqual(risk.risk_level, RiskLevel.HIGH)
        self.assertEqual(risk.category, RiskCategory.INTEREST_RATE_RISK)

    def test_loan_score_valid(self):
        """Test safety score parses correctly with valid data."""
        score = LoanSafetyScore(**self.valid_score_dict)
        self.assertEqual(score.score, 7.8)
        self.assertEqual(score.rating, SafetyRating.GOOD)

    def test_loan_score_invalid_rating_mismatch(self):
        """Test safety score fails validation when score does not align with rating."""
        bad_data = self.valid_score_dict.copy()
        bad_data["score"] = 2.0  # High Risk range
        bad_data["rating"] = SafetyRating.EXCELLENT  # Mismatched rating
        with self.assertRaises(ValidationError):
            LoanSafetyScore(**bad_data)

    def test_loan_score_bounds(self):
        """Test safety score bounds are enforced (0.0 to 10.0)."""
        bad_data = self.valid_score_dict.copy()
        bad_data["score"] = 10.5
        with self.assertRaises(ValidationError):
            LoanSafetyScore(**bad_data)

    def test_loan_analysis_valid(self):
        """Test analysis response parses correctly with valid data."""
        analysis = LoanAnalysisResponse(**self.valid_analysis_dict)
        self.assertEqual(analysis.effective_apr, 8.92)

    def test_loan_analysis_financial_incoherence(self):
        """Test analysis response fails validation when total payment is less than principal + interest."""
        bad_data = self.valid_analysis_dict.copy()
        bad_data["total_payment"] = Decimal("5000000.00")  # Equal to principal, meaning interest was not included
        with self.assertRaises(ValidationError):
            LoanAnalysisResponse(**bad_data)

    def test_loan_comparison_valid(self):
        """Test loan comparison schema validation."""
        comp_results = {
            "cost_difference": Decimal("-250000.00"),
            "interest_difference": Decimal("-240000.00"),
            "risk_difference": "Loan A has lower fees...",
            "recommended_loan": "Loan A",
            "recommendation_reason": "Cheaper and less risky",
        }
        comparison = LoanComparison(
            loan_a=self.valid_metadata_dict,
            loan_b=self.valid_metadata_dict,
            comparison_results=comp_results,
        )
        self.assertEqual(comparison.comparison_results.recommended_loan, "Loan A")

    def test_chat_citation_and_rag_response(self):
        """Test chat citation and RAG response structures."""
        citation = ChatCitation(
            page_number=8,
            source_text="Clause 7.2 details early prepayment terms.",
            confidence=0.95,
            citation_type=CitationType.LEGAL_PROVISION,
        )
        rag = RAGResponse(
            answer="Yes, it does.",
            citations=[citation],
            confidence_score=0.96,
            source_references=["Agreement_V2.pdf"],
            supporting_clauses=["Clause 7.2"]
        )
        self.assertEqual(len(rag.citations), 1)
        self.assertEqual(rag.citations[0].page_number, 8)
        self.assertEqual(rag.source_references[0], "Agreement_V2.pdf")
        self.assertEqual(rag.supporting_clauses[0], "Clause 7.2")

    def test_api_schemas(self):
        """Test API request and response parsing."""
        analysis_resp = AnalysisResponse(
            loan_id="loan-123",
            status="success",
            analysis=self.valid_analysis_dict,
        )
        self.assertEqual(analysis_resp.loan_id, "loan-123")

        risks_resp = RisksResponse(
            loan_id="loan-123",
            risks=[self.valid_risk_dict],
            total_risks=1,
            high_risks_count=1,
            medium_risks_count=0,
            low_risks_count=0,
        )
        self.assertEqual(risks_resp.high_risks_count, 1)

        compare_req = CompareRequest(loan_id_a="loan-123", loan_id_b="loan-456")
        self.assertEqual(compare_req.loan_id_a, "loan-123")

        chat_req = ChatRequest(query="Is this loan safe?", history=[])
        self.assertEqual(chat_req.query, "Is this loan safe?")


if __name__ == "__main__":
    unittest.main()
