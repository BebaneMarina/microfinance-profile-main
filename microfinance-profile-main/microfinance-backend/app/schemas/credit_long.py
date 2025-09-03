# app/schemas/credit_long.py
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
from datetime import datetime

class PersonalInfo(BaseModel):
    full_name: str = Field(..., min_length=2)
    email: str = Field(..., regex=r'^[^@]+@[^@]+\.[^@]+$')
    phone: str = Field(..., min_length=8)
    address: str = Field(..., min_length=10)
    profession: str
    company: str
    marital_status: Optional[str] = None
    dependents: Optional[int] = Field(0, ge=0)

class FinancialDetails(BaseModel):
    monthly_income: float = Field(..., gt=0)
    other_incomes: List[Dict[str, Any]] = Field(default_factory=list)
    monthly_expenses: float = Field(..., ge=0)
    existing_loans: List[Dict[str, Any]] = Field(default_factory=list)
    assets: List[Dict[str, Any]] = Field(default_factory=list)
    employment_details: Dict[str, Any]

class CreditDetails(BaseModel):
    requested_amount: float = Field(..., gt=0, le=100_000_000)
    duration: int = Field(..., ge=3, le=120)  # 3 mois à 10 ans
    purpose: str = Field(..., min_length=10)
    repayment_frequency: str = Field("mensuel")

class CreditLongRequest(BaseModel):
    personal_info: PersonalInfo
    financial_details: FinancialDetails
    credit_details: CreditDetails

class CreditLongDraft(BaseModel):
    personal_info: Optional[PersonalInfo] = None
    financial_details: Optional[FinancialDetails] = None
    credit_details: Optional[CreditDetails] = None

class CreditLongSimulation(BaseModel):
    requested_amount: float = Field(..., gt=0)
    duration: int = Field(..., ge=3, le=120)
    client_profile: Dict[str, Any]
    financial_details: Optional[Dict[str, Any]] = None

class CreditLongResponse(BaseModel):
    id: int
    reference: str
    status: str
    requested_amount: float
    duration_months: int
    purpose: str
    credit_score: Optional[float] = None
    risk_level: Optional[str] = None
    approved_amount: Optional[float] = None
    created_at: datetime
    submitted_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True