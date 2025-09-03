# app/models/credit_long.py
from sqlalchemy import Column, Integer, String, Float, DateTime, Boolean, ForeignKey, Text, JSON
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.core.database import Base

class CreditLong(Base):
    __tablename__ = "credit_long"
    
    id = Column(Integer, primary_key=True, index=True)
    reference = Column(String(50), unique=True, nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    
    # Détails de la demande
    requested_amount = Column(Float, nullable=False)
    duration_months = Column(Integer, nullable=False)
    purpose = Column(Text, nullable=False)
    
    # Informations personnelles (snapshot)
    personal_info = Column(JSON)
    
    # Informations financières détaillées
    financial_details = Column(JSON)
    
    # Documents requis
    documents_status = Column(JSON)
    
    # Simulation et scoring
    simulation_results = Column(JSON)
    credit_score = Column(Float)
    risk_level = Column(String(20))
    
    # Statut de la demande
    status = Column(String(20), default="draft")  # draft, submitted, in_review, approved, rejected, cancelled
    
    # Décision
    approved_amount = Column(Float)
    approved_duration = Column(Integer)
    interest_rate = Column(Float)
    monthly_payment = Column(Float)
    
    # Dates importantes
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    submitted_at = Column(DateTime(timezone=True))
    reviewed_at = Column(DateTime(timezone=True))
    approved_at = Column(DateTime(timezone=True))
    
    # Métadonnées
    reviewer_id = Column(Integer, ForeignKey("users.id"))
    review_notes = Column(Text)
    
    # Relations
    user = relationship("User", back_populates="credit_long_requests")
    documents = relationship("CreditLongDocument", back_populates="credit_long")
    history = relationship("CreditLongHistory", back_populates="credit_long")

class CreditLongDocument(Base):
    __tablename__ = "credit_long_documents"
    
    id = Column(Integer, primary_key=True, index=True)
    credit_long_id = Column(Integer, ForeignKey("credit_long.id"), nullable=False)
    
    document_type = Column(String(50), nullable=False)  # identity, salary_slip, bank_statement, etc.
    file_name = Column(String(255), nullable=False)
    file_path = Column(String(500))
    file_size = Column(Integer)
    mime_type = Column(String(100))
    
    uploaded_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relations
    credit_long = relationship("CreditLong", back_populates="documents")

class CreditLongHistory(Base):
    __tablename__ = "credit_long_history"
    
    id = Column(Integer, primary_key=True, index=True)
    credit_long_id = Column(Integer, ForeignKey("credit_long.id"), nullable=False)
    
    action = Column(String(50), nullable=False)  # created, submitted, reviewed, approved, etc.
    comment = Column(Text)
    agent_id = Column(Integer, ForeignKey("users.id"))
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relations
    credit_long = relationship("CreditLong", back_populates="history")