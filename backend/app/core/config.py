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

class Settings(BaseSettings):
    PROJECT_NAME: str = "LoanSense AI"
    API_V1_STR: str = "/api/v1"
    
    # NVIDIA NIM
    NVIDIA_API_KEY: str = ""
    NVIDIA_LLM_MODEL: str = "meta/llama-3.1-8b-instruct"
    NVIDIA_EMBED_MODEL: str = "nvidia/nv-embedqa-e5-v5"
    
    # Database - Load from environment (.env)
    DATABASE_URL: str = os.getenv("DATABASE_URL", "sqlite:///./loansense.db")
    
    # Redis & Celery - Load from environment
    REDIS_URL: str = os.getenv("REDIS_URL", "redis://localhost:6379/0")
    
    # ChromaDB
    CHROMA_DB_DIR: str = os.getenv("CHROMA_DB_DIR", "./chroma_db")
    
    # Security - CRITICAL: Must be provided via environment variable
    SECRET_KEY: str = os.getenv("SECRET_KEY") or "change-me-in-production-set-secret-key-env-var"
    ALGORITHM: str = os.getenv("ALGORITHM", "HS256")
    ACCESS_TOKEN_EXPIRE_MINUTES: int = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "30"))
    
    # Storage
    UPLOAD_DIR: str = os.getenv("UPLOAD_DIR", "./uploads")
    
    # API Configuration
    API_HOST: str = os.getenv("API_HOST", "0.0.0.0")
    API_PORT: int = int(os.getenv("API_PORT", "8000"))

    class Config:
        env_file = ".env"
        extra = "ignore"

settings = Settings()

# Force set environment variable for NVIDIA NIM library
if settings.NVIDIA_API_KEY:
    os.environ["NVIDIA_API_KEY"] = settings.NVIDIA_API_KEY
    print(f"--- LoanSense AI: NVIDIA API Key loaded (Length: {len(settings.NVIDIA_API_KEY)}) ---")
else:
    print("--- WARNING: NVIDIA API Key not found in .env ---")
