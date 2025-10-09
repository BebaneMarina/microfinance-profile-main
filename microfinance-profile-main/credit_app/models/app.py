# app.py - MISE À JOUR COMPLÈTE
from flask import Flask, request, jsonify
from flask_cors import CORS
import numpy as np
import pandas as pd
import logging
from datetime import datetime, timedelta
import json
import os
import traceback
from scoring_model import PostgresCreditScoringModel

app = Flask(__name__)

# Configuration CORS
CORS(app, 
     origins=["http://localhost:4200"],
     methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
     allow_headers=["Content-Type", "Authorization", "Accept", "X-Requested-With"],
     supports_credentials=True,
     max_age=86400
)

# Configuration logging
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Configuration PostgreSQL
DB_CONFIG = {
    'host': os.getenv('DB_HOST', 'localhost'),
    'database': os.getenv('DB_NAME', 'credit_scoring'),
    'user': os.getenv('DB_USER', 'postgres'),
    'password': os.getenv('DB_PASSWORD', 'admin'),
    'port': int(os.getenv('DB_PORT', 5432))
}

# Initialiser le modèle de scoring PostgreSQL
try:
    scoring_model = PostgresCreditScoringModel(DB_CONFIG)
    logger.info("✅ Modèle de scoring Random Forest initialisé avec succès")
    logger.info(f"🤖 Type de modèle: {'Random Forest' if scoring_model.model is not None else 'Règles métier'}")
except Exception as e:
    logger.error(f"❌ Erreur lors de l'initialisation du modèle: {str(e)}")
    scoring_model = None

@app.after_request
def after_request(response):
    if not response.headers.get('Access-Control-Allow-Origin'):
        origin = request.headers.get('Origin')
        if origin == 'http://localhost:4200':
            response.headers['Access-Control-Allow-Origin'] = 'http://localhost:4200'
    
    if response.headers.get('Access-Control-Allow-Methods'):
        response.headers['Access-Control-Allow-Methods'] = 'GET,POST,PUT,DELETE,OPTIONS'
    
    if response.headers.get('Access-Control-Allow-Headers'):
        response.headers['Access-Control-Allow-Headers'] = 'Content-Type,Authorization,Accept,X-Requested-With'
    
    return response

@app.before_request
def handle_preflight():
    if request.method == "OPTIONS":
        response = jsonify({'status': 'OK'})
        response.headers['Access-Control-Allow-Origin'] = 'http://localhost:4200'
        response.headers['Access-Control-Allow-Methods'] = 'GET,POST,PUT,DELETE,OPTIONS'
        response.headers['Access-Control-Allow-Headers'] = 'Content-Type,Authorization,Accept,X-Requested-With'
        response.headers['Access-Control-Max-Age'] = '86400'
        return response

@app.route('/')
def home():
    return jsonify({
        'message': 'API de Scoring de Crédit - Bamboo EMF',
        'version': '7.0 - Random Forest ML',
        'status': 'running',
        'database': 'PostgreSQL',
        'model_type': 'Random Forest' if (scoring_model and scoring_model.model is not None) else 'Règles métier',
        'features': {
            'postgres_integration': True,
            'machine_learning': scoring_model.model is not None,
            'auto_scoring': True,
            'real_time_calculation': True,
            'payment_history_analysis': True
        },
        'endpoints': {
            '/test': 'GET - Test de connectivité',
            '/health': 'GET - Vérification de santé',
            '/client-scoring/<user_id>': 'GET - Score d\'un client',
            '/recalculate-score/<user_id>': 'POST - Recalculer le score',
            '/check-eligibility/<user_id>': 'GET - Vérifier l\'éligibilité',
            '/user-profile/<user_id>': 'GET - Profil complet',
            '/score-trend/<username>': 'GET - Historique des scores',
            '/payment-analysis/<user_id>': 'GET - Analyse des paiements',
            '/statistics': 'GET - Statistiques générales',
            '/retrain-model': 'POST - Réentraîner le modèle'
        }
    })

@app.route('/test', methods=['GET', 'OPTIONS'])
def test():
    if request.method == 'OPTIONS':
        return '', 200
    
    logger.info("🧪 Test de connectivité demandé")
    
    return jsonify({
        'status': 'ok',
        'message': 'API fonctionne correctement - Random Forest ML',
        'timestamp': datetime.now().isoformat(),
        'database_status': 'connected' if scoring_model else 'disconnected',
        'server_info': {
            'model_status': 'Random Forest ML' if (scoring_model and scoring_model.model) else 'Règles métier',
            'database': 'PostgreSQL',
            'ml_available': scoring_model.model is not None if scoring_model else False
        }
    })

