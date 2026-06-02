import logging
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status
from app.models.api_schemas import ChatRequest, ChatResponse
from app.services.ai.chat_service import ChatService
from app.api.deps import get_chat_service

logger = logging.getLogger(__name__)
router = APIRouter()

@router.post("/{loan_id}", response_model=ChatResponse)
async def chat_with_loan(
    loan_id: str,
    query: Optional[str] = None,
    request_data: Optional[ChatRequest] = None,
    chat_service: ChatService = Depends(get_chat_service)
):
    """Interact with the loan document using RAG assistant and retrieve citation-backed responses."""
    logger.info(f"Chat request received for loan_id={loan_id}")
    
    # Support query parameter (for frontend compatibility) or request body
    chat_query = query
    chat_history = []
    session_id = None
    
    if request_data:
        if not chat_query:
            chat_query = request_data.query
        chat_history = request_data.history or []
        
    if not chat_query:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="A 'query' must be provided either as a query parameter or in the request body."
        )
        
    try:
        response = await chat_service.get_answer(
            loan_id=loan_id,
            query=chat_query,
            history=chat_history,
            session_id=session_id
        )
        logger.info(f"Chat request processed successfully for loan_id={loan_id}")
        return response
    except Exception as e:
        logger.error(f"Chat failure for loan_id={loan_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Chat failure: {str(e)}"
        )
