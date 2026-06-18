"""
app/services/user_profile_service.py
Business logic for user profile and settings management.

All public methods follow an "upsert" pattern: they retrieve or create
the row for the given user_id so no explicit initialisation step is needed.
"""

import logging
import os
from datetime import datetime, timezone
from typing import Any, Dict, Optional

from sqlalchemy.orm import Session

from app.database.models import LoanReport
from app.database.user_models import UserProfile, UserSettings
from app.models.user_profile_schemas import (
    NotificationSettingsSchema,
    PrivacySettingsSchema,
    UpdateUserProfileRequest,
    UpdateUserSettingsRequest,
    UserProfileResponse,
    UserSettingsResponse,
)

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Default values (mirror Flutter AppSettings.defaults())
# ---------------------------------------------------------------------------

_DEFAULT_NOTIFICATIONS: Dict[str, Any] = {
    "pushEnabled": True,
    "emailEnabled": True,
    "riskAlerts": True,
    "weeklyDigest": False,
    "aiInsights": True,
}

_DEFAULT_PRIVACY: Dict[str, Any] = {
    "biometricLock": True,
    "dataCollectionOptIn": False,
    "crashReporting": True,
    "dataRetentionDays": "30 Days",
}

_DEFAULT_DISPLAY_NAME = "LoanSense User"
_DEFAULT_EMAIL = "user@loansense.ai"
_APP_VERSION = "v4.12.0-STABLE"


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


# ---------------------------------------------------------------------------
# UserProfileService
# ---------------------------------------------------------------------------


