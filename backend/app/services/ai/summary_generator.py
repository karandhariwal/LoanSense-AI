import logging
from langchain_core.language_models import BaseChatModel
from langchain_nvidia_ai_endpoints import ChatNVIDIA
from langchain_core.output_parsers import StrOutputParser
from app.core.config import settings
from app.services.ai.prompt_templates import LOAN_SUMMARY_PROMPT

logger = logging.getLogger(__name__)

class SummaryGenerator:
    """
    Sub-service for generating consumer-friendly loan summaries.
    Uses ChatNVIDIA with plain text generation.
    """
    def __init__(self, llm: BaseChatModel = None):
        if llm is not None:
            self.llm = llm
        else:
            self.llm = ChatNVIDIA(
                model=settings.NVIDIA_LLM_MODEL,
                nvidia_api_key=settings.NVIDIA_API_KEY,
                temperature=0.3  # slightly higher temperature for creative text generation
            )
        self.chain = LOAN_SUMMARY_PROMPT | self.llm | StrOutputParser()

    async def generate_summary(
        self,
        document_context: str,
        extracted_metadata: str,
        detected_risks: str
    ) -> str:
        """
        Run the summary generation chain.
        """
        logger.info("Executing Summary Generation...")
        try:
            if not document_context or not document_context.strip():
                logger.warning("Empty document context provided to SummaryGenerator.")
                return "No document text available to generate a summary."

            summary = await self.chain.ainvoke({
                "document_context": document_context,
                "extracted_metadata": extracted_metadata,
                "detected_risks": detected_risks
            })
            
            summary_stripped = summary.strip()
            logger.info(f"Successfully generated summary ({len(summary_stripped.split())} words).")
            return summary_stripped
        except Exception as e:
            logger.error(f"Error during summary generation: {e}", exc_info=True)
            # Fallback summary
            return "Unable to generate loan summary due to an internal system error."
