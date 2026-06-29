import os
import time
import logging
import asyncio
import hashlib
import uuid
from datetime import datetime, timezone
from celery.utils.log import get_task_logger

from app.celery_app import celery_app
from app.database.session import SessionLocal
from app.database.models import LoanReport
from app.database.enums import ProcessingStatus
from app.services.ai.pdf_processor import pdf_processor
from app.services.ai.extraction_service import LoanExtractionService
from app.services.cache_service import cache

logger = get_task_logger(__name__)

# ─── Module-level singletons ──────────────────────────────────────────────────
# LoanExtractionService initializes the NVIDIA NIM client and builds the
# LangChain pipeline chains. Doing this once per worker process (rather than
# once per task) saves 2–3 seconds of cold-start overhead per document.
_extraction_service: "LoanExtractionService | None" = None

def _get_extraction_service() -> "LoanExtractionService":
    global _extraction_service
    if _extraction_service is None:
        logger.info("Initializing LoanExtractionService singleton for this worker process.")
        _extraction_service = LoanExtractionService()
    return _extraction_service


def calculate_file_hash(file_path: str) -> str:
    """Calculate the SHA-256 hash of a file."""
    if not os.path.exists(file_path):
        return ""
    sha256_hash = hashlib.sha256()
    with open(file_path, "rb") as f:
        for byte_block in iter(lambda: f.read(4096), b""):
            sha256_hash.update(byte_block)
    return sha256_hash.hexdigest()

@celery_app.task(
    bind=True,
    max_retries=3,
    name="app.tasks.process_loan_document_task"
)
def process_loan_document_task(self, loan_id: str, file_path: str):
    """
    Celery background task to process a loan document.
    Updates the LoanReport status, stores text chunks in ChromaDB,
    runs the AI extraction & calculations pipeline, and stores results in the database.
    """
    logger.info(f"Task started: processing loan document for loan_id={loan_id}, file_path={file_path}")
    start_time = time.time()
    
    try:
        loan_uuid = uuid.UUID(loan_id) if isinstance(loan_id, str) else loan_id
    except ValueError as val_err:
        logger.error(f"Invalid UUID string passed as loan_id: {loan_id}. Error: {val_err}")
        return f"Error: Invalid UUID loan_id={loan_id}"

    db = SessionLocal()
    report = None
    try:
        report = db.query(LoanReport).filter(LoanReport.loan_id == loan_uuid).first()
        if not report:
            logger.error(f"LoanReport not found in database for loan_uuid={loan_uuid}")
            return f"Error: LoanReport not found for loan_uuid={loan_uuid}"

        # 1. Update status to PROCESSING
        report.status = ProcessingStatus.PROCESSING
        report.file_path = file_path
        report.document_name = os.path.basename(file_path)
        report.updated_at = datetime.now(timezone.utc)
        db.commit()
        
        # Calculate file hash
        file_hash = calculate_file_hash(file_path)
        report.file_hash = file_hash
        db.commit()

        # 2. Extract text AND store RAG chunks in a single PDF pass
        # (process_and_extract opens the file once, builds chunks + full text together)
        logger.info(f"Opening PDF for RAG indexing + full-text extraction (single pass) for loan_id={loan_id}")
        text, num_chunks = pdf_processor.process_and_extract(file_path, loan_id)
        logger.info(f"Single-pass PDF processing done. Chunks: {num_chunks}, Text size: {len(text)} chars for loan_id={loan_id}")

        if not text or not text.strip():
            raise ValueError("No extractable text found in PDF document.")

        # 4. Run AI Extraction & Audit Pipeline (async)
        logger.info(f"Running LoanExtractionService pipeline for loan_id={loan_id}")
        extraction_service = _get_extraction_service()
        
        # Executing async pipeline in a synchronous worker thread
        analysis_response = asyncio.run(extraction_service.analyze_document(text))
        logger.info(f"AI Extraction & Calculations completed for loan_id={loan_id}")

        # 5. Populate and Save to Database
        # Extract metadata fields directly for SQL columns
        report.lender_name = analysis_response.metadata.lender_name
        report.loan_type = analysis_response.metadata.loan_type
        report.principal_amount = analysis_response.metadata.principal_amount
        
        # Serialize the entire analysis response to a JSON-safe dict
        report.analysis_json = analysis_response.model_dump(mode="json")
        
        report.status = ProcessingStatus.COMPLETED
        report.processing_duration = time.time() - start_time
        report.error_message = None
        report.updated_at = datetime.now(timezone.utc)
        
        db.commit()
        logger.info(f"Database saved. LoanReport status updated to COMPLETED for loan_id={loan_id}")

        # ── Cache integration ──────────────────────────────────────────────────
        # 1. Invalidate any stale chat/doc caches for this loan (e.g. re-upload).
        # 2. Seed the analysis cache so the first chat hit is instant.
        async def _update_cache():
            await cache.delete_loan(loan_id)
            await cache.set_analysis(loan_id, report.analysis_json)
        asyncio.run(_update_cache())
        # ──────────────────────────────────────────────────────────────────

        return f"Success: loan_id={loan_id} processed"

    except Exception as exc:
        db.rollback()
        logger.error(f"Task failed: Error processing loan document for loan_id={loan_id}: {exc}")
        
        # If we have run out of retries, mark as FAILED and stop
        if self.request.retries >= self.max_retries:
            logger.error(f"Max retries reached. Marking loan_id={loan_id} as FAILED.")
            try:
                if report:
                    report.status = ProcessingStatus.FAILED
                    report.error_message = str(exc)
                    report.processing_duration = time.time() - start_time
                    report.updated_at = datetime.now(timezone.utc)
                    db.commit()
            except Exception as db_exc:
                logger.error(f"Failed to write FAILED status to database: {db_exc}")
            raise exc  # Don't retry, just propagate

        # Still have retries left — retry with exponential backoff
        countdown = 2 ** self.request.retries  # 1s, 2s, 4s
        logger.warning(f"Retrying loan_id={loan_id} in {countdown}s (attempt {self.request.retries + 1}/{self.max_retries})")
        raise self.retry(exc=exc, countdown=countdown)
        
    finally:
        db.close()
