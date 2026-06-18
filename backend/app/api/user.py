"""
app/api/user.py
FastAPI router for user profile and settings endpoints.

Endpoints:
    GET    /user/profile                      → UserProfileResponse
    PATCH  /user/profile                      → UserProfileResponse
    GET    /user/settings                     → UserSettingsResponse
    PATCH  /user/settings                     → UserSettingsResponse
    DELETE /user/documents                    → DeleteDocumentsResponse (all docs)
    DELETE /user/documents/{document_id}      → DeleteDocumentsResponse (one doc)
"""

import logging

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database.session import get_db
from app.models.user_profile_schemas import (
    DeleteDocumentsResponse,
    UpdateUserProfileRequest,
    UpdateUserSettingsRequest,
    UserProfileResponse,
    UserSettingsResponse,
)
from app.services.user_profile_service import UserProfileService

logger = logging.getLogger(__name__)
router = APIRouter()

# ---------------------------------------------------------------------------
# Dependency: service instance
# ---------------------------------------------------------------------------

def get_user_profile_service() -> UserProfileService:
    """Dependency provider for UserProfileService."""
    return UserProfileService()


# ---------------------------------------------------------------------------
# Resolve user_id
# ---------------------------------------------------------------------------

def _current_user_id() -> str:
    """
    Returns the current user's identifier.

    Stub: always returns "default" until JWT authentication is wired in.
    When auth is added, replace this with:
        token_data = Depends(verify_jwt_token)
        return token_data.sub
    """
    return "default"


# ---------------------------------------------------------------------------
# Profile endpoints
# ---------------------------------------------------------------------------


@router.get(
    "/profile",
    response_model=UserProfileResponse,
    response_model_by_alias=True,
    summary="Get user profile",
    description=(
        "Retrieve the current user's profile. "
        "A default profile is created automatically on first access."
    ),
)
async def get_user_profile(
    db: Session = Depends(get_db),
    service: UserProfileService = Depends(get_user_profile_service),
) -> UserProfileResponse:
    """GET /user/profile — returns (or auto-creates) the user profile."""
    logger.info("GET /user/profile requested")
    try:
        user_id = _current_user_id()
        profile = service.get_or_create_profile(db, user_id)
        return service.profile_to_response(profile)
    except Exception as exc:
        logger.error(f"Failed to fetch user profile: {exc}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch user profile: {str(exc)}",
        )


@router.patch(
    "/profile",
    response_model=UserProfileResponse,
    response_model_by_alias=True,
    summary="Update user profile",
    description=(
        "Partially update the current user's profile. "
        "Only the fields provided in the request body will be changed."
    ),
)
async def update_user_profile(
    body: UpdateUserProfileRequest,
    db: Session = Depends(get_db),
    service: UserProfileService = Depends(get_user_profile_service),
) -> UserProfileResponse:
    """PATCH /user/profile — partially update the user profile."""
    logger.info("PATCH /user/profile requested")

    # Guard: at least one field must be provided
    if not any(
        [body.display_name, body.email, body.phone_number, body.avatar_url]
    ):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="At least one field must be provided for update.",
        )

    try:
        user_id = _current_user_id()
        profile = service.update_profile(db, body, user_id)
        return service.profile_to_response(profile)
    except Exception as exc:
        logger.error(f"Failed to update user profile: {exc}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update user profile: {str(exc)}",
        )


# ---------------------------------------------------------------------------
# Settings endpoints
# ---------------------------------------------------------------------------


@router.get(
    "/settings",
    response_model=UserSettingsResponse,
    response_model_by_alias=True,
    summary="Get user settings",
    description=(
        "Retrieve the current user's application settings. "
        "Default settings are created automatically on first access."
    ),
)
async def get_user_settings(
    db: Session = Depends(get_db),
    service: UserProfileService = Depends(get_user_profile_service),
) -> UserSettingsResponse:
    """GET /user/settings — returns (or auto-creates) the user settings."""
    logger.info("GET /user/settings requested")
    try:
        user_id = _current_user_id()
        settings = service.get_or_create_settings(db, user_id)
        return service.settings_to_response(settings)
    except Exception as exc:
        logger.error(f"Failed to fetch user settings: {exc}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch user settings: {str(exc)}",
        )


@router.patch(
    "/settings",
    response_model=UserSettingsResponse,
    response_model_by_alias=True,
    summary="Update user settings",
    description=(
        "Partially update the current user's application settings. "
        "Nested objects (notifications, privacy) are deep-merged — "
        "only the keys you provide will change."
    ),
)
async def update_user_settings(
    body: UpdateUserSettingsRequest,
    db: Session = Depends(get_db),
    service: UserProfileService = Depends(get_user_profile_service),
) -> UserSettingsResponse:
    """PATCH /user/settings — partially update application settings."""
    logger.info("PATCH /user/settings requested")
    try:
        user_id = _current_user_id()
        settings = service.update_settings(db, body, user_id)
        return service.settings_to_response(settings)
    except Exception as exc:
        logger.error(f"Failed to update user settings: {exc}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update user settings: {str(exc)}",
        )


# ---------------------------------------------------------------------------
# Document management endpoints
# ---------------------------------------------------------------------------


@router.delete(
    "/documents",
    response_model=DeleteDocumentsResponse,
    response_model_by_alias=True,
    summary="Delete all uploaded documents",
    description=(
        "Delete ALL loan documents uploaded by the current user, "
        "including their on-disk files. This action is irreversible."
    ),
)
async def delete_all_user_documents(
    db: Session = Depends(get_db),
    service: UserProfileService = Depends(get_user_profile_service),
) -> DeleteDocumentsResponse:
    """DELETE /user/documents — bulk-delete all user documents."""
    logger.info("DELETE /user/documents requested")
    try:
        user_id = _current_user_id()
        count = service.delete_all_documents(db, user_id)
        return DeleteDocumentsResponse(
            deleted_count=count,
            message=f"Successfully deleted {count} document(s).",
        )
    except Exception as exc:
        logger.error(f"Failed to delete user documents: {exc}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to delete documents: {str(exc)}",
        )


@router.delete(
    "/documents/{document_id}",
    response_model=DeleteDocumentsResponse,
    response_model_by_alias=True,
    summary="Delete a specific document",
    description="Delete a single loan document by its UUID.",
)
async def delete_single_document(
    document_id: str,
    db: Session = Depends(get_db),
    service: UserProfileService = Depends(get_user_profile_service),
) -> DeleteDocumentsResponse:
    """DELETE /user/documents/{document_id} — delete one document."""
    logger.info(f"DELETE /user/documents/{document_id} requested")
    try:
        user_id = _current_user_id()
        found = service.delete_document_by_id(db, document_id, user_id)
    except Exception as exc:
        logger.error(f"Failed to delete document {document_id}: {exc}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to delete document: {str(exc)}",
        )

    if not found:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Document not found: {document_id}",
        )

    return DeleteDocumentsResponse(
        deleted_count=1,
        message=f"Document {document_id} deleted successfully.",
    )
