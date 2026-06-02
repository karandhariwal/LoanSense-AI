from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker, Session
from typing import Generator
from app.core.config import settings

# Build engine kwargs based on database backend
_is_sqlite = settings.DATABASE_URL.startswith("sqlite")

_engine_kwargs: dict = {"pool_pre_ping": True}

if _is_sqlite:
    # SQLite requires connect_args for multi-threaded use; no pool_size support
    _engine_kwargs["connect_args"] = {"check_same_thread": False}
else:
    # PostgreSQL supports advanced pool settings
    _engine_kwargs["pool_size"] = 10
    _engine_kwargs["max_overflow"] = 20

# Initialize the SQLAlchemy database engine
engine = create_engine(settings.DATABASE_URL, **_engine_kwargs)

# Enable WAL mode for SQLite (better concurrent read performance)
if _is_sqlite:
    @event.listens_for(engine, "connect")
    def set_sqlite_pragma(dbapi_conn, connection_record):
        cursor = dbapi_conn.cursor()
        cursor.execute("PRAGMA journal_mode=WAL")
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.close()

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine
)

def get_db() -> Generator[Session, None, None]:
    """
    FastAPI dependency that provides a transactional database session context.
    Ensures that the connection is closed after the request lifecycle.
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
