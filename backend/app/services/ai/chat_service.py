import asyncio
import logging
import re
import uuid
from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field
from langchain_nvidia_ai_endpoints import ChatNVIDIA, NVIDIAEmbeddings
from langchain_community.vectorstores import Chroma
from langchain_core.prompts import ChatPromptTemplate
from langchain_community.retrievers import BM25Retriever
from langchain_core.documents import Document
from sqlalchemy.orm import Session
from app.core.config import settings
from app.database.models import LoanReport, ChatMessage
from app.database.session import SessionLocal
from app.models.chat_citation import ChatCitation, CitationType
from app.models.loan_analysis import LoanAnalysisResponse
from app.models.api_schemas import ChatResponse
from app.services.cache_service import cache

logger = logging.getLogger(__name__)


class _CachedDoc:
    """Duck-typed LangChain Document reconstructed from cached dict."""
    def __init__(self, page_content: str, metadata: dict):
        self.page_content = page_content
        self.metadata = metadata

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
        # ── Cache layer 1: document chunk cache ──────────────────────────────
        cached_docs = await cache.get_docs(loan_id, query)
        if cached_docs is not None:
            return [_CachedDoc(d["page_content"], d["metadata"]) for d in cached_docs]

        # ── Cache miss: hit ChromaDB + embedding API ──────────────────────────
        vector_store = Chroma(
            persist_directory=settings.CHROMA_DB_DIR,
            embedding_function=self.embeddings,
            collection_name="loan_documents"
        )
        
        # 1. Dense (Vector) Retrieval
        dense_retriever = vector_store.as_retriever(
            search_type="similarity",
            search_kwargs={
                "k": 10,
                "filter": {"loan_id": loan_id},
            }
        )
        dense_docs = await self._invoke_retriever(dense_retriever, query)

        # 2. Sparse (BM25) Retrieval
        try:
            payload = vector_store._collection.get(  # noqa: SLF001
                where={"loan_id": loan_id},
                include=["documents", "metadatas"],
            )
            all_chunks = payload.get("documents") or []
            all_metadatas = payload.get("metadatas") or []
        except Exception as exc:
            logger.warning(f"Error fetching all chunks from Chroma for BM25 setup: {exc}")
            all_chunks, all_metadatas = [], []

        bm25_docs = []
        if all_chunks:
            lc_docs = [
                Document(page_content=chunk, metadata=meta)
                for chunk, meta in zip(all_chunks, all_metadatas)
                if chunk
            ]
            try:
                bm25_retriever = BM25Retriever.from_documents(lc_docs)
                bm25_retriever.k = min(len(lc_docs), 10)
                bm25_docs = await asyncio.to_thread(bm25_retriever.invoke, query)
            except Exception as exc:
                logger.error(f"Failed to run BM25 retriever: {exc}")
                bm25_docs = []

        # 3. Reciprocal Rank Fusion (RRF)
        combined_docs = self._reciprocal_rank_fusion(dense_docs, bm25_docs)

        # 4. Hybrid Sparse-Dense Reranking
        final_docs = self._hybrid_rerank(combined_docs, query, top_n=6)

        # Store in Redis for next time (fire-and-forget)
        if final_docs:
            await cache.set_docs(loan_id, query, final_docs)

        return final_docs

    def _reciprocal_rank_fusion(
        self,
        vector_docs: List[Any],
        bm25_docs: List[Any],
        k: int = 60,
    ) -> List[Any]:
        """Combine dense and sparse search results using Reciprocal Rank Fusion."""
        doc_map = {}
        
        # Build 1-based ranks
        vector_ranks = {doc.page_content: i + 1 for i, doc in enumerate(vector_docs)}
        bm25_ranks = {doc.page_content: i + 1 for i, doc in enumerate(bm25_docs)}
        
        for doc in vector_docs:
            doc_map[doc.page_content] = doc
        for doc in bm25_docs:
            doc_map[doc.page_content] = doc
            
        scores = {}
        for content in doc_map:
            score = 0.0
            if content in vector_ranks:
                score += 1.0 / (k + vector_ranks[content])
            if content in bm25_ranks:
                score += 1.0 / (k + bm25_ranks[content])
            scores[content] = score
            
        # Sort documents desc by RRF score
        sorted_contents = sorted(scores.keys(), key=lambda x: scores[x], reverse=True)
        return [doc_map[content] for content in sorted_contents]

    def _hybrid_rerank(self, combined_docs: List[Any], query: str, top_n: int = 6) -> List[Any]:
        """Rerank retrieved chunks by raw keyword overlap count to prioritize exact matches."""
        query_terms = self._extract_query_terms(query)
        if not query_terms:
            return combined_docs[:top_n]
            
        scored_docs = []
        for doc in combined_docs:
            term_score = self._score_chunk(doc.page_content, query_terms)
            scored_docs.append((term_score, doc))
            
        # Sort by keyword match count descending, preserving original relative RRF order
        scored_docs.sort(key=lambda item: item[0], reverse=True)
        return [doc for score, doc in scored_docs[:top_n]]


    def _load_analysis_response(self, loan_id: str) -> Optional[tuple[LoanReport, LoanAnalysisResponse]]:
        """Load persisted analysis data — checks Redis first, then SQLite."""
        try:
            loan_uuid = uuid.UUID(loan_id)
        except ValueError:
            return None

        db = SessionLocal()
        try:
            report = db.query(LoanReport).filter(LoanReport.loan_id == loan_uuid).first()
            if not report or not report.analysis_json:
                return None

            analysis = LoanAnalysisResponse.model_validate(report.analysis_json)
            return report, analysis
        except Exception as exc:
            logger.warning(f"Unable to load persisted analysis for loan_id={loan_id}: {exc}")
            return None
        finally:
            db.close()

    def _extract_query_terms(self, query: str) -> List[str]:
        stop_words = {
            "the", "and", "for", "with", "that", "this", "from", "what", "when",
            "where", "which", "will", "have", "has", "are", "was", "were", "can",
            "could", "should", "would", "about", "loan", "please", "tell", "show",
            "explain", "summarise", "summarize", "summary", "details", "me", "to",
            "a", "an", "in", "on", "of", "it", "is",
        }
        tokens = re.findall(r"[a-z0-9]+", query.lower())
        return [token for token in tokens if len(token) > 2 and token not in stop_words]

    def _score_chunk(self, text: str, query_terms: List[str]) -> int:
        lowered = text.lower()
        return sum(lowered.count(term) for term in query_terms)

    def _build_analysis_fallback_response(
        self,
        loan_id: str,
        query: str,
        session_id: Optional[str],
    ) -> Optional[ChatResponse]:
        loaded = self._load_analysis_response(loan_id)
        if not loaded:
            return None

        report, analysis = loaded
        query_terms = self._extract_query_terms(query)

        risks = list(analysis.risks)
        if query_terms:
            risks.sort(
                key=lambda risk: self._score_chunk(
                    " ".join([
                        risk.clause_title,
                        risk.clause_text,
                        risk.explanation,
                        getattr(risk.category, "value", str(risk.category)),
                    ]),
                    query_terms,
                ),
                reverse=True,
            )
        else:
            risks.sort(key=lambda risk: (risk.page_number, risk.clause_title))

        highlighted_risks = risks[:3]
        answer_lines = [analysis.ai_summary.strip()]

        if highlighted_risks:
            answer_lines.append("Most relevant clauses:")
            for risk in highlighted_risks:
                answer_lines.append(
                    f"- {risk.clause_title} (Page {risk.page_number}): {risk.explanation}"
                )

        citations: List[ChatCitation] = []
        for risk in highlighted_risks:
            category_text = getattr(risk.category, "value", str(risk.category)).lower()
            citation_type = CitationType.RISK_CLAUSE
            if "fee" in category_text or "charge" in category_text:
                citation_type = CitationType.FEE_TABLE
            elif "legal" in category_text or "interest" in category_text:
                citation_type = CitationType.LEGAL_PROVISION

            citations.append(
                ChatCitation(
                    page_number=risk.page_number,
                    source_text=risk.clause_text,
                    confidence=min(1.0, max(0.55, float(analysis.confidence_score))),
                    citation_type=citation_type,
                    clause_reference=risk.clause_title,
                )
            )

        return ChatResponse(
            answer="\n".join(answer_lines).strip(),
            citations=citations,
            confidence_score=float(analysis.confidence_score),
            source_references=[report.document_name or "Agreement.pdf"],
            supporting_clauses=[risk.clause_title for risk in highlighted_risks if risk.clause_title],
            session_id=session_id,
        )

    def _build_document_fallback_response(
        self,
        loan_id: str,
        query: str,
        session_id: Optional[str],
    ) -> Optional[ChatResponse]:
        try:
            vector_store = Chroma(
                persist_directory=settings.CHROMA_DB_DIR,
                embedding_function=self.embeddings,
                collection_name="loan_documents",
            )
            payload = vector_store._collection.get(  # noqa: SLF001 - direct Chroma fallback
                where={"loan_id": loan_id},
                include=["documents", "metadatas"],
            )
        except Exception as exc:
            logger.warning(f"Document fallback retrieval failed for loan_id={loan_id}: {exc}")
            return None

        documents = payload.get("documents") or []
        metadatas = payload.get("metadatas") or []
        if not documents or not metadatas:
            return None

        query_terms = self._extract_query_terms(query)
        chunks = []
        for document, metadata in zip(documents, metadatas):
            if not document:
                continue
            chunk_text = str(document).strip()
            if not chunk_text:
                continue
            score = self._score_chunk(chunk_text, query_terms) if query_terms else 0
            chunks.append((score, chunk_text, metadata or {}))

        if not chunks:
            return None

        chunks.sort(key=lambda item: item[0], reverse=True)
        selected = chunks[:3]

        answer_lines = [
            "I could not complete the NVIDIA-backed answer right now, but these are the most relevant document excerpts I found:",
        ]
        citations: List[ChatCitation] = []
        supporting_clauses: List[str] = []
        source_references: List[str] = []

        for _, chunk_text, metadata in selected:
            page_number = int(metadata.get("page_number", 1) or 1)
            source_name = metadata.get("source", "Agreement.pdf")
            snippet = re.sub(r"\s+", " ", chunk_text).strip()
            if len(snippet) > 260:
                snippet = snippet[:257].rstrip() + "..."

            answer_lines.append(f"- Page {page_number}: {snippet}")
            citations.append(
                ChatCitation(
                    page_number=page_number,
                    source_text=chunk_text,
                    confidence=0.6,
                    citation_type=CitationType.GENERAL,
                    clause_reference=source_name,
                )
            )
            supporting_clauses.append(f"Page {page_number}")
            source_references.append(source_name)

        return ChatResponse(
            answer="\n".join(answer_lines).strip(),
            citations=citations,
            confidence_score=0.6,
            source_references=source_references,
            supporting_clauses=supporting_clauses,
            session_id=session_id,
        )

    async def _invoke_retriever(self, retriever: Any, query: str):
        """Support both legacy and current LangChain retriever APIs."""
        if hasattr(retriever, "ainvoke"):
            return await retriever.ainvoke(query)

        if hasattr(retriever, "aget_relevant_documents"):
            return await retriever.aget_relevant_documents(query)

        if hasattr(retriever, "invoke"):
            return await asyncio.to_thread(retriever.invoke, query)

        if hasattr(retriever, "get_relevant_documents"):
            return await asyncio.to_thread(retriever.get_relevant_documents, query)

        raise AttributeError(
            "Retriever does not expose a supported document retrieval method."
        )

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

        # ── Cache layer 2: full response cache ────────────────────────────────
        # Conversations with history are never cached (context-dependent).
        if not history:
            cached_response = await cache.get_chat(loan_id, query)
            if cached_response is not None:
                logger.info(f"[Cache] Returning cached chat response for loan_id={loan_id}")
                return ChatResponse(**cached_response)
        # ─────────────────────────────────────────────────────────────────────

        try:
            self._ensure_runtime()
            source_documents = await self._get_relevant_documents(loan_id, query)
        except Exception as e:
            logger.error(f"Chat runtime unavailable for loan_id={loan_id}: {e}", exc_info=True)
            fallback = self._build_analysis_fallback_response(loan_id, query, session_id)
            if fallback is not None:
                return fallback

            fallback = self._build_document_fallback_response(loan_id, query, session_id)
            if fallback is not None:
                return fallback

            return self._build_unavailable_response(
                "The loan assistant is temporarily unavailable because the AI backend is not configured correctly. Verify the NVIDIA API key and vector database setup, then try again.",
                session_id,
            )
        
        if not source_documents:
            logger.warning(f"No source documents found in ChromaDB for loan_id={loan_id}")
            fallback = self._build_analysis_fallback_response(loan_id, query, session_id)
            if fallback is not None:
                return fallback

            fallback = self._build_document_fallback_response(loan_id, query, session_id)
            if fallback is not None:
                return fallback

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
            fallback = self._build_analysis_fallback_response(loan_id, query, session_id)
            if fallback is not None:
                return fallback

            fallback = self._build_document_fallback_response(loan_id, query, session_id)
            if fallback is not None:
                return fallback

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

        response = ChatResponse(
            answer=structured_res.answer,
            citations=validated_citations,
            confidence_score=structured_res.confidence_score,
            source_references=source_refs,
            supporting_clauses=supporting_clauses,
            session_id=session_id
        )

        # ── Write-through: cache the full response for future identical queries ──
        if not history:
            await cache.set_chat(loan_id, query, response.model_dump())

        return response

    async def get_answer_stream(
        self,
        loan_id: str,
        query: str,
        db: Session,
        history: Optional[List[Dict[str, Any]]] = None,
        session_id: Optional[str] = None
    ):
        """Perform asynchronous RAG retrieval and yield streaming tokens, then structured citations at the end."""
        logger.info(f"Streaming chat request for loan_id={loan_id}, query='{query}'")
        
        try:
            self._ensure_runtime()
            source_documents = await self._get_relevant_documents(loan_id, query)
        except Exception as e:
            logger.error(f"Chat runtime unavailable for loan_id={loan_id}: {e}", exc_info=True)
            fallback = self._build_analysis_fallback_response(loan_id, query, session_id)
            if fallback is not None:
                yield {"type": "token", "content": fallback.answer}
                yield {"type": "final", "citations": [c.model_dump() for c in fallback.citations], "confidence_score": fallback.confidence_score}
                return
            
            fallback = self._build_document_fallback_response(loan_id, query, session_id)
            if fallback is not None:
                yield {"type": "token", "content": fallback.answer}
                yield {"type": "final", "citations": [c.model_dump() for c in fallback.citations], "confidence_score": fallback.confidence_score}
                return
                
            err_msg = "The loan assistant is temporarily unavailable because the AI backend is not configured correctly."
            yield {"type": "token", "content": err_msg}
            yield {"type": "final", "citations": [], "confidence_score": 0.0}
            return

        if not source_documents:
            logger.warning(f"No source documents found in ChromaDB for loan_id={loan_id}")
            fallback = self._build_analysis_fallback_response(loan_id, query, session_id)
            if fallback is not None:
                yield {"type": "token", "content": fallback.answer}
                yield {"type": "final", "citations": [c.model_dump() for c in fallback.citations], "confidence_score": fallback.confidence_score}
                return
                
            fallback = self._build_document_fallback_response(loan_id, query, session_id)
            if fallback is not None:
                yield {"type": "token", "content": fallback.answer}
                yield {"type": "final", "citations": [c.model_dump() for c in fallback.citations], "confidence_score": fallback.confidence_score}
                return
                
            err_msg = "I cannot find the answer in the provided loan document."
            yield {"type": "token", "content": err_msg}
            yield {"type": "final", "citations": [], "confidence_score": 0.0}
            return

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

        # 5. Build raw streaming prompt
        template = """You are "LoanSense AI", a professional retail lending auditor and legal RAG assistant.
Your goal is to answer the user's question about their loan agreement based ONLY on the provided document context and chat history.

Chat History:
{history_str}

Context:
{context}

Question: {question}

Format your output exactly as follows:
1. First, output the plain-text answer directly. Do not use markdown code blocks or JSON formatting for the answer itself.
2. Immediately after the answer, output the exact tag: `[CITATIONS]`
3. Right after the tag, output a valid JSON array of citations. Do not wrap the JSON in markdown code blocks. Each citation must be a JSON object with fields:
   - "page_number": integer
   - "source_text": string (exact verbatim text from context)
   - "confidence": float between 0.0 and 1.0
   - "citation_type": string (one of: metadata, risk_clause, fee_table, legal_provision, general)
   - "clause_reference": string (e.g. "Clause 7.2") or null
4. Right after the citations JSON, output the exact tag: `[CONFIDENCE]`
5. Output the confidence score as a single float between 0.0 and 1.0.
"""
        prompt = ChatPromptTemplate.from_template(template)
        chain = prompt | self.llm

        full_content = ""
        answer_yielded = 0
        
        try:
            async for chunk in chain.astream({
                "context": context_str,
                "history_str": history_str,
                "question": query
            }):
                content = chunk.content
                full_content += content
                
                if "[CITATIONS]" in full_content:
                    parts = full_content.split("[CITATIONS]")
                    answer_text = parts[0]
                    if len(answer_text) > answer_yielded:
                        yield {"type": "token", "content": answer_text[answer_yielded:]}
                        answer_yielded = len(answer_text)
                else:
                    yield {"type": "token", "content": content}
                    answer_yielded = len(full_content)
        except Exception as e:
            logger.error(f"Error invoking raw streaming chain: {e}", exc_info=True)
            yield {"type": "token", "content": "\n[Stream interrupted]"}
            yield {"type": "final", "citations": [], "confidence_score": 0.0}
            return

        # Parse citations and confidence score
        citations_list = []
        confidence_val = 0.0
        answer_final = full_content
        
        if "[CITATIONS]" in full_content:
            parts = full_content.split("[CITATIONS]")
            answer_final = parts[0]
            citations_part = parts[1]
            
            if "[CONFIDENCE]" in citations_part:
                subparts = citations_part.split("[CONFIDENCE]")
                citations_str = subparts[0].strip()
                confidence_str = subparts[1].strip()
            else:
                citations_str = citations_part.strip()
                confidence_str = "0.0"
                
            try:
                citations_str = re.sub(r"^```json\s*", "", citations_str)
                citations_str = re.sub(r"\s*```$", "", citations_str)
                import json
                citations_list = json.loads(citations_str)
            except Exception as e:
                logger.error(f"Failed to parse citations JSON in stream: {e} | Text: {citations_str}")
                
            try:
                confidence_val = float(confidence_str)
            except Exception:
                confidence_val = 0.0

        # Yield the final metadata
        yield {"type": "final", "citations": citations_list, "confidence_score": confidence_val}

        # Save to database
        try:
            loan_uuid = uuid.UUID(loan_id)
            user_message = ChatMessage(
                loan_id=loan_uuid,
                role="user",
                content=query
            )
            db.add(user_message)
            
            assistant_message = ChatMessage(
                loan_id=loan_uuid,
                role="assistant",
                content=answer_final.strip(),
                citations=citations_list,
                confidence_score=confidence_val
            )
            db.add(assistant_message)
            db.commit()
            logger.info(f"Streaming chat saved to database for loan_id={loan_id}")
        except Exception as db_err:
            db.rollback()
            logger.error(f"Failed to save streaming chat to database for loan_id={loan_id}: {db_err}")
