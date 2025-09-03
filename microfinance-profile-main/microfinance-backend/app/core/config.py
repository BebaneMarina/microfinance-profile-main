# app/core/config.py
from pydantic_settings import BaseSettings
import os

class Settings(BaseSettings):
    # API
    PROJECT_NAME: str = "Microfinance API"
    API_V1_STR: str = "/api/v1"
    
    # Database
    DATABASE_URL: str = os.getenv("DATABASE_URL", "postgresql://postgres:password@localhost:5432/credit_scoring")
    
    # JWT
    SECRET_KEY: str = os.getenv("SECRET_KEY", "your-secret-key-change-in-production")
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    
    # Flask Scoring Service
    SCORING_SERVICE_URL: str = os.getenv("SCORING_SERVICE_URL", "http://localhost:5000")
    
    # Business Rules
    MAX_CREDIT_CASH: int = 2_000_000  # 2M FCFA
    MAX_CREDIT_LONG: int = 100_000_000  # 100M FCFA
    DEFAULT_INTEREST_RATE_CASH: float = 0.05
    DEFAULT_INTEREST_RATE_LONG: float = 0.08
    
    class Config:
        env_file = ".env"

settings = Settings()