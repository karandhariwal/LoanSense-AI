import logging
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database.session import get_db
from app.models.api_schemas import RisksResponse
from app.models.risk_clause import RiskLevel
from app.api.analysis import get_loan_analysis

logger = logging.getLogger(__name__)
router = APIRouter()

@router.get("/{loan_id}", response_model=RisksResponse)
async def get_loan_risks(
    loan_id: str,
    db: Session = Depends(get_db)
):
    """
    Retrieve loan risk clause details and metrics from the persisted database report.
    Fails if the analysis task is still pending, processing, or has failed.
    """
    logger.info(f"Risk analysis requested for loan_id={loan_id}")
    
    # Retrieve the analysis from database (delegates to the database query flow)
    try:
        analysis_resp = await get_loan_analysis(loan_id, db)
    except HTTPException as he:
        raise he
    except Exception as e:
        logger.error(f"Failed to retrieve analysis for risks endpoint: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to retrieve loan analysis: {str(e)}"
        )

    # Check status of the processing
    if analysis_resp.status != "COMPLETED":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Loan analysis is not completed yet. Current status: {analysis_resp.status}"
        )

    analysis = analysis_resp.analysis
    if not analysis:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Inconsistent state: Completed analysis holds empty data."
        )

    # Calculate metrics
    risks = analysis.risks
    total_risks = len(risks)
    high_risks_count = sum(1 for r in risks if r.risk_level == RiskLevel.HIGH)
    medium_risks_count = sum(1 for r in risks if r.risk_level == RiskLevel.MEDIUM)
    low_risks_count = sum(1 for r in risks if r.risk_level == RiskLevel.LOW)

    logger.info(
        f"Risk analysis completed for loan_id={loan_id}: "
        f"Total={total_risks}, High={high_risks_count}, Medium={medium_risks_count}, Low={low_risks_count}"
    )

    return RisksResponse(
        loan_id=loan_id,
        risks=risks,
        total_risks=total_risks,
        high_risks_count=high_risks_count,
        medium_risks_count=medium_risks_count,
        low_risks_count=low_risks_count
    )
