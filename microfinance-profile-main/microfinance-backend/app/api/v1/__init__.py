# app/api/v1/__init__.py
from fastapi import APIRouter
from .endpoints import auth, credit_cash, credit_long, scoring

api_router = APIRouter()

api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(credit_cash.router, prefix="/credit-cash", tags=["credit-cash"])  
api_router.include_router(credit_long.router, prefix="/credit-long", tags=["credit-long"])
api_router.include_router(scoring.router, prefix="/scoring", tags=["scoring"])

if __name__ == "__main__":
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info"
    )