# app/schemas/credit_cash.py
from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime

class CreditCashRequest(BaseModel):
    credit_type: str = Field(..., regex="^(consommation_generale|avance_salaire|depannage)$")
    requested_amount: float = Field(..., gt=0, le=2_000_000)
    auto_approve: bool = Field(True, description="Décaissement automatique si éligible")

class CreditCashResponse(BaseModel):
    id: int
    reference: str
    credit_type: str
    requested_amount: float
    approved_amount: Optional[float] = None
    status: str
    decision: Optional[str] = None
    auto_approved: bool
    credit_score: Optional[float] = None
    created_at: datetime
    approved_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True