from .loan_metadata import LoanMetadata
from .risk_clause import RiskLevel, RiskCategory, RiskClause
from .loan_score import SafetyRating, LoanSafetyScore
from .chat_citation import CitationType, ChatCitation, RAGResponse
from .loan_analysis import LoanAnalysisResponse
from .loan_comparison import LoanComparisonResult, LoanComparison
from .api_schemas import (
    AnalysisResponse,
    RisksResponse,
    CompareRequest,
    CompareResponse,
    ChatRequest,
    ChatResponse,
)
from .user_profile_schemas import (
    NotificationSettingsSchema,
    PrivacySettingsSchema,
    UserProfileResponse,
    UpdateUserProfileRequest,
    UserSettingsResponse,
    UpdateUserSettingsRequest,
    LogoutResponse,
    DeleteDocumentsResponse,
)

__all__ = [
    "LoanMetadata",
    "RiskLevel",
    "RiskCategory",
    "RiskClause",
    "SafetyRating",
    "LoanSafetyScore",
    "CitationType",
    "ChatCitation",
    "RAGResponse",
    "LoanAnalysisResponse",
    "LoanComparisonResult",
    "LoanComparison",
    "AnalysisResponse",
    "RisksResponse",
    "CompareRequest",
    "CompareResponse",
    "ChatRequest",
    "ChatResponse",
    # User profile & settings
    "NotificationSettingsSchema",
    "PrivacySettingsSchema",
    "UserProfileResponse",
    "UpdateUserProfileRequest",
    "UserSettingsResponse",
    "UpdateUserSettingsRequest",
    "LogoutResponse",
    "DeleteDocumentsResponse",
]
