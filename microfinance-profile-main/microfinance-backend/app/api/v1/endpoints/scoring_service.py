# app/services/scoring_service.py
import httpx
import asyncio
from typing import Dict, Any, Optional
from app.core.config import settings
import logging

logger = logging.getLogger(__name__)

class ScoringService:
    def __init__(self):
        self.base_url = settings.SCORING_SERVICE_URL
        self.timeout = 30.0
    
    async def calculate_score(self, user_data: Dict[str, Any]) -> Dict[str, Any]:
        """Calcule le score via le service Flask"""
        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                response = await client.post(
                    f"{self.base_url}/client-scoring",
                    json=user_data
                )
                response.raise_for_status()
                return response.json()
                
        except Exception as e:
            logger.error(f"Erreur scoring Flask: {str(e)}")
            return self._fallback_scoring(user_data)
    
    async def calculate_realtime_score(self, user_data: Dict[str, Any]) -> Dict[str, Any]:
        """Score temps réel"""
        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                response = await client.post(
                    f"{self.base_url}/realtime-scoring",
                    json=user_data
                )
                response.raise_for_status()
                return response.json()
                
        except Exception as e:
            logger.error(f"Erreur scoring temps réel: {str(e)}")
            return self._fallback_realtime_scoring(user_data)
    
    def _fallback_scoring(self, user_data: Dict) -> Dict[str, Any]:
        """Scoring de fallback"""
        monthly_income = user_data.get("monthly_income", 0)
        employment_status = user_data.get("employment_status", "autre")
        
        # Score de base
        if monthly_income >= 500000:
            score = 8.0
        elif monthly_income >= 300000:
            score = 6.5
        elif monthly_income >= 150000:
            score = 5.0
        else:
            score = 3.0
        
        # Ajustements
        if employment_status == "cdi":
            score += 1.0
        elif employment_status == "cdd":
            score += 0.5
        
        score = max(0, min(10, score))
        
        # Montants éligibles
        eligible_cash = min(monthly_income * 0.5, settings.MAX_CREDIT_CASH)
        eligible_long = min(monthly_income * 3, settings.MAX_CREDIT_LONG) if score >= 6 else 0
        
        return {
            "score": score,
            "risk_level": "low" if score >= 7 else ("medium" if score >= 5 else "high"),
            "probability": score / 10,
            "decision": "approuvé" if score >= 7 else ("à étudier" if score >= 5 else "refusé"),
            "eligible_amount": int(eligible_cash),
            "eligible_amount_cash": int(eligible_cash),
            "eligible_amount_long": int(eligible_long),
            "factors": [],
            "recommendations": ["Scoring de fallback utilisé"],
            "model_version": "fallback_1.0"
        }
    
    def _fallback_realtime_scoring(self, user_data: Dict) -> Dict[str, Any]:
        """Scoring temps réel de fallback"""
        result = self._fallback_scoring(user_data)
        result.update({
            "is_realtime": True,
            "previous_score": user_data.get("current_score", 6.0),
            "score_change": result["score"] - user_data.get("current_score", 6.0),
            "last_updated": "now"
        })
        return result

scoring_service = ScoringService()