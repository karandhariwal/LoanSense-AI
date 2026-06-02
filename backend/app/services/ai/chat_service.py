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

class ChatAnswerSchema(BaseModel):
    """Structured LLM output for loan assistant QA."""
    answer: str = Field(
        ...,
        description="The direct plain-English answer to the user's question, based strictly on context."
    )
    citations: List[ChatCitation] = Field(
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
        self.embeddings = NVIDIAEmbeddings(
            nvidia_api_key=settings.NVIDIA_API_KEY,
            model=settings.NVIDIA_EMBED_MODEL
        )
        self.llm = ChatNVIDIA(
            model=settings.NVIDIA_LLM_MODEL,
            nvidia_api_key=settings.NVIDIA_API_KEY,
            temperature=0
        )
        # Structured output model
        self.structured_llm = self.llm.with_structured_output(ChatAnswerSchema)

    async def get_answer(
        self,
        loan_id: str,
        query: str,
        history: Optional[List[Dict[str, Any]]] = None,
        session_id: Optional[str] = None
    ) -> ChatResponse:
        """Perform asynchronous RAG retrieval and answer queries with structured citations."""
        logger.info(f"Chat request processed for loan_id={loan_id}, query='{query}'")
        
        # 1. Initialize Vector Store
        vector_store = Chroma(
            persist_directory=settings.CHROMA_DB_DIR,
            embedding_function=self.embeddings,
            collection_name="loan_documents"
        )
        
        # 2. Retrieve relevant chunks
        retriever = vector_store.as_retriever(
            search_kwargs={"filter": {"loan_id": loan_id}}
        )
        source_documents = await retriever.aget_relevant_documents(query)
        
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

        # 5. Build prompt and invoke LLM chain
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
3. Each citation MUST extract the exact verbatim 'source_text' from the context, specify the 'page_number' matching the page in the context, and specify the 'clause_reference' if available (e.g. 'Clause 7.2').
4. If the answer cannot be found in the context, state "I cannot find the answer in the provided loan document." and set confidence_score to 0.0 with empty citations.
"""
        prompt = ChatPromptTemplate.from_template(template)
        chain = prompt | self.structured_llm

        try:
            structured_res = await chain.ainvoke({
                "context": context_str,
                "history_str": history_str,
                "question": query
            })
        except Exception as e:
            logger.error(f"Error invoking structured LLM chain: {e}")
            # Fallback to simple answer on LLM structured failure
            return ChatResponse(
                answer="Sorry, I encountered an error while processing the structured citation logic.",
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

        # Ensure citations have a valid citation_type
        validated_citations = []
        for cit in structured_res.citations:
            if not cit.citation_type:
                cit.citation_type = CitationType.GENERAL
            validated_citations.append(cit)

        return ChatResponse(
            answer=structured_res.answer,
            citations=validated_citations,
            confidence_score=structured_res.confidence_score,
            source_references=source_refs,
            supporting_clauses=supporting_clauses,
            session_id=session_id
        )

chat_service = ChatService()
