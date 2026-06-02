import os
import uuid
import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI, UploadFile, File, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session

from app.core.config import settings
from app.database.session import engine, get_db
from app.database.base import Base
from app.database.models import LoanReport  # noqa: F401 - registers model with Base
from app.database.enums import ProcessingStatus
from app.tasks import process_loan_document_task

# Import API Routers
from app.api.analysis import router as analysis_router
from app.api.risks import router as risks_router
from app.api.compare import router as compare_router
from app.api.chat import router as chat_router

# Configure logger
logger = logging.getLogger(__name__)

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Auto-create database tables on startup (SQLite) or verify connection (PostgreSQL)."""
    try:
        Base.metadata.create_all(bind=engine)
        logger.info("Database tables ensured via SQLAlchemy create_all().")
    except Exception as e:
        logger.error(f"Failed to initialize database tables: {e}")
    yield  # Application runs here

app = FastAPI(title=settings.PROJECT_NAME, lifespan=lifespan)

# Enable CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include API Routers
app.include_router(analysis_router, prefix="/analysis", tags=["analysis"])
app.include_router(risks_router, prefix="/risks", tags=["risks"])
app.include_router(compare_router, prefix="/compare", tags=["compare"])
app.include_router(chat_router, prefix="/chat", tags=["chat"])

@app.get("/")
def read_root():
    return {"message": "Welcome to LoanSense AI API"}

@app.post("/upload")
async def upload_loan(
    file: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    logger.info(f"Upload requested for file: {file.filename}")
    if not file.filename.endswith('.pdf'):
        raise HTTPException(status_code=400, detail="Only PDF files are allowed")
    
    loan_id_str = str(uuid.uuid4())
    loan_uuid = uuid.UUID(loan_id_str)
    file_path = os.path.join(settings.UPLOAD_DIR, f"{loan_id_str}.pdf")
    
    # Ensure upload directory exists
    os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
    
    try:
        with open(file_path, "wb") as buffer:
            buffer.write(await file.read())
        logger.info(f"File saved to path: {file_path}")
    except Exception as e:
        logger.error(f"Failed to save uploaded file: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to save file: {str(e)}")
    
    # Create LoanReport record in database with status PENDING
    try:
        report = LoanReport(
            loan_id=loan_uuid,
            status=ProcessingStatus.PENDING,
            document_name=file.filename,
            file_path=file_path
        )
        db.add(report)
        db.commit()
        logger.info(f"Created pending LoanReport row in database with loan_id={loan_id_str}")
    except Exception as e:
        logger.error(f"Failed to create LoanReport in database: {e}")
        raise HTTPException(status_code=500, detail=f"Database failure: {str(e)}")

    # Queue Celery background processing task
    try:
        process_loan_document_task.delay(loan_id_str, file_path)
        logger.info(f"Dispatched process_loan_document_task for loan_id={loan_id_str}")
    except Exception as e:
        logger.error(f"Failed to queue background task: {e}")
        # Update status to FAILED since task dispatch failed
        try:
            report.status = ProcessingStatus.FAILED
            report.error_message = f"Failed to queue background task: {str(e)}"
            db.commit()
        except Exception as db_err:
            logger.error(f"Failed to update task failure status in DB: {db_err}")
        raise HTTPException(status_code=500, detail=f"Celery queue failure: {str(e)}")
    
    return {
        "loan_id": loan_id_str,
        "status": "PENDING"
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
