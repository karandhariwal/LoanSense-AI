import io
import uuid
import logging
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session

from app.database.session import get_db
from app.database.models import LoanReport
from app.database.enums import ProcessingStatus

logger = logging.getLogger(__name__)
router = APIRouter()


def _safe_str(value, fallback: str = "N/A") -> str:
    """Return a clean string or fallback if value is None/empty."""
    if value is None:
        return fallback
    s = str(value).strip()
    return s if s else fallback


def _derive_risk_score(report: LoanReport):
    """Return (risk_score_0_100, rating_label) from the stored analysis_json."""
    analysis = report.analysis_json or {}
    loan_score = analysis.get("loan_score")
    if not isinstance(loan_score, dict):
        return None, "Unknown"
    raw = loan_score.get("score")
    try:
        safety = float(raw)
    except (TypeError, ValueError):
        return None, "Unknown"
    safety = max(0.0, min(10.0, safety))
    risk = round((10.0 - safety) * 10.0, 1)
    if risk <= 30:
        label = "SAFE"
    elif risk <= 60:
        label = "MODERATE"
    else:
        label = "DANGEROUS"
    return risk, label


def _build_pdf_bytes(report: LoanReport) -> bytes:
    """Generate a styled PDF report using reportlab and return as bytes."""
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.units import mm
    from reportlab.lib.styles import ParagraphStyle
    from reportlab.lib.enums import TA_LEFT, TA_CENTER, TA_RIGHT
    from reportlab.platypus import (
        SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
        HRFlowable, KeepTogether,
    )
    from reportlab.lib import colors

    # ── Color palette (dark theme translated to print-friendly) ──────────
    COL_BG        = colors.HexColor("#131314")
    COL_SURFACE   = colors.HexColor("#201F20")
    COL_PRIMARY   = colors.HexColor("#C3C6D7")
    COL_ACCENT    = colors.HexColor("#DBC3A8")
    COL_DANGER    = colors.HexColor("#FFB4AB")
    COL_WARNING   = colors.HexColor("#F5C518")
    COL_SAFE      = colors.HexColor("#6FD080")
    COL_TEXT      = colors.HexColor("#E5E2E3")
    COL_MUTED     = colors.HexColor("#C7C6CC")
    COL_DIVIDER   = colors.HexColor("#353436")

    buf = io.BytesIO()
    doc = SimpleDocTemplate(
        buf,
        pagesize=A4,
        leftMargin=18 * mm,
        rightMargin=18 * mm,
        topMargin=18 * mm,
        bottomMargin=18 * mm,
    )

    W = A4[0] - 36 * mm  # usable width

    def style(name, **kw):
        base = ParagraphStyle(name)
        base.textColor = COL_TEXT
        base.fontName = "Helvetica"
        base.fontSize = 10
        for k, v in kw.items():
            setattr(base, k, v)
        return base

    S_HEADER  = style("H",  fontSize=22, fontName="Helvetica-Bold", textColor=COL_PRIMARY, alignment=TA_LEFT)
    S_SUBHEAD = style("SH", fontSize=13, fontName="Helvetica-Bold", textColor=COL_ACCENT, spaceBefore=14, spaceAfter=4)
    S_LABEL   = style("LB", fontSize=9,  fontName="Helvetica-Bold", textColor=COL_MUTED)
    S_VALUE   = style("VL", fontSize=10, textColor=COL_TEXT)
    S_SMALL   = style("SM", fontSize=8,  textColor=COL_MUTED)
    S_BODY    = style("BD", fontSize=9,  textColor=COL_TEXT, leading=13, spaceAfter=6)
    S_RISK_H  = style("RH", fontSize=9,  fontName="Helvetica-Bold", textColor=COL_DANGER)
    S_RISK_M  = style("RM", fontSize=9,  fontName="Helvetica-Bold", textColor=COL_WARNING)
    S_RISK_L  = style("RL", fontSize=9,  fontName="Helvetica-Bold", textColor=COL_SAFE)
    S_FOOTER  = style("FT", fontSize=8,  textColor=COL_MUTED, alignment=TA_CENTER)

    # ── Data extraction ────────────────────────────────────────────────────
    analysis   = report.analysis_json or {}
    metadata   = analysis.get("metadata") or {}
    loan_score = analysis.get("loan_score") or {}
    risks      = analysis.get("risks") or []
    ai_summary = analysis.get("ai_summary") or ""
    recommendations = analysis.get("recommendations") or []
    risk_score, risk_label = _derive_risk_score(report)

    lender        = _safe_str(metadata.get("lender_name") or report.lender_name)
    loan_type     = _safe_str(metadata.get("loan_type"))
    principal     = _safe_str(metadata.get("principal_amount"))
    interest_rate = _safe_str(metadata.get("interest_rate"))
    interest_type = _safe_str(metadata.get("interest_type"))
    tenure        = _safe_str(metadata.get("tenure_months"))
    emi           = _safe_str(metadata.get("emi_amount"))
    total_interest = _safe_str(analysis.get("total_interest"))
    total_payment  = _safe_str(analysis.get("total_payment"))
    safety_score_val = loan_score.get("score")
    safety_score  = f"{safety_score_val}/10" if safety_score_val is not None else "N/A"
    rating        = _safe_str(loan_score.get("rating"))

    generated_at  = datetime.now(timezone.utc).strftime("%B %d, %Y at %H:%M UTC")

    def risk_color(level: str):
        l = level.upper()
        if l == "HIGH":   return COL_DANGER
        if l == "MEDIUM": return COL_WARNING
        return COL_SAFE

    # ── Build story ────────────────────────────────────────────────────────
    story = []

    # Header block
    story.append(Paragraph("LoanSense AI", S_HEADER))
    story.append(Paragraph("Loan Analysis Report", style("HS", fontSize=14, textColor=COL_MUTED)))
    story.append(Spacer(1, 4 * mm))
    story.append(HRFlowable(width=W, thickness=1, color=COL_DIVIDER))
    story.append(Spacer(1, 3 * mm))

    # Meta row
    meta_data = [
        [Paragraph("<b>Loan ID</b>", S_LABEL), Paragraph(str(report.loan_id), S_SMALL),
         Paragraph("<b>Generated</b>", S_LABEL), Paragraph(generated_at, S_SMALL)],
        [Paragraph("<b>Document</b>", S_LABEL), Paragraph(_safe_str(report.document_name), S_SMALL),
         Paragraph("<b>Status</b>", S_LABEL), Paragraph(report.status.value, S_SMALL)],
    ]
    meta_tbl = Table(meta_data, colWidths=[28 * mm, W / 2 - 28 * mm, 28 * mm, W / 2 - 28 * mm])
    meta_tbl.setStyle(TableStyle([
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
    ]))
    story.append(meta_tbl)
    story.append(Spacer(1, 4 * mm))

    # ── Risk score badge ───────────────────────────────────────────────────
    if risk_score is not None:
        badge_color = COL_SAFE if risk_label == "SAFE" else (COL_WARNING if risk_label == "MODERATE" else COL_DANGER)
        badge_data = [[
            Paragraph(f"<b>{risk_label}</b>", style("BA", fontSize=14, fontName="Helvetica-Bold", textColor=badge_color, alignment=TA_CENTER)),
            Paragraph(f"<b>{risk_score}%</b> Risk", style("RS", fontSize=11, fontName="Helvetica-Bold", textColor=COL_TEXT)),
            Paragraph(f"Safety Score: <b>{safety_score}</b>  Rating: <b>{rating}</b>", style("SS", fontSize=10, textColor=COL_MUTED)),
        ]]
        badge_tbl = Table(badge_data, colWidths=[35 * mm, 40 * mm, W - 75 * mm])
        badge_tbl.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (0, 0), badge_color.clone(alpha=0.12)),
            ("BOX", (0, 0), (0, 0), 1, badge_color),
            ("ROUNDEDCORNERS", [4]),
            ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
            ("LEFTPADDING", (0, 0), (-1, -1), 8),
            ("RIGHTPADDING", (0, 0), (-1, -1), 8),
            ("TOPPADDING", (0, 0), (-1, -1), 8),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
        ]))
        story.append(badge_tbl)
        story.append(Spacer(1, 5 * mm))

    # ── Loan Details ───────────────────────────────────────────────────────
    story.append(HRFlowable(width=W, thickness=0.5, color=COL_DIVIDER))
    story.append(Paragraph("Loan Details", S_SUBHEAD))

    details_rows = [
        ["Lender", lender,        "Loan Type",     loan_type],
        ["Principal",  principal,  "Interest Rate", f"{interest_rate}% ({interest_type})"],
        ["Tenure",     f"{tenure} months", "Monthly EMI", f"₹{emi}"],
        ["Total Interest", f"₹{total_interest}", "Total Payment", f"₹{total_payment}"],
    ]
    col_w = W / 4
    det_tbl = Table(
        [[Paragraph(f"<b>{r[0]}</b>", S_LABEL), Paragraph(r[1], S_VALUE),
          Paragraph(f"<b>{r[2]}</b>", S_LABEL), Paragraph(r[3], S_VALUE)]
         for r in details_rows],
        colWidths=[col_w, col_w, col_w, col_w],
    )
    det_tbl.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), COL_SURFACE),
        ("ROWBACKGROUNDS", (0, 0), (-1, -1), [COL_SURFACE, COL_BG.clone(alpha=0.4)]),
        ("VALIGN",  (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING",  (0, 0), (-1, -1), 6),
        ("RIGHTPADDING", (0, 0), (-1, -1), 6),
        ("TOPPADDING",   (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING",(0, 0), (-1, -1), 5),
        ("LINEBELOW", (0, 0), (-1, -2), 0.5, COL_DIVIDER),
    ]))
    story.append(det_tbl)
    story.append(Spacer(1, 5 * mm))

    # ── AI Summary ─────────────────────────────────────────────────────────
    if ai_summary:
        story.append(HRFlowable(width=W, thickness=0.5, color=COL_DIVIDER))
        story.append(Paragraph("AI Summary", S_SUBHEAD))
        story.append(Paragraph(ai_summary[:1200], S_BODY))
        story.append(Spacer(1, 3 * mm))

    # ── Risk Clauses ───────────────────────────────────────────────────────
    if risks:
        story.append(HRFlowable(width=W, thickness=0.5, color=COL_DIVIDER))
        story.append(Paragraph(f"Risk Clauses  ({len(risks)} found)", S_SUBHEAD))

        for idx, clause in enumerate(risks, 1):
            level = _safe_str(clause.get("risk_level", "LOW"))
            title = _safe_str(clause.get("clause_title"))
            category = _safe_str(clause.get("category"))
            explanation = _safe_str(clause.get("explanation"))
            recommendation = _safe_str(clause.get("recommendation"))
            page_num = clause.get("page_number")
            page_str = f"Page {page_num}" if page_num else ""

            rc = risk_color(level)
            risk_style = S_RISK_H if level == "HIGH" else (S_RISK_M if level == "MEDIUM" else S_RISK_L)

            header_data = [[
                Paragraph(f"<b>{idx}. {title}</b>", style(f"RCH{idx}", fontSize=9, fontName="Helvetica-Bold", textColor=COL_TEXT)),
                Paragraph(f"<b>{level}</b>", risk_style),
                Paragraph(category, S_SMALL),
                Paragraph(page_str, S_SMALL),
            ]]
            header_tbl = Table(header_data, colWidths=[W * 0.45, W * 0.12, W * 0.28, W * 0.15])
            header_tbl.setStyle(TableStyle([
                ("BACKGROUND", (0, 0), (-1, -1), rc.clone(alpha=0.08)),
                ("LINEBELOW", (0, 0), (-1, -1), 0.5, rc),
                ("LEFTPADDING", (0, 0), (-1, -1), 6),
                ("TOPPADDING", (0, 0), (-1, -1), 5),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
            ]))

            body_rows = []
            if explanation and explanation != "N/A":
                body_rows.append([Paragraph("<b>Explanation:</b>", S_LABEL), Paragraph(explanation[:400], S_BODY)])
            if recommendation and recommendation != "N/A":
                body_rows.append([Paragraph("<b>Recommendation:</b>", S_LABEL), Paragraph(recommendation[:400], S_BODY)])

            body_tbl = Table(body_rows, colWidths=[30 * mm, W - 30 * mm]) if body_rows else None

            if body_tbl:
                body_tbl.setStyle(TableStyle([
                    ("BACKGROUND", (0, 0), (-1, -1), COL_SURFACE),
                    ("LEFTPADDING", (0, 0), (-1, -1), 6),
                    ("RIGHTPADDING", (0, 0), (-1, -1), 6),
                    ("TOPPADDING", (0, 0), (-1, -1), 4),
                    ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
                    ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ]))
                story.append(KeepTogether([header_tbl, body_tbl, Spacer(1, 3 * mm)]))
            else:
                story.append(KeepTogether([header_tbl, Spacer(1, 3 * mm)]))

    # ── Recommendations ────────────────────────────────────────────────────
    if recommendations:
        story.append(HRFlowable(width=W, thickness=0.5, color=COL_DIVIDER))
        story.append(Paragraph("Recommendations", S_SUBHEAD))
        for rec in recommendations[:8]:
            story.append(Paragraph(f"• {_safe_str(rec)}", S_BODY))
        story.append(Spacer(1, 3 * mm))

    # ── Footer ─────────────────────────────────────────────────────────────
    story.append(Spacer(1, 6 * mm))
    story.append(HRFlowable(width=W, thickness=0.5, color=COL_DIVIDER))
    story.append(Spacer(1, 2 * mm))
    story.append(Paragraph(
        "Generated by LoanSense AI • For informational purposes only • Not legal or financial advice",
        S_FOOTER,
    ))

    doc.build(story)
    buf.seek(0)
    return buf.read()


@router.get("/{loan_id}")
async def export_loan_pdf(
    loan_id: str,
    db: Session = Depends(get_db),
):
    """
    Export a completed loan analysis as a downloadable PDF report.

    Returns a streamed PDF file with:
    - Loan metadata (lender, type, amount, rate, tenure, EMI)
    - Safety score and risk rating badge
    - AI summary
    - Risk clauses table
    - Recommendations
    """
    logger.info(f"PDF export requested for loan_id={loan_id}")

    try:
        loan_uuid = uuid.UUID(loan_id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid loan ID format. Must be a valid UUID.",
        )

    report = db.query(LoanReport).filter(LoanReport.loan_id == loan_uuid).first()
    if not report:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Loan report not found for ID: {loan_id}",
        )

    if report.status != ProcessingStatus.COMPLETED:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Cannot export: analysis is not completed (status={report.status.value}).",
        )

    try:
        pdf_bytes = _build_pdf_bytes(report)
    except Exception as exc:
        logger.error(f"PDF generation failed for loan_id={loan_id}: {exc}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"PDF generation failed: {str(exc)}",
        )

    lender_slug = (report.lender_name or "loan").replace(" ", "_")[:40]
    filename = f"LoanSense_{lender_slug}_{loan_id[:8]}.pdf"

    return StreamingResponse(
        io.BytesIO(pdf_bytes),
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )
