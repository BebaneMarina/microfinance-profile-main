# realtime_scoring_service.py
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional
import json
import asyncio
from dataclasses import dataclass
from enum import Enum

logger = logging.getLogger(__name__)

class TransactionType(Enum):
    PAYMENT = "payment"
    LATE_PAYMENT = "late_payment"
    MISSED_PAYMENT = "missed_payment"
    EARLY_PAYMENT = "early_payment"
    NEW_LOAN = "new_loan"
    LOAN_CLOSURE = "loan_closure"
    INCOME_UPDATE = "income_update"
    EMPLOYMENT_CHANGE = "employment_change"

@dataclass
class Transaction:
    user_id: str
    transaction_type: TransactionType
    amount: float
    scheduled_date: datetime
    actual_date: datetime
    loan_id: Optional[str] = None
    metadata: Optional[Dict] = None

class RealtimeScoringService:
    def __init__(self, scoring_model):
        self.scoring_model = scoring_model
        self.transaction_history = {}  # user_id -> list of transactions
        self.current_scores = {}  # user_id -> current score data
        self.score_cache = {}  # Pour éviter les recalculs inutiles
        self.score_history = {}  # Historique des scores
        
        # Configuration des impacts par type de transaction
        self.transaction_impacts = {
            TransactionType.PAYMENT: self._handle_regular_payment,
            TransactionType.LATE_PAYMENT: self._handle_late_payment,
            TransactionType.MISSED_PAYMENT: self._handle_missed_payment,
            TransactionType.EARLY_PAYMENT: self._handle_early_payment,
            TransactionType.NEW_LOAN: self._handle_new_loan,
            TransactionType.LOAN_CLOSURE: self._handle_loan_closure,
            TransactionType.INCOME_UPDATE: self._handle_income_update,
            TransactionType.EMPLOYMENT_CHANGE: self._handle_employment_change
        }
        
        logger.info("🚀 Service de scoring en temps réel initialisé")

    async def process_transaction(self, transaction: Transaction) -> Dict:
        """Traite une transaction et met à jour le score en temps réel"""
        try:
            user_id = transaction.user_id
            
            logger.info(f"=== TRAITEMENT TRANSACTION TEMPS RÉEL ===")
            logger.info(f"👤 Utilisateur: {user_id}")
            logger.info(f"💳 Type: {transaction.transaction_type.value}")
            logger.info(f"💰 Montant: {transaction.amount:,} FCFA")
            logger.info(f"📅 Date: {transaction.actual_date}")
            
            # Enregistrer la transaction
            if user_id not in self.transaction_history:
                self.transaction_history[user_id] = []
            self.transaction_history[user_id].append(transaction)
            
            # Récupérer le score actuel
            current_score_data = self.current_scores.get(user_id, {
                'score': 6.0,
                'score_850': 650,
                'risk_level': 'moyen',
                'last_update': datetime.now(),
                'payment_history': [],
                'behavioral_factors': {}
            })
            
            # Traiter l'impact de la transaction
            impact_result = await self._calculate_transaction_impact(
                transaction, current_score_data
            )
            
            # Calculer le nouveau score
            new_score_data = await self._calculate_updated_score(
                user_id, current_score_data, impact_result
            )
            
            # Sauvegarder le nouveau score
            self.current_scores[user_id] = new_score_data
            
            # Historique des scores
            if user_id not in self.score_history:
                self.score_history[user_id] = []
            
            self.score_history[user_id].append({
                'score': new_score_data['score'],
                'score_850': new_score_data['score_850'],
                'date': datetime.now(),
                'trigger_transaction': transaction.transaction_type.value,
                'score_change': new_score_data['score'] - current_score_data.get('score', 6.0)
            })
            
            # Notification si changement significatif
            score_change = new_score_data['score'] - current_score_data.get('score', 6.0)
            if abs(score_change) >= 0.5:
                await self._notify_significant_score_change(user_id, score_change, transaction)
            
            logger.info(f"✅ Score mis à jour: {current_score_data.get('score', 6.0):.1f} → {new_score_data['score']:.1f}")
            logger.info(f"📊 Changement: {score_change:+.1f} points")
            
            return {
                'success': True,
                'user_id': user_id,
                'previous_score': current_score_data.get('score', 6.0),
                'new_score': new_score_data['score'],
                'score_change': score_change,
                'risk_level': new_score_data['risk_level'],
                'eligible_amount': new_score_data.get('eligible_amount', 0),
                'transaction_impact': impact_result,
                'behavioral_insights': new_score_data.get('behavioral_factors', {}),
                'updated_at': datetime.now().isoformat()
            }
            
        except Exception as e:
            logger.error(f"❌ Erreur traitement transaction: {str(e)}")
            return {
                'success': False,
                'error': str(e),
                'user_id': transaction.user_id
            }

    async def _calculate_transaction_impact(self, transaction: Transaction, current_score_data: Dict) -> Dict:
        """Calcule l'impact d'une transaction sur le score"""
        transaction_type = transaction.transaction_type
        
        if transaction_type in self.transaction_impacts:
            handler = self.transaction_impacts[transaction_type]
            return await handler(transaction, current_score_data)
        else:
            return {'score_delta': 0, 'factors': [], 'notes': 'Type de transaction non reconnu'}

    async def _handle_regular_payment(self, transaction: Transaction, score_data: Dict) -> Dict:
        """Gère un paiement régulier dans les temps"""
        # Impact positif modéré
        score_delta = 0.1
        
        # Bonus si paiement récurrent
        payment_history = score_data.get('payment_history', [])
        recent_payments = [p for p in payment_history if 
                          (datetime.now() - p.get('date', datetime.now())).days <= 90]
        
        if len(recent_payments) >= 3:
            score_delta += 0.05  # Bonus pour régularité
        
        return {
            'score_delta': score_delta,
            'factors': ['Paiement dans les temps', 'Comportement régulier'],
            'notes': f'Paiement de {transaction.amount:,} FCFA effectué à temps'
        }

    async def _handle_late_payment(self, transaction: Transaction, score_data: Dict) -> Dict:
        """Gère un paiement en retard"""
        # Calculer les jours de retard
        days_late = (transaction.actual_date - transaction.scheduled_date).days
        
        # Impact négatif proportionnel au retard
        if days_late <= 5:
            score_delta = -0.1  # Retard mineur
        elif days_late <= 15:
            score_delta = -0.3  # Retard modéré
        elif days_late <= 30:
            score_delta = -0.5  # Retard significatif
        else:
            score_delta = -0.8  # Retard grave
        
        return {
            'score_delta': score_delta,
            'factors': [f'Retard de {days_late} jours', 'Impact sur la ponctualité'],
            'notes': f'Paiement en retard de {days_late} jours'
        }

    async def _handle_missed_payment(self, transaction: Transaction, score_data: Dict) -> Dict:
        """Gère un paiement manqué"""
        # Impact négatif important
        score_delta = -1.0
        
        # Aggravation si paiements manqués récurrents
        missed_count = len([t for t in self.transaction_history.get(transaction.user_id, [])
                           if t.transaction_type == TransactionType.MISSED_PAYMENT and
                           (datetime.now() - t.actual_date).days <= 90])
        
        if missed_count > 1:
            score_delta -= 0.5 * (missed_count - 1)  # Pénalité cumulative
        
        return {
            'score_delta': score_delta,
            'factors': ['Paiement manqué', 'Risque de défaut élevé'],
            'notes': f'Paiement manqué - {missed_count}e incident récent'
        }

    async def _handle_early_payment(self, transaction: Transaction, score_data: Dict) -> Dict:
        """Gère un paiement anticipé"""
        # Impact positif
        days_early = (transaction.scheduled_date - transaction.actual_date).days
        score_delta = min(0.2, 0.05 + days_early * 0.01)  # Bonus limité
        
        return {
            'score_delta': score_delta,
            'factors': ['Paiement anticipé', 'Excellente gestion financière'],
            'notes': f'Paiement anticipé de {days_early} jours'
        }

    async def _handle_new_loan(self, transaction: Transaction, score_data: Dict) -> Dict:
        """Gère l'octroi d'un nouveau prêt"""
        # Impact négatif temporaire (augmentation de l'endettement)
        score_delta = -0.2
        
        # Vérifier la charge totale
        total_debt = transaction.metadata.get('total_debt_after', 0)
        monthly_income = transaction.metadata.get('monthly_income', 1)
        debt_ratio = total_debt / monthly_income
        
        if debt_ratio > 0.5:
            score_delta -= 0.3  # Pénalité pour surendettement
        
        return {
            'score_delta': score_delta,
            'factors': ['Nouveau crédit', f'Ratio d\'endettement: {debt_ratio:.1%}'],
            'notes': f'Nouveau prêt de {transaction.amount:,} FCFA'
        }

    async def _handle_loan_closure(self, transaction: Transaction, score_data: Dict) -> Dict:
        """Gère la clôture d'un prêt"""
        # Impact positif (réduction de l'endettement)
        score_delta = 0.3
        
        # Bonus si remboursement anticipé
        if transaction.metadata.get('early_closure', False):
            score_delta += 0.2
        
        return {
            'score_delta': score_delta,
            'factors': ['Clôture de prêt', 'Réduction de l\'endettement'],
            'notes': 'Prêt remboursé intégralement'
        }

    async def _handle_income_update(self, transaction: Transaction, score_data: Dict) -> Dict:
        """Gère une mise à jour de revenus"""
        old_income = transaction.metadata.get('old_income', 0)
        new_income = transaction.amount
        
        income_change_ratio = (new_income - old_income) / max(old_income, 1)
        
        if income_change_ratio > 0.1:  # Augmentation > 10%
            score_delta = min(0.5, income_change_ratio)
            factors = ['Augmentation de revenus', 'Amélioration de la capacité de remboursement']
        elif income_change_ratio < -0.1:  # Diminution > 10%
            score_delta = max(-0.5, income_change_ratio)
            factors = ['Diminution de revenus', 'Réduction de la capacité de remboursement']
        else:
            score_delta = 0
            factors = ['Mise à jour de revenus', 'Pas d\'impact significatif']
        
        return {
            'score_delta': score_delta,
            'factors': factors,
            'notes': f'Revenus: {old_income:,} → {new_income:,} FCFA'
        }

    async def _handle_employment_change(self, transaction: Transaction, score_data: Dict) -> Dict:
        """Gère un changement d'emploi"""
        old_status = transaction.metadata.get('old_employment_status', 'autre')
        new_status = transaction.metadata.get('new_employment_status', 'autre')
        
        status_scores = {'cdi': 3, 'cdd': 2, 'independant': 1, 'autre': 0}
        
        old_score = status_scores.get(old_status.lower(), 0)
        new_score = status_scores.get(new_status.lower(), 0)
        
        score_delta = (new_score - old_score) * 0.2
        
        return {
            'score_delta': score_delta,
            'factors': [f'Changement d\'emploi: {old_status} → {new_status}'],
            'notes': f'Nouveau statut d\'emploi: {new_status}'
        }

    async def _calculate_updated_score(self, user_id: str, current_score_data: Dict, impact_result: Dict) -> Dict:
        """Calcule le nouveau score après impact de la transaction"""
        current_score = current_score_data.get('score', 6.0)
        current_score_850 = current_score_data.get('score_850', 650)
        
        # Appliquer le delta
        score_delta = impact_result['score_delta']
        new_score = max(0, min(10, current_score + score_delta))
        
        # Convertir en score 850
        new_score_850 = int(300 + (new_score / 10) * 550)
        new_score_850 = max(300, min(850, new_score_850))
        
        # Mise à jour des facteurs comportementaux
        behavioral_factors = current_score_data.get('behavioral_factors', {})
        
        # Analyser l'historique récent
        recent_transactions = [t for t in self.transaction_history.get(user_id, [])
                              if (datetime.now() - t.actual_date).days <= 90]
        
        # Calculer la ponctualité
        payment_transactions = [t for t in recent_transactions 
                               if t.transaction_type in [TransactionType.PAYMENT, 
                                                        TransactionType.LATE_PAYMENT, 
                                                        TransactionType.MISSED_PAYMENT]]
        
        if payment_transactions:
            on_time_payments = len([t for t in payment_transactions 
                                   if t.transaction_type == TransactionType.PAYMENT])
            punctuality_score = (on_time_payments / len(payment_transactions)) * 100
        else:
            punctuality_score = 75  # Score par défaut
        
        behavioral_factors.update({
            'punctuality_score': punctuality_score,
            'recent_transactions_count': len(recent_transactions),
            'last_transaction_type': impact_result.get('factors', [''])[0],
            'payment_consistency': self._calculate_payment_consistency(user_id),
            'debt_trend': self._calculate_debt_trend(user_id)
        })
        
        # Déterminer le niveau de risque
        risk_level = self._get_risk_level_from_score(new_score_850)
        
        # Calculer le montant éligible basé sur le nouveau score
        eligible_amount = self._calculate_eligible_amount_from_score(
            new_score_850, current_score_data.get('monthly_income', 500000)
        )
        
        return {
            'score': round(new_score, 1),
            'score_850': new_score_850,
            'risk_level': risk_level,
            'eligible_amount': eligible_amount,
            'last_update': datetime.now(),
            'behavioral_factors': behavioral_factors,
            'recent_impact': impact_result,
            'monthly_income': current_score_data.get('monthly_income', 500000)
        }

    def _calculate_payment_consistency(self, user_id: str) -> float:
        """Calcule la cohérence des paiements"""
        transactions = self.transaction_history.get(user_id, [])
        payment_transactions = [t for t in transactions[-12:]  # 12 dernières transactions
                               if t.transaction_type in [TransactionType.PAYMENT, 
                                                        TransactionType.LATE_PAYMENT]]
        
        if len(payment_transactions) < 2:
            return 75.0
        
        # Analyser la régularité des montants et dates
        amounts = [t.amount for t in payment_transactions]
        avg_amount = sum(amounts) / len(amounts)
        amount_variance = sum((a - avg_amount) ** 2 for a in amounts) / len(amounts)
        amount_consistency = max(0, 100 - (amount_variance / avg_amount * 100))
        
        return min(100, amount_consistency)

    def _calculate_debt_trend(self, user_id: str) -> str:
        """Calcule la tendance d'endettement"""
        transactions = self.transaction_history.get(user_id, [])
        recent_loans = [t for t in transactions[-6:]  # 6 derniers mois
                       if t.transaction_type == TransactionType.NEW_LOAN]
        recent_closures = [t for t in transactions[-6:]
                          if t.transaction_type == TransactionType.LOAN_CLOSURE]
        
        if len(recent_loans) > len(recent_closures):
            return 'increasing'
        elif len(recent_closures) > len(recent_loans):
            return 'decreasing'
        else:
            return 'stable'

    def _get_risk_level_from_score(self, score_850: int) -> str:
        """Détermine le niveau de risque"""
        if score_850 >= 750:
            return 'bas'
        elif score_850 >= 650:
            return 'moyen'
        elif score_850 >= 550:
            return 'élevé'
        else:
            return 'très élevé'

    def _calculate_eligible_amount_from_score(self, score_850: int, monthly_income: float) -> int:
        """Calcule le montant éligible basé sur le score"""
        base_amount = monthly_income * 0.8  # 80% du salaire de base
        
        if score_850 >= 750:
            multiplier = 1.2
        elif score_850 >= 650:
            multiplier = 1.0
        elif score_850 >= 550:
            multiplier = 0.7
        else:
            multiplier = 0.5
        
        eligible_amount = int(base_amount * multiplier)
        return min(eligible_amount, 2000000)  # Plafond à 2M FCFA

    async def _notify_significant_score_change(self, user_id: str, score_change: float, transaction: Transaction):
        """Notifie les changements significatifs de score"""
        logger.info(f"🔔 CHANGEMENT SIGNIFICATIF DE SCORE")
        logger.info(f"👤 Utilisateur: {user_id}")
        logger.info(f"📊 Changement: {score_change:+.1f} points")
        logger.info(f"🎯 Déclencheur: {transaction.transaction_type.value}")
        
        # Ici vous pouvez ajouter des notifications push, emails, etc.

    def get_user_score_history(self, user_id: str, days: int = 30) -> List[Dict]:
        """Récupère l'historique des scores d'un utilisateur"""
        history = self.score_history.get(user_id, [])
        cutoff_date = datetime.now() - timedelta(days=days)
        
        return [entry for entry in history if entry['date'] >= cutoff_date]

    def get_current_score(self, user_id: str) -> Optional[Dict]:
        """Récupère le score actuel d'un utilisateur"""
        return self.current_scores.get(user_id)

    async def bulk_recalculate_scores(self, user_ids: List[str] = None):
        """Recalcule les scores pour plusieurs utilisateurs"""
        if user_ids is None:
            user_ids = list(self.current_scores.keys())
        
        logger.info(f"🔄 Recalcul en masse pour {len(user_ids)} utilisateurs")
        
        for user_id in user_ids:
            try:
                # Simuler une transaction de mise à jour
                update_transaction = Transaction(
                    user_id=user_id,
                    transaction_type=TransactionType.INCOME_UPDATE,
                    amount=self.current_scores.get(user_id, {}).get('monthly_income', 500000),
                    scheduled_date=datetime.now(),
                    actual_date=datetime.now(),
                    metadata={'bulk_update': True}
                )
                
                await self.process_transaction(update_transaction)
                
            except Exception as e:
                logger.error(f"❌ Erreur recalcul pour {user_id}: {str(e)}")

    def get_scoring_analytics(self) -> Dict:
        """Retourne des analytics sur le scoring"""
        total_users = len(self.current_scores)
        
        if total_users == 0:
            return {'message': 'Aucune donnée disponible'}
        
        scores = [data['score'] for data in self.current_scores.values()]
        avg_score = sum(scores) / len(scores)
        
        risk_distribution = {}
        for data in self.current_scores.values():
            risk_level = data.get('risk_level', 'moyen')
            risk_distribution[risk_level] = risk_distribution.get(risk_level, 0) + 1
        
        return {
            'total_users': total_users,
            'average_score': round(avg_score, 1),
            'score_distribution': {
                'excellent': len([s for s in scores if s >= 9]),
                'tres_bon': len([s for s in scores if 7 <= s < 9]),
                'bon': len([s for s in scores if 6 <= s < 7]),
                'moyen': len([s for s in scores if 5 <= s < 6]),
                'a_ameliorer': len([s for s in scores if s < 5])
            },
            'risk_distribution': risk_distribution,
            'total_transactions': sum(len(hist) for hist in self.transaction_history.values()),
            'last_updated': datetime.now().isoformat()
        }