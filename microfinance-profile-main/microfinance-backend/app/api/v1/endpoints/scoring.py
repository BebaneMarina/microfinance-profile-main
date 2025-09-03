# app/api/v1/endpoints/scoring.py
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from datetime import datetime

from app.core.database import get_db
from app.models.user import User
from app.models.scoring import CreditScoring
from app.services.scoring_service import scoring_service
from app.api.v1.endpoints.auth import get_current_user_dependency

router = APIRouter()

@router.get("/realtime-score")
async def get_realtime_score(
    current_user: User = Depends(get_current_user_dependency),
    db: Session = Depends(get_db)
):
    """Obtient le score de crédit en temps réel"""
    
    # Compter les crédits actifs pour le calcul
    from app.models.credit_cash import CreditCash
    from app.models.credit_long import CreditLong
    
    active_cash_credits = db.query(CreditCash).filter(
        CreditCash.user_id == current_user.id,
        CreditCash.status.in_(["approved", "disbursed"])
    ).all()
    
    active_long_credits = db.query(CreditLong).filter(
        CreditLong.user_id == current_user.id,
        CreditLong.status.in_(["approved", "disbursed"])
    ).all()
    
    # Calculer les dettes existantes
    total_debt = sum([credit.approved_amount or 0 for credit in active_cash_credits])
    total_debt += sum([credit.approved_amount or 0 for credit in active_long_credits])
    
    user_data = {
        "username": current_user.email,
        "monthly_income": current_user.monthly_income,
        "employment_status": current_user.employment_status,
        "job_seniority": current_user.work_experience,
        "profession": current_user.profession or "",
        "company": current_user.employer_name or "",
        "existing_debts": total_debt,
        "current_score": current_user.credit_score,
        "active_credits": [
            {
                "amount": credit.approved_amount or credit.requested_amount,
                "type": "cash",
                "status": credit.status
            } for credit in active_cash_credits
        ] + [
            {
                "amount": credit.approved_amount or credit.requested_amount, 
                "type": "long",
                "status": credit.status
            } for credit in active_long_credits
        ]
    }
    
    try:
        scoring_result = await scoring_service.calculate_realtime_score(user_data)
        
        # Mettre à jour le profil utilisateur si le score a changé
        new_score = scoring_result.get("score", current_user.credit_score)
        if abs(new_score - current_user.credit_score) >= 0.1:
            current_user.credit_score = new_score
            current_user.risk_level = scoring_result.get("risk_level", "medium")
            current_user.eligible_amount_cash = scoring_result.get("eligible_amount_cash", 0)
            current_user.eligible_amount_long = scoring_result.get("eligible_amount_long", 0)
            db.commit()
        
        return {
            "success": True,
            "data": scoring_result,
            "timestamp": datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        return {
            "success": False,
            "error": str(e),
            "data": {
                "score": current_user.credit_score,
                "risk_level": current_user.risk_level,
                "eligible_amount_cash": current_user.eligible_amount_cash,
                "eligible_amount_long": current_user.eligible_amount_long,
                "is_realtime": False
            }
        }

@router.post("/refresh-score")
async def refresh_user_score(
    current_user: User = Depends(get_current_user_dependency),
    db: Session = Depends(get_db)
):
    """Force le recalcul du score utilisateur"""
    
    user_data = {
        "username": current_user.email,
        "monthly_income": current_user.monthly_income,
        "employment_status": current_user.employment_status,
        "job_seniority": current_user.work_experience,
        "profession": current_user.profession or "",
        "company": current_user.employer_name or "",
        "loan_amount": 1000000,  # Montant de référence
        "loan_duration": 12,
        "use_realtime": True
    }
    
    try:
        scoring_result = await scoring_service.calculate_score(user_data)
        
        # Mettre à jour le profil
        current_user.credit_score = scoring_result.get("score", 6.0)
        current_user.risk_level = scoring_result.get("risk_level", "medium")
        current_user.eligible_amount_cash = scoring_result.get("eligible_amount_cash", 0)
        current_user.eligible_amount_long = scoring_result.get("eligible_amount_long", 0)
        
        # Sauvegarder le scoring
        scoring_record = CreditScoring(
            user_id=current_user.id,
            score=current_user.credit_score,
            risk_level=current_user.risk_level,
            eligible_amount_cash=current_user.eligible_amount_cash,
            eligible_amount_long=current_user.eligible_amount_long,
            factors=scoring_result.get("factors", []),
            recommendations=scoring_result.get("recommendations", []),
            model_version=scoring_result.get("model_version", "1.0"),
            is_realtime=True,
            input_data=user_data
        )
        
        db.add(scoring_record)
        db.commit()
        
        return {
            "success": True,
            "message": "Score mis à jour avec succès",
            "data": {
                "score": current_user.credit_score,
                "previous_score": scoring_result.get("previous_score"),
                "change": scoring_result.get("score_change", 0),
                "risk_level": current_user.risk_level,
                "eligible_amount_cash": current_user.eligible_amount_cash,
                "eligible_amount_long": current_user.eligible_amount_long,
                "recommendations": scoring_result.get("recommendations", [])
            }
        }
        
    except Exception as e:
        return {
            "success": False,
            "message": f"Erreur lors du calcul du score: {str(e)}"
        }

@router.get("/history")
async def get_scoring_history(
    limit: int = 10,
    current_user: User = Depends(get_current_user_dependency),
    db: Session = Depends(get_db)
):
    """Historique des scores de l'utilisateur"""
    
    history = db.query(CreditScoring).filter(
        CreditScoring.user_id == current_user.id
    ).order_by(
        CreditScoring.created_at.desc()
    ).limit(limit).all()
    
    return {
        "success": True,
        "data": [
            {
                "score": record.score,
                "risk_level": record.risk_level,
                "date": record.created_at.isoformat(),
                "model_version": record.model_version,
                "is_realtime": record.is_realtime,
                "eligible_amount_cash": record.eligible_amount_cash,
                "eligible_amount_long": record.eligible_amount_long
            } for record in history
        ]
    }