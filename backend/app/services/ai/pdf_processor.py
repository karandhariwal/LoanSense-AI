import fitz  # PyMuPDF
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_nvidia_ai_endpoints import NVIDIAEmbeddings
from langchain_community.vectorstores import Chroma
from app.core.config import settings
import os
import logging

logger = logging.getLogger(__name__)

# Maximum characters of raw text to pass to LLM calls.
# The key financial terms and risk clauses are almost always
# in the first ~10-12 pages, so we cap text before LLM calls.
MAX_METADATA_CHARS = 12000   # ~10 pages
MAX_RISK_CHARS = 16000       # ~13 pages — risk clauses can appear later

class PDFProcessor:
    def __init__(self):
        self.text_splitter = RecursiveCharacterTextSplitter(
            chunk_size=1200,
            chunk_overlap=300,
            separators=["\n\nSection", "\n\nClause", "\n\n", "\n", ". ", " ", ""],
            length_function=len,
        )
        self.embeddings = NVIDIAEmbeddings(
            nvidia_api_key=settings.NVIDIA_API_KEY,
            model=settings.NVIDIA_EMBED_MODEL
        )

    def extract_text(self, file_path: str) -> str:
        """Extract full text from PDF using PyMuPDF."""
        doc = fitz.open(file_path)
        text = ""
        try:
            for page in doc:
                text += page.get_text()
        finally:
            doc.close()
        return text

    def process_and_store(self, file_path: str, loan_id: str):
        """Extract text, chunk it page by page, and store in ChromaDB with page_number metadata."""
        doc = fitz.open(file_path)
        all_chunks = []
        all_metadatas = []
        try:
            for page_num, page in enumerate(doc, start=1):
                page_text = page.get_text()
                if not page_text.strip():
                    continue
                chunks = self.text_splitter.split_text(page_text)
                for chunk in chunks:
                    all_chunks.append(chunk)
                    all_metadatas.append({
                        "loan_id": loan_id,
                        "source": os.path.basename(file_path),
                        "page_number": page_num
                    })
        finally:
            doc.close()

        if all_chunks:
            vector_store = Chroma(
                persist_directory=settings.CHROMA_DB_DIR,
                embedding_function=self.embeddings,
                collection_name="loan_documents"
            )
            vector_store.add_texts(texts=all_chunks, metadatas=all_metadatas)
        return len(all_chunks)

    def process_and_extract(self, file_path: str, loan_id: str) -> tuple[str, int]:
        """
        Open the PDF exactly ONCE, simultaneously:
          - Build and store all text chunks in ChromaDB (for RAG)
          - Concatenate and return the full raw text (for LLM pipeline)

        Returns:
            (full_text: str, num_chunks: int)
        """
        logger.info(f"Opening PDF once for chunking + full-text extraction: {file_path}")
        doc = fitz.open(file_path)
        all_chunks = []
        all_metadatas = []
        full_text_parts = []

        try:
            for page_num, page in enumerate(doc, start=1):
                page_text = page.get_text()
                if not page_text.strip():
                    continue

                # Accumulate full text for the LLM pipeline
                full_text_parts.append(page_text)

                # Build RAG chunks with page metadata
                chunks = self.text_splitter.split_text(page_text)
                for chunk in chunks:
                    all_chunks.append(chunk)
                    all_metadatas.append({
                        "loan_id": loan_id,
                        "source": os.path.basename(file_path),
                        "page_number": page_num
                    })
        finally:
            doc.close()

        # Store chunks in ChromaDB
        if all_chunks:
            logger.info(f"Storing {len(all_chunks)} chunks in ChromaDB for loan_id={loan_id}")
            vector_store = Chroma(
                persist_directory=settings.CHROMA_DB_DIR,
                embedding_function=self.embeddings,
                collection_name="loan_documents"
            )
            vector_store.add_texts(texts=all_chunks, metadatas=all_metadatas)
            logger.info(f"ChromaDB indexing done. {len(all_chunks)} chunks stored.")

        full_text = "\n".join(full_text_parts)
        return full_text, len(all_chunks)

pdf_processor = PDFProcessor()
