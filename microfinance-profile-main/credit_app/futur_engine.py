import pandas as pd
import numpy as np
from datetime import datetime
import logging

logger = logging.getLogger(__name__)

class FeatureEngineer:
    def __init__(self):
        self.age_mapping = {
            'moins_25': 22,
            '25_35': 30,
            '35_45': 40,
            '45_55': 50,
            'plus_55': 60
        }
        
        self.contract_mapping = {
            'CDI': 10,
            'Fonctionnaire': 10,
            'CDD': 5,
            'Freelance': 3,
            'Autres': 2
        }
        
        self.seniority_mapping = {
            'moins_1_an': 0.5,
            '1_3_ans': 2,
            '3_5_ans': 4,
            '5_10_ans': 7,
            'plus_10_ans': 10
        }
    
    def engineer_features(self, data):
        """Ingénierie des caractéristiques"""
        features = {}
        
        # Caractéristiques de base
        features['age'] = self._calculate_age(data.get('birthDate', ''))
        features['monthlyIncome'] = data.get('monthlyIncome', 0)
        features['otherIncome'] = data.get('otherIncome', 0)
        features['totalIncome'] = features['monthlyIncome'] + features['otherIncome']
        features['existingDebts'] = data.get('existingDebts', 0)
        features['requestedAmount'] = data.get('requestedAmount', 0)
        features['requestedDuration'] = data.get('requestedDuration', 0)
        
        # Caractéristiques dérivées
        features['debtToIncomeRatio'] = self._safe_divide(
            features['existingDebts'], features['monthlyIncome']
        )
        features['repaymentCapacity'] = features['monthlyIncome'] * 0.35
        features['requestedAmountRatio'] = self._safe_divide(
            features['requestedAmount'], features['monthlyIncome']
        )
        
        # Caractéristiques d'emploi
        features['jobSeniority'] = self._map_seniority(data.get('jobSeniority', ''))
        features['employmentStability'] = self._calculate_employment_stability(data)
        
        # Caractéristiques bancaires
        features['bankAccountAge'] = data.get('bankAccountAge', 0)
        features['averageBalance'] = data.get('averageBalance', 0)
        features['previousLoans'] = data.get('previousLoans', 0)
        
        # Caractéristiques de risque
        features['riskScore'] = self._calculate_risk_score(features)
        features['creditUtilization'] = self._calculate_credit_utilization(data)
        
        return features
    
    def _calculate_age(self, birth_date):
        """Calcul de l'âge"""
        try:
            if not birth_date:
                return 35  # Âge par défaut
            
            birth = datetime.strptime(birth_date, '%Y-%m-%d')
            today = datetime.now()
            age = today.year - birth.year
            
            if today.month < birth.month or (today.month == birth.month and today.day < birth.day):
                age -= 1
            
            return age
        except Exception as e:
            logger.warning(f"Erreur calcul âge: {e}")
            return 35
    
    def _safe_divide(self, numerator, denominator):
        """Division sécurisée"""
        if denominator == 0:
            return 0
        return numerator / denominator
    
    def _map_seniority(self, seniority):
        """Mapping de l'ancienneté"""
        return self.seniority_mapping.get(seniority, 0)
    
    def _calculate_employment_stability(self, data):
        """Calcul de la stabilité de l'emploi"""
        stability = 0
        
        # Score basé sur le type de contrat
        contract_type = data.get('contractType', '')
        stability += self.contract_mapping.get(contract_type, 0)
        
        # Bonus pour l'ancienneté
        seniority = self._map_seniority(data.get('jobSeniority', ''))
        stability += min(seniority, 5)
        
        return min(stability, 10)
    
    def _calculate_risk_score(self, features):
        """Calcul du score de risque"""
        risk_score = 0
        
        # Âge
        age = features['age']
        if age < 25:
            risk_score += 2
        elif age > 65:
            risk_score += 3
        else:
            risk_score += 0
        
        # Ratio dette/revenus
        debt_ratio = features['debtToIncomeRatio']
        if debt_ratio > 0.5:
            risk_score += 5
        elif debt_ratio > 0.3:
            risk_score += 2
        
        # Montant demandé vs revenus
        amount_ratio = features['requestedAmountRatio']
        if amount_ratio > 10:
            risk_score += 4
        elif amount_ratio > 5:
            risk_score += 2
        
        return risk_score
    
    def _calculate_credit_utilization(self, data):
        """Calcul du taux d'utilisation du crédit"""
        credit_limit = data.get('creditLimit', 0)
        current_balance = data.get('currentBalance', 0)
        
        if credit_limit <= 0:
            return 0
            
        utilization = (current_balance / credit_limit) * 100
        return min(utilization, 100)  # Limite à 100% même si dépassement

    def add_credit_type_features(self, features, credit_type, data):
        """Ajoute des caractéristiques spécifiques au type de crédit"""
        if credit_type == 'investissement':
            features['turnover'] = self._safe_log(data.get('turnover', 1))
            features['profitMargin'] = self._safe_divide(
                data.get('netProfit', 0), 
                data.get('turnover', 1)
            )
            
        elif credit_type == 'avance_facture':
            invoice_amount = data.get('invoiceAmount', 0)
            features['advanceRatio'] = self._safe_divide(
                features['requestedAmount'],
                invoice_amount
            )
            features['clientPaymentHistory'] = data.get('clientPaymentHistory', 0)
            
        return features

    def _safe_log(self, value):
        """Logarithme sécurisé"""
        return np.log1p(max(0, value))

    def calculate_affordability(self, features):
        """Calcule la capacité de remboursement"""
        disposable_income = features['monthlyIncome'] * 0.65  # 35% pour le remboursement
        monthly_payment = self._estimate_monthly_payment(
            features['requestedAmount'],
            features['requestedDuration']
        )
        
        return self._safe_divide(disposable_income, monthly_payment)

    def _estimate_monthly_payment(self, amount, duration, interest_rate=0.08):
        """Estime la mensualité (formule simplifiée)"""
        if duration == 0:
            return 0
            
        monthly_rate = interest_rate / 12
        return (amount * monthly_rate) / (1 - (1 + monthly_rate) ** -duration)

    def finalize_features(self, raw_features):
        """Finalise les caractéristiques pour le modèle"""
        # Conversion en DataFrame
        features_df = pd.DataFrame([raw_features])
        
        # Normalisation des valeurs numériques
        numeric_cols = features_df.select_dtypes(include=[np.number]).columns
        features_df[numeric_cols] = features_df[numeric_cols].fillna(0)
        
        # Gestion des valeurs extrêmes
        for col in ['debtToIncomeRatio', 'requestedAmountRatio']:
            features_df[col] = np.clip(features_df[col], 0, 10)
        
        return features_df.to_dict(orient='records')[0]