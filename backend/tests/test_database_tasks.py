import pytest
import uuid
import os
from decimal import Decimal
from datetime import datetime, timezone, date
from unittest.mock import MagicMock, AsyncMock, patch, mock_open

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.database.base import Base
from app.database.models import LoanReport
from app.database.enums import ProcessingStatus
from app.tasks import process_loan_document_task
from app.models.loan_analysis import LoanAnalysisResponse
from app.models.loan_metadata import LoanMetadata
from app.models.loan_score import LoanSafetyScore, SafetyRating
from app.models.risk_clause import RiskClause, RiskLevel, RiskCategory

# Setup SQLite in-memory database for testing
DATABASE_URL = "sqlite:///:memory:"
engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

@pytest.fixture(scope="function")
def db_session():
    """Fixture to set up database tables and yield a session for testing."""
    Base.metadata.create_all(bind=engine)
    session = TestingSessionLocal()
    try:
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(bind=engine)

def test_loan_report_model_creation(db_session):
    """Test creating a LoanReport database record with standard columns."""
    loan_uuid = uuid.uuid4()
    report = LoanReport(
        loan_id=loan_uuid,
        lender_name="Test Bank",
        loan_type="Business Loan",
        principal_amount=Decimal("250000.00"),
        status=ProcessingStatus.PENDING,
        user_id="user-999",
        file_path="/var/loans/test.pdf",
        document_name="test.pdf"
    )
    db_session.add(report)
    db_session.commit()

    db_report = db_session.query(LoanReport).filter(LoanReport.loan_id == loan_uuid).first()
    assert db_report is not None
    assert db_report.lender_name == "Test Bank"
    assert db_report.loan_type == "Business Loan"
    assert db_report.principal_amount == Decimal("250000.00")
    assert db_report.status == ProcessingStatus.PENDING
    assert db_report.created_at is not None
    if db_session.bind.dialect.name == "postgresql":
        assert db_report.created_at.tzinfo == timezone.utc
    assert db_report.user_id == "user-999"

def test_loan_report_status_transitions(db_session):
    """Test transitions of LoanReport status fields."""
    loan_uuid = uuid.uuid4()
    report = LoanReport(
        loan_id=loan_uuid,
        status=ProcessingStatus.PENDING
    )
    db_session.add(report)
    db_session.commit()

    # Move to PROCESSING
    report.status = ProcessingStatus.PROCESSING
    db_session.commit()
    db_report = db_session.query(LoanReport).filter(LoanReport.loan_id == loan_uuid).first()
    assert db_report.status == ProcessingStatus.PROCESSING

    # Move to COMPLETED
    report.status = ProcessingStatus.COMPLETED
    report.analysis_json = {"mock_key": "mock_val"}
    db_session.commit()
    db_report = db_session.query(LoanReport).filter(LoanReport.loan_id == loan_uuid).first()
    assert db_report.status == ProcessingStatus.COMPLETED
    assert db_report.analysis_json == {"mock_key": "mock_val"}

