import unittest
from fastapi.testclient import TestClient
from decimal import Decimal
from datetime import date, datetime, timezone
from unittest.mock import AsyncMock, MagicMock

from app.main import app
from app.api.deps import get_extraction_service, get_chat_service, get_comparison_service
from app.models.loan_analysis import LoanAnalysisResponse
from app.models.loan_metadata import LoanMetadata
from app.models.loan_score import LoanSafetyScore, SafetyRating
from app.models.risk_clause import RiskClause, RiskLevel, RiskCategory
from app.models.api_schemas import (
    AnalysisResponse,
    LoanHistoryItemResponse,
    RisksResponse,
    CompareResponse,
    ChatResponse,
)
from app.models.loan_comparison import LoanComparison, LoanComparisonResult
from app.models.chat_citation import ChatCitation, CitationType

import uuid
from app.database.session import get_db
from app.database.models import LoanReport, ChatMessage
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

    def test_loans_endpoint_returns_history(self):
        """Test GET /loans returns reverse-chronological loan history."""
        first_report = LoanReport(
            loan_id=uuid.UUID("8a7b3c2d-1a2b-3c4d-5e6f-7a8b9c0d1e2f"),
            status=ProcessingStatus.COMPLETED,
            lender_name="Mock Bank",
            created_at=datetime(2026, 6, 7, 13, 25, 14, tzinfo=timezone.utc),
            analysis_json={
                "loan_score": {
                    "score": 8.0,
                }
            },
        )
        second_report = LoanReport(
            loan_id=uuid.UUID("9f8e7d6c-5b4a-3c2d-1e0f-9a8b7c6d5e4f"),
            status=ProcessingStatus.PENDING,
            document_name="sample-loan.pdf",
            created_at=datetime(2026, 6, 6, 8, 10, 0, tzinfo=timezone.utc),
            analysis_json=None,
        )
        mock_query = self.mock_db.query.return_value
        mock_query.all.return_value = [first_report, second_report]

        response = self.client.get("/loans")
        self.assertEqual(response.status_code, 200)

        data = response.json()
        self.assertEqual(len(data), 2)
        self.assertEqual(data[0]["loan_id"], "8a7b3c2d-1a2b-3c4d-5e6f-7a8b9c0d1e2f")
        self.assertEqual(data[0]["lender_name"], "Mock Bank")
        self.assertEqual(data[0]["status"], "COMPLETED")
        self.assertEqual(data[0]["risk_score"], 20.0)
        self.assertEqual(data[1]["lender_name"], "sample-loan.pdf")
        self.assertIsNone(data[1]["risk_score"])

    def test_loans_endpoint_filtering_and_sorting(self):
        """Test GET /loans with filters (search, risk_level, dates) and sorting."""
        report_safe = LoanReport(
            loan_id=uuid.UUID("11111111-1111-1111-1111-111111111111"),
            status=ProcessingStatus.COMPLETED,
            lender_name="Apex Bank",
            document_name="apex-loan.pdf",
            created_at=datetime(2026, 6, 7, 10, 0, 0, tzinfo=timezone.utc),
            analysis_json={"loan_score": {"score": 8.0}},  # risk = 20.0 (Safe)
        )
        report_moderate = LoanReport(
            loan_id=uuid.UUID("22222222-2222-2222-2222-222222222222"),
            status=ProcessingStatus.COMPLETED,
            lender_name="Summit Finance",
            document_name="summit-loan.pdf",
            created_at=datetime(2026, 6, 6, 10, 0, 0, tzinfo=timezone.utc),
            analysis_json={"loan_score": {"score": 5.0}},  # risk = 50.0 (Moderate)
        )
        report_dangerous = LoanReport(
            loan_id=uuid.UUID("33333333-3333-3333-3333-333333333333"),
            status=ProcessingStatus.COMPLETED,
            lender_name="Predatory Lenders",
            document_name="bad-loan.pdf",
            created_at=datetime(2026, 6, 5, 10, 0, 0, tzinfo=timezone.utc),
            analysis_json={"loan_score": {"score": 2.0}},  # risk = 80.0 (Dangerous)
        )

        # Mock database query chain for list_loans
        mock_query = self.mock_db.query.return_value
        mock_query.filter.return_value = mock_query  # Keep returning query mock for chain
        mock_query.all.return_value = [report_safe, report_moderate, report_dangerous]

        # 1. Test search filter
        response = self.client.get("/loans?search=summit")
        self.assertEqual(response.status_code, 200)
        # Verify the database filter was called on the mock
        self.assertTrue(mock_query.filter.called)

        # 2. Test risk_level filtering (which happens on Python side)
        response = self.client.get("/loans?risk_level=moderate")
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(len(data), 1)
        self.assertEqual(data[0]["lender_name"], "Summit Finance")

        # 3. Test sort_by risk_score asc
        response = self.client.get("/loans?sort_by=risk_score&order=asc")
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(len(data), 3)
        self.assertEqual(data[0]["risk_score"], 20.0)
        self.assertEqual(data[1]["risk_score"], 50.0)
        self.assertEqual(data[2]["risk_score"], 80.0)

        # 4. Test sort_by lender_name desc
        response = self.client.get("/loans?sort_by=lender_name&order=desc")
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(len(data), 3)
        self.assertEqual(data[0]["lender_name"], "Summit Finance")  # Summit Finance, Predatory, Apex Bank
        self.assertEqual(data[1]["lender_name"], "Predatory Lenders")
        self.assertEqual(data[2]["lender_name"], "Apex Bank")

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

        response = self.client.post("/chat/8a7b3c2d-1a2b-3c4d-5e6f-7a8b9c0d1e2f?query=prepayment")
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
        response = self.client.post("/chat/8a7b3c2d-1a2b-3c4d-5e6f-7a8b9c0d1e2f", json=request_body)
        self.assertEqual(response.status_code, 200)
        
        data = response.json()
        self.assertEqual(data["answer"], "According to Clause 7.2, prepayment is allowed.")

    def test_chat_endpoint_missing_query(self):
        """Test POST /chat/{loan_id} with no query returns 400."""
        response = self.client.post("/chat/8a7b3c2d-1a2b-3c4d-5e6f-7a8b9c0d1e2f")
        self.assertEqual(response.status_code, 400)
        self.assertIn("must be provided", response.json()["detail"].lower())

    def test_chat_endpoint_invalid_uuid(self):
        """Test POST /chat/{loan_id} with invalid UUID returns 400."""
        response = self.client.post("/chat/invalid-uuid?query=prepayment")
        self.assertEqual(response.status_code, 400)
        self.assertIn("invalid uuid", response.json()["detail"].lower())

    def test_get_chat_history_success(self):
        """Test GET /chat/{loan_id}/history returns chat messages list."""
        mock_messages = [
            ChatMessage(
                message_id=uuid.UUID("11111111-2222-3333-4444-555555555555"),
                loan_id=uuid.UUID("8a7b3c2d-1a2b-3c4d-5e6f-7a8b9c0d1e2f"),
                role="user",
                content="Is there a prepayment fee?",
                citations=[],
                confidence_score=None,
                created_at=datetime.now(timezone.utc)
            ),
            ChatMessage(
                message_id=uuid.UUID("66666666-7777-8888-9999-000000000000"),
                loan_id=uuid.UUID("8a7b3c2d-1a2b-3c4d-5e6f-7a8b9c0d1e2f"),
                role="assistant",
                content="Yes, 2%.",
                citations=[
                    {
                        "page_number": 8,
                        "source_text": "7.2 Prepayment: 2%",
                        "confidence": 0.98,
                        "citation_type": "legal_provision",
                        "clause_reference": "Clause 7.2"
                    }
                ],
                confidence_score=0.98,
                created_at=datetime.now(timezone.utc)
            )
        ]
        
        mock_query = MagicMock()
        mock_filter = MagicMock()
        mock_order_by = MagicMock()
        
        self.mock_db.query.return_value = mock_query
        mock_query.filter.return_value = mock_filter
        mock_filter.order_by.return_value = mock_order_by
        mock_order_by.all.return_value = mock_messages
        
        response = self.client.get("/chat/8a7b3c2d-1a2b-3c4d-5e6f-7a8b9c0d1e2f/history")
        self.assertEqual(response.status_code, 200)
        
        data = response.json()
        self.assertEqual(len(data), 2)
        self.assertEqual(data[0]["role"], "user")
        self.assertEqual(data[0]["content"], "Is there a prepayment fee?")
        self.assertEqual(data[1]["role"], "assistant")
        self.assertEqual(data[1]["content"], "Yes, 2%.")
        self.assertEqual(data[1]["citations"][0]["page_number"], 8)
        self.assertEqual(data[1]["confidence_score"], 0.98)

    def test_get_chat_history_invalid_uuid(self):
        """Test GET /chat/{loan_id}/history with invalid UUID returns 400."""
        response = self.client.get("/chat/invalid-uuid/history")
        self.assertEqual(response.status_code, 400)
        self.assertIn("invalid uuid", response.json()["detail"].lower())

    def test_chat_endpoint_stream_success(self):
        """Test POST /chat/{loan_id}/stream returns a line-by-line SSE stream."""
        import json
        mock_chat_service = MagicMock()
        
        async def mock_stream_gen(loan_id, query, db, history=None, session_id=None):
            yield {"type": "token", "content": "According to"}
            yield {"type": "token", "content": " Clause 7.2"}
            yield {"type": "final", "citations": [
                {
                    "page_number": 3,
                    "source_text": "Clause 7.2 details prepayment.",
                    "confidence": 0.98,
                    "citation_type": "legal_provision",
                    "clause_reference": "Clause 7.2"
                }
            ], "confidence_score": 0.98}
            
        mock_chat_service.get_answer_stream = mock_stream_gen
        app.dependency_overrides[get_chat_service] = lambda: mock_chat_service

        response = self.client.post("/chat/8a7b3c2d-1a2b-3c4d-5e6f-7a8b9c0d1e2f/stream?query=prepayment")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.headers["content-type"], "text/event-stream; charset=utf-8")
        
        lines = [line if isinstance(line, str) else line.decode("utf-8") for line in response.iter_lines()]
        events = [line for line in lines if line.startswith("data: ")]
        self.assertEqual(len(events), 3)
        
        event0 = json.loads(events[0][6:])
        self.assertEqual(event0["type"], "token")
        self.assertEqual(event0["content"], "According to")
        
        event1 = json.loads(events[1][6:])
        self.assertEqual(event1["type"], "token")
        self.assertEqual(event1["content"], " Clause 7.2")
        
        event2 = json.loads(events[2][6:])
        self.assertEqual(event2["type"], "final")
        self.assertEqual(event2["confidence_score"], 0.98)
        self.assertEqual(event2["citations"][0]["page_number"], 3)

    def test_chat_endpoint_stream_invalid_uuid(self):
        """Test POST /chat/{loan_id}/stream with invalid UUID returns 400."""
        response = self.client.post("/chat/invalid-uuid/stream?query=prepayment")
        self.assertEqual(response.status_code, 400)
        self.assertIn("invalid uuid", response.json()["detail"].lower())

if __name__ == "__main__":
    unittest.main()
