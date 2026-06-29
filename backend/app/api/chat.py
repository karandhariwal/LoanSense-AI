import logging
import uuid
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
import json

from app.models.api_schemas import ChatRequest, ChatResponse, ChatMessageResponse
from app.services.ai.chat_service import ChatService
from app.api.deps import get_chat_service
from app.database.session import get_db
from app.database.models import ChatMessage

logger = logging.getLogger(__name__)
router = APIRouter()


@router.post("/{loan_id}", response_model=ChatResponse)
async def chat_with_loan(
    loan_id: str,
    query: Optional[str] = None,
    request_data: Optional[ChatRequest] = None,
    chat_service: ChatService = Depends(get_chat_service),
    db: Session = Depends(get_db)
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
        loan_uuid = uuid.UUID(loan_id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid UUID loan_id: {loan_id}"
        )

    try:
        response = await chat_service.get_answer(
            loan_id=loan_id,
            query=chat_query,
            history=chat_history,
            session_id=session_id
        )
        
        # Save user message to database
        user_message = ChatMessage(
            loan_id=loan_uuid,
            role="user",
            content=chat_query
        )
        db.add(user_message)
        
        # Save assistant response to database
        citations_list = [cit.model_dump() for cit in response.citations] if response.citations else []
        assistant_message = ChatMessage(
            loan_id=loan_uuid,
            role="assistant",
            content=response.answer,
            citations=citations_list,
            confidence_score=response.confidence_score
        )
        db.add(assistant_message)
        
        db.commit()
        logger.info(f"Chat request processed and messages saved to DB for loan_id={loan_id}")
        return response
    except Exception as e:
        db.rollback()
        logger.error(f"Chat failure for loan_id={loan_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Chat failure: {str(e)}"
        )


@router.get("/{loan_id}/history", response_model=List[ChatMessageResponse])
def get_chat_history(
    loan_id: str,
    db: Session = Depends(get_db)
):
    """Retrieve the chat history for a specific loan ID."""
    logger.info(f"Retrieving chat history for loan_id={loan_id}")
    try:
        loan_uuid = uuid.UUID(loan_id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid UUID loan_id: {loan_id}"
        )

    try:
        messages = (
            db.query(ChatMessage)
            .filter(ChatMessage.loan_id == loan_uuid)
            .order_by(ChatMessage.created_at.asc())
            .all()
        )
        return messages
    except Exception as e:
        logger.error(f"Failed to retrieve chat history for loan_id={loan_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to retrieve chat history: {str(e)}"
        )


@router.post("/{loan_id}/stream")
async def chat_with_loan_stream(
    loan_id: str,
    query: Optional[str] = None,
    request_data: Optional[ChatRequest] = None,
    chat_service: ChatService = Depends(get_chat_service),
    db: Session = Depends(get_db)
):
    """Interact with the loan document using RAG assistant and stream token-by-token responses."""
    logger.info(f"Streaming chat request received for loan_id={loan_id}")
    
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
        uuid.UUID(loan_id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid UUID loan_id: {loan_id}"
        )

    async def event_generator():
        try:
            async for event in chat_service.get_answer_stream(
                loan_id=loan_id,
                query=chat_query,
                db=db,
                history=chat_history,
                session_id=session_id
            ):
                yield f"data: {json.dumps(event)}\n\n"
        except Exception as exc:
            logger.error(f"Error in chat event generator: {exc}")
            err_event = {"type": "token", "content": f"\n[Streaming error: {str(exc)}]"}
            yield f"data: {json.dumps(err_event)}\n\n"

    return StreamingResponse(event_generator(), media_type="text/event-stream")
