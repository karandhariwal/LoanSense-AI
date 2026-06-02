import unittest
from fastapi.testclient import TestClient
from decimal import Decimal
from datetime import date
from unittest.mock import AsyncMock, MagicMock

from app.main import app
from app.api.deps import get_extraction_service, get_chat_service, get_comparison_service
from app.models.loan_analysis import LoanAnalysisResponse
from app.models.loan_metadata import LoanMetadata
from app.models.loan_score import LoanSafetyScore, SafetyRating
from app.models.risk_clause import RiskClause, RiskLevel, RiskCategory
from app.models.api_schemas import (
    AnalysisResponse,
    RisksResponse,
    CompareResponse,
    ChatResponse,
)
from app.models.loan_comparison import LoanComparison, LoanComparisonResult
from app.models.chat_citation import ChatCitation, CitationType

import uuid
from app.database.session import get_db
from app.database.models import LoanReport
from app.database.enums import ProcessingStatus

class TestLoanSenseAPI(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(app)
        
        # Reset dependency overrides
        app.dependency_overrides = {}
        
        self.mock_db = MagicMock()
        app.dependency_overrides[get_db] = lambda: self.mock_db

        # Setup standard mock objects for reuse
        self.mock_metadata = LoanMetadata(
            lender_name="Mock Bank",
            loan_type="Home Loan",
            principal_amount=Decimal("100000.00"),
            sanctioned_amount=Decimal("100000.00"),
            interest_rate=10.0,
            interest_type="fixed",
            tenure_months=12,
            emi_amount=Decimal("8791.59"),
            processing_fee=Decimal("1000.00"),
            documentation_fee=Decimal("200.00"),
            insurance_fee=Decimal("800.00"),
            foreclosure_charges=Decimal("2.00"),
            prepayment_charges=Decimal("1.00"),
            bounce_charges=Decimal("500.00"),
            late_payment_fee=Decimal("24.00"),
            disbursal_amount=Decimal("98000.00"),
            repayment_frequency="monthly",
            loan_start_date=date(2026, 6, 1),
            maturity_date=date(2027, 6, 1),
        )

        self.mock_risk = RiskClause(
            clause_id="clause_prepayment",
            clause_title="Prepayment Charge",
            clause_text="A prepayment charge of 1% is applicable...",
            risk_level=RiskLevel.MEDIUM,
            category=RiskCategory.FORECLOSURE_RISK,
            explanation="Charging fee on prepayment restricts freedom.",
            page_number=3,
            recommendation="Request waiver.",
        )

        self.mock_score = LoanSafetyScore(
            score=8.0,
            rating=SafetyRating.GOOD,
            strengths=["Fixed interest rate"],
            weaknesses=["Prepayment penalty"],
            explanation="A good loan overall.",
        )

        self.mock_analysis = LoanAnalysisResponse(
            metadata=self.mock_metadata,
            risks=[self.mock_risk],
            ai_summary="This is a summary of the mock loan.",
            loan_score=self.mock_score,
            confidence_score=0.95,
            total_interest=Decimal("5499.08"),
            total_payment=Decimal("107499.08"),
            effective_apr=12.5,
            recommendations=["Negotiate processing fee"],
        )

    def test_root_endpoint(self):
        """Test GET / returns welcome message."""
        response = self.client.get("/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"message": "Welcome to LoanSense AI API"})

    def test_analysis_endpoint_success(self):
        """Test GET /analysis/{loan_id} successfully fetches and returns completed analysis."""
        loan_uuid_str = "8a7b3c2d-1a2b-3c4d-5e6f-7a8b9c0d1e2f"
        mock_report = LoanReport(
            loan_id=uuid.UUID(loan_uuid_str),
            status=ProcessingStatus.COMPLETED,
            lender_name="Mock Bank",
            loan_type="Home Loan",
            principal_amount=Decimal("100000.00"),
            analysis_json=self.mock_analysis.model_dump(mode="json")
        )
        self.mock_db.query.return_value.filter.return_value.first.return_value = mock_report

        response = self.client.get(f"/analysis/{loan_uuid_str}")
        self.assertEqual(response.status_code, 200)
        
        data = response.json()
        self.assertEqual(data["loan_id"], loan_uuid_str)
        self.assertEqual(data["status"], "COMPLETED")
        self.assertEqual(data["analysis"]["metadata"]["lender_name"], "Mock Bank")
        self.assertEqual(len(data["analysis"]["risks"]), 1)

    def test_analysis_endpoint_not_found(self):
        """Test GET /analysis/{loan_id} returns 404 if report is not in database."""
        loan_uuid_str = "00000000-0000-0000-0000-000000000000"
        self.mock_db.query.return_value.filter.return_value.first.return_value = None

        response = self.client.get(f"/analysis/{loan_uuid_str}")
        self.assertEqual(response.status_code, 404)
        self.assertIn("not found", response.json()["detail"].lower())

    def test_risks_endpoint_success(self):
        """Test GET /risks/{loan_id} calculates risk metrics correctly."""
        mock_service = MagicMock()
        mock_analysis_response = AnalysisResponse(
            loan_id="test-loan-id",
            status="COMPLETED",
            analysis=self.mock_analysis
        )
        
        # Override analysis helper
        with unittest.mock.patch("app.api.risks.get_loan_analysis", new_callable=AsyncMock) as mock_get_analysis:
            mock_get_analysis.return_value = mock_analysis_response

            response = self.client.get("/risks/test-loan-id")
            self.assertEqual(response.status_code, 200)
            
            data = response.json()
            self.assertEqual(data["loan_id"], "test-loan-id")
            self.assertEqual(data["total_risks"], 1)
            self.assertEqual(data["high_risks_count"], 0)
            self.assertEqual(data["medium_risks_count"], 1)
            self.assertEqual(data["low_risks_count"], 0)
            self.assertEqual(data["risks"][0]["clause_id"], "clause_prepayment")

    def test_compare_endpoint_success(self):
        """Test POST /compare runs comparison successfully."""
        mock_comp_service = MagicMock()
        
        mock_comparison = LoanComparison(
            loan_a=self.mock_metadata,
            loan_b=self.mock_metadata,
            comparison_results=LoanComparisonResult(
                cost_difference=Decimal("0.00"),
                interest_difference=Decimal("0.00"),
                risk_difference="No risk differences.",
                recommended_loan="None",
                recommendation_reason="Both loans are equivalent."
            )
        )
        mock_comp_service.compare_loans = AsyncMock(return_value=mock_comparison)
        app.dependency_overrides[get_comparison_service] = lambda: mock_comp_service

        mock_analysis_response = AnalysisResponse(
            loan_id="loan-a",
            status="COMPLETED",
            analysis=self.mock_analysis
        )

        with unittest.mock.patch("app.api.compare.get_loan_analysis", new_callable=AsyncMock) as mock_get_analysis:
            mock_get_analysis.return_value = mock_analysis_response

            request_payload = {"loan_id_a": "loan-a", "loan_id_b": "loan-b"}
            response = self.client.post("/compare", json=request_payload)
            self.assertEqual(response.status_code, 200)
            
            data = response.json()
            self.assertEqual(data["comparison"]["comparison_results"]["recommended_loan"], "None")
            self.assertEqual(data["comparison"]["comparison_results"]["recommendation_reason"], "Both loans are equivalent.")

    def test_chat_endpoint_query_param_success(self):
        """Test POST /chat/{loan_id} with query param returns correct ChatResponse."""
        mock_chat_service = MagicMock()
        mock_chat_resp = ChatResponse(
            answer="According to Clause 7.2, prepayment is allowed.",
            citations=[
                ChatCitation(
                    page_number=3,
                    source_text="Clause 7.2 details prepayment.",
                    confidence=0.98,
                    citation_type=CitationType.LEGAL_PROVISION,
                    clause_reference="Clause 7.2"
                )
            ],
            confidence_score=0.98,
            source_references=["Agreement.pdf"],
            supporting_clauses=["Clause 7.2"],
            session_id="session-123"
        )
        mock_chat_service.get_answer = AsyncMock(return_value=mock_chat_resp)
        app.dependency_overrides[get_chat_service] = lambda: mock_chat_service

        response = self.client.post("/chat/test-loan-id?query=prepayment")
        self.assertEqual(response.status_code, 200)
        
        data = response.json()
        self.assertEqual(data["answer"], "According to Clause 7.2, prepayment is allowed.")
        self.assertEqual(data["confidence_score"], 0.98)
        self.assertEqual(len(data["citations"]), 1)
        self.assertEqual(data["citations"][0]["page_number"], 3)
        self.assertEqual(data["source_references"][0], "Agreement.pdf")
        self.assertEqual(data["supporting_clauses"][0], "Clause 7.2")

    def test_chat_endpoint_request_body_success(self):
        """Test POST /chat/{loan_id} with request body json returns correct ChatResponse."""
        mock_chat_service = MagicMock()
        mock_chat_resp = ChatResponse(
            answer="According to Clause 7.2, prepayment is allowed.",
            citations=[
                ChatCitation(
                    page_number=3,
                    source_text="Clause 7.2 details prepayment.",
                    confidence=0.98,
                    citation_type=CitationType.LEGAL_PROVISION,
                    clause_reference="Clause 7.2"
                )
            ],
            confidence_score=0.98,
            source_references=["Agreement.pdf"],
            supporting_clauses=["Clause 7.2"],
            session_id="session-123"
        )
        mock_chat_service.get_answer = AsyncMock(return_value=mock_chat_resp)
        app.dependency_overrides[get_chat_service] = lambda: mock_chat_service

        request_body = {
            "query": "prepayment",
            "history": [{"role": "user", "content": "Hi"}]
        }
        response = self.client.post("/chat/test-loan-id", json=request_body)
        self.assertEqual(response.status_code, 200)
        
        data = response.json()
        self.assertEqual(data["answer"], "According to Clause 7.2, prepayment is allowed.")

    def test_chat_endpoint_missing_query(self):
        """Test POST /chat/{loan_id} with no query returns 400."""
        response = self.client.post("/chat/test-loan-id")
        self.assertEqual(response.status_code, 400)
        self.assertIn("must be provided", response.json()["detail"].lower())

if __name__ == "__main__":
    unittest.main()
