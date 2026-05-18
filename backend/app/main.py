from fastapi import FastAPI, UploadFile, File, HTTPException
from app.core.config import settings
from app.services.ai.pdf_processor import pdf_processor
from app.services.ai.chat_service import chat_service
import os
import uuid

app = FastAPI(title=settings.PROJECT_NAME)

@app.get("/")
def read_root():
    return {"message": "Welcome to LoanSense AI API"}

@app.post("/upload")
async def upload_loan(file: UploadFile = File(...)):
    if not file.filename.endswith('.pdf'):
        raise HTTPException(status_code=400, detail="Only PDF files are allowed")
    
    loan_id = str(uuid.uuid4())
    file_path = os.path.join(settings.UPLOAD_DIR, f"{loan_id}.pdf")
    
    # Ensure upload directory exists
    os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
    
    with open(file_path, "wb") as buffer:
        buffer.write(await file.read())
    
    # Process PDF (Phase 1: Synchronous for MVP)
    try:
        num_chunks = pdf_processor.process_and_store(file_path, loan_id)
        return {
            "loan_id": loan_id,
            "filename": file.filename,
            "chunks_processed": num_chunks,
            "status": "success"
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error processing PDF: {str(e)}")

@app.post("/chat/{loan_id}")
async def chat(loan_id: str, query: str):
    try:
        result = chat_service.get_answer(loan_id, query)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error in chat: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
