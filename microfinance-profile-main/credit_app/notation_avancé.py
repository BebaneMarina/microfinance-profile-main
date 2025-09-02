import numpy as np
import pandas as pd
from datetime import datetime
import logging

logger = logging.getLogger(__name__)

class AdvancedCreditScoringModel:
    def __init__(self):
        # Score de base pour chaque type de crédit
        self.base_scores = {
            'consommation': 600,
            'investissement': 550,
            'avance_facture': 700,
            'avance_commande': 650,
            'tontine': 750,
            'retraite': 800,
            'spot': 500
        }
        
        # Poids des critères par type de crédit
        self.criteria_weights = {
            'consommation': {
                'age': 0.10,
                'employment': 0.25,
                'income': 0.30,
                'debt_ratio': 0.20,
                'loan_purpose': 0.15
            },
            'investissement': {
                'business_age': 0.15,
                'turnover': 0.25,
                'profit_margin': 0.20,
                'collateral': 0.20,
                'business_type': 0.10,
                'documents': 0.10
            },
            'avance_facture': {
                'client_reputation': 0.30,
                'invoice_amount': 0.20,
                'payment_history': 0.25,
                'invoice_validity': 0.15,
                'business_relationship': 0.10
            },
            'avance_commande': {
                'order_validity': 0.25,
                'client_reputation': 0.25,
                'production_capacity': 0.20,
                'profit_margin': 0.15,
                'raw_materials': 0.15
            },
            'tontine': {
                'contribution_history': 0.35,
                'member_duration': 0.25,
                'contribution_amount': 0.20,
                'group_solidarity': 0.20
            },
            'retraite': {
                'pension_amount': 0.30,
                'pension_duration': 0.25,
                'age': 0.15,
                'health_status': 0.15,
                'other_income': 0.15
            },
            'spot': {
                'urgency_validity': 0.25,
                'repayment_capacity': 0.30,
                'cash_flow': 0.25,
                'business_stability': 0.20
            }
        }
        
        # Plafonds par type de crédit
        self.credit_limits = {
            'consommation': {'max_amount': None, 'salary_ratio': 0.35},
            'investissement': {'max_amount': 100000000},
            'avance_facture': {'max_amount': 100000000, 'invoice_ratio': 0.70},
            'avance_commande': {'max_amount': 100000000},
            'tontine': {'max_amount': 5000000},
            'retraite': {'max_amount': None},  # Basé sur la quotité
            'spot': {'max_amount': 100000000}
        }

    def calculate_score(self, data):
        """Calcule le score de crédit en fonction du type de crédit et des données fournies"""
        try:
            credit_type = data.get('credit_type', 'consommation')
            base_score = self.base_scores.get(credit_type, 600)
            
            # Calculer le score selon le type de crédit
            if credit_type == 'consommation':
                score = self._score_consommation(data, base_score)
            elif credit_type == 'investissement':
                score = self._score_investissement(data, base_score)
            elif credit_type == 'avance_facture':
                score = self._score_avance_facture(data, base_score)
            elif credit_type == 'avance_commande':
                score = self._score_avance_commande(data, base_score)
            elif credit_type == 'tontine':
                score = self._score_tontine(data, base_score)
            elif credit_type == 'retraite':
                score = self._score_retraite(data, base_score)
            elif credit_type == 'spot':
                score = self._score_spot(data, base_score)
            else:
                score = base_score
            
            # Ajustements généraux
            score = self._apply_general_adjustments(data, score)
            
            # Limiter le score entre 300 et 900
            score = max(300, min(900, score))
            
            # Calculer la probabilité d'approbation
            probability = self._calculate_probability(score)
            
            # Identifier les facteurs influençant le score
            factors = self._identify_factors(data, credit_type, score)
            
            # Vérifier l'éligibilité
            eligibility = self._check_eligibility(data, credit_type)
            
            return {
                'score': int(score),
                'probability': round(probability, 2),
                'risk_level': self._get_risk_level(score),
                'factors': factors,
                'eligibility': eligibility,
                'recommendations': self._get_recommendations(data, credit_type, score)
            }
            
        except Exception as e:
            logger.error(f"Erreur dans le calcul du score: {e}")
            return {
                'score': 500,
                'probability': 0.5,
                'risk_level': 'moyen',
                'factors': [],
                'eligibility': {'eligible': False, 'reasons': [str(e)]},
                'recommendations': []
            }

    def _score_consommation(self, data, base_score):
        """Scoring spécifique pour le crédit consommation"""
        score = base_score
        
        # Age (10%)
        age = data.get('age', 30)
        if 25 <= age <= 55:
            score += 50
        elif 18 <= age < 25 or 55 < age <= 65:
            score += 20
        else:
            score -= 30
        
        # Statut d'emploi (25%)
        employment = data.get('employment_status', '').lower()
        if employment in ['cdi', 'fonctionnaire']:
            score += 100
        elif employment == 'cdd':
            score += 50
        elif employment == 'independant':
            score += 30
        else:
            score -= 50
        
        # Revenu mensuel (30%)
        income = data.get('monthly_income', 0)
        loan_amount = data.get('loan_amount', 0)
        if income > 0:
            debt_service = (loan_amount / data.get('loan_duration', 12))
            ratio = debt_service / income
            
            if ratio <= 0.35:  # Respecte la limite de 35%
                score += 120
            elif ratio <= 0.45:
                score += 60
            elif ratio <= 0.55:
                score += 20
            else:
                score -= 100
        
        # Objet du crédit (15%)
        purpose = data.get('loan_purpose', '').lower()
        if any(word in purpose for word in ['santé', 'éducation', 'urgence médicale']):
            score += 60
        elif any(word in purpose for word in ['électroménager', 'rénovation', 'famille']):
            score += 40
        elif any(word in purpose for word in ['voyage', 'loisir']):
            score += 20
        else:
            score += 10
        
        return score

    def _score_investissement(self, data, base_score):
        """Scoring spécifique pour le crédit investissement"""
        score = base_score
        
        # Type d'entité
        entity_type = data.get('entity_type', 'particulier').lower()
        if entity_type == 'entreprise':
            # Chiffre d'affaires (25%)
            turnover = data.get('company_turnover', 0)
            if turnover >= 50000000:
                score += 100
            elif turnover >= 20000000:
                score += 70
            elif turnover >= 10000000:
                score += 40
            else:
                score += 20
            
            # Marge bénéficiaire (20%)
            profit = data.get('net_profit', 0)
            if turnover > 0:
                margin = (profit / turnover) * 100
                if margin >= 20:
                    score += 80
                elif margin >= 10:
                    score += 50
                elif margin >= 5:
                    score += 30
                else:
                    score -= 20
            
            # Documents fournis (10%)
            if data.get('has_statutes') and data.get('has_patent') and data.get('has_financial_statements'):
                score += 40
            elif data.get('has_patent'):
                score += 20
            
        else:  # Particulier
            # Revenu et capacité de remboursement
            income = data.get('monthly_income', 0)
            if income >= 1000000:
                score += 80
            elif income >= 500000:
                score += 50
            elif income >= 300000:
                score += 30
            
        # Garanties (20%)
        collateral_value = data.get('collateral_value', 0)
        loan_amount = data.get('loan_amount', 0)
        if loan_amount > 0 and collateral_value >= loan_amount * 1.5:
            score += 80
        elif collateral_value >= loan_amount:
            score += 50
        elif collateral_value >= loan_amount * 0.5:
            score += 20
        
        # Type d'investissement (10%)
        investment_type = data.get('investment_type', '').lower()
        if 'équipement' in investment_type or 'machines' in investment_type:
            score += 40
        elif 'immobilier' in investment_type:
            score += 35
        elif 'stock' in investment_type:
            score += 20
        
        return score

    def _score_avance_facture(self, data, base_score):
        """Scoring spécifique pour l'avance sur facture"""
        score = base_score
        
        # Montant de la facture vs montant demandé
        invoice_amount = data.get('invoice_amount', 0)
        loan_amount = data.get('loan_amount', 0)
        
        if invoice_amount > 0:
            advance_ratio = loan_amount / invoice_amount
            if advance_ratio <= 0.7:  # Respecte la limite de 70%
                score += 100
            else:
                score -= 100  # Dépasse la limite autorisée
        
        # Réputation du client (30%)
        client_rating = data.get('client_payment_history', 'moyen').lower()
        if client_rating == 'excellent':
            score += 120
        elif client_rating == 'bon':
            score += 80
        elif client_rating == 'moyen':
            score += 40
        else:
            score -= 50
        
        # Délai de paiement (25%)
        payment_deadline = data.get('payment_deadline_days', 90)
        if payment_deadline <= 30:
            score += 100
        elif payment_deadline <= 60:
            score += 70
        elif payment_deadline <= 90:
            score += 40
        else:
            score -= 30
        
        # Validité de la facture (15%)
        if data.get('invoice_verified', False):
            score += 60
        
        # Relation commerciale (10%)
        relationship_duration = data.get('business_relationship_months', 0)
        if relationship_duration >= 24:
            score += 40
        elif relationship_duration >= 12:
            score += 25
        elif relationship_duration >= 6:
            score += 10
        
        return score

    def _score_avance_commande(self, data, base_score):
        """Scoring spécifique pour l'avance sur bon de commande"""
        score = base_score
        
        # Validité du bon de commande (25%)
        if data.get('order_verified', False):
            score += 100
        else:
            score -= 50
        
        # Réputation du client (25%)
        client_reputation = data.get('order_client_reputation', 'moyen').lower()
        if client_reputation == 'excellent':
            score += 100
        elif client_reputation == 'bon':
            score += 60
        elif client_reputation == 'moyen':
            score += 30
        else:
            score -= 40
        
        # Capacité de production (20%)
        production_capacity = data.get('production_capacity_score', 5)  # Sur 10
        score += (production_capacity * 8)
        
        # Marge bénéficiaire prévue (15%)
        expected_margin = data.get('profit_margin_percentage', 0)
        if expected_margin >= 30:
            score += 60
        elif expected_margin >= 20:
            score += 40
        elif expected_margin >= 10:
            score += 20
        else:
            score -= 20
        
        # Coût des matières premières (15%)
        raw_materials_ratio = data.get('raw_materials_cost_ratio', 0.5)
        if raw_materials_ratio <= 0.4:
            score += 60
        elif raw_materials_ratio <= 0.6:
            score += 30
        else:
            score -= 20
        
        return score

    def _score_tontine(self, data, base_score):
        """Scoring spécifique pour le crédit tontine"""
        score = base_score
        
        # Historique de cotisation (35%)
        contribution_months = data.get('contribution_history_months', 0)
        missed_contributions = data.get('missed_contributions', 0)
        
        if contribution_months >= 24 and missed_contributions == 0:
            score += 140
        elif contribution_months >= 12 and missed_contributions <= 1:
            score += 100
        elif contribution_months >= 6 and missed_contributions <= 2:
            score += 60
        else:
            score -= 50
        
        # Durée d'adhésion (25%)
        membership_months = data.get('tontine_membership_months', 0)
        if membership_months >= 24:
            score += 100
        elif membership_months >= 12:
            score += 60
        elif membership_months >= 6:
            score += 30
        else:
            score -= 30
        
        # Montant de cotisation (20%)
        contribution_amount = data.get('contribution_amount', 0)
        loan_amount = data.get('loan_amount', 0)
        if contribution_amount > 0:
            ratio = loan_amount / (contribution_amount * 12)
            if ratio <= 2:
                score += 80
            elif ratio <= 3:
                score += 50
            elif ratio <= 4:
                score += 20
            else:
                score -= 40
        
        # Solidarité du groupe (20%)
        group_default_rate = data.get('group_default_rate', 0)
        if group_default_rate == 0:
            score += 80
        elif group_default_rate <= 0.05:
            score += 50
        elif group_default_rate <= 0.1:
            score += 20
        else:
            score -= 50
        
        return score

    def _score_retraite(self, data, base_score):
        """Scoring spécifique pour le crédit retraite"""
        score = base_score
        
        # Montant de la pension (30%)
        pension_amount = data.get('pension_amount', 0)
        loan_amount = data.get('loan_amount', 0)
        loan_duration = data.get('loan_duration', 12)
        
        if pension_amount > 0:
            monthly_payment = loan_amount / loan_duration
            payment_ratio = monthly_payment / pension_amount
            
            if payment_ratio <= 0.3:
                score += 120
            elif payment_ratio <= 0.4:
                score += 80
            elif payment_ratio <= 0.5:
                score += 40
            else:
                score -= 60
        
        # Durée de perception de la pension (25%)
        pension_duration_months = data.get('pension_duration_months', 0)
        if pension_duration_months >= 24:
            score += 100
        elif pension_duration_months >= 12:
            score += 60
        elif pension_duration_months >= 6:
            score += 30
        
        # Age du retraité (15%)
        age = data.get('age', 65)
        if age <= 65:
            score += 60
        elif age <= 70:
            score += 40
        elif age <= 75:
            score += 20
        else:
            score -= 30
        
        # Affiliation (CNSS ou CPPF)
        affiliation = data.get('retirement_organization', '').upper()
        if affiliation in ['CNSS', 'CPPF']:
            score += 40
        
        # Autres revenus (15%)
        other_income = data.get('other_income', 0)
        if other_income > 0:
            score += min(60, int(other_income / 50000 * 10))
        
        return score

    def _score_spot(self, data, base_score):
        """Scoring spécifique pour le crédit spot"""
        score = base_score
        
        # Validité de l'urgence (25%)
        urgency_reason = data.get('urgency', '').lower()
        valid_urgencies = ['medical', 'décès', 'accident', 'catastrophe', 'opportunité commerciale']
        if any(reason in urgency_reason for reason in valid_urgencies):
            score += 100
        else:
            score += 20
        
        # Capacité de remboursement rapide (30%)
        repayment_source = data.get('repayment_source', '').lower()
        if 'contrat' in repayment_source or 'facture' in repayment_source:
            score += 120
        elif 'vente' in repayment_source or 'stock' in repayment_source:
            score += 80
        elif 'salaire' in repayment_source:
            score += 60
        else:
            score += 20
        
        # Cash flow (25%)
        monthly_cash_flow = data.get('cash_flow', 0)
        loan_amount = data.get('loan_amount', 0)
        if monthly_cash_flow > 0:
            coverage_ratio = (monthly_cash_flow * 3) / loan_amount
            if coverage_ratio >= 2:
                score += 100
            elif coverage_ratio >= 1.5:
                score += 60
            elif coverage_ratio >= 1:
                score += 30
            else:
                score -= 50
        
        # Stabilité de l'activité (20%)
        business_age_years = data.get('business_age_years', 0)
        if business_age_years >= 3:
            score += 80
        elif business_age_years >= 2:
            score += 50
        elif business_age_years >= 1:
            score += 20
        else:
            score -= 30
        
        return score

    def _apply_general_adjustments(self, data, score):
        """Applique des ajustements généraux au score"""
        
        # Historique de crédit
        credit_history = data.get('credit_history', 'nouveau')
        if credit_history == 'excellent':
            score += 50
        elif credit_history == 'bon':
            score += 30
        elif credit_history == 'moyen':
            score += 10
        elif credit_history == 'mauvais':
            score -= 100
        
        # Durée du prêt
        loan_duration = data.get('loan_duration', 12)
        credit_type = data.get('credit_type')
        max_duration = {
            'consommation': 48,
            'investissement': 36,
            'avance_facture': 12,
            'avance_commande': 12,
            'tontine': 24,
            'retraite': 12,
            'spot': 3
        }
        
        if credit_type in max_duration and loan_duration > max_duration[credit_type]:
            score -= 50  # Pénalité pour dépassement de durée max
        
        # Montant du prêt
        loan_amount = data.get('loan_amount', 0)
        limits = self.credit_limits.get(credit_type, {})
        max_amount = limits.get('max_amount')
        
        if max_amount and loan_amount > max_amount:
            score -= 100  # Pénalité forte pour dépassement du plafond
        
        return score

    def _calculate_probability(self, score):
        """Calcule la probabilité d'approbation basée sur le score"""
        if score >= 850:
            return 0.95
        elif score >= 750:
            return 0.85
        elif score >= 650:
            return 0.70
        elif score >= 550:
            return 0.50
        elif score >= 450:
            return 0.30
        else:
            return 0.10

    def _get_risk_level(self, score):
        """Détermine le niveau de risque basé sur le score"""
        if score >= 750:
            return 'bas'
        elif score >= 550:
            return 'moyen'
        else:
            return 'élevé'

    def _check_eligibility(self, data, credit_type):
        """Vérifie l'éligibilité selon les critères stricts de BAMBOO EMF"""
        eligible = True
        reasons = []
        
        # Vérifications communes
        age = data.get('age', 0)
        if age < 18:
            eligible = False
            reasons.append("Âge minimum requis: 18 ans")
        
        # Vérifications spécifiques par type
        if credit_type == 'consommation':
            income = data.get('monthly_income', 0)
            loan_amount = data.get('loan_amount', 0)
            loan_duration = data.get('loan_duration', 12)
            
            if income > 0:
                monthly_payment = loan_amount / loan_duration
                if monthly_payment > income * 0.35:
                    eligible = False
                    reasons.append("La mensualité dépasse 35% du salaire")
            
            if loan_duration > 48:
                eligible = False
                reasons.append("Durée maximale: 48 mois")
        
        elif credit_type == 'investissement':
            if data.get('loan_amount', 0) > 100000000:
                eligible = False
                reasons.append("Montant maximum: 100 000 000 FCFA")
            
            if data.get('entity_type') == 'entreprise':
                if not data.get('has_statutes'):
                    eligible = False
                    reasons.append("Statuts de l'entreprise requis")
                if not data.get('has_patent'):
                    eligible = False
                    reasons.append("Patente requise")
        
        elif credit_type == 'avance_facture':
            invoice_amount = data.get('invoice_amount', 0)
            loan_amount = data.get('loan_amount', 0)
            
            if invoice_amount > 0 and loan_amount > invoice_amount * 0.7:
                eligible = False
                reasons.append("Maximum 70% du montant de la facture")
            
            if loan_amount > 100000000:
                eligible = False
                reasons.append("Montant maximum: 100 000 000 FCFA")
        
        elif credit_type == 'tontine':
            if data.get('loan_amount', 0) > 5000000:
                eligible = False
                reasons.append("Montant maximum: 5 000 000 FCFA")
            
            if data.get('contribution_history_months', 0) < 6:
                eligible = False
                reasons.append("Minimum 6 mois de cotisation requis")
        
        elif credit_type == 'retraite':
            if data.get('retirement_organization', '').upper() not in ['CNSS', 'CPPF']:
                eligible = False
                reasons.append("Affiliation CNSS ou CPPF requise")
            
            if data.get('loan_duration', 0) > 12:
                eligible = False
                reasons.append("Durée maximale: 12 mois")
        
        elif credit_type == 'spot':
            if data.get('loan_duration', 0) > 3:
                eligible = False
                reasons.append("Durée maximale: 3 mois")
            
            if data.get('loan_amount', 0) > 100000000:
                eligible = False
                reasons.append("Montant maximum: 100 000 000 FCFA")
        
        return {
            'eligible': eligible,
            'reasons': reasons
        }

    def _identify_factors(self, data, credit_type, score):
        """Identifie les facteurs qui ont influencé le score"""
        factors = []
        
        # Facteurs génériques
        if score >= 750:
            factors.append({
                'name': 'profile_quality',
                'label': 'Profil de qualité',
                'impact': 'positive',
                'value': 'Excellent profil de crédit'
            })
        
        # Facteurs spécifiques selon le type
        if credit_type == 'consommation':
            income = data.get('monthly_income', 0)
            loan_amount = data.get('loan_amount', 0)
            loan_duration = data.get('loan_duration', 12)
            
            if income > 0:
                debt_ratio = (loan_amount / loan_duration) / income
                factors.append({
                    'name': 'debt_ratio',
                    'label': 'Ratio d\'endettement',
                    'impact': 'positive' if debt_ratio <= 0.35 else 'negative',
                    'value': f'{debt_ratio * 100:.1f}%'
                })
        
        elif credit_type == 'tontine':
            missed = data.get('missed_contributions', 0)
            factors.append({
                'name': 'contribution_regularity',
                'label': 'Régularité des cotisations',
                'impact': 'positive' if missed == 0 else 'negative',
                'value': f'{missed} cotisation(s) manquée(s)'
            })
        
        # Ajouter d'autres facteurs selon les données
        
        return factors

    def _get_recommendations(self, data, credit_type, score):
        """Génère des recommandations pour améliorer le score"""
        recommendations = []
        
        if score < 550:
            recommendations.append("Améliorer votre historique de crédit")
            
        if credit_type == 'consommation':
            income = data.get('monthly_income', 0)
            loan_amount = data.get('loan_amount', 0)
            loan_duration = data.get('loan_duration', 12)
            
            if income > 0:
                debt_ratio = (loan_amount / loan_duration) / income
                if debt_ratio > 0.35:
                    recommendations.append("Réduire le montant demandé ou augmenter la durée pour respecter le ratio de 35%")
        
        elif credit_type == 'investissement':
            if not data.get('has_financial_statements'):
                recommendations.append("Fournir les états financiers de l'entreprise")
            
            if data.get('collateral_value', 0) < data.get('loan_amount', 0):
                recommendations.append("Augmenter la valeur des garanties")
        
        elif credit_type == 'tontine':
            if data.get('contribution_history_months', 0) < 12:
                recommendations.append("Continuer à cotiser régulièrement pendant au moins 12 mois")
        
        return recommendations

    def predict(self, features):
        """Interface principale pour la prédiction - compatible avec l'API existante"""
        # Adapter les features au nouveau format si nécessaire
        data = {
            'credit_type': features.get('credit_type', 'consommation'),
            'age': features.get('age', 30),
            'employment_status': features.get('employment_status', 'cdi'),
            'job_seniority': features.get('job_seniority', 0),
            'monthly_income': features.get('monthly_income', 0),
            'other_income': features.get('other_income', 0),
            'existing_debts': features.get('existing_debts', 0),
            'loan_amount': features.get('loan_amount', 0),
            'loan_duration': features.get('loan_duration', 12),
            **features  # Inclure toutes les autres données
        }
        
        # Calculer le score avec toutes les données
        result = self.calculate_score(data)
        
        # Adapter le format de retour pour l'API
        return {
            'score': result['score'],
            'probability': result['probability'],
            'risk_level': result['risk_level'],
            'factors': result['factors'],
            'eligibility': result['eligibility'],
            'recommendations': result['recommendations']
        }