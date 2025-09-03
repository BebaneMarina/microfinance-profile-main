# app/models/user.py
from sqlalchemy import Column, Integer, String, Float, DateTime, Boolean, Text, Date
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.core.database import Base

class User(Base):
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(255), unique=True, index=True, nullable=False)
    password_hash = Column(String(255), nullable=False)
    
    # Informations personnelles
    first_name = Column(String(100), nullable=False)
    last_name = Column(String(100), nullable=False)
    phone_number = Column(String(20), unique=True)
    
    # Profil financier
    monthly_income = Column(Float, default=0)
    profession = Column(String(255))
    employer_name = Column(String(255))
    employment_status = Column(String(50), default="cdi")  # cdi, cdd, independant, autre
    work_experience = Column(Integer, default=0)  # en mois
    
    # Scoring
    credit_score = Column(Float, default=6.0)
    risk_level = Column(String(20), default="medium")
    eligible_amount_cash = Column(Float, default=0)
    eligible_amount_long = Column(Float, default=0)
    
    # Statut
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relations
    credit_cash_requests = relationship("CreditCash", back_populates="user")
    credit_long_requests = relationship("CreditLong", back_populates="user")
    scoring_results = relationship("CreditScoring", back_populates="user")