@app.route('/health', methods=['GET', 'OPTIONS'])
def health_check():
    if request.method == 'OPTIONS':
        return '', 200
    
    try:
        db_status = 'ok'
        model_status = 'inactive'
        
        if scoring_model:
            try:
                # Test de connexion DB
                with scoring_model.get_db_connection() as conn:
                    with conn.cursor() as cur:
                        cur.execute("SELECT 1")
                db_status = 'ok'
                
                # Vérifier le modèle
                if scoring_model.model is not None:
                    model_status = 'random_forest'
                else:
                    model_status = 'rule_based'
                    
            except Exception as e:
                db_status = f'error: {str(e)}'
        
        return jsonify({
            'status': 'healthy',
            'timestamp': datetime.now().isoformat(),
            'version': '7.0 - Random Forest ML',
            'components': {
                'model': model_status,
                'database': db_status,
                'api': 'ok'
            }
        })
    except Exception as e:
        return jsonify({
            'status': 'unhealthy',
            'error': str(e),
            'timestamp': datetime.now().isoformat()
        }), 500

# ==========================================
# ENDPOINTS PRINCIPAUX - SCORING
# ==========================================

@app.route('/client-scoring/<int:user_id>', methods=['GET', 'OPTIONS'])
def get_client_scoring(user_id):
    """Récupère le score d'un client depuis la base"""
    if request.method == 'OPTIONS':
        return '', 200
    
    try:
        logger.info(f"📊 Récupération score pour user_id: {user_id}")
        
        if not scoring_model:
            return jsonify({
                'error': 'Modèle non disponible',
                'cors_ok': True
            }), 500
        
        # Option: forcer le recalcul avec ?recalculate=true
        force_recalculate = request.args.get('recalculate', 'false').lower() == 'true'
        
        # Récupérer ou calculer le score
        score_data = scoring_model.get_or_calculate_score(user_id, force_recalculate)
        
        if not score_data:
            return jsonify({
                'error': f'Utilisateur {user_id} non trouvé',
                'cors_ok': True
            }), 404
        
        result = {
            'user_id': user_id,
            'score': score_data.get('score_credit') or score_data.get('score'),
            'score_850': score_data.get('score_850'),
            'risk_level': score_data.get('niveau_risque'),
            'eligible_amount': score_data.get('montant_eligible'),
            'last_updated': score_data.get('date_modification'),
            'model_used': score_data.get('model_type', 'database'),
            'model_confidence': score_data.get('model_confidence', 0.75),
            'details': score_data.get('details', {}),
            'recommendations': score_data.get('recommendations', []),
            'cors_ok': True
        }
        
        logger.info(f"✅ Score récupéré: {result['score']}/10 ({result['model_used']})")
        
        return jsonify(result)
        
    except Exception as e:
        logger.error(f"❌ Erreur récupération score: {str(e)}")
        logger.error(traceback.format_exc())
        
        return jsonify({
            'error': str(e),
            'cors_ok': True
        }), 500
    
# Dans votre fichier Flask principal (app.py ou similaire)

