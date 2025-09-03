# app/main.py
from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer
from contextlib import asynccontextmanager
import uvicorn

from app.core.config import settings
from app.core.database import engine, Base
from app.api.v1 import api_router

# Créer les tables au démarrage
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Créer les tables
    Base.metadata.create_all(bind=engine)
    print("✅ Tables créées")
    yield
    print("🔄 Arrêt de l'application")

app = FastAPI(
    title="Microfinance API",
    description="API pour crédits cash et crédits longs avec scoring automatique",
    version="1.0.0",
    lifespan=lifespan
)

# CORS pour Angular
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:4200", "http://127.0.0.1:4200"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Routes principales
app.include_router(api_router, prefix="/api/v1")

@app.get("/")
async def root():
    return {"message": "Microfinance API", "version": "1.0.0"}

@app.get("/health")
async def health():
    return {"status": "healthy", "database": "connected"}