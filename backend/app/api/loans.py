import logging
from typing import Optional

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database.models import LoanReport
from app.database.session import get_db
from app.models.api_schemas import LoanHistoryItemResponse

logger = logging.getLogger(__name__)
router = APIRouter()


def _derive_risk_score(report: LoanReport) -> Optional[float]:
    """
    Convert the persisted 0-10 safety score into a 0-100 risk percentage.
    Higher percentages represent riskier agreements.
    """
    analysis = report.analysis_json or {}
    loan_score = analysis.get("loan_score")
    if not isinstance(loan_score, dict):
        return None

    raw_score = loan_score.get("score")
    try:
        safety_score = float(raw_score)
    except (TypeError, ValueError):
        return None

    safety_score = max(0.0, min(10.0, safety_score))
    return round((10.0 - safety_score) * 10.0, 1)


@router.get("/loans", response_model=list[LoanHistoryItemResponse])
async def list_loans(db: Session = Depends(get_db)) -> list[LoanHistoryItemResponse]:
    """
    Return reverse-chronological loan upload history for the dashboard.
    """
    logger.info("Loan history requested.")

    reports = (
        db.query(LoanReport)
        .order_by(LoanReport.created_at.desc())
        .all()
    )

    return [
        LoanHistoryItemResponse(
            loan_id=str(report.loan_id),
            lender_name=report.lender_name or report.document_name or "Pending lender detection",
            upload_date=report.created_at,
            status=report.status.value,
            risk_score=_derive_risk_score(report),
        )
        for report in reports
    ]