class UserProfileService:
    """Handles all database operations for user profile and settings."""

    # ------------------------------------------------------------------
    # Profile
    # ------------------------------------------------------------------

    def get_or_create_profile(
        self, db: Session, user_id: str = "default"
    ) -> UserProfile:
        """
        Return the UserProfile row for user_id, creating it with sensible
        defaults if it does not yet exist.
        """
        profile = (
            db.query(UserProfile)
            .filter(UserProfile.user_id == user_id)
            .first()
        )
        if profile is None:
            logger.info(f"Creating default UserProfile for user_id={user_id!r}")
            profile = UserProfile(
                user_id=user_id,
                display_name=_DEFAULT_DISPLAY_NAME,
                email=_DEFAULT_EMAIL,
            )
            db.add(profile)
            db.commit()
            db.refresh(profile)
        return profile

    def update_profile(
        self,
        db: Session,
        data: UpdateUserProfileRequest,
        user_id: str = "default",
    ) -> UserProfile:
        """
        Apply the non-null fields from data to the UserProfile row.
        """
        profile = self.get_or_create_profile(db, user_id)

        changed = False
        if data.display_name is not None:
            profile.display_name = data.display_name
            changed = True
        if data.email is not None:
            profile.email = data.email
            changed = True
        if data.phone_number is not None:
            profile.phone_number = data.phone_number
            changed = True
        if data.avatar_url is not None:
            profile.avatar_url = data.avatar_url
            changed = True

        if changed:
            profile.updated_at = _utcnow()
            db.commit()
            db.refresh(profile)
            logger.info(f"Updated UserProfile for user_id={user_id!r}")

        return profile

    # ------------------------------------------------------------------
    # Settings
    # ------------------------------------------------------------------

    def get_or_create_settings(
        self, db: Session, user_id: str = "default"
    ) -> UserSettings:
        """
        Return the UserSettings row for user_id, creating it with defaults
        if it does not yet exist.
        """
        settings = (
            db.query(UserSettings)
            .filter(UserSettings.user_id == user_id)
            .first()
        )
        if settings is None:
            logger.info(f"Creating default UserSettings for user_id={user_id!r}")
            settings = UserSettings(
                user_id=user_id,
                theme_mode="dark",
                ai_response_style="balanced",
                language="en_US",
                notifications=_DEFAULT_NOTIFICATIONS,
                privacy=_DEFAULT_PRIVACY,
                app_version=_APP_VERSION,
            )
            db.add(settings)
            db.commit()
            db.refresh(settings)
        return settings

    def update_settings(
        self,
        db: Session,
        data: UpdateUserSettingsRequest,
        user_id: str = "default",
    ) -> UserSettings:
        """
        Apply the non-null fields from data to the UserSettings row.
        Nested notification/privacy objects are deep-merged so a partial
        update (e.g. only weeklyDigest) doesn't clobber other flags.
        """
        settings = self.get_or_create_settings(db, user_id)

        changed = False

        if data.theme_mode is not None:
            settings.theme_mode = data.theme_mode
            changed = True

        if data.ai_response_style is not None:
            settings.ai_response_style = data.ai_response_style
            changed = True

        if data.language is not None:
            settings.language = data.language
            changed = True

        if data.notifications is not None:
            # Deep-merge: start from existing, overlay incoming
            existing_notif = dict(settings.notifications or _DEFAULT_NOTIFICATIONS)
            incoming = data.notifications.model_dump(by_alias=True, exclude_none=True)
            existing_notif.update(incoming)
            settings.notifications = existing_notif
            changed = True

        if data.privacy is not None:
            existing_priv = dict(settings.privacy or _DEFAULT_PRIVACY)
            incoming = data.privacy.model_dump(by_alias=True, exclude_none=True)
            existing_priv.update(incoming)
            settings.privacy = existing_priv
            changed = True

        if changed:
            settings.updated_at = _utcnow()
            db.commit()
            db.refresh(settings)
            logger.info(f"Updated UserSettings for user_id={user_id!r}")

        return settings

    # ------------------------------------------------------------------
    # Document management
    # ------------------------------------------------------------------

    def delete_all_documents(
        self, db: Session, user_id: str = "default"
    ) -> int:
        """
        Delete all LoanReport rows associated with user_id and their
        corresponding files on disk.

        Returns the count of documents deleted.
        """
        reports = (
            db.query(LoanReport)
            .filter(LoanReport.user_id == user_id)
            .all()
        )

        deleted_count = 0
        for report in reports:
            # Remove the file from disk (best effort)
            if report.file_path and os.path.isfile(report.file_path):
                try:
                    os.remove(report.file_path)
                    logger.info(f"Deleted file: {report.file_path}")
                except OSError as exc:
                    logger.warning(f"Could not delete file {report.file_path}: {exc}")

            db.delete(report)
            deleted_count += 1

        if deleted_count > 0:
            db.commit()
            logger.info(
                f"Deleted {deleted_count} document(s) for user_id={user_id!r}"
            )

        return deleted_count

    def delete_document_by_id(
        self, db: Session, document_id: str, user_id: str = "default"
    ) -> bool:
        """
        Delete a single LoanReport by loan_id (string UUID).
        Returns True if found-and-deleted, False if not found.
        """
        import uuid as _uuid

        try:
            loan_uuid = _uuid.UUID(document_id)
        except ValueError:
            logger.warning(f"Invalid document_id format: {document_id!r}")
            return False

        report = (
            db.query(LoanReport)
            .filter(
                LoanReport.loan_id == loan_uuid,
                LoanReport.user_id == user_id,
            )
            .first()
        )
        if report is None:
            return False

        if report.file_path and os.path.isfile(report.file_path):
            try:
                os.remove(report.file_path)
            except OSError as exc:
                logger.warning(f"Could not delete file {report.file_path}: {exc}")

        db.delete(report)
        db.commit()
        logger.info(
            f"Deleted document loan_id={document_id!r} for user_id={user_id!r}"
        )
        return True

    # ------------------------------------------------------------------
    # Auth / session
    # ------------------------------------------------------------------

    def logout(self, db: Session, user_id: str = "default") -> None:
        """
        Invalidate the user session server-side.

        Currently a no-op stub — when JWT blacklisting or session tables
        are added, the token/session invalidation logic goes here.
        """
        logger.info(f"User logout recorded for user_id={user_id!r}")

    # ------------------------------------------------------------------
    # Response builders (ORM → Pydantic)
    # ------------------------------------------------------------------

    @staticmethod
    def profile_to_response(profile: UserProfile) -> UserProfileResponse:
        """Convert a UserProfile ORM object to its Pydantic response schema."""
        return UserProfileResponse(
            id=profile.user_id,
            display_name=profile.display_name or _DEFAULT_DISPLAY_NAME,
            email=profile.email or _DEFAULT_EMAIL,
            phone_number=profile.phone_number,
            avatar_url=profile.avatar_url,
            created_at=profile.created_at,
            updated_at=profile.updated_at,
        )

    @staticmethod
    def settings_to_response(settings: UserSettings) -> UserSettingsResponse:
        """Convert a UserSettings ORM object to its Pydantic response schema."""
        notif_data = settings.notifications or _DEFAULT_NOTIFICATIONS
        priv_data = settings.privacy or _DEFAULT_PRIVACY

        # Map camelCase JSON keys → Pydantic snake_case fields
        notifications = NotificationSettingsSchema(
            push_enabled=notif_data.get("pushEnabled", True),
            email_enabled=notif_data.get("emailEnabled", True),
            risk_alerts=notif_data.get("riskAlerts", True),
            weekly_digest=notif_data.get("weeklyDigest", False),
            ai_insights=notif_data.get("aiInsights", True),
        )
        privacy = PrivacySettingsSchema(
            biometric_lock=priv_data.get("biometricLock", True),
            data_collection_opt_in=priv_data.get("dataCollectionOptIn", False),
            crash_reporting=priv_data.get("crashReporting", True),
            data_retention_days=priv_data.get("dataRetentionDays", "30 Days"),
        )

        return UserSettingsResponse(
            theme_mode=settings.theme_mode,
            ai_response_style=settings.ai_response_style,
            language=settings.language,
            notifications=notifications,
            privacy=privacy,
            app_version=settings.app_version,
        )
