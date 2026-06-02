from app.services.ai.extraction_service import LoanExtractionService
from app.services.ai.chat_service import ChatService
from app.services.ai.comparison_service import LoanComparisonService

def get_extraction_service() -> LoanExtractionService:
    """Dependency provider for LoanExtractionService."""
    return LoanExtractionService()

def get_chat_service() -> ChatService:
    """Dependency provider for ChatService."""
    return ChatService()

def get_comparison_service() -> LoanComparisonService:
    """Dependency provider for LoanComparisonService."""
    return LoanComparisonService()