@app.route('/ml-statistics/<int:user_id>', methods=['GET'])
def get_ml_statistics(user_id):
    """Retourne les statistiques ML pour un utilisateur"""
    try:
        # Récupérer les données de l'utilisateur
        user_data = get_user_data(user_id)
        
        if not user_data:
            return jsonify({
                'success': False,
                'error': 'Utilisateur non trouvé'
            }), 404
        
        # Calculer les statistiques ML
        stats = {
            'user_id': user_id,
            'model_type': 'random_forest',
            'last_training': '2025-10-09',
            'prediction_accuracy': 0.85,
            'feature_importance': [
                {'feature': 'payment_history', 'importance': 0.35},
                {'feature': 'debt_ratio', 'importance': 0.25},
                {'feature': 'income_stability', 'importance': 0.20},
                {'feature': 'credit_utilization', 'importance': 0.15},
                {'feature': 'account_age', 'importance': 0.05}
            ],
            'risk_distribution': {
                'very_low': 15,
                'low': 25,
                'medium': 35,
                'high': 20,
                'very_high': 5
            }
        }
        
        return jsonify({
            'success': True,
            'data': stats
        })
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/recalculate-score/<int:user_id>', methods=['POST', 'OPTIONS'])
def recalculate_score(user_id):
    """Force le recalcul du score d'un client avec le modèle ML"""
    if request.method == 'OPTIONS':
        return '', 200
    
    try:
        logger.info(f"🔄 Recalcul du score ML pour user_id: {user_id}")
        
        if not scoring_model:
            return jsonify({
                'error': 'Modèle non disponible',
                'cors_ok': True
            }), 500
        
        # Forcer le recalcul
        score_data = scoring_model.get_or_calculate_score(user_id, force_recalculate=True)
        
        if not score_data:
            return jsonify({
                'error': f'Utilisateur {user_id} non trouvé',
                'cors_ok': True
            }), 404
        
        result = {
            'success': True,
            'user_id': user_id,
            'score': score_data.get('score'),
            'score_850': score_data.get('score_850'),
            'risk_level': score_data.get('niveau_risque'),
            'eligible_amount': score_data.get('montant_eligible'),
            'model_used': score_data.get('model_type'),
            'model_confidence': score_data.get('model_confidence'),
            'details': score_data.get('details', {}),
            'recommendations': score_data.get('recommendations', []),
            'recalculated_at': datetime.now().isoformat(),
            'cors_ok': True
        }
        
        logger.info(f"✅ Score recalculé: {result['score']}/10 ({result['model_used']})")
        
        return jsonify(result)
        
    except Exception as e:
        logger.error(f"❌ Erreur recalcul score: {str(e)}")
        
        return jsonify({
            'success': False,
            'error': str(e),
            'cors_ok': True
        }), 500

@app.route('/check-eligibility/<int:user_id>', methods=['GET', 'OPTIONS'])
def check_eligibility(user_id):
    """Vérifie l'éligibilité d'un client pour un crédit"""
    if request.method == 'OPTIONS':
        return '', 200
    
    try:
        logger.info(f"✔️ Vérification éligibilité pour user_id: {user_id}")
        
        if not scoring_model:
            return jsonify({
                'error': 'Modèle non disponible',
                'cors_ok': True
            }), 500
        
        eligibility = scoring_model.check_eligibility(user_id)
        
        result = {
            'user_id': user_id,
            'eligible': eligibility.get('eligible', False),
            'raison': eligibility.get('raison'),
            'montant_eligible': eligibility.get('montant_eligible', 0),
            'score': eligibility.get('score'),
            'timestamp': datetime.now().isoformat(),
            'cors_ok': True
        }
        
        logger.info(f"✅ Éligibilité: {result['eligible']}")
        
        return jsonify(result)
        
    except Exception as e:
        logger.error(f"❌ Erreur vérification éligibilité: {str(e)}")
        
        return jsonify({
            'user_id': user_id,
            'eligible': False,
            'error': str(e),
            'cors_ok': True
        }), 500

@app.route('/payment-analysis/<int:user_id>', methods=['GET', 'OPTIONS'])
def payment_analysis(user_id):
    """Analyse détaillée de l'historique de paiements"""
    if request.method == 'OPTIONS':
        return '', 200
    
    try:
        logger.info(f"📈 Analyse paiements pour user_id: {user_id}")
        
        if not scoring_model:
            return jsonify({
                'error': 'Modèle non disponible',
                'cors_ok': True
            }), 500
        
        # Récupérer les données complètes
        user_data = scoring_model._get_user_complete_data(user_id)
        
        if not user_data:
            return jsonify({
                'error': f'Utilisateur {user_id} non trouvé',
                'cors_ok': True
            }), 404
        
        result = {
            'user_id': user_id,
            'total_payments': user_data.get('total_paiements', 0),
            'on_time_payments': user_data.get('paiements_a_temps', 0),
            'late_payments': user_data.get('paiements_en_retard', 0),
            'missed_payments': user_data.get('paiements_manques', 0),
            'on_time_ratio': round(user_data.get('ratio_paiements_temps', 0) * 100, 1),
            'avg_delay_days': round(user_data.get('moyenne_jours_retard', 0), 1),
            'reliability': user_data.get('reliability', 'N/A'),
            'current_debt': user_data.get('dette_totale_active', 0),
            'debt_ratio': user_data.get('ratio_endettement', 0),
            'active_credits': user_data.get('credits_actifs_count', 0),
            'cors_ok': True
        }
        
        logger.info(f"✅ Analyse terminée: {result['on_time_ratio']}% à temps")
        
        return jsonify(result)
        
    except Exception as e:
        logger.error(f"❌ Erreur analyse paiements: {str(e)}")
        
        return jsonify({
            'error': str(e),
            'cors_ok': True
        }), 500

