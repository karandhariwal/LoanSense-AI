import uuid
from decimal import Decimal
from datetime import datetime, timezone
from typing import Any, Dict, Optional
from sqlalchemy import String, Numeric, Enum as SqlEnum, DateTime, Text, JSON, TypeDecorator, CHAR
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base
from app.database.enums import ProcessingStatus


class UUIDType(TypeDecorator):
    """
    Platform-independent UUID type.
    Stores as CHAR(36) string for SQLite compatibility; works with PostgreSQL too.
    """
    impl = CHAR(36)
    cache_ok = True

    def process_bind_param(self, value, dialect):
        if value is None:
            return value
        return str(value)

    def process_result_value(self, value, dialect):
        if value is None:
            return value
        return uuid.UUID(str(value))


class LoanReport(Base):
    """
    SQLAlchemy model representing a persistent Loan Report.
    Stores metadata, safety score, risk details, and processing status.
    Compatible with both SQLite and PostgreSQL.
    """
    __tablename__ = "loan_reports"

    # UUID Primary Key (stored as CHAR(36) for SQLite compatibility)
    loan_id: Mapped[uuid.UUID] = mapped_column(
        UUIDType,
        primary_key=True,
        default=uuid.uuid4
    )

    # Core Extracted Fields (populated on COMPLETED)
    lender_name: Mapped[Optional[str]] = mapped_column(
        String(255),
        nullable=True,
        index=True
    )
    loan_type: Mapped[Optional[str]] = mapped_column(
        String(100),
        nullable=True
    )
    principal_amount: Mapped[Optional[Decimal]] = mapped_column(
        Numeric(15, 2),
        nullable=True
    )

    # Complete analysis payload: metadata, risks, summary, score, recommendations
    # Using plain JSON which works for both SQLite and PostgreSQL
    analysis_json: Mapped[Optional[Dict[str, Any]]] = mapped_column(
        JSON,
        nullable=True
    )

    # Background task status
    status: Mapped[ProcessingStatus] = mapped_column(
        SqlEnum(ProcessingStatus, name="processing_status"),
        default=ProcessingStatus.PENDING,
        nullable=False,
        index=True
    )

    # Timestamps
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
        index=True
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False
    )

    # Optional & Expansion Fields
    user_id: Mapped[Optional[str]] = mapped_column(
        String(255),
        nullable=True,
        index=True
    )
    file_path: Mapped[Optional[str]] = mapped_column(
        String(512),
        nullable=True
    )
    file_hash: Mapped[Optional[str]] = mapped_column(
        String(64),
        nullable=True,
        index=True
    )
    document_name: Mapped[Optional[str]] = mapped_column(
        String(255),
        nullable=True
    )
    error_message: Mapped[Optional[str]] = mapped_column(
        Text,
        nullable=True
    )
    processing_duration: Mapped[Optional[float]] = mapped_column(
        nullable=True
    )

    def __repr__(self) -> str:
        return f"<LoanReport loan_id={self.loan_id} lender={self.lender_name} status={self.status}>"
