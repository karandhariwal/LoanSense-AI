"""
app/models/user_profile_schemas.py
Pydantic request/response schemas for user profile and settings endpoints.

Key design: all response schemas use camelCase aliases that match the Flutter
UserProfile.fromJson() / AppSettings.fromJson() key names exactly, so the
Flutter client can deserialize without any mapping changes.
"""

from datetime import datetime
from typing import Any, Dict, Optional

from pydantic import BaseModel, ConfigDict, EmailStr, Field


# ---------------------------------------------------------------------------
# Shared camelCase alias helper
# ---------------------------------------------------------------------------

def _camel(name: str) -> str:
    """snake_case → camelCase for use as JSON alias."""
    parts = name.split("_")
    return parts[0] + "".join(p.capitalize() for p in parts[1:])


# ---------------------------------------------------------------------------
# Notification Settings
# ---------------------------------------------------------------------------

class NotificationSettingsSchema(BaseModel):
    """
    Mirrors Flutter NotificationSettings model.
    Keys: pushEnabled, emailEnabled, riskAlerts, weeklyDigest, aiInsights
    """

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=_camel,
    )

    push_enabled: bool = Field(default=True, description="Push notifications on/off")
    email_enabled: bool = Field(default=True, description="Email notifications on/off")
    risk_alerts: bool = Field(default=True, description="Loan risk alerts on/off")
    weekly_digest: bool = Field(default=False, description="Weekly email digest on/off")
    ai_insights: bool = Field(default=True, description="AI-generated insights on/off")


# ---------------------------------------------------------------------------
# Privacy Settings
# ---------------------------------------------------------------------------

class PrivacySettingsSchema(BaseModel):
    """
    Mirrors Flutter PrivacySettings model.
    Keys: biometricLock, dataCollectionOptIn, crashReporting, dataRetentionDays
    """

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=_camel,
    )

    biometric_lock: bool = Field(default=True, description="Require biometric auth")
    data_collection_opt_in: bool = Field(
        default=False, description="Allow analytics data collection"
    )
    crash_reporting: bool = Field(default=True, description="Send crash reports")
    data_retention_days: str = Field(
        default="30 Days", description="How long to retain documents on server"
    )


# ---------------------------------------------------------------------------
# UserProfile schemas
# ---------------------------------------------------------------------------

class UserProfileResponse(BaseModel):
    """
    Mirrors Flutter UserProfile.fromJson() — camelCase keys.
    Returned by GET /user/profile and PATCH /user/profile.
    """

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=_camel,
        json_schema_extra={
            "example": {
                "id": "default",
                "displayName": "Alexander Vance",
                "email": "alexander.vance@financial-elite.com",
                "phoneNumber": "+91 98765 43210",
                "avatarUrl": None,
                "createdAt": "2024-01-15T00:00:00Z",
                "updatedAt": "2026-06-07T11:00:00Z",
            }
        },
    )

    id: str = Field(..., description="Unique user identifier")
    display_name: str = Field(..., description="User display name")
    email: str = Field(..., description="User email address")
    phone_number: Optional[str] = Field(default=None, description="User phone number")
    avatar_url: Optional[str] = Field(default=None, description="Avatar image URL")
    created_at: datetime = Field(..., description="Profile creation timestamp (UTC)")
    updated_at: datetime = Field(..., description="Profile last-update timestamp (UTC)")


class UpdateUserProfileRequest(BaseModel):
    """
    Request body for PATCH /user/profile.
    All fields are optional — only provided fields are updated.
    """

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=_camel,
        json_schema_extra={
            "example": {
                "displayName": "Karan Dhariwal",
                "phoneNumber": "+91 99999 00000",
            }
        },
    )

    display_name: Optional[str] = Field(
        default=None,
        min_length=1,
        max_length=255,
        description="New display name",
    )
    email: Optional[str] = Field(
        default=None,
        description="New email address",
    )
    phone_number: Optional[str] = Field(
        default=None,
        max_length=50,
        description="New phone number",
    )
    avatar_url: Optional[str] = Field(
        default=None,
        description="New avatar URL",
    )


# ---------------------------------------------------------------------------
# UserSettings schemas
# ---------------------------------------------------------------------------

class UserSettingsResponse(BaseModel):
    """
    Mirrors Flutter AppSettings.fromJson() — camelCase keys.
    Returned by GET /user/settings and PATCH /user/settings.
    """

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=_camel,
        json_schema_extra={
            "example": {
                "themeMode": "dark",
                "aiResponseStyle": "balanced",
                "language": "en_US",
                "notifications": {
                    "pushEnabled": True,
                    "emailEnabled": True,
                    "riskAlerts": True,
                    "weeklyDigest": False,
                    "aiInsights": True,
                },
                "privacy": {
                    "biometricLock": True,
                    "dataCollectionOptIn": False,
                    "crashReporting": True,
                    "dataRetentionDays": "30 Days",
                },
                "appVersion": "v4.12.0-STABLE",
            }
        },
    )

    theme_mode: str = Field(default="dark", description="'dark' or 'light'")
    ai_response_style: str = Field(
        default="balanced",
        description="'precise', 'balanced', or 'analytical'",
    )
    language: str = Field(default="en_US", description="BCP-47 language code")
    notifications: NotificationSettingsSchema = Field(
        default_factory=NotificationSettingsSchema,
        description="Notification preferences",
    )
    privacy: PrivacySettingsSchema = Field(
        default_factory=PrivacySettingsSchema,
        description="Privacy preferences",
    )
    app_version: str = Field(default="v4.12.0-STABLE", description="App version string")


class UpdateUserSettingsRequest(BaseModel):
    """
    Request body for PATCH /user/settings.
    All fields optional — only provided fields are updated.
    """

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=_camel,
        json_schema_extra={
            "example": {
                "themeMode": "light",
                "aiResponseStyle": "precise",
                "notifications": {"weeklyDigest": True},
            }
        },
    )

    theme_mode: Optional[str] = Field(
        default=None,
        description="'dark' or 'light'",
        pattern="^(dark|light)$",
    )
    ai_response_style: Optional[str] = Field(
        default=None,
        description="'precise', 'balanced', or 'analytical'",
        pattern="^(precise|balanced|analytical)$",
    )
    language: Optional[str] = Field(
        default=None,
        description="BCP-47 language code (e.g. 'en_US', 'hi_IN')",
    )
    notifications: Optional[NotificationSettingsSchema] = Field(
        default=None,
        description="Notification preferences (partial update supported)",
    )
    privacy: Optional[PrivacySettingsSchema] = Field(
        default=None,
        description="Privacy preferences (partial update supported)",
    )


# ---------------------------------------------------------------------------
# Auth schemas
# ---------------------------------------------------------------------------

class LogoutResponse(BaseModel):
    """Response returned by POST /auth/logout."""

    message: str = Field(default="Logged out successfully")


# ---------------------------------------------------------------------------
# Document management schemas
# ---------------------------------------------------------------------------

class DeleteDocumentsResponse(BaseModel):
    """Response returned after deleting user documents."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=_camel,
    )

    deleted_count: int = Field(..., description="Number of documents deleted", ge=0)
    message: str = Field(..., description="Human-readable result message")


class BulkDeleteDocumentsRequest(BaseModel):
    """Request payload containing a list of document IDs to delete."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=_camel,
    )

    document_ids: list[str] = Field(..., description="List of document UUID strings to delete")

