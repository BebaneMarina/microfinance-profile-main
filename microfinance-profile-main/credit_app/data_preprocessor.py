from flask import Flask, request, jsonify
from flask_cors import CORS
import logging
import os
from datetime import datetime
import traceback

from models.scoring_model import ScoringModel
from utils.feature_engineering import FeatureEngineer
from config.config import Config

# Configuration du logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)

# Configuration
config = Config()
app.config.from_object(config)

# Initialisation des services
scoring_model = ScoringModel(config)
feature_engineer = FeatureEngineer()

@app.route('/health', methods=['GET'])
def health_check():
    """Vérification de l'état du service"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'model_loaded': scoring_model.is_loaded(),
        'version': config.MODEL_VERSION
    })

@app.route('/predict', methods=['POST'])
def predict_score():
    """Prédiction du score de crédit"""
    try:
        # Validation des données d'entrée
        data = request.get_json()
        if not data:
            return jsonify({'error': 'Données manquantes'}), 400
        
        # Ingénierie des caractéristiques
        features = feature_engineer.engineer_features(data)
        
        # Prédiction
        prediction = scoring_model.predict(features)
        
        # Formatage de la réponse
        response = {
            'score': float(prediction['score']),
            'probability': float(prediction['probability']),
            'factors': prediction['factors'],
            'modelVersion': config.MODEL_VERSION,
            'timestamp': datetime.now().isoformat()
        }
        
        logger.info(f"Prédiction réalisée: score={response['score']}")
        return jsonify(response)
        
    except Exception as e:
        logger.error(f"Erreur lors de la prédiction: {str(e)}")
        return jsonify({'error': 'Erreur interne du serveur'}), 500

@app.route('/retrain', methods=['POST'])
def retrain_model():
    """Réentraînement du modèle"""
    try:
        # Données d'entraînement (à adapter selon votre source)
        training_data = request.get_json()
        
        # Réentraînement
        result = scoring_model.retrain(training_data)
        
        return jsonify({
            'message': 'Modèle réentraîné avec succès',
            'metrics': result['metrics'],
            'modelVersion': result['version'],
            'timestamp': datetime.now().isoformat()
        })
        
    except Exception as e:
        logger.error(f"Erreur lors du réentraînement: {str(e)}")
        return jsonify({'error': 'Erreur lors du réentraînement'}), 500

@app.route('/model/info', methods=['GET'])
def model_info():
    """Informations sur le modèle"""
    try:
        info = scoring_model.get_model_info()
        return jsonify(info)
    except Exception as e:
        logger.error(f"Erreur lors de la récupération des infos: {str(e)}")
        return jsonify({'error': 'Erreur interne du serveur'}), 500

@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'Endpoint non trouvé'}), 404

@app.errorhandler(500)
def internal_error(error):
    return jsonify({'error': 'Erreur interne du serveur'}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=config.DEBUG)

# models/scoring_model.py
import joblib
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, classification_report, roc_auc_score
import os
from datetime import datetime
import logging

logger = logging.getLogger(__name__)

class ScoringModel:
    def __init__(self, config):
        self.config = config
        self.model = None
        self.scaler = None
        self.feature_names = None
        self.model_version = config.MODEL_VERSION
        self.model_path = config.MODEL_PATH
        
        # Chargement du modèle au démarrage
        self._load_model()
    
    def _load_model(self):
        """Chargement du modèle pré-entraîné"""
        try:
            if os.path.exists(self.model_path):
                self.model = joblib.load(os.path.join(self.model_path, 'random_forest_model.pkl'))
                self.scaler = joblib.load(os.path.join(self.model_path, 'scaler.pkl'))
                self.feature_names = joblib.load(os.path.join(self.model_path, 'feature_names.pkl'))
                logger.info("Modèle chargé avec succès")
            else:
                logger.warning("Modèle non trouvé, création d'un nouveau modèle")
                self._create_default_model()
        except Exception as e:
            logger.error(f"Erreur lors du chargement du modèle: {str(e)}")
            self._create_default_model()
    
    def _create_default_model(self):
        """Création d'un modèle par défaut"""
        self.model = RandomForestClassifier(n_estimators=100, random_state=42)
        self.scaler = StandardScaler()
        self.feature_names = [
            'age', 'monthlyIncome', 'totalIncome', 'debtToIncomeRatio',
            'repaymentCapacity', 'jobSeniority', 'employmentStability',
            'requestedAmount', 'requestedDuration', 'requestedAmountRatio',
            'bankAccountAge', 'averageBalance', 'previousLoans'
        ]
    
    def predict(self, features):
        """Prédiction du score de crédit"""
        if not self.is_loaded():
            raise ValueError("Modèle non chargé")
        
        # Préparation des données
        feature_array = self._prepare_features(features)
        
        # Prédiction
        if hasattr(self.model, 'predict_proba'):
            probability = self.model.predict_proba(feature_array)[0][1]
        else:
            probability = 0.5
        
        # Calcul du score (0-1000)
        score = self._calculate_score(probability, features)
        
        # Analyse des facteurs d'influence
        factors = self._analyze_factors(features, feature_array)
        
        return {
            'score': score,
            'probability': probability,
            'factors': factors
        }
    
    def _prepare_features(self, features):
        """Préparation des caractéristiques pour le modèle"""
        # Extraction des valeurs selon les noms des caractéristiques
        feature_values = []
        for feature_name in self.feature_names:
            value = features.get(feature_name, 0)
            feature_values.append(value)
        
        # Normalisation si un scaler est disponible
        feature_array = np.array(feature_values).reshape(1, -1)
        if self.scaler:
            try:
                feature_array = self.scaler.transform(feature_array)
            except:
                pass  # Si la normalisation échoue, on utilise les valeurs brutes
        
        return feature_array
    
    def _calculate_score(self, probability, features):
        """Calcul du score final (0-1000)"""
        # Score de base basé sur la probabilité
        base_score = (1 - probability) * 1000
        
        # Ajustements basés sur les règles métier
        adjustments = 0
        
        # Ajustement pour le ratio dette/revenus
        debt_ratio = features.get('debtToIncomeRatio', 0)
        if debt_ratio > 0.5:
            adjustments -= 100
        elif debt_ratio < 0.2:
            adjustments += 50
        
        # Ajustement pour la stabilité de l'emploi
        employment_stability = features.get('employmentStability', 0)
        if employment_stability >= 8:
            adjustments += 50
        elif employment_stability <= 3:
            adjustments -= 50
        
        # Ajustement pour l'ancienneté
        job_seniority = features.get('jobSeniority', 0)
        if job_seniority >= 5:
            adjustments += 30
        
        # Score final
        final_score = max(0, min(1000, base_score + adjustments))
        return final_score
    
    def _analyze_factors(self, features, feature_array):
        """Analyse des facteurs d'influence"""
        factors = []
        
        # Analyse du ratio dette/revenus
        debt_ratio = features.get('debtToIncomeRatio', 0)
        if debt_ratio > 0.4:
            factors.append({
                'name': 'Ratio dette/revenus élevé',
                'value': debt_ratio,
                'impact': 'negative'
            })
        elif debt_ratio < 0.2:
            factors.append({
                'name': 'Ratio dette/revenus faible',
                'value': debt_ratio,
                'impact': 'positive'
            })
        
        # Analyse de la stabilité de l'emploi
        employment_stability = features.get('employmentStability', 0)
        if employment_stability >= 8:
            factors.append({
                'name': 'Stabilité de l\'emploi excellente',
                'value': employment_stability,
                'impact': 'positive'
            })
        elif employment_stability <= 3:
            factors.append({
                'name': 'Stabilité de l\'emploi faible',
                'value': employment_stability,
                'impact': 'negative'
            })
        
        # Analyse des revenus
        monthly_income = features.get('monthlyIncome', 0)
        if monthly_income >= 5000:
            factors.append({
                'name': 'Revenus élevés',
                'value': monthly_income,
                'impact': 'positive'
            })
        elif monthly_income <= 1500:
            factors.append({
                'name': 'Revenus faibles',
                'value': monthly_income,
                'impact': 'negative'
            })
        
        return factors
    
    def retrain(self, training_data):
        """Réentraînement du modèle"""
        try:
            # Préparation des données d'entraînement
            X, y = self._prepare_training_data(training_data)
            
            # Division des données
            X_train, X_test, y_train, y_test = train_test_split(
                X, y, test_size=0.2, random_state=42
            )
            
            # Normalisation
            self.scaler = StandardScaler()
            X_train_scaled = self.scaler.fit_transform(X_train)
            X_test_scaled = self.scaler.transform(X_test)
            
            # Entraînement du modèle
            self.model = RandomForestClassifier(
                n_estimators=100,
                max_depth=10,
                random_state=42
            )
            self.model.fit(X_train_scaled, y_train)
            
            # Évaluation
            y_pred = self.model.predict(X_test_scaled)
            y_pred_proba = self.model.predict_proba(X_test_scaled)[:, 1]
            
            metrics = {
                'accuracy': accuracy_score(y_test, y_pred),
                'auc': roc_auc_score(y_test, y_pred_proba),
                'classification_report': classification_report(y_test, y_pred, output_dict=True)
            }
            
            # Sauvegarde du modèle
            self._save_model()
            
            # Mise à jour de la version
            self.model_version = datetime.now().strftime('%Y%m%d_%H%M%S')
            
            return {
                'metrics': metrics,
                'version': self.model_version
            }
            
        except Exception as e:
            logger.error(f"Erreur lors du réentraînement: {str(e)}")
            raise e
    
    def _prepare_training_data(self, training_data):
        """Préparation des données d'entraînement"""
        # Ici vous devez adapter selon votre format de données
        # Ceci est un exemple basique
        df = pd.DataFrame(training_data)
        
        # Extraction des caractéristiques
        X = df[self.feature_names]
        y = df['target']  # Supposons que 'target' est la colonne cible
        
        return X.values, y.values
    
    def _save_model(self):
        """Sauvegarde du modèle"""
        os.makedirs(self.model_path, exist_ok=True)
        
        joblib.dump(self.model, os.path.join(self.model_path, 'random_forest_model.pkl'))
        joblib.dump(self.scaler, os.path.join(self.model_path, 'scaler.pkl'))
        joblib.dump(self.feature_names, os.path.join(self.model_path, 'feature_names.pkl'))
        
        logger.info("Modèle sauvegardé avec succès")
    
    def get_model_info(self):
        """Informations sur le modèle"""
        return {
            'version': self.model_version,
            'loaded': self.is_loaded(),
            'features': self.feature_names,
            'model_type': 'RandomForest',
            'last_updated': datetime.now().isoformat()
        }
    
    def is_loaded(self):
        """Vérification si le modèle est chargé"""
        return self.model is not None