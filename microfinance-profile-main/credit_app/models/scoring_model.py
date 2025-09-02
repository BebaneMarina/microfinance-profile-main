# scoring_model_fixed.py - VERSION OPTIMISÉE SANS RÉCURSION
import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score
import joblib
import os
import logging
import warnings
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional
warnings.filterwarnings('ignore')

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class CreditScoringModel:
    def __init__(self):
        self.model = None
        self.scaler = StandardScaler()
        self.feature_names = [
            'age', 'monthly_income', 'other_income', 'monthly_charges',
            'existing_debts', 'job_seniority', 'employment_status_encoded',
            'loan_amount', 'loan_duration', 'debt_ratio', 'payment_capacity',
            'income_stability', 'credit_history_score'
        ]
        self.model_path = 'models/credit_scoring_model.pkl'
        self.scaler_path = 'models/credit_scaler.pkl'
        
        # Cache pour les scores temps réel - OPTIMISÉ
        self.score_cache = {}
        self.last_calculation_time = {}  # NOUVEAU : éviter les calculs répétitifs
        self.cache_duration = 30  # secondes - durée de validité du cache
        
        # Configuration des types de crédit
        self.credit_types_config = {
            'consommation_generale': {
                'max_amount': 5000000,
                'max_duration': 3,
                'min_income': 200000,
                'interest_rate': 0.05
            },
            'avance_salaire': {
                'max_amount': 2000000,
                'max_duration': 1,
                'min_income': 150000,
                'interest_rate': 0.03
            },
            'depannage': {
                'max_amount': 1000000,
                'max_duration': 1,
                'min_income': 100000,
                'interest_rate': 0.04
            }
        }
        
        # Pondération temps réel
        self.realtime_weights = {
            'base_score': 0.6,  # 60% score de base
            'payment_history': 0.25,  # 25% historique
            'recent_behavior': 0.15   # 15% comportement récent
        }
        
        # Impact des transactions
        self.transaction_impacts = {
            'on_time_payment': 0.1,
            'early_payment': 0.15,
            'late_1_7_days': -0.05,
            'late_8_30_days': -0.2,
            'late_31_plus_days': -0.5,
            'missed_payment': -1.0,
            'loan_disbursement': -0.1,
            'loan_closure': 0.3
        }
        
        # Charger le modèle
        if not self.load_model():
            logger.info("Aucun modèle trouvé, entraînement d'un nouveau modèle...")
            self.train_with_synthetic_data()

    def load_model(self):
        """Charge le modèle pré-entraîné"""
        try:
            if os.path.exists(self.model_path) and os.path.exists(self.scaler_path):
                self.model = joblib.load(self.model_path)
                self.scaler = joblib.load(self.scaler_path)
                logger.info("✅ Modèle chargé avec succès")
                return True
            return False
        except Exception as e:
            logger.error(f"❌ Erreur chargement modèle: {str(e)}")
            return False

    def save_model(self):
        """Sauvegarde le modèle"""
        try:
            if self.model is not None:
                os.makedirs('models', exist_ok=True)
                joblib.dump(self.model, self.model_path)
                joblib.dump(self.scaler, self.scaler_path)
                logger.info("💾 Modèle sauvegardé")
                return True
            return False
        except Exception as e:
            logger.error(f"❌ Erreur sauvegarde: {str(e)}")
            return False

    def train_with_synthetic_data(self):
        """Entraîne le modèle avec des données synthétiques"""
        try:
            logger.info("🔄 Entraînement du modèle...")
            
            n_samples = 1000  # Réduit pour éviter la surcharge
            data = []
            
            np.random.seed(42)
            
            for i in range(n_samples):
                age = max(18, min(65, np.random.normal(35, 10)))
                monthly_income = max(100000, min(5000000, np.random.lognormal(13, 0.7)))
                other_income = np.random.exponential(100000) if np.random.random() < 0.3 else 0
                monthly_charges = monthly_income * np.random.uniform(0.2, 0.8)
                existing_debts = monthly_income * np.random.uniform(0, 1.5)
                job_seniority = np.random.exponential(24)
                
                employment_status = np.random.choice(['cdi', 'cdd', 'independant', 'autre'], 
                                                   p=[0.4, 0.3, 0.2, 0.1])
                employment_encoded = {'cdi': 3, 'cdd': 2, 'independant': 1, 'autre': 0}[employment_status]
                
                loan_amount = np.random.uniform(100000, 2000000)
                loan_duration = np.random.uniform(0.5, 3)
                
                total_income = monthly_income + other_income
                debt_ratio = (monthly_charges + existing_debts) / total_income
                payment_capacity = max(0, total_income - monthly_charges - existing_debts)
                income_stability = min(100, (job_seniority / 12) * 20 + employment_encoded * 20)
                credit_history_score = np.random.uniform(50, 100)
                
                score_factors = [
                    monthly_income / 500000 * 0.3,
                    employment_encoded / 3 * 0.2,
                    (1 - debt_ratio) * 0.25,
                    job_seniority / 36 * 0.1,
                    credit_history_score / 100 * 0.15
                ]
                
                final_score = sum(score_factors)
                approved = 1 if final_score > 0.6 else 0
                
                sample = [
                    age, monthly_income, other_income, monthly_charges,
                    existing_debts, job_seniority, employment_encoded,
                    loan_amount, loan_duration, debt_ratio, payment_capacity,
                    income_stability, credit_history_score
                ]
                
                data.append(sample + [approved])
            
            # Créer le DataFrame
            columns = self.feature_names + ['approved']
            df = pd.DataFrame(data, columns=columns)
            
            X = df[self.feature_names]
            y = df['approved']
            
            X_train, X_test, y_train, y_test = train_test_split(
                X, y, test_size=0.2, random_state=42, stratify=y
            )
            
            X_train_scaled = self.scaler.fit_transform(X_train)
            X_test_scaled = self.scaler.transform(X_test)
            
            self.model = RandomForestClassifier(
                n_estimators=50,  # Réduit pour les performances
                max_depth=8,
                min_samples_split=5,
                min_samples_leaf=2,
                random_state=42,
                n_jobs=1  # Un seul job pour éviter les conflits
            )
            
            self.model.fit(X_train_scaled, y_train)
            
            y_pred = self.model.predict(X_test_scaled)
            accuracy = accuracy_score(y_test, y_pred)
            
            logger.info(f"✅ Modèle entraîné! Précision: {accuracy:.2%}")
            self.save_model()
            
            return accuracy
            
        except Exception as e:
            logger.error(f"❌ Erreur entraînement: {str(e)}")
            return 0.0

    # MÉTHODE OPTIMISÉE : Calcul temps réel sans récursion
    def calculate_realtime_score(self, user_id: int, client_data: Dict, transaction_history: List = None) -> Dict[str, Any]:
        """Calcule le score temps réel - VERSION OPTIMISÉE"""
        try:
            current_time = datetime.now()
            
            # VÉRIFICATION CACHE : éviter les calculs répétitifs
            cache_key = f"{user_id}_{hash(str(client_data))}"
            if cache_key in self.last_calculation_time:
                last_calc = self.last_calculation_time[cache_key]
                if (current_time - last_calc).seconds < self.cache_duration:
                    cached_result = self.score_cache.get(cache_key)
                    if cached_result:
                        logger.info(f"🔄 Score temps réel (cache) pour utilisateur {user_id}")
                        return cached_result
            
            logger.info(f"🔄 Calcul score temps réel pour utilisateur {user_id}")
            
            # 1. Score de base SANS récursion
            base_score_result = self.predict_base_score(client_data)
            base_score = base_score_result['score']
            
            # 2. Analyse de l'historique
            payment_analysis = self.analyze_payment_history_simple(transaction_history or [])
            
            # 3. Score final pondéré
            final_score = (
                base_score * self.realtime_weights['base_score'] +
                payment_analysis['payment_score'] * self.realtime_weights['payment_history'] +
                payment_analysis['behavior_score'] * self.realtime_weights['recent_behavior']
            )
            
            final_score = max(0, min(10, final_score))
            
            # 4. Calculer le changement
            previous_score = self.get_cached_score(user_id)
            score_change = final_score - previous_score
            
            # 5. Résultat
            result = {
                'user_id': user_id,
                'score': round(final_score, 1),
                'previous_score': previous_score,
                'score_change': round(score_change, 1),
                'risk_level': self.determine_risk_level(final_score),
                'factors': self.get_simplified_factors(base_score, payment_analysis),
                'recommendations': self.get_basic_recommendations(final_score, payment_analysis),
                'model_confidence': base_score_result.get('model_confidence', 0.75),
                'model_type': 'optimized_realtime',
                'payment_analysis': payment_analysis,
                'is_realtime': True,
                'last_updated': current_time.isoformat()
            }
            
            # 6. Mettre à jour le cache
            self.score_cache[user_id] = final_score
            self.score_cache[cache_key] = result
            self.last_calculation_time[cache_key] = current_time
            
            logger.info(f"✅ Score temps réel calculé: {previous_score} → {final_score} (Δ{score_change:+.1f})")
            
            return result
            
        except Exception as e:
            logger.error(f"❌ Erreur calcul score temps réel: {str(e)}")
            # Fallback simple
            return self.predict_base_score(client_data)

    def predict_base_score(self, client_data):
        """Prédiction de base SANS récursion"""
        try:
            if self.model is None:
                return self.rule_based_scoring(client_data)
            
            # Préparer les features de base seulement
            X = self.prepare_basic_features(client_data)
            X_scaled = self.scaler.transform(X)
            
            prediction = self.model.predict(X_scaled)[0]
            proba = self.model.predict_proba(X_scaled)[0]
            
            score_850 = 700 if prediction == 1 else 400
            score_850 = int(score_850 + 150 * proba[1])
            score_850 = max(300, min(850, score_850))
            
            score_10 = self.convert_score_to_10(score_850)
            
            return {
                'score': score_10,
                'score_850': score_850,
                'probability': float(proba[1]),
                'risk_level': self.determine_risk_level(score_10),
                'decision': self.get_decision(score_850),
                'factors': [],
                'model_confidence': float(max(proba)),
                'model_type': 'random_forest_base',
                'is_realtime': False
            }
            
        except Exception as e:
            logger.error(f"❌ Erreur prédiction base: {str(e)}")
            return self.rule_based_scoring(client_data)

    def prepare_basic_features(self, data):
        """Prépare SEULEMENT les features de base"""
        features = {}
        
        features['age'] = float(data.get('age', 30))
        features['monthly_income'] = float(data.get('monthly_income', 0))
        features['other_income'] = float(data.get('other_income', 0))
        features['monthly_charges'] = float(data.get('monthly_charges', 0))
        features['existing_debts'] = float(data.get('existing_debts', 0))
        features['job_seniority'] = float(data.get('job_seniority', 12))
        features['loan_amount'] = float(data.get('loan_amount', 1000000))
        features['loan_duration'] = float(data.get('loan_duration', 1))
        
        employment_status = data.get('employment_status', 'autre').lower()
        employment_mapping = {'cdi': 3, 'cdd': 2, 'independant': 1, 'autre': 0}
        features['employment_status_encoded'] = employment_mapping.get(employment_status, 0)
        
        total_income = features['monthly_income'] + features['other_income']
        features['debt_ratio'] = (features['monthly_charges'] + features['existing_debts']) / max(total_income, 1)
        features['payment_capacity'] = max(0, total_income - features['monthly_charges'] - features['existing_debts'])
        features['income_stability'] = min(100, (features['job_seniority'] / 12) * 20 + features['employment_status_encoded'] * 20)
        features['credit_history_score'] = 75  # Valeur par défaut
        
        df = pd.DataFrame([features])[self.feature_names]
        return df

    def analyze_payment_history_simple(self, transaction_history: List) -> Dict[str, Any]:
        """Analyse simplifiée de l'historique de paiement"""
        if not transaction_history:
            return {
                'payment_score': 6.0,
                'behavior_score': 6.0,
                'total_payments': 0,
                'on_time_ratio': 0.8,
                'trend': 'stable'
            }
        
        # Analyser seulement les 10 dernières transactions
        recent = transaction_history[-10:] if len(transaction_history) > 10 else transaction_history
        
        total_payments = len(recent)
        on_time_payments = sum(1 for t in recent if t.get('days_late', 0) == 0)
        
        on_time_ratio = on_time_payments / total_payments if total_payments > 0 else 0.8
        
        # Score de paiement simple
        payment_score = on_time_ratio * 10
        
        # Score de comportement basé sur la régularité
        behavior_score = 6.0 + (on_time_ratio - 0.5) * 4
        behavior_score = max(0, min(10, behavior_score))
        
        return {
            'payment_score': round(payment_score, 1),
            'behavior_score': round(behavior_score, 1),
            'total_payments': total_payments,
            'on_time_ratio': round(on_time_ratio, 2),
            'trend': 'improving' if on_time_ratio > 0.8 else ('declining' if on_time_ratio < 0.6 else 'stable')
        }

    def get_simplified_factors(self, base_score: float, payment_analysis: Dict) -> List[Dict]:
        """Facteurs simplifiés"""
        return [
            {
                'name': 'profil_base',
                'value': int(base_score * 10),
                'impact': 60,
                'description': 'Profil financier de base'
            },
            {
                'name': 'historique_paiements',
                'value': int(payment_analysis.get('payment_score', 6) * 10),
                'impact': 25,
                'description': 'Historique des paiements'
            },
            {
                'name': 'comportement_recent',
                'value': int(payment_analysis.get('behavior_score', 6) * 10),
                'impact': 15,
                'description': 'Comportement récent'
            }
        ]

    def get_basic_recommendations(self, score: float, payment_analysis: Dict) -> List[str]:
        """Recommandations de base"""
        recommendations = []
        
        if score < 5:
            recommendations.append("⚠️ Améliorez votre régularité de paiement")
        elif score < 7:
            recommendations.append("📈 Continuez vos efforts, votre score progresse")
        else:
            recommendations.append("🎉 Excellent score ! Maintenez vos bonnes habitudes")
        
        on_time_ratio = payment_analysis.get('on_time_ratio', 0.8)
        if on_time_ratio < 0.8:
            recommendations.append("📅 Respectez vos échéances pour améliorer votre score")
        
        return recommendations[:3]  # Maximum 3 recommandations

    # MÉTHODES UTILITAIRES OPTIMISÉES
    def get_cached_score(self, user_id: int) -> float:
        """Score en cache"""
        return self.score_cache.get(user_id, 6.0)

    def determine_risk_level(self, score: float) -> str:
        """Niveau de risque"""
        if score >= 9: return 'très_bas'
        elif score >= 7: return 'bas'
        elif score >= 5: return 'moyen'
        elif score >= 3: return 'élevé'
        else: return 'très_élevé'

    def convert_score_to_10(self, score_850):
        """Conversion score 850 vers 10"""
        score_10 = ((score_850 - 300) / 550) * 10
        return max(0, min(10, round(score_10, 1)))

    def get_decision(self, score_850):
        """Décision basée sur score 850"""
        if score_850 >= 650: return 'approuvé'
        elif score_850 >= 550: return 'à étudier'
        else: return 'refusé'

    # MÉTHODE SIMPLIFIÉE POUR LE MAIN PREDICT
    def predict(self, client_data):
        """Méthode principale de prédiction - SIMPLIFIÉE"""
        try:
            # Utiliser seulement le scoring de base pour éviter la récursion
            return self.predict_base_score(client_data)
            
        except Exception as e:
            logger.error(f"❌ Erreur prédiction: {str(e)}")
            return self.rule_based_scoring(client_data)

    def rule_based_scoring(self, client_data):
        """Scoring par règles métier"""
        score_850 = 650
        factors = []
        
        monthly_income = float(client_data.get('monthly_income', 0))
        employment_status = client_data.get('employment_status', 'autre').lower()
        job_seniority = float(client_data.get('job_seniority', 0))
        
        # Revenus
        if monthly_income >= 500000:
            score_850 += 80
            factors.append({'name': 'monthly_income', 'value': 90, 'impact': 25})
        elif monthly_income >= 300000:
            score_850 += 40
            factors.append({'name': 'monthly_income', 'value': 70, 'impact': 15})
        
        # Emploi
        if employment_status == 'cdi':
            score_850 += 80
            factors.append({'name': 'employment_status', 'value': 90, 'impact': 25})
        elif employment_status == 'cdd':
            score_850 += 40
            factors.append({'name': 'employment_status', 'value': 70, 'impact': 15})
        
        # Ancienneté
        if job_seniority >= 24:
            score_850 += 60
            factors.append({'name': 'job_seniority', 'value': 85, 'impact': 20})
        
        score_850 = max(300, min(850, score_850))
        score_10 = self.convert_score_to_10(score_850)
        
        return {
            'score': score_10,
            'score_850': score_850,
            'probability': (score_850 - 300) / 550,
            'risk_level': self.determine_risk_level(score_10),
            'decision': self.get_decision(score_850),
            'factors': factors,
            'model_confidence': 0.75,
            'model_type': 'rule_based',
            'is_realtime': False
        }

    def calculate_eligible_amount(self, client_data):
        """Calcul du montant éligible"""
        try:
            score_result = self.predict_base_score(client_data)
            score_10 = score_result['score']
            risk_level = score_result['risk_level']
            
            monthly_income = float(client_data.get('monthly_income', 0))
            max_amount = min(monthly_income * 0.3333, 2000000)
            
            if risk_level == 'élevé':
                max_amount *= 0.7
            elif risk_level == 'très_élevé':
                max_amount *= 0.5
            elif risk_level in ['bas', 'très_bas']:
                max_amount = min(max_amount * 1.2, 2000000)
            
            return {
                'eligible_amount': int(max_amount // 1000 * 1000),
                'score': score_10,
                'risk_level': risk_level,
                'factors': score_result['factors'],
                'recommendations': [
                    'Montant calculé selon votre profil de risque',
                    'Maintenez vos revenus stables pour conserver ce montant'
                ]
            }
            
        except Exception as e:
            logger.error(f"❌ Erreur calcul montant éligible: {str(e)}")
            monthly_income = float(client_data.get('monthly_income', 500000))
            return {
                'eligible_amount': int(min(monthly_income * 0.3333, 1000000)),
                'score': 6.0,
                'risk_level': 'moyen',
                'factors': [],
                'recommendations': ['Calcul par défaut']
            }

    # NOUVELLES MÉTHODES POUR LA COMPATIBILITÉ
    def process_transaction_impact(self, user_id: int, transaction_type: str, 
                                 days_late: int = 0, amount: float = 0) -> Dict[str, Any]:
        """Impact d'une transaction - VERSION SIMPLIFIÉE"""
        try:
            current_score = self.get_cached_score(user_id)
            
            # Impact simple basé sur le type
            if transaction_type == 'payment' and days_late == 0:
                impact = 0.1
            elif transaction_type == 'payment' and days_late > 0:
                impact = -0.1 * (1 + days_late / 30)
            elif transaction_type == 'missed_payment':
                impact = -0.5
            else:
                impact = 0
            
            new_score = max(0, min(10, current_score + impact))
            
            # Mettre à jour le cache
            self.score_cache[user_id] = new_score
            
            return {
                'previous_score': current_score,
                'new_score': round(new_score, 1),
                'score_change': round(impact, 1),
                'risk_level': self.determine_risk_level(new_score),
                'updated_at': datetime.now().isoformat()
            }
            
        except Exception as e:
            logger.error(f"❌ Erreur impact transaction: {str(e)}")
            return {
                'previous_score': 6.0,
                'new_score': 6.0,
                'score_change': 0,
                'error': str(e)
            }

    def get_score_trend_analysis(self, user_id: int, days: int = 90) -> Dict:
        """Analyse de tendance - SIMPLIFIÉE"""
        return {
            'trend': 'stable',
            'average_change_per_month': 0.1,
            'consistency_score': 75,
            'prediction_next_month': self.get_cached_score(user_id) + 0.1
        }

    def simulate_transaction_impact(self, user_id: int, transaction_type: str, 
                                  amount: float = 0, days_late: int = 0) -> Dict:
        """Simulation d'impact - SIMPLIFIÉE"""
        current_score = self.get_cached_score(user_id)
        
        # Impact simulé
        if transaction_type == 'payment' and days_late == 0:
            impact = 0.1
            description = 'Paiement à temps - Impact positif'
        elif days_late > 0:
            impact = -0.1 * (1 + days_late / 30)
            description = f'Paiement en retard - Impact négatif'
        else:
            impact = 0
            description = 'Impact neutre'
        
        estimated_score = max(0, min(10, current_score + impact))
        
        return {
            'current_score': current_score,
            'estimated_new_score': round(estimated_score, 1),
            'estimated_change': round(impact, 2),
            'transaction_type': transaction_type,
            'impact_description': description,
            'simulation': True
        }