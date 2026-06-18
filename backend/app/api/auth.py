"""
app/api/auth.py
FastAPI router for authentication-related endpoints.

Endpoints:
    POST /auth/logout  → LogoutResponse

Note: Full JWT authentication is not yet implemented. This endpoint provides
a clean integration point for the Flutter client's sign-out flow and will
be extended when auth middleware is added.
"""

import logging

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database.session import get_db
from app.models.user_profile_schemas import LogoutResponse
from app.services.user_profile_service import UserProfileService

logger = logging.getLogger(__name__)
router = APIRouter()


def get_user_profile_service() -> UserProfileService:
    """Dependency provider for UserProfileService."""
    return UserProfileService()


@router.post(
    "/logout",
    response_model=LogoutResponse,
    summary="Logout current user",
    description=(
        "Invalidate the current user session. "
        "The Flutter client should clear locally stored tokens after calling this. "
        "Full JWT blacklisting will be added when auth middleware is implemented."
    ),
    status_code=200,
)
async def logout(
    db: Session = Depends(get_db),
    service: UserProfileService = Depends(get_user_profile_service),
) -> LogoutResponse:
    """
    POST /auth/logout
    Records the logout server-side (stub) and signals the client to clear tokens.
    """
    logger.info("POST /auth/logout requested")

    # Stub: calls the service logout method which will be wired to real session
    # invalidation when JWT authentication is added.
    service.logout(db, user_id="default")

    return LogoutResponse(message="Logged out successfully")
