import logging
from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field
from langchain_nvidia_ai_endpoints import ChatNVIDIA, NVIDIAEmbeddings
from langchain_community.vectorstores import Chroma
from langchain_core.prompts import ChatPromptTemplate
from app.core.config import settings
from app.models.chat_citation import ChatCitation, CitationType
from app.models.api_schemas import ChatResponse

logger = logging.getLogger(__name__)

class ChatCitationDraft(BaseModel):
    """Lenient structured citation shape returned by the LLM."""
    page_number: int = Field(..., ge=1)
    source_text: str = Field(..., min_length=10)
    confidence: Optional[float] = Field(default=None, ge=0.0, le=1.0)
    citation_type: CitationType = Field(default=CitationType.GENERAL)
    clause_reference: Optional[str] = None


class ChatAnswerSchema(BaseModel):
    """Structured LLM output for loan assistant QA."""
    answer: str = Field(
        ...,
        description="The direct plain-English answer to the user's question, based strictly on context."
    )
    citations: List[ChatCitationDraft] = Field(
        default_factory=list,
        description="List of specific citations supporting the answer."
    )
    confidence_score: float = Field(
        ...,
        ge=0.0,
        le=1.0,
        description="AI confidence score for the answer matching the context (0.0 to 1.0)."
    )


class ChatService:
    def __init__(self):
        self.embeddings: Optional[NVIDIAEmbeddings] = None
        self.llm: Optional[ChatNVIDIA] = None
        self.structured_llm = None

    def _ensure_runtime(self) -> None:
        """Initialize NVIDIA clients lazily so import/startup stays resilient."""
        if self.embeddings is not None and self.structured_llm is not None:
            return

        if not settings.NVIDIA_API_KEY:
            raise RuntimeError(
                "NVIDIA_API_KEY is not configured. The loan assistant cannot run until the backend AI key is set."
            )

        self.embeddings = NVIDIAEmbeddings(
            nvidia_api_key=settings.NVIDIA_API_KEY,
            model=settings.NVIDIA_EMBED_MODEL
        )
        self.llm = ChatNVIDIA(
            model=settings.NVIDIA_LLM_MODEL,
            nvidia_api_key=settings.NVIDIA_API_KEY,
            temperature=0
        )
        self.structured_llm = self.llm.with_structured_output(ChatAnswerSchema)

    async def _get_relevant_documents(self, loan_id: str, query: str):
        vector_store = Chroma(
            persist_directory=settings.CHROMA_DB_DIR,
            embedding_function=self.embeddings,
            collection_name="loan_documents"
        )
        retriever = vector_store.as_retriever(
            search_kwargs={"filter": {"loan_id": loan_id}}
        )
        return await retriever.aget_relevant_documents(query)

    async def _invoke_structured_chain(
        self,
        context_str: str,
        history_str: str,
        query: str,
    ) -> ChatAnswerSchema:
        template = """You are "LoanSense AI", a professional retail lending auditor and legal RAG assistant.
Your goal is to answer the user's question about their loan agreement based ONLY on the provided document context and chat history.

Chat History:
{history_str}

Context:
{context}

Question: {question}

Requirements:
1. Provide a clear, precise, and direct answer.
2. Back up your answer with citations from the context.
3. Every citation must include:
   - page_number
   - exact verbatim source_text copied from the context
   - confidence between 0.0 and 1.0
   - citation_type from: metadata, risk_clause, fee_table, legal_provision, general
   - clause_reference when available (for example "Clause 7.2")
4. If the answer cannot be found in the context, respond with "I cannot find the answer in the provided loan document.", confidence_score 0.0, and an empty citations list.
"""
        prompt = ChatPromptTemplate.from_template(template)
        chain = prompt | self.structured_llm
        return await chain.ainvoke({
            "context": context_str,
            "history_str": history_str,
            "question": query
        })

    def _build_unavailable_response(
        self,
        message: str,
        session_id: Optional[str],
    ) -> ChatResponse:
        return ChatResponse(
            answer=message,
            citations=[],
            confidence_score=0.0,
            source_references=[],
            supporting_clauses=[],
            session_id=session_id
        )

    def _normalize_citations(
        self,
        citations: List[ChatCitationDraft],
        default_confidence: float,
    ) -> List[ChatCitation]:
        normalized = []
        for citation in citations:
            normalized.append(
                ChatCitation(
                    page_number=citation.page_number,
                    source_text=citation.source_text,
                    confidence=citation.confidence if citation.confidence is not None else default_confidence,
                    citation_type=citation.citation_type or CitationType.GENERAL,
                    clause_reference=citation.clause_reference,
                )
            )
        return normalized

    async def get_answer(
        self,
        loan_id: str,
        query: str,
        history: Optional[List[Dict[str, Any]]] = None,
        session_id: Optional[str] = None
    ) -> ChatResponse:
        """Perform asynchronous RAG retrieval and answer queries with structured citations."""
        logger.info(f"Chat request processed for loan_id={loan_id}, query='{query}'")

        try:
            self._ensure_runtime()
            source_documents = await self._get_relevant_documents(loan_id, query)
        except Exception as e:
            logger.error(f"Chat runtime unavailable for loan_id={loan_id}: {e}", exc_info=True)
            return self._build_unavailable_response(
                "The loan assistant is temporarily unavailable because the AI backend is not configured correctly. Verify the NVIDIA API key and vector database setup, then try again.",
                session_id,
            )
        
        if not source_documents:
            logger.warning(f"No source documents found in ChromaDB for loan_id={loan_id}")
            return ChatResponse(
                answer="I cannot find the answer in the provided loan document. No document content is uploaded or registered under this ID.",
                citations=[],
                confidence_score=0.0,
                source_references=[],
                supporting_clauses=[],
                session_id=session_id
            )

        # 3. Format context with source and page metadata
        context_parts = []
        for doc in source_documents:
            source_file = doc.metadata.get("source", "Agreement.pdf")
            page_num = doc.metadata.get("page_number", 1)
            context_parts.append(
                f"--- Source: {source_file} | Page: {page_num} ---\n{doc.page_content}"
            )
        context_str = "\n\n".join(context_parts)

        # 4. Format chat history
        history_str = ""
        if history:
            for turn in history:
                role = turn.get("role", "user")
                content = turn.get("content", "")
                history_str += f"{role.capitalize()}: {content}\n"

        try:
            structured_res = await self._invoke_structured_chain(
                context_str=context_str,
                history_str=history_str,
                query=query,
            )
        except Exception as e:
            logger.error(f"Error invoking structured LLM chain: {e}")
            return ChatResponse(
                answer="I couldn't generate a reliable answer from the model just now. Please retry the question in a moment.",
                citations=[],
                confidence_score=0.0,
                source_references=[doc.metadata.get("source", "Agreement.pdf") for doc in source_documents][:1],
                supporting_clauses=[],
                session_id=session_id
            )

        # 6. Extract source references and supporting clauses
        source_refs = list(set(
            doc.metadata.get("source", "Agreement.pdf")
            for doc in source_documents
            if "source" in doc.metadata
        ))
        
        supporting_clauses = list(set(
            cit.clause_reference for cit in structured_res.citations if cit.clause_reference
        ))

        validated_citations = self._normalize_citations(
            structured_res.citations,
            default_confidence=structured_res.confidence_score,
        )

        return ChatResponse(
            answer=structured_res.answer,
            citations=validated_citations,
            confidence_score=structured_res.confidence_score,
            source_references=source_refs,
            supporting_clauses=supporting_clauses,
            session_id=session_id
        )
