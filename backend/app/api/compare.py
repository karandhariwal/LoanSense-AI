import logging
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database.session import get_db
from app.models.api_schemas import CompareRequest, CompareResponse
from app.services.ai.comparison_service import LoanComparisonService
from app.api.deps import get_comparison_service
from app.api.analysis import get_loan_analysis

logger = logging.getLogger(__name__)
router = APIRouter()

@router.post("", response_model=CompareResponse)
async def compare_loans(
    request: CompareRequest,
    db: Session = Depends(get_db),
    comparison_service: LoanComparisonService = Depends(get_comparison_service)
):
    """
    Compare two pre-analyzed database-persisted loans side-by-side.
    Fails if either of the loan documents is not yet COMPLETED.
    """
    logger.info(f"Comparison requested for loan_a={request.loan_id_a} and loan_b={request.loan_id_b}")
    
    # 1. Retrieve Loan A analysis
    try:
        analysis_resp_a = await get_loan_analysis(request.loan_id_a, db)
        if analysis_resp_a.status != "COMPLETED":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Loan A (ID: {request.loan_id_a}) is not yet fully analyzed. Status: {analysis_resp_a.status}"
            )
        loan_a_analysis = analysis_resp_a.analysis
    except HTTPException as he:
        logger.error(f"Failed to load analysis for Loan A: {he.detail}")
        raise HTTPException(
            status_code=he.status_code,
            detail=f"Loan A retrieval failed: {he.detail}"
        )
    except Exception as e:
        logger.error(f"Failed to load analysis for Loan A: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Loan A retrieval failed: {str(e)}"
        )

    # 2. Retrieve Loan B analysis
    try:
        analysis_resp_b = await get_loan_analysis(request.loan_id_b, db)
        if analysis_resp_b.status != "COMPLETED":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Loan B (ID: {request.loan_id_b}) is not yet fully analyzed. Status: {analysis_resp_b.status}"
            )
        loan_b_analysis = analysis_resp_b.analysis
    except HTTPException as he:
        logger.error(f"Failed to load analysis for Loan B: {he.detail}")
        raise HTTPException(
            status_code=he.status_code,
            detail=f"Loan B retrieval failed: {he.detail}"
        )
    except Exception as e:
        logger.error(f"Failed to load analysis for Loan B: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Loan B retrieval failed: {str(e)}"
        )

    if not loan_a_analysis or not loan_b_analysis:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Inconsistent DB state: Completed reports with empty analysis data cannot be compared."
        )

    # 3. Perform comparison using comparison service
    try:
        logger.info("Executing comparison service comparison...")
        comparison = await comparison_service.compare_loans(loan_a_analysis, loan_b_analysis)
        logger.info("Comparison completed successfully.")
        return CompareResponse(comparison=comparison)
    except Exception as e:
        logger.error(f"Comparison failure: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Comparison failure: {str(e)}"
        )
