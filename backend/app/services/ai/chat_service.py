from langchain_nvidia_ai_endpoints import ChatNVIDIA, NVIDIAEmbeddings
from langchain_community.vectorstores import Chroma
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.runnables import RunnablePassthrough
from langchain_core.output_parsers import StrOutputParser
from app.core.config import settings

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

    def get_answer(self, loan_id: str, query: str):
        """Perform RAG retrieval and answer the query using LCEL."""
        vector_store = Chroma(
            persist_directory=settings.CHROMA_DB_DIR,
            embedding_function=self.embeddings,
            collection_name="loan_documents"
        )
        
        retriever = vector_store.as_retriever(
            search_kwargs={"filter": {"loan_id": loan_id}}
        )
        
        template = """Answer the question based only on the following context:
        {context}

        Question: {question}
        """
        prompt = ChatPromptTemplate.from_template(template)
        
        def format_docs(docs):
            return "\n\n".join(doc.page_content for doc in docs)

        rag_chain = (
            {"context": retriever | format_docs, "question": RunnablePassthrough()}
            | prompt
            | self.llm
            | StrOutputParser()
        )
        
        # Get response and source documents
        source_documents = retriever.get_relevant_documents(query)
        answer = rag_chain.invoke(query)
        
        return {
            "answer": answer,
            "sources": [doc.metadata for doc in source_documents]
        }

chat_service = ChatService()
