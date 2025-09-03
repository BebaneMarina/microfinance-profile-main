# app/models/scoring.py
from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, JSON, Text
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.core.database import Base

class CreditScoring(Base):
    __tablename__ = "credit_scoring"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    
    # Référence à la demande (optionnel)
    credit_cash_id = Column(Integer, ForeignKey("credit_cash.id"))
    credit_long_id = Column(Integer, ForeignKey("credit_long.id"))
    
    # Résultats du scoring
    score = Column(Float, nullable=False)
    risk_level = Column(String(20), nullable=False)
    probability = Column(Float)
    decision = Column(String(50))
    
    # Montants éligibles calculés
    eligible_amount_cash = Column(Float)
    eligible_amount_long = Column(Float)
    
    # Détails de l'analyse
    factors = Column(JSON)
    recommendations = Column(JSON)
    
    # Métadonnées du modèle
    model_version = Column(String(50))
    model_confidence = Column(Float)
    processing_time = Column(Float)
    is_realtime = Column(Boolean, default=False)
    
    # Données d'entrée (pour audit)
    input_data = Column(JSON)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relations
    user = relationship("User", back_populates="scoring_results")