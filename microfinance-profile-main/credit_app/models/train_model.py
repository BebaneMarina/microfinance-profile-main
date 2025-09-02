import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import StandardScaler, LabelEncoder
from sklearn.metrics import classification_report, confusion_matrix, roc_auc_score
import joblib
import logging
from datetime import datetime
import os

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class CreditScoringRetrainer:
    def __init__(self):
        self.model = None
        self.scaler = StandardScaler()
        self.label_encoders = {}
        self.feature_columns = []
        self.target_column = 'decision_credit'
        
        # Types de crédit à automatiser
        self.automated_credit_types = ['consommation_generale', 'avance_salaire', 'depannage']
        
    def generate_synthetic_data(self, n_samples=10000):
        """Génère des données synthétiques pour l'entraînement"""
        logger.info(f"Génération de {n_samples} échantillons synthétiques...")
        
        data = []
        
        # S'assurer d'avoir une distribution équilibrée des décisions
        decisions_target = ['approuve', 'a_etudier', 'refuse']
        samples_per_decision = n_samples // 3
        remaining_samples = n_samples % 3
        
        decision_counts = {
            'approuve': samples_per_decision + (1 if remaining_samples > 0 else 0),
            'a_etudier': samples_per_decision + (1 if remaining_samples > 1 else 0),
            'refuse': samples_per_decision
        }
        
        for target_decision, target_count in decision_counts.items():
            generated_count = 0
            attempts = 0
            max_attempts = target_count * 10  # Limite de sécurité
            
            while generated_count < target_count and attempts < max_attempts:
                attempts += 1
                
                # Type de crédit aléatoire
                credit_type = np.random.choice(self.automated_credit_types)
                
                # Ajuster les paramètres selon la décision cible
                if target_decision == 'approuve':
                    # Profil favorable
                    age = np.random.randint(25, 56)
                    employment_status = np.random.choice(['cdi', 'fonctionnaire'], p=[0.6, 0.4])
                    job_seniority = np.random.randint(24, 120)
                    monthly_income = np.random.choice(range(300000, 1500001, 10000))
                    debt_ratio_max = 0.3
                elif target_decision == 'a_etudier':
                    # Profil moyen
                    age = np.random.randint(22, 60)
                    employment_status = np.random.choice(['cdi', 'cdd', 'fonctionnaire'], p=[0.4, 0.4, 0.2])
                    job_seniority = np.random.randint(12, 60)
                    monthly_income = np.random.choice(range(200000, 800001, 10000))
                    debt_ratio_max = 0.45
                else:  # refuse
                    # Profil défavorable
                    age = np.random.choice(list(range(18, 25)) + list(range(60, 66)))
                    employment_status = np.random.choice(['cdd', 'independant'], p=[0.6, 0.4])
                    job_seniority = np.random.randint(0, 12)
                    monthly_income = np.random.choice(range(100000, 300001, 10000))
                    debt_ratio_max = 0.6
                
                # Autres revenus
                other_income = np.random.choice(range(0, int(monthly_income * 0.3) + 1, 10000))
                
                # Charges proportionnelles au profil
                max_charges = int(monthly_income * debt_ratio_max)
                monthly_charges = np.random.choice(range(50000, max_charges + 1, 10000)) if max_charges > 50000 else 50000
                
                # Dettes existantes
                max_debt = int(monthly_income * 0.5)
                existing_debts = np.random.choice(range(0, max_debt + 1, 10000))
                
                marital_status = np.random.choice(['celibataire', 'marie', 'divorce', 'veuf'])
                dependents = np.random.randint(0, 4)
                education = np.random.choice(['primaire', 'secondaire', 'superieur', 'post_universitaire'])
                
                # Montant et durée selon le type
                if credit_type == 'consommation_generale':
                    if target_decision == 'approuve':
                        max_loan = min(5000000, int(monthly_income * 0.35))
                    else:
                        max_loan = min(5000000, int(monthly_income * 2))
                    loan_amount = np.random.choice(range(100000, max_loan + 1, 50000)) if max_loan > 100000 else 100000
                    loan_duration = np.random.randint(6, 37)
                elif credit_type == 'avance_salaire':
                    if target_decision == 'approuve':
                        max_loan = min(1000000, int(monthly_income * 0.7))
                    else:
                        max_loan = min(1000000, int(monthly_income * 0.9))
                    loan_amount = np.random.choice(range(50000, max_loan + 1, 10000)) if max_loan > 50000 else 50000
                    loan_duration = 1
                else:  # depannage
                    loan_amount = np.random.choice(range(100000, min(2000000, monthly_income * 4) + 1, 50000))
                    loan_duration = np.random.randint(1, 6)
                
                # Calcul des ratios
                debt_ratio = existing_debts / monthly_income if monthly_income > 0 else 0
                disposable_income = monthly_income + other_income - monthly_charges - existing_debts
                
                # Données spécifiques par type
                salary_domiciliation = False
                employer_convention = False
                urgency_justification = ''
                liquidity_problem = ''
                cash_flow_status = 'equilibre'
                
                if credit_type == 'avance_salaire':
                    if target_decision == 'approuve':
                        salary_domiciliation = True
                        employer_convention = True
                    else:
                        salary_domiciliation = np.random.choice([True, False], p=[0.3, 0.7])
                        employer_convention = np.random.choice([True, False], p=[0.3, 0.7])
                elif credit_type == 'depannage':
                    urgency_justification = np.random.choice(['urgent', 'tres_urgent', 'normal'])
                    liquidity_problem = np.random.choice(['temporaire', 'structurel', 'ponctuel'])
                    if target_decision == 'approuve':
                        cash_flow_status = np.random.choice(['positif', 'equilibre'], p=[0.7, 0.3])
                    else:
                        cash_flow_status = np.random.choice(['equilibre', 'temporairement_negatif', 'negatif'], p=[0.3, 0.4, 0.3])
                
                # Décision basée sur des règles métier
                decision = self.calculate_decision(
                    credit_type, age, employment_status, job_seniority, monthly_income,
                    debt_ratio, loan_amount, loan_duration, salary_domiciliation,
                    employer_convention, urgency_justification, disposable_income
                )
                
                # Vérifier si la décision correspond à la cible
                if decision == target_decision:
                    generated_count += 1
                    
                    # Ajout de l'échantillon
                    data.append({
                        'type_credit': credit_type,
                        'age': age,
                        'employment_status': employment_status,
                        'job_seniority': job_seniority,
                        'monthly_income': monthly_income,
                        'other_income': other_income,
                        'monthly_charges': monthly_charges,
                        'existing_debts': existing_debts,
                        'loan_amount': loan_amount,
                        'loan_duration': loan_duration,
                        'debt_ratio': debt_ratio,
                        'disposable_income': disposable_income,
                        'marital_status': marital_status,
                        'dependents': dependents,
                        'education': education,
                        'salary_domiciliation': salary_domiciliation,
                        'employer_convention': employer_convention,
                        'urgency_justification': urgency_justification,
                        'liquidity_problem': liquidity_problem,
                        'cash_flow_status': cash_flow_status,
                        'decision_credit': decision
                    })
        
        df = pd.DataFrame(data)
        
        # Vérifier la distribution des classes
        logger.info(f"Distribution des décisions générées:")
        for decision, count in df['decision_credit'].value_counts().items():
            logger.info(f"  {decision}: {count} ({count/len(df)*100:.1f}%)")
        
        return df
    
    def calculate_decision(self, credit_type, age, employment_status, job_seniority,
                          monthly_income, debt_ratio, loan_amount, loan_duration,
                          salary_domiciliation, employer_convention, urgency_justification,
                          disposable_income):
        """Calcule la décision selon les règles métier"""
        
        # Score de base
        score = 50
        
        # Règles communes
        if 25 <= age <= 55:
            score += 10
        if employment_status in ['cdi', 'fonctionnaire']:
            score += 15
        if job_seniority >= 24:
            score += 10
        if monthly_income >= 300000:
            score += 10
        if debt_ratio <= 0.35:
            score += 15
        elif debt_ratio > 0.5:
            score -= 10
        if disposable_income >= loan_amount * 0.1:  # Au moins 10% du prêt en revenu disponible
            score += 10
        
        # Règles spécifiques par type
        if credit_type == 'consommation_generale':
            if loan_amount <= monthly_income * 0.35:
                score += 10
            if job_seniority >= 6:
                score += 5
        
        elif credit_type == 'avance_salaire':
            if salary_domiciliation:
                score += 20
            if employer_convention:
                score += 15
            if loan_amount <= monthly_income * 0.7:
                score += 10
        
        elif credit_type == 'depannage':
            if urgency_justification in ['urgent', 'tres_urgent']:
                score += 5
            if disposable_income > 0:
                score += 10
            if loan_duration <= 3:
                score += 5
        
        # Décision finale
        if score >= 75:
            return 'approuve'
        elif score >= 60:
            return 'a_etudier'
        else:
            return 'refuse'
    
    def preprocess_data(self, data):
        """Préprocessing des données"""
        try:
            logger.info("Préprocessing des données...")
            
            # Filtrer uniquement les types automatisés
            data = data[data['type_credit'].isin(self.automated_credit_types)].copy()
            
            # Gestion des valeurs manquantes
            numerical_columns = [
                'age', 'job_seniority', 'monthly_income', 'other_income',
                'monthly_charges', 'existing_debts', 'loan_amount', 'loan_duration',
                'debt_ratio', 'disposable_income', 'dependents'
            ]
            
            categorical_columns = [
                'type_credit', 'employment_status', 'marital_status', 'education',
                'urgency_justification', 'liquidity_problem', 'cash_flow_status'
            ]
            
            boolean_columns = ['salary_domiciliation', 'employer_convention']
            
            # Remplir les valeurs manquantes
            for col in numerical_columns:
                if col in data.columns:
                    data[col] = data[col].fillna(data[col].median())
            
            for col in categorical_columns:
                if col in data.columns:
                    data[col] = data[col].fillna('inconnu')
            
            for col in boolean_columns:
                if col in data.columns:
                    data[col] = data[col].fillna(False).astype(int)
            
            # Encodage des variables catégorielles
            for col in categorical_columns:
                if col in data.columns:
                    if col not in self.label_encoders:
                        self.label_encoders[col] = LabelEncoder()
                        data[col] = self.label_encoders[col].fit_transform(data[col].astype(str))
                    else:
                        # Gérer les nouvelles catégories
                        data[col] = data[col].apply(
                            lambda x: self.label_encoders[col].transform([str(x)])[0] 
                            if str(x) in self.label_encoders[col].classes_ 
                            else -1
                        )
            
            # Sélection des features
            feature_cols = numerical_columns + categorical_columns + boolean_columns
            self.feature_columns = [col for col in feature_cols if col in data.columns]
            
            logger.info(f"Features utilisées: {len(self.feature_columns)}")
            
            return data[self.feature_columns], data[self.target_column] if self.target_column in data.columns else None
            
        except Exception as e:
            logger.error(f"Erreur préprocessing: {str(e)}")
            raise
    
    def train_model(self, X_train, y_train):
        """Entraîne le modèle"""
        try:
            logger.info("Entraînement du modèle...")
            
            # Normalisation
            X_train_scaled = self.scaler.fit_transform(X_train)
            
            # Configuration du modèle
            self.model = RandomForestClassifier(
                n_estimators=100,
                max_depth=10,
                min_samples_split=5,
                min_samples_leaf=2,
                random_state=42,
                class_weight='balanced'
            )
            
            # Entraînement
            self.model.fit(X_train_scaled, y_train)
            
            logger.info("Modèle entraîné avec succès")
            
        except Exception as e:
            logger.error(f"Erreur entraînement: {str(e)}")
            raise
    
    def evaluate_model(self, X_test, y_test):
        """Évalue le modèle"""
        try:
            logger.info("Évaluation du modèle...")
            
            # Normalisation
            X_test_scaled = self.scaler.transform(X_test)
            
            # Prédictions
            y_pred = self.model.predict(X_test_scaled)
            
            # Métriques
            report = classification_report(y_test, y_pred, output_dict=True)
            conf_matrix = confusion_matrix(y_test, y_pred)
            
            metrics = {
                'accuracy': report['accuracy'],
                'precision': report['weighted avg']['precision'],
                'recall': report['weighted avg']['recall'],
                'f1_score': report['weighted avg']['f1-score'],
                'confusion_matrix': conf_matrix.tolist(),
                'classification_report': report
            }
            
            logger.info(f"Accuracy: {metrics['accuracy']:.4f}")
            logger.info(f"F1-Score: {metrics['f1_score']:.4f}")
            
            return metrics
            
        except Exception as e:
            logger.error(f"Erreur évaluation: {str(e)}")
            raise
    
    def save_model(self, model_path='models/'):
        """Sauvegarde le modèle"""
        try:
            os.makedirs(model_path, exist_ok=True)
            
            joblib.dump(self.model, os.path.join(model_path, 'credit_scoring_model.pkl'))
            joblib.dump(self.scaler, os.path.join(model_path, 'scaler.pkl'))
            joblib.dump(self.label_encoders, os.path.join(model_path, 'label_encoders.pkl'))
            joblib.dump(self.feature_columns, os.path.join(model_path, 'feature_columns.pkl'))
            
            # Sauvegarder la configuration
            config = {
                'automated_credit_types': self.automated_credit_types,
                'training_date': datetime.now().isoformat(),
                'features': self.feature_columns,
                'model_type': 'RandomForestClassifier'
            }
            
            import json
            with open(os.path.join(model_path, 'model_config.json'), 'w') as f:
                json.dump(config, f, indent=2)
            
            logger.info(f"Modèle sauvegardé dans {model_path}")
            
        except Exception as e:
            logger.error(f"Erreur sauvegarde: {str(e)}")
            raise
    
    def retrain_with_synthetic_data(self, n_samples=10000):
        """Pipeline complet avec données synthétiques"""
        try:
            logger.info("=== Début du réentraînement ===")
            
            # 1. Génération des données
            data = self.generate_synthetic_data(n_samples)
            
            # Vérifier qu'on a assez d'échantillons par classe
            min_samples_per_class = data['decision_credit'].value_counts().min()
            if min_samples_per_class < 2:
                raise ValueError(f"Pas assez d'échantillons pour certaines classes (min: {min_samples_per_class})")
            
            # 2. Split train/test/validation
            train_data, temp_data = train_test_split(data, test_size=0.3, random_state=42, stratify=data['decision_credit'])
            test_data, val_data = train_test_split(temp_data, test_size=0.5, random_state=42, stratify=temp_data['decision_credit'])
            
            logger.info(f"Train: {len(train_data)}, Test: {len(test_data)}, Validation: {len(val_data)}")
            
            # 3. Préprocessing
            X_train, y_train = self.preprocess_data(train_data)
            X_test, y_test = self.preprocess_data(test_data)
            X_val, y_val = self.preprocess_data(val_data)
            
            # 4. Entraînement
            self.train_model(X_train, y_train)
            
            # 5. Évaluation
            logger.info("=== Métriques sur Test ===")
            test_metrics = self.evaluate_model(X_test, y_test)
            
            logger.info("=== Métriques sur Validation ===")
            val_metrics = self.evaluate_model(X_val, y_val)
            
            # 6. Sauvegarde
            self.save_model()
            
            # 7. Résultats
            results = {
                'status': 'success',
                'timestamp': datetime.now().isoformat(),
                'samples': {
                    'total': n_samples,
                    'train': len(train_data),
                    'test': len(test_data),
                    'validation': len(val_data)
                },
                'credit_types': self.automated_credit_types,
                'features_used': len(self.feature_columns),
                'test_metrics': test_metrics,
                'validation_metrics': val_metrics
            }
            
            logger.info("=== Réentraînement terminé avec succès ===")
            return results
            
        except Exception as e:
            logger.error(f"Erreur pipeline: {str(e)}")
            raise

# Script principal
if __name__ == "__main__":
    retrainer = CreditScoringRetrainer()
    
    try:
        # Réentraînement avec données synthétiques
        results = retrainer.retrain_with_synthetic_data(n_samples=10000)
        
        print("\n" + "="*50)
        print("RÉSULTATS DU RÉENTRAÎNEMENT")
        print("="*50)
        print(f"Status: {results['status']}")
        print(f"Date: {results['timestamp']}")
        print(f"Types de crédit: {', '.join(results['credit_types'])}")
        print(f"Échantillons total: {results['samples']['total']}")
        print(f"Features utilisées: {results['features_used']}")
        
        print("\nPerformance sur Test:")
        print(f"  Accuracy: {results['test_metrics']['accuracy']:.4f}")
        print(f"  F1-Score: {results['test_metrics']['f1_score']:.4f}")
        
        print("\nPerformance sur Validation:")
        print(f"  Accuracy: {results['validation_metrics']['accuracy']:.4f}")
        print(f"  F1-Score: {results['validation_metrics']['f1_score']:.4f}")
        
    except Exception as e:
        print(f"Erreur: {str(e)}")