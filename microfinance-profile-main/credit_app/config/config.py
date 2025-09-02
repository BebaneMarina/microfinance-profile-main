# config/config.py
import os

class Config:
    """Classe de configuration pour l'application de scoring de crédit"""
    
    # Mode debug
    DEBUG = os.getenv('DEBUG', 'False').lower() == 'true'
    
    # Configuration du modèle
    MODEL_VERSION = os.getenv('MODEL_VERSION', '1.0.0')
    MODEL_PATH = os.getenv('MODEL_PATH', 'models/trained_model.pkl')
    
    # Configuration PostgreSQL
    DATABASE_URL = os.getenv('DATABASE_URL', 'postgresql://postgres:admin@localhost:5432/credit_scoring')
    SQLALCHEMY_DATABASE_URI = DATABASE_URL
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    
    # Configuration de l'API
    API_RATE_LIMIT = int(os.getenv('API_RATE_LIMIT', '100'))
    
    # Configuration du logging
    LOG_LEVEL = os.getenv('LOG_LEVEL', 'INFO')
    
    # Configuration de l'ingénierie des caractéristiques
    FEATURE_SCALING = os.getenv('FEATURE_SCALING', 'standard')
    
    # Seuils du modèle
    DEFAULT_THRESHOLD = float(os.getenv('DEFAULT_THRESHOLD', '0.5'))
    
    # Configuration de sécurité
    SECRET_KEY = os.getenv('SECRET_KEY', 'votre-cle-secrete-changez-la')
    
    # Configuration Redis (pour la mise en cache si nécessaire)
    REDIS_URL = os.getenv('REDIS_URL', 'redis://localhost:6379/0')
    
    # Configuration du modèle ML
    MODEL_RETRAIN_INTERVAL = int(os.getenv('MODEL_RETRAIN_INTERVAL', '24'))  # heures
    MIN_TRAINING_SAMPLES = int(os.getenv('MIN_TRAINING_SAMPLES', '1000'))
    
    # Configuration des fonctionnalités
    ENABLE_MODEL_RETRAINING = os.getenv('ENABLE_MODEL_RETRAINING', 'True').lower() == 'true'
    ENABLE_FEATURE_MONITORING = os.getenv('ENABLE_FEATURE_MONITORING', 'True').lower() == 'true'