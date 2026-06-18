"""
app/database/user_models.py
SQLAlchemy models for user profile and application settings.

Design: single-user-per-user_id row, idempotently created on first request.
user_id is a plain string key (e.g. "default") — trivially replaceable by a
JWT sub-claim when authentication is added later.
"""

from datetime import datetime, timezone
from typing import Any, Dict, Optional

from sqlalchemy import Boolean, DateTime, JSON, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base


def _utcnow() -> datetime:
    """Return the current UTC datetime (timezone-aware)."""
    return datetime.now(timezone.utc)


class UserProfile(Base):
    """
    Persistent user profile record.

    One row per logical user (keyed by user_id).
    All fields except user_id are nullable so a profile can be created
    with minimal data and filled in gradually.
    """

    __tablename__ = "user_profiles"
    __table_args__ = (
        UniqueConstraint("user_id", name="uq_user_profiles_user_id"),
    )

    # Primary key — plain integer, simple and portable
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)

    # Logical user identifier (e.g. "default", JWT sub, Firebase UID)
    user_id: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        index=True,
    )

    # Display-facing fields (match Flutter UserProfile model)
    display_name: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    email: Mapped[Optional[str]] = mapped_column(String(320), nullable=True, index=True)
    phone_number: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    avatar_url: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    # Timestamps
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=_utcnow,
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=_utcnow,
        onupdate=_utcnow,
        nullable=False,
    )

    def __repr__(self) -> str:
        return f"<UserProfile user_id={self.user_id!r} email={self.email!r}>"


class UserSettings(Base):
    """
    Per-user application settings.

    Compound preferences (notifications, privacy) are stored as JSON blobs
    for flexibility — avoids needing extra tables for nested settings objects
    that map directly to Flutter model sub-classes.
    """

    __tablename__ = "user_settings"
    __table_args__ = (
        UniqueConstraint("user_id", name="uq_user_settings_user_id"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)

    user_id: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        index=True,
    )

    # Appearance / AI preferences (stored as plain strings — simple enum values)
    theme_mode: Mapped[str] = mapped_column(
        String(20),
        default="dark",
        nullable=False,
    )
    ai_response_style: Mapped[str] = mapped_column(
        String(30),
        default="balanced",
        nullable=False,
    )
    language: Mapped[str] = mapped_column(
        String(20),
        default="en_US",
        nullable=False,
    )

    # Nested settings stored as JSON blobs
    notifications: Mapped[Optional[Dict[str, Any]]] = mapped_column(
        JSON,
        nullable=True,
    )
    privacy: Mapped[Optional[Dict[str, Any]]] = mapped_column(
        JSON,
        nullable=True,
    )

    # Read-only version string surfaced to the client
    app_version: Mapped[str] = mapped_column(
        String(50),
        default="v4.12.0-STABLE",
        nullable=False,
    )

    # Timestamps
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=_utcnow,
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=_utcnow,
        onupdate=_utcnow,
        nullable=False,
    )

    def __repr__(self) -> str:
        return (
            f"<UserSettings user_id={self.user_id!r} theme={self.theme_mode!r}>"
        )
