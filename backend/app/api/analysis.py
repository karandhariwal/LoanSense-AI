import logging
import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database.session import get_db
from app.database.models import LoanReport
from app.database.enums import ProcessingStatus
from app.models.api_schemas import AnalysisResponse
from app.models.loan_analysis import LoanAnalysisResponse
from app.services.cache_service import cache

logger = logging.getLogger(__name__)
router = APIRouter()

@router.get("/{loan_id}", response_model=AnalysisResponse)
async def get_loan_analysis(
    loan_id: str,
    db: Session = Depends(get_db)
):
    """
    Retrieve loan analysis status and results.
    Checks Redis cache first; falls back to SQLite.
    Prevents repeated LLM and PDF parsing runs by reading persisted analysis.
    """
    logger.info(f"Database analysis retrieval requested for loan_id={loan_id}")
    
    try:
        loan_uuid = uuid.UUID(loan_id)
    except ValueError:
        logger.warning(f"Invalid UUID format: {loan_id}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid loan ID format. Must be a valid UUID."
        )

    # ── Cache layer: check Redis before hitting SQLite ──────────────────────
    cached_analysis = await cache.get_analysis(loan_id)
    if cached_analysis is not None:
        try:
            analysis_obj = LoanAnalysisResponse.model_validate(cached_analysis)
            logger.info(f"[Cache] HIT analysis:{loan_id} — returning from Redis")
            return AnalysisResponse(
                loan_id=loan_id,
                status=ProcessingStatus.COMPLETED.value,
                analysis=analysis_obj,
            )
        except Exception as e:
            logger.warning(f"[Cache] analysis:{loan_id} parse error, falling through to DB: {e}")
    # ───────────────────────────────────────────────────────────────────────

    report = db.query(LoanReport).filter(LoanReport.loan_id == loan_uuid).first()
    if not report:
        logger.warning(f"LoanReport not found for loan_id={loan_id}")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Loan report not found for ID: {loan_id}"
        )

    # If the processing has completed successfully, validate and return the payload
    if report.status == ProcessingStatus.COMPLETED:
        if not report.analysis_json:
            logger.error(f"LoanReport marked COMPLETED but analysis_json is empty for loan_id={loan_id}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Inconsistent database state: completed report has no analysis data."
            )
        try:
            analysis_obj = LoanAnalysisResponse.model_validate(report.analysis_json)
            # Seed cache for future requests
            await cache.set_analysis(loan_id, report.analysis_json)
            return AnalysisResponse(
                loan_id=str(report.loan_id),
                status=report.status.value,
                analysis=analysis_obj
            )
        except Exception as e:
            logger.error(f"Failed to parse database analysis_json for loan_id={loan_id}: {e}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Failed to parse persisted analysis: {str(e)}"
            )

    # For PENDING, PROCESSING, or FAILED status
    logger.info(f"Returning report status: {report.status.value} for loan_id={loan_id}")
    return AnalysisResponse(
        loan_id=str(report.loan_id),
        status=report.status.value,
        analysis=None
    )
