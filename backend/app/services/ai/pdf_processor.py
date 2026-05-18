import fitz  # PyMuPDF
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_nvidia_ai_endpoints import NVIDIAEmbeddings
from langchain_community.vectorstores import Chroma
from app.core.config import settings
import os

class PDFProcessor:
    def __init__(self):
        self.text_splitter = RecursiveCharacterTextSplitter(
            chunk_size=1000,
            chunk_overlap=200,
            length_function=len,
        )
        self.embeddings = NVIDIAEmbeddings(
            nvidia_api_key=settings.NVIDIA_API_KEY,
            model=settings.NVIDIA_EMBED_MODEL
        )

    def extract_text(self, file_path: str) -> str:
        """Extract text from PDF using PyMuPDF."""
        doc = fitz.open(file_path)
        text = ""
        for page in doc:
            text += page.get_text()
        return text

    def process_and_store(self, file_path: str, loan_id: str):
        """Extract text, chunk it, and store in ChromaDB."""
        text = self.extract_text(file_path)
        chunks = self.text_splitter.split_text(text)
        
        # Add metadata
        metadatas = [{"loan_id": loan_id, "source": os.path.basename(file_path)} for _ in chunks]
        
        # Store in Chroma
        vector_store = Chroma(
            persist_directory=settings.CHROMA_DB_DIR,
            embedding_function=self.embeddings,
            collection_name="loan_documents"
        )
        
        vector_store.add_texts(texts=chunks, metadatas=metadatas)
        return len(chunks)

pdf_processor = PDFProcessor()
