from pydantic_settings import BaseSettings
from typing import List
from dotenv import load_dotenv
import os
from pathlib import Path

# Get the absolute path to the directory containing this file (app/core)
# then go up two levels to get to the backend root where .env is.
BASE_DIR = Path(__file__).resolve().parent.parent.parent
env_path = BASE_DIR / ".env"

print(f"--- LoanSense AI: Looking for .env at {env_path} ---")
print(f"--- LoanSense AI: Current Working Directory is {os.getcwd()} ---")

load_dotenv(dotenv_path=env_path)


def _resolve_local_path(raw_path: str, fallback: Path) -> str:
    """Resolve relative storage paths against the backend root directory."""
    path = Path(raw_path or fallback)
    if not path.is_absolute():
        path = (BASE_DIR / path).resolve()
    return str(path)


def _resolve_sqlite_url(raw_url: str, fallback_name: str) -> str:
    """Normalize SQLite URLs so they always point at the backend root."""
    raw_url = raw_url or f"sqlite:///{fallback_name}"
    if not raw_url.startswith("sqlite:///"):
        return raw_url

    db_path = raw_url[len("sqlite:///"):]
    if not db_path:
        db_path = fallback_name

    path = Path(db_path)
    if not path.is_absolute():
        path = (BASE_DIR / path).resolve()
    return f"sqlite:///{path.as_posix()}"

class Settings(BaseSettings):
    PROJECT_NAME: str = "LoanSense AI"
    API_V1_STR: str = "/api/v1"
    
    # NVIDIA NIM
    NVIDIA_API_KEY: str = ""
    NVIDIA_LLM_MODEL: str = "meta/llama-3.1-8b-instruct"
    NVIDIA_EMBED_MODEL: str = "nvidia/nv-embedqa-e5-v5"
    
    # Database - Load from environment (.env)
    DATABASE_URL: str = _resolve_sqlite_url(
        os.getenv("DATABASE_URL", ""),
        "loansense.db",
    )
    
    # Redis & Celery - Load from environment
    REDIS_URL: str = os.getenv("REDIS_URL", "redis://localhost:6379/0")
    
    # ChromaDB
    CHROMA_DB_DIR: str = _resolve_local_path(
        os.getenv("CHROMA_DB_DIR", ""),
        BASE_DIR / "chroma_db",
    )
    
    # Security - CRITICAL: Must be provided via environment variable
    SECRET_KEY: str = os.getenv("SECRET_KEY") or "change-me-in-production-set-secret-key-env-var"
    ALGORITHM: str = os.getenv("ALGORITHM", "HS256")
    ACCESS_TOKEN_EXPIRE_MINUTES: int = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "30"))
    
    # Storage
    UPLOAD_DIR: str = _resolve_local_path(
        os.getenv("UPLOAD_DIR", ""),
        BASE_DIR / "uploads",
    )
    
    # API Configuration
    API_HOST: str = os.getenv("API_HOST", "0.0.0.0")
    API_PORT: int = int(os.getenv("API_PORT", "8000"))

    class Config:
        env_file = ".env"
        extra = "ignore"

settings = Settings()

# Normalize storage paths after BaseSettings has loaded environment overrides.
settings.DATABASE_URL = _resolve_sqlite_url(settings.DATABASE_URL, "loansense.db")
settings.CHROMA_DB_DIR = _resolve_local_path(settings.CHROMA_DB_DIR, BASE_DIR / "chroma_db")
settings.UPLOAD_DIR = _resolve_local_path(settings.UPLOAD_DIR, BASE_DIR / "uploads")

# Force set environment variable for NVIDIA NIM library
if settings.NVIDIA_API_KEY:
    os.environ["NVIDIA_API_KEY"] = settings.NVIDIA_API_KEY
    print(f"--- LoanSense AI: NVIDIA API Key loaded (Length: {len(settings.NVIDIA_API_KEY)}) ---")
else:
    print("--- WARNING: NVIDIA API Key not found in .env ---")
