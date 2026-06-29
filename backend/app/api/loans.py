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
async def list_loans(
    db: Session = Depends(get_db),
    search: Optional[str] = None,
    risk_level: Optional[str] = None,
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    sort_by: Optional[str] = "upload_date",
    order: Optional[str] = "desc",
) -> list[LoanHistoryItemResponse]:
    """
    Return filtered and sorted loan upload history for the dashboard.
    """
    logger.info(
        f"Loan history requested. filters: search={search}, risk_level={risk_level}, "
        f"start_date={start_date}, end_date={end_date}, sort_by={sort_by}, order={order}"
    )

    query = db.query(LoanReport)

    # 1. Search Filter (database level)
    if search:
        search_pattern = f"%{search}%"
        query = query.filter(
            (LoanReport.lender_name.ilike(search_pattern)) |
            (LoanReport.document_name.ilike(search_pattern))
        )

    # 2. Date range filters (database level)
    if start_date:
        try:
            from datetime import datetime
            s_date = datetime.strptime(start_date, "%Y-%m-%d")
            query = query.filter(LoanReport.created_at >= s_date)
        except ValueError:
            pass

    if end_date:
        try:
            from datetime import datetime, timedelta
            e_date = datetime.strptime(end_date, "%Y-%m-%d")
            # Include the entire end day
            e_date = e_date + timedelta(days=1)
            query = query.filter(LoanReport.created_at < e_date)
        except ValueError:
            pass

    reports = query.all()

    # 3. Derive risk scores and map
    items = []
    for report in reports:
        r_score = _derive_risk_score(report)
        items.append((report, r_score))

    # 4. Filter by risk level (Safe <= 30, Moderate 30-60, Dangerous > 60)
    if risk_level:
        rl_lower = risk_level.lower()
        filtered_items = []
        for report, r_score in items:
            if r_score is None:
                continue
            if rl_lower == "safe" and r_score <= 30.0:
                filtered_items.append((report, r_score))
            elif rl_lower == "moderate" and 30.0 < r_score <= 60.0:
                filtered_items.append((report, r_score))
            elif rl_lower == "dangerous" and r_score > 60.0:
                filtered_items.append((report, r_score))
        items = filtered_items

    # 5. Sorting
    reverse = (order == "desc")
    if sort_by == "risk_score":
        # Sort items; put items with None risk scores at the end
        items.sort(
            key=lambda x: (x[1] is not None, x[1] if x[1] is not None else (999.0 if not reverse else -999.0)),
            reverse=reverse
        )
    elif sort_by == "lender_name":
        items.sort(
            key=lambda x: (x[0].lender_name or x[0].document_name or "").lower(),
            reverse=reverse
        )
    else:  # Default sort_by is "upload_date"
        items.sort(
            key=lambda x: x[0].created_at,
            reverse=reverse
        )

    return [
        LoanHistoryItemResponse(
            loan_id=str(report.loan_id),
            lender_name=report.lender_name or report.document_name or "Pending lender detection",
            upload_date=report.created_at,
            status=report.status.value,
            risk_score=r_score,
        )
        for report, r_score in items
    ]

