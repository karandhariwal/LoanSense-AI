from typing import List
import logging
from pydantic import BaseModel, Field
from langchain_core.language_models import BaseChatModel
from langchain_nvidia_ai_endpoints import ChatNVIDIA
from app.core.config import settings
from app.models.risk_clause import RiskClause
from app.services.ai.prompt_templates import RISK_CLAUSE_DETECTION_PROMPT

logger = logging.getLogger(__name__)

class RiskClauseList(BaseModel):
    """Container schema for extracting a list of risk clauses."""
    risks: List[RiskClause] = Field(
        default_factory=list,
        description="A list of high-risk clauses detected in the loan agreement."
    )

class RiskDetector:
    """
    Sub-service for extracting and validating high-risk clauses from loan agreements.
    Uses ChatNVIDIA with structured output parsing.
    """
    def __init__(self, llm: BaseChatModel = None):
        if llm is not None:
            self.llm = llm
        else:
            self.llm = ChatNVIDIA(
                model=settings.NVIDIA_LLM_MODEL,
                nvidia_api_key=settings.NVIDIA_API_KEY,
                temperature=0
            )
        # Configure the structured output model
        self.structured_llm = self.llm.with_structured_output(RiskClauseList)
        self.chain = RISK_CLAUSE_DETECTION_PROMPT | self.structured_llm

    async def detect_risks(self, document_context: str) -> List[RiskClause]:
        """
        Run the risk clause detection chain.
        """
        logger.info("Executing Risk Clause Detection...")
        try:
            if not document_context or not document_context.strip():
                logger.warning("Empty document context provided to RiskDetector.")
                return []

            response: RiskClauseList = await self.chain.ainvoke({
                "document_context": document_context
            })
            
            if response and response.risks:
                logger.info(f"Successfully detected {len(response.risks)} risk clauses.")
                return response.risks
            
            logger.info("No risk clauses detected.")
            return []
        except Exception as e:
            logger.error(f"Error during risk clause detection: {e}", exc_info=True)
            # Graceful fallback: return empty list on parsing/LLM failure
            return []