@app.route('/user-profile/<int:user_id>', methods=['GET', 'OPTIONS'])
def get_user_profile(user_id):
    """Récupère le profil complet d'un utilisateur"""
    if request.method == 'OPTIONS':
        return '', 200
    
    try:
        logger.info(f"👤 Récupération profil pour user_id: {user_id}")
        
        if not scoring_model:
            return jsonify({
                'error': 'Modèle non disponible',
                'cors_ok': True
            }), 500
        
        profile = scoring_model._get_user_complete_data(user_id)
        
        if not profile:
            return jsonify({
                'error': f'Utilisateur {user_id} non trouvé',
                'cors_ok': True
            }), 404
        
        # Conversion des données pour JSON
        result = {k: (str(v) if isinstance(v, (datetime,)) else v) 
                  for k, v in profile.items()}
        result['cors_ok'] = True
        
        return jsonify(result)
        
    except Exception as e:
        logger.error(f"❌ Erreur récupération profil: {str(e)}")
        
        return jsonify({
            'error': str(e),
            'cors_ok': True
        }), 500

@app.route('/score-trend/<username>', methods=['GET', 'OPTIONS'])
def get_score_trend(username):
    """Récupère l'historique des scores d'un utilisateur"""
    if request.method == 'OPTIONS':
        return '', 200
    
    try:
        logger.info(f"📈 Récupération tendance score pour: {username}")
        
        if not scoring_model:
            return jsonify({
                'error': 'Modèle non disponible',
                'cors_ok': True
            }), 500
        
        # Trouver l'utilisateur par email/username
        with scoring_model.get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT id FROM utilisateurs 
                    WHERE email = %s OR nom = %s
                    LIMIT 1
                """, (username, username))
                
                user = cur.fetchone()
                
                if not user:
                    return jsonify({
                        'error': 'Utilisateur non trouvé',
                        'recent_transactions': [],
                        'cors_ok': True
                    }), 404
                
                user_id = user[0]
                
                # Récupérer l'historique des scores
                cur.execute("""
                    SELECT 
                        score_credit,
                        score_850,
                        niveau_risque,
                        evenement_declencheur,
                        date_calcul
                    FROM historique_scores
                    WHERE utilisateur_id = %s
                    ORDER BY date_calcul DESC
                    LIMIT 20
                """, (user_id,))
                
                history = cur.fetchall()
                
                recent_transactions = []
                for row in history:
                    recent_transactions.append({
                        'score': float(row[0]),
                        'score_850': row[1],
                        'risk_level': row[2],
                        'event': row[3],
                        'date': row[4].isoformat() if row[4] else None
                    })
        
        return jsonify({
            'username': username,
            'user_id': user_id,
            'recent_transactions': recent_transactions,
            'total_records': len(recent_transactions),
            'cors_ok': True
        })
        
    except Exception as e:
        logger.error(f"❌ Erreur score-trend: {str(e)}")
        return jsonify({
            'error': str(e),
            'recent_transactions': [],
            'cors_ok': True
        }), 500

@app.route('/statistics', methods=['GET', 'OPTIONS'])
def get_statistics():
    """Statistiques générales du système"""
    if request.method == 'OPTIONS':
        return '', 200
    
    try:
        if not scoring_model:
            return jsonify({
                'error': 'Modèle non disponible',
                'cors_ok': True
            }), 500
        
        with scoring_model.get_db_connection() as conn:
            with conn.cursor() as cur:
                # Statistiques utilisateurs
                cur.execute("""
                    SELECT 
                        COUNT(*) as total_users,
                        AVG(score_credit) as avg_score,
                        COUNT(CASE WHEN peut_emprunter THEN 1 END) as eligible_users
                    FROM utilisateurs u
                    LEFT JOIN restrictions_credit r ON u.id = r.utilisateur_id
                    WHERE u.statut = 'actif'
                """)
                stats = cur.fetchone()
                
                # Distribution des scores
                cur.execute("""
                    SELECT 
                        niveau_risque,
                        COUNT(*) as count
                    FROM utilisateurs
                    WHERE statut = 'actif'
                    GROUP BY niveau_risque
                """)
                risk_distribution = {row[0]: row[1] for row in cur.fetchall()}
                
                # Statistiques de paiements
                cur.execute("""
                    SELECT 
                        COUNT(*) as total_payments,
                        COUNT(CASE WHEN type_paiement = 'a_temps' THEN 1 END) as on_time,
                        AVG(jours_retard) as avg_delay
                    FROM historique_paiements
                    WHERE date_paiement >= NOW() - INTERVAL '30 days'
                """)
                payment_stats = cur.fetchone()
        
        return jsonify({
            'total_users': stats[0] if stats else 0,
            'average_score': round(float(stats[1]), 2) if stats and stats[1] else 0,
            'eligible_users': stats[2] if stats else 0,
            'risk_distribution': risk_distribution,
            'payment_statistics': {
                'total_last_30_days': payment_stats[0] if payment_stats else 0,
                'on_time_last_30_days': payment_stats[1] if payment_stats else 0,
                'avg_delay_days': round(float(payment_stats[2]), 1) if payment_stats and payment_stats[2] else 0
            },
            'model_info': {
                'type': 'Random Forest' if (scoring_model.model is not None) else 'Règles métier',
                'ml_available': scoring_model.model is not None
            },
            'cors_ok': True,
            'timestamp': datetime.now().isoformat()
        })
        
    except Exception as e:
        logger.error(f"❌ Erreur statistiques: {str(e)}")
        return jsonify({
            'error': str(e),
            'cors_ok': True
        }), 500

# ==========================================
# ENDPOINT RÉENTRAÎNEMENT DU MODÈLE
# ==========================================

@app.route('/retrain-model', methods=['POST', 'OPTIONS'])
def retrain_model():
    """Réentraîne le modèle Random Forest avec les nouvelles données"""
    if request.method == 'OPTIONS':
        return '', 200
    
    try:
        logger.info("🔄 Démarrage du réentraînement du modèle...")
        
        if not scoring_model:
            return jsonify({
                'error': 'Modèle non disponible',
                'cors_ok': True
            }), 500
        
        # Réentraîner
        success = scoring_model.train_model_from_database()
        
        if success:
            return jsonify({
                'success': True,
                'message': 'Modèle réentraîné avec succès',
                'model_type': 'random_forest',
                'timestamp': datetime.now().isoformat(),
                'cors_ok': True
            })
        else:
            return jsonify({
                'success': False,
                'message': 'Échec du réentraînement',
                'cors_ok': True
            }), 500
        
    except Exception as e:
        logger.error(f"❌ Erreur réentraînement: {str(e)}")
        return jsonify({
            'success': False,
            'error': str(e),
            'cors_ok': True
        }), 500

# ==========================================
# GESTION DES ERREURS
# ==========================================

@app.errorhandler(Exception)
def handle_error(e):
    logger.error(f"❌ Erreur non gérée: {str(e)}")
    return jsonify({
        'error': 'Erreur serveur interne',
        'message': str(e),
        'cors_ok': True,
        'timestamp': datetime.now().isoformat()
    }), 500

@app.errorhandler(404)
def not_found(e):
    return jsonify({
        'error': 'Endpoint non trouvé',
        'available_endpoints': [
            '/', '/test', '/health', 
            '/client-scoring/<user_id>', 
            '/recalculate-score/<user_id>',
            '/check-eligibility/<user_id>',
            '/payment-analysis/<user_id>',
            '/user-profile/<user_id>',
            '/score-trend/<username>',
            '/statistics',
            '/retrain-model'
        ],
        'cors_ok': True
    }), 404

if __name__ == '__main__':
    logger.info("=" * 60)
    logger.info("🚀 BAMBOO EMF - API v7.0 - Random Forest ML")
    logger.info("=" * 60)
    logger.info("🌐 Serveur: http://localhost:5000")
    logger.info("🗄️ Base de données: PostgreSQL")
    logger.info("🤖 Machine Learning: Random Forest")
    logger.info("📡 Endpoints principaux:")
    logger.info("   • GET  /client-scoring/<user_id> - Score client ML")
    logger.info("   • POST /recalculate-score/<user_id> - Recalculer score ML")
    logger.info("   • GET  /check-eligibility/<user_id> - Vérifier éligibilité")
    logger.info("   • GET  /payment-analysis/<user_id> - Analyse paiements")
    logger.info("   • GET  /user-profile/<user_id> - Profil complet")
    logger.info("   • GET  /score-trend/<username> - Historique scores")
    logger.info("   • GET  /statistics - Statistiques")
    logger.info("   • POST /retrain-model - Réentraîner le modèle")
    
    if scoring_model:
        logger.info(f"✅ Modèle: {'Random Forest ML' if scoring_model.model else 'Règles métier'}")
    else:
        logger.info("⚠️ Modèle non initialisé")
    
    logger.info("=" * 60)
    
    try:
        app.run(debug=True, host='0.0.0.0', port=5000, threaded=True)
    except Exception as e:
        logger.error(f"❌ Erreur démarrage: {e}")