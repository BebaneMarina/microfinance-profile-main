# app/models/credit_cash.py
from sqlalchemy import Column, Integer, String, Float, DateTime, Boolean, ForeignKey, Text, JSON
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.core.database import Base

class CreditCash(Base):
    __tablename__ = "credit_cash"
    
    id = Column(Integer, primary_key=True, index=True)
    reference = Column(String(50), unique=True, nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    
    # Type de crédit cash
    credit_type = Column(String(50), nullable=False)  # consommation_generale, avance_salaire, depannage
    
    # Montants
    requested_amount = Column(Float, nullable=False)
    approved_amount = Column(Float)
    disbursed_amount = Column(Float, default=0)
    
    # Statut et décision
    status = Column(String(20), default="pending")  # pending, approved, rejected, disbursed, completed, cancelled
    decision = Column(String(20))  # auto_approved, manual_review, rejected
    
    # Scoring
    credit_score = Column(Float)
    risk_level = Column(String(20))
    auto_approved = Column(Boolean, default=False)
    
    # Dates
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    approved_at = Column(DateTime(timezone=True))
    disbursed_at = Column(DateTime(timezone=True))
    due_date = Column(DateTime(timezone=True))
    
    # Métadonnées
    scoring_factors = Column(JSON)
    recommendations = Column(JSON)
    notes = Column(Text)
    
    # Relations
    user = relationship("User", back_populates="credit_cash_requests")
    transactions = relationship("CashTransaction", back_populates="credit_cash")

class CashTransaction(Base):
    __tablename__ = "cash_transactions"
    
    id = Column(Integer, primary_key=True, index=True)
    credit_cash_id = Column(Integer, ForeignKey("credit_cash.id"), nullable=False)
    
    transaction_type = Column(String(20), nullable=False)  # disbursement, repayment, fee
    amount = Column(Float, nullable=False)
    description = Column(Text)
    reference = Column(String(100))
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relations
    credit_cash = relationship("CreditCash", back_populates="transactions")