@patch("app.tasks.pdf_processor")
@patch("app.tasks.LoanExtractionService")
def test_celery_task_success(mock_extraction_class, mock_pdf_proc, db_session):
    """Test Celery background processing task under standard/happy path conditions."""
    loan_uuid = uuid.uuid4()
    loan_id_str = str(loan_uuid)
    file_path = "uploads/dummy.pdf"

    # Create initial report row in PENDING
    report = LoanReport(
        loan_id=loan_uuid,
        status=ProcessingStatus.PENDING,
        document_name="dummy.pdf",
        file_path=file_path
    )
    db_session.add(report)
    db_session.commit()

    # Setup Mocks
    mock_pdf_proc.process_and_store.return_value = 10
    mock_pdf_proc.extract_text.return_value = "This is dummy loan agreement text."
    
    # Mock LoanExtractionService and return value
    mock_service_instance = MagicMock()
    mock_extraction_class.return_value = mock_service_instance

    # Mock response model
    mock_metadata = LoanMetadata(
        lender_name="Apex Bank",
        loan_type="Home Loan",
        principal_amount=Decimal("150000.00"),
        sanctioned_amount=Decimal("150000.00"),
        interest_rate=8.5,
        interest_type="fixed",
        tenure_months=120,
        emi_amount=Decimal("1850.00"),
        processing_fee=Decimal("1500.00"),
        documentation_fee=Decimal("500.00"),
        insurance_fee=Decimal("2000.00"),
        foreclosure_charges=Decimal("0.00"),
        prepayment_charges=Decimal("0.00"),
        bounce_charges=Decimal("500.00"),
        late_payment_fee=Decimal("24.00"),
        disbursal_amount=Decimal("146000.00"),
        repayment_frequency="monthly",
        loan_start_date=date(2026, 6, 1),
        maturity_date=date(2036, 6, 1)
    )
    mock_risk = RiskClause(
        clause_id="clause_prepayment",
        clause_title="Prepayment Charge",
        clause_text="No charges apply.",
        risk_level=RiskLevel.LOW,
        category=RiskCategory.FORECLOSURE_RISK,
        explanation="Friendly prepayment terms.",
        page_number=2,
        recommendation="No negotiation needed."
    )
    mock_score = LoanSafetyScore(
        score=9.0,
        rating=SafetyRating.EXCELLENT,
        strengths=["Fixed interest rate"],
        weaknesses=[],
        explanation="Excellent score."
    )
    mock_analysis_resp = LoanAnalysisResponse(
        metadata=mock_metadata,
        risks=[mock_risk],
        ai_summary="AI generated summary here.",
        loan_score=mock_score,
        confidence_score=0.96,
        total_interest=Decimal("72000.00"),
        total_payment=Decimal("226000.00"),
        effective_apr=9.2,
        recommendations=["Ensure start date is correct."]
    )
    mock_service_instance.analyze_document = AsyncMock(return_value=mock_analysis_resp)

    # Patch DB SessionLocal in tasks module to use our testing session
    with patch("app.tasks.SessionLocal", return_value=db_session), \
         patch("app.tasks.os.path.exists", return_value=True), \
         patch("app.tasks.calculate_file_hash", return_value="dummy_hash_123"):
        
        process_loan_document_task.run(loan_id_str, file_path)

    # Verify report updates in database
    db_report = db_session.query(LoanReport).filter(LoanReport.loan_id == loan_uuid).first()
    assert db_report is not None
    assert db_report.status == ProcessingStatus.COMPLETED
    assert db_report.lender_name == "Apex Bank"
    assert db_report.loan_type == "Home Loan"
    assert db_report.principal_amount == Decimal("150000.00")
    assert db_report.analysis_json is not None
    assert db_report.analysis_json["metadata"]["lender_name"] == "Apex Bank"
    assert db_report.error_message is None
    assert db_report.processing_duration > 0

@patch("app.tasks.pdf_processor")
def test_celery_task_failure(mock_pdf_proc, db_session):
    """Test Celery background processing task error handling and failed status mapping."""
    loan_uuid = uuid.uuid4()
    loan_id_str = str(loan_uuid)
    file_path = "uploads/broken.pdf"

    # Create initial report row in PENDING
    report = LoanReport(
        loan_id=loan_uuid,
        status=ProcessingStatus.PENDING,
        document_name="broken.pdf",
        file_path=file_path
    )
    db_session.add(report)
    db_session.commit()

    # Setup Mock to raise error
    mock_pdf_proc.process_and_store.side_effect = RuntimeError("PDF Processing Error")

    # Patch DB SessionLocal, task attributes, and run task using Celery context helpers
    process_loan_document_task.push_request(retries=3)
    try:
        with patch("app.tasks.SessionLocal", return_value=db_session), \
             patch("app.tasks.os.path.exists", return_value=True), \
             patch("app.tasks.calculate_file_hash", return_value="dummy_hash_123"), \
             patch.object(process_loan_document_task, "max_retries", 3), \
             patch.object(process_loan_document_task, "retry", side_effect=Exception("Celery Retry Triggered")):
            
            with pytest.raises(Exception, match="Celery Retry Triggered"):
                process_loan_document_task.run(loan_id_str, file_path)
    finally:
        process_loan_document_task.pop_request()

    # Verify report status is set to FAILED in the database
    db_report = db_session.query(LoanReport).filter(LoanReport.loan_id == loan_uuid).first()
    assert db_report is not None
    assert db_report.status == ProcessingStatus.FAILED
    assert "PDF Processing Error" in db_report.error_message
