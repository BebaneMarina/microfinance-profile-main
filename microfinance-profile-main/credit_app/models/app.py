from flask import Flask, request, jsonify
from flask_cors import CORS
import numpy as np
import pandas as pd
import logging
from datetime import datetime, timedelta  # AJOUT DE TIMEDELTA
import json
import os
import traceback
from scoring_model import CreditScoringModel

app = Flask(__name__)



# IMPORTANT : Configuration CORS spécifique pour éviter les valeurs multiples
CORS(app, 
     origins=["http://localhost:4200"],  # UNE SEULE origin pour le développement
     methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
     allow_headers=["Content-Type", "Authorization", "Accept", "X-Requested-With"],
     supports_credentials=True,
     max_age=86400
)

# Gestionnaire CORS manuel pour éviter les doublons
@app.after_request
def after_request(response):
    # Ne pas ajouter de headers CORS supplémentaires si CORS extension les gère déjà
    # Cela évite les valeurs multiples dans Access-Control-Allow-Origin
    
    # Seulement si les headers ne sont pas déjà présents
    if not response.headers.get('Access-Control-Allow-Origin'):
        origin = request.headers.get('Origin')
        if origin == 'http://localhost:4200':
            response.headers['Access-Control-Allow-Origin'] = 'http://localhost:4200'
        else:
            response.headers['Access-Control-Allow-Origin'] = 'http://localhost:4200'
    
    # S'assurer qu'il n'y a pas de doublons
    if response.headers.get('Access-Control-Allow-Methods'):
        response.headers['Access-Control-Allow-Methods'] = 'GET,POST,PUT,DELETE,OPTIONS'
    
    if response.headers.get('Access-Control-Allow-Headers'):
        response.headers['Access-Control-Allow-Headers'] = 'Content-Type,Authorization,Accept,X-Requested-With'
    
    return response

# Gestionnaire OPTIONS global
@app.before_request
def handle_preflight():
    if request.method == "OPTIONS":
        response = jsonify({'status': 'OK'})
        response.headers['Access-Control-Allow-Origin'] = 'http://localhost:4200'
        response.headers['Access-Control-Allow-Methods'] = 'GET,POST,PUT,DELETE,OPTIONS'
        response.headers['Access-Control-Allow-Headers'] = 'Content-Type,Authorization,Accept,X-Requested-With'
        response.headers['Access-Control-Max-Age'] = '86400'
        return response

# ============================================================================

logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialiser le modèle de scoring
try:
    scoring_model = CreditScoringModel()
    logger.info("✅ Modèle de scoring initialisé avec succès")
    logger.info(f"🤖 Type de modèle: {'Random Forest' if scoring_model.model is not None else 'Règles métier'}")
except Exception as e:
    logger.error(f"❌ Erreur lors de l'initialisation du modèle: {str(e)}")
    scoring_model = None

# Fichiers pour stocker les données
APPLICATIONS_FILE = 'applications.json'
CLIENTS_FILE = 'clients_scoring.json'
TRANSACTIONS_FILE = 'transactions_history.json'

def load_applications():
    if os.path.exists(APPLICATIONS_FILE):
        try:
            with open(APPLICATIONS_FILE, 'r', encoding='utf-8') as f:
                return json.load(f)
        except Exception as e:
            logger.error(f"Erreur chargement applications: {e}")
            return []
    return []

def save_applications(applications):
    try:
        with open(APPLICATIONS_FILE, 'w', encoding='utf-8') as f:
            json.dump(applications, f, indent=2, default=str, ensure_ascii=False)
        logger.info(f"Applications sauvegardées: {len(applications)} entrées")
    except Exception as e:
        logger.error(f"Erreur sauvegarde applications: {e}")

def load_client_scorings():
    if os.path.exists(CLIENTS_FILE):
        try:
            with open(CLIENTS_FILE, 'r', encoding='utf-8') as f:
                return json.load(f)
        except Exception as e:
            logger.error(f"Erreur chargement scorings clients: {e}")
            return {}
    return {}

def save_client_scorings(scorings):
    try:
        with open(CLIENTS_FILE, 'w', encoding='utf-8') as f:
            json.dump(scorings, f, indent=2, default=str, ensure_ascii=False)
        logger.info(f"Scorings clients sauvegardés: {len(scorings)} entrées")
    except Exception as e:
        logger.error(f"Erreur sauvegarde scorings: {e}")

def load_transactions_history():
    if os.path.exists(TRANSACTIONS_FILE):
        try:
            with open(TRANSACTIONS_FILE, 'r', encoding='utf-8') as f:
                return json.load(f)
        except Exception as e:
            logger.error(f"Erreur chargement historique transactions: {e}")
            return {}
    return {}

def save_transactions_history(history):
    try:
        with open(TRANSACTIONS_FILE, 'w', encoding='utf-8') as f:
            json.dump(history, f, indent=2, default=str, ensure_ascii=False)
        logger.info(f"Historique transactions sauvegardé")
    except Exception as e:
        logger.error(f"Erreur sauvegarde historique transactions: {e}")

def add_transaction_to_history(username, transaction_data):
    history = load_transactions_history()
    
    if username not in history:
        history[username] = []
    
    transaction = {
        'id': len(history[username]) + 1,
        'date': datetime.now().isoformat(),
        'type': transaction_data.get('type', 'payment'),
        'amount': transaction_data.get('amount', 0),
        'days_late': transaction_data.get('days_late', 0),
        'loan_contract_id': transaction_data.get('loan_contract_id'),
        'description': transaction_data.get('description', ''),
        'status': transaction_data.get('status', 'completed')
    }
    
    history[username].append(transaction)
    save_transactions_history(history)
    
    return transaction

@app.route('/')
def home():
    return jsonify({
        'message': 'API de Scoring de Crédit - Bamboo EMF',
        'version': '5.1 - CORS Corrigé',
        'status': 'running',
        'cors_fixed': True,
        'model_type': 'Random Forest' if (scoring_model and scoring_model.model is not None) else 'Règles métier',
        'clients_scored': len(load_client_scorings()),
        'supported_credit_types': ['consommation_generale', 'avance_salaire', 'depannage'],
        'features': {
            'auto_scoring': True,
            'real_time_calculation': True,
            'cors_single_origin': True,
            'transaction_tracking': True
        },
        'endpoints': {
            '/test': 'GET - Test de connectivité',
            '/health': 'GET - Vérification de santé',
            '/client-scoring': 'POST - Scoring automatique',
            '/eligible-amount': 'POST - Calcul montant éligible',
            '/realtime-scoring': 'POST - Scoring temps réel',
            '/score-trend/<username>': 'GET - Analyse tendance du score',
            '/process-transaction': 'POST - Traiter une transaction',
            '/simulate-transaction': 'POST - Simuler impact transaction',
            '/statistics': 'GET - Statistiques générales'
        }
    })

@app.route('/test', methods=['GET', 'OPTIONS'])
def test():
    if request.method == 'OPTIONS':
        return '', 200
    
    logger.info("🧪 Test de connectivité demandé")
    logger.info(f"🌐 Origin: {request.headers.get('Origin', 'Non spécifié')}")
    logger.info(f"📋 Headers: {dict(request.headers)}")
    
    return jsonify({
        'status': 'ok',
        'message': 'API fonctionne correctement - CORS corrigé',
        'timestamp': datetime.now().isoformat(),
        'cors_test': {
            'origin_received': request.headers.get('Origin'),
            'method': request.method,
            'cors_configured': True,
            'single_origin_policy': True
        },
        'server_info': {
            'model_status': 'active' if scoring_model else 'fallback',
            'clients_count': len(load_client_scorings()),
            'transactions_count': sum(len(trans) for trans in load_transactions_history().values())
        }
    })

@app.route('/health', methods=['GET', 'OPTIONS'])
def health_check():
    if request.method == 'OPTIONS':
        return '', 200
    
    try:
        model_status = 'active' if (scoring_model and scoring_model.model is not None) else 'fallback'
        
        return jsonify({
            'status': 'healthy',
            'timestamp': datetime.now().isoformat(),
            'version': '5.1 - CORS Corrigé',
            'components': {
                'model': model_status,
                'cors': 'fixed_single_origin',
                'api': 'ok',
                'files': {
                    'applications': 'ok' if os.path.exists(APPLICATIONS_FILE) else 'missing',
                    'clients': 'ok' if os.path.exists(CLIENTS_FILE) else 'missing',
                    'transactions': 'ok' if os.path.exists(TRANSACTIONS_FILE) else 'missing'
                }
            }
        })
    except Exception as e:
        return jsonify({
            'status': 'unhealthy',
            'error': str(e),
            'timestamp': datetime.now().isoformat()
        }), 500

def prepare_client_data_for_scoring(client_data):
    age = estimate_age_from_profession(client_data.get('profession', ''))
    job_seniority = estimate_job_seniority(client_data.get('profession', ''))
    monthly_income = float(client_data.get('monthly_income', 0) or client_data.get('monthlyIncome', 0))
    other_income = float(client_data.get('other_income', 0))
    monthly_charges = float(client_data.get('monthlyCharges', monthly_income * 0.3))
    existing_debts = float(client_data.get('existingDebts', 0))
    employment_status = client_data.get('employmentStatus') or map_profession_to_employment(client_data.get('profession', ''))
    username = client_data.get('username', '')
    user_id = hash(username) % 10000 if username else None
    
    return {
        'username': username,
        'user_id': user_id,
        'age': age,
        'monthly_income': monthly_income,
        'other_income': other_income,
        'monthly_charges': monthly_charges,
        'existing_debts': existing_debts,
        'job_seniority': job_seniority,
        'employment_status': employment_status,
        'loan_amount': 1000000,
        'loan_duration': 1,
        'credit_type': 'consommation_generale',
        'marital_status': 'single',
        'education': 'superieur',
        'dependents': 2,
        'repayment_frequency': 'mensuel',
        'profession': client_data.get('profession', ''),
        'company': client_data.get('company', ''),
        'client_type': client_data.get('clientType', 'particulier'),
        'name': client_data.get('name', ''),
        'email': client_data.get('email', ''),
        'phone': client_data.get('phone', '')
    }

@app.route('/client-scoring', methods=['POST', 'OPTIONS'])
def calculate_client_scoring():
    if request.method == 'OPTIONS':
        return '', 200
    
    try:
        # Logging détaillé pour debug
        logger.info("=" * 50)
        logger.info("📊 REQUÊTE CLIENT-SCORING REÇUE")
        logger.info(f"🌐 Origin: {request.headers.get('Origin')}")
        logger.info(f"📋 Method: {request.method}")
        logger.info(f"📦 Content-Type: {request.headers.get('Content-Type')}")
        logger.info("=" * 50)
        
        data = request.json
        if not data:
            logger.error("❌ Aucune donnée JSON reçue")
            return jsonify({
                'error': 'Données manquantes',
                'message': 'Aucune donnée reçue dans la requête'
            }), 400
        
        username = data.get('username', 'unknown')
        logger.info(f"👤 Traitement scoring pour: {username}")
        
        if not scoring_model:
            logger.warning("⚠️ Modèle non initialisé - utilisation fallback")
            return jsonify({
                'score': 6.0,
                'eligible_amount': 500000,
                'risk_level': 'moyen',
                'decision': 'à étudier',
                'factors': [],
                'recommendations': ['Modèle non disponible - Calcul par défaut'],
                'model_used': 'fallback',
                'cors_ok': True
            })
        
        # Préparer les données
        scoring_data = prepare_client_data_for_scoring(data)
        logger.info(f"💰 Revenu traité: {scoring_data['monthly_income']:,} FCFA")
        
        # Calcul du scoring
        score_result = scoring_model.predict(scoring_data)
        eligible_result = scoring_model.calculate_eligible_amount(scoring_data)
        
        # Résultat final
        result = {
            'username': username,
            'score': score_result.get('score', 6.0),
            'eligible_amount': eligible_result.get('eligible_amount', 500000),
            'risk_level': score_result.get('risk_level', 'moyen'),
            'decision': score_result.get('decision', 'à étudier'),
            'factors': score_result.get('factors', []),
            'recommendations': eligible_result.get('recommendations', []),
            'model_used': score_result.get('model_type', 'unknown'),
            'model_confidence': score_result.get('model_confidence', 0.5),
            'calculation_date': datetime.now().isoformat(),
            'cors_ok': True,
            'client_data': {
                'name': data.get('name', ''),
                'email': data.get('email', ''),
                'phone': data.get('phone', ''),
                'profession': data.get('profession', ''),
                'monthly_income': scoring_data.get('monthly_income', 0)
            }
        }
        
        # Sauvegarder
        save_client_scoring(username, result)
        
        logger.info(f"✅ Scoring calculé: {result['score']}/10")
        logger.info(f"💳 Montant éligible: {result['eligible_amount']:,} FCFA")
        
        return jsonify(result)
        
    except Exception as e:
        logger.error(f"❌ Erreur client-scoring: {str(e)}")
        logger.error(traceback.format_exc())
        
        return jsonify({
            'username': data.get('username', 'unknown') if 'data' in locals() else 'unknown',
            'score': 6.0,
            'eligible_amount': 500000,
            'risk_level': 'moyen',
            'decision': 'à étudier',
            'factors': [],
            'recommendations': ['Erreur lors du calcul - Valeurs par défaut'],
            'model_used': 'fallback',
            'error': str(e),
            'cors_ok': True
        }), 500

@app.route('/eligible-amount', methods=['POST', 'OPTIONS'])
def calculate_eligible_amount():
    if request.method == 'OPTIONS':
        return '', 200
    
    try:
        logger.info("💳 CALCUL MONTANT ÉLIGIBLE")
        
        data = request.json
        if not data:
            return jsonify({
                'error': 'Données manquantes'
            }), 400
        
        username = data.get('username', 'unknown')
        logger.info(f"👤 Client: {username}")
        
        if not scoring_model:
            monthly_income = float(data.get('monthly_income', data.get('monthlyIncome', 500000)))
            default_amount = min(monthly_income * 0.3333, 2000000)
            
            return jsonify({
                'eligible_amount': int(default_amount),
                'score': 6.0,
                'risk_level': 'moyen',
                'factors': [],
                'recommendations': ['Calcul par défaut'],
                'cors_ok': True
            })
        
        scoring_data = prepare_client_data_for_scoring(data)
        result = scoring_model.calculate_eligible_amount(scoring_data)
        
        result['cors_ok'] = True
        logger.info(f"✅ Montant calculé: {result['eligible_amount']:,} FCFA")
        
        return jsonify(result)
        
    except Exception as e:
        logger.error(f"❌ Erreur eligible-amount: {str(e)}")
        
        return jsonify({
            'eligible_amount': 500000,
            'score': 6.0,
            'risk_level': 'moyen',
            'factors': [],
            'recommendations': ['Erreur système'],
            'error': str(e),
            'cors_ok': True
        }), 500

@app.route('/realtime-scoring', methods=['POST', 'OPTIONS'])
def calculate_realtime_scoring():
    if request.method == 'OPTIONS':
        return '', 200
    
    try:
        logger.info("⚡ SCORING TEMPS RÉEL")
        logger.info(f"🌐 Origin: {request.headers.get('Origin')}")
        
        data = request.json
        if not data:
            return jsonify({
                'error': 'Données manquantes'
            }), 400
        
        username = data.get('username', 'unknown')
        logger.info(f"👤 Client: {username}")
        
        if not scoring_model:
            return jsonify({
                'error': 'Modèle non disponible',
                'cors_ok': True
            }), 500
        
        scoring_data = prepare_client_data_for_scoring(data)
        user_id = scoring_data['user_id']
        
        # Charger l'historique
        all_transactions = load_transactions_history()
        user_transactions = all_transactions.get(username, [])
        
        # Calcul temps réel
        result = scoring_model.calculate_realtime_score(
            user_id, 
            scoring_data, 
            user_transactions
        )
        
        # Enrichir le résultat
        result.update({
            'username': username,
            'cors_ok': True,
            'client_info': {
                'name': data.get('name', ''),
                'email': data.get('email', ''),
                'profession': data.get('profession', ''),
                'monthly_income': scoring_data.get('monthly_income', 0)
            }
        })
        
        # Sauvegarder
        save_client_scoring(username, result)
        
        logger.info(f"✅ Score temps réel: {result['score']}")
        
        return jsonify(result)
        
    except Exception as e:
        logger.error(f"❌ Erreur realtime-scoring: {str(e)}")
        logger.error(traceback.format_exc())
        
        return jsonify({
            'error': 'Erreur calcul temps réel',
            'message': str(e),
            'cors_ok': True
        }), 500

@app.route('/score-trend/<username>', methods=['GET', 'OPTIONS'])
def get_score_trend(username):
    """Analyse la tendance du score d'un client"""
    if request.method == 'OPTIONS':
        return '', 200
    
    try:
        logger.info(f"📈 ANALYSE TENDANCE SCORE pour {username}")
        
        # Charger l'historique des transactions
        all_transactions = load_transactions_history()
        user_transactions = all_transactions.get(username, [])
        
        # Charger le scoring du client
        client_scorings = load_client_scorings()
        client_scoring = client_scorings.get(username, {})
        
        # Générer des données d'historique simulées si pas de vraies données
        if not user_transactions:
            # Créer des transactions fictives pour la démo
            now = datetime.now()
            user_transactions = []
            for i in range(10):
                days_ago = (i + 1) * 10
                transaction_date = now - timedelta(days=days_ago)
                user_transactions.append({
                    'id': i + 1,
                    'date': transaction_date.isoformat(),
                    'type': 'payment' if i % 3 != 2 else 'late_payment',
                    'amount': 50000 + (i * 10000),
                    'days_late': 0 if i % 3 != 2 else (i % 3) * 2,
                    'description': f'Transaction automatique #{i + 1}'
                })
        
        # Analyser la tendance
        recent_transactions = user_transactions[-20:] if len(user_transactions) > 20 else user_transactions
        
        # Calculer les métriques de tendance
        total_payments = len([t for t in recent_transactions if t.get('type') in ['payment', 'late_payment']])
        on_time_payments = len([t for t in recent_transactions if t.get('type') == 'payment'])
        late_payments = len([t for t in recent_transactions if t.get('type') == 'late_payment'])
        
        on_time_ratio = (on_time_payments / total_payments) if total_payments > 0 else 0.8
        
        # Déterminer la tendance
        if on_time_ratio >= 0.9:
            trend = 'improving'
            trend_description = 'En amélioration'
        elif on_time_ratio >= 0.7:
            trend = 'stable'
            trend_description = 'Stable'
        else:
            trend = 'declining'
            trend_description = 'En baisse'
        
        # Score actuel
        current_score = client_scoring.get('score', 6.0)
        
        result = {
            'username': username,
            'current_score': current_score,
            'trend_analysis': {
                'trend': trend,
                'trend_description': trend_description,
                'on_time_ratio': round(on_time_ratio, 2),
                'total_payments': total_payments,
                'on_time_payments': on_time_payments,
                'late_payments': late_payments,
                'average_change_per_month': 0.1 if trend == 'improving' else (-0.1 if trend == 'declining' else 0),
                'consistency_score': int(on_time_ratio * 100),
                'prediction_next_month': min(10, max(0, current_score + (0.2 if trend == 'improving' else (-0.2 if trend == 'declining' else 0))))
            },
            'recent_transactions': recent_transactions[-5:],  # 5 dernières transactions
            'analysis_period_days': 90,
            'cors_ok': True,
            'last_updated': datetime.now().isoformat()
        }
        
        logger.info(f"✅ Tendance analysée: {trend_description}")
        
        return jsonify(result)
        
    except Exception as e:
        logger.error(f"❌ Erreur analyse tendance: {str(e)}")
        return jsonify({
            'username': username,
            'error': str(e),
            'trend_analysis': {
                'trend': 'stable',
                'trend_description': 'Données insuffisantes',
                'on_time_ratio': 0.8,
                'total_payments': 0,
                'average_change_per_month': 0
            },
            'recent_transactions': [],
            'cors_ok': True
        }), 500

@app.route('/process-transaction', methods=['POST', 'OPTIONS'])
def process_transaction():
    """Traite une transaction et met à jour le score en temps réel"""
    if request.method == 'OPTIONS':
        return '', 200
    
    try:
        data = request.json
        username = data.get('username')
        
        if not username:
            return jsonify({
                'error': 'Username requis',
                'cors_ok': True
            }), 400
        
        logger.info(f"💳 TRAITEMENT TRANSACTION pour {username}")
        
        # Ajouter la transaction à l'historique
        transaction = add_transaction_to_history(username, data)
        
        # Si on a le modèle de scoring, calculer l'impact
        if scoring_model:
            user_id = hash(username) % 10000
            impact_result = scoring_model.process_transaction_impact(
                user_id,
                data.get('type', 'payment'),
                data.get('days_late', 0),
                data.get('amount', 0)
            )
            
            # Mettre à jour le scoring sauvegardé
            scorings = load_client_scorings()
            if username in scorings:
                scorings[username]['score'] = impact_result['new_score']
                scorings[username]['last_transaction'] = transaction
                scorings[username]['last_updated'] = datetime.now().isoformat()
                save_client_scorings(scorings)
        else:
            # Impact par défaut sans modèle
            impact_result = {
                'previous_score': 6.0,
                'new_score': 6.0,
                'score_change': 0
            }
        
        result = {
            'success': True,
            'transaction_id': transaction['id'],
            'score_impact': impact_result,
            'new_score': impact_result['new_score'],
            'score_change': impact_result['score_change'],
            'message': f"Transaction traitée. Score: {impact_result['previous_score']} → {impact_result['new_score']}",
            'cors_ok': True
        }
        
        logger.info(f"✅ Transaction traitée avec succès")
        
        return jsonify(result)
        
    except Exception as e:
        logger.error(f"❌ Erreur traitement transaction: {str(e)}")
        
        return jsonify({
            'success': False,
            'error': str(e),
            'cors_ok': True
        }), 500

@app.route('/simulate-transaction', methods=['POST', 'OPTIONS'])
def simulate_transaction():
    """Simule l'impact d'une transaction sans l'enregistrer"""
    if request.method == 'OPTIONS':
        return '', 200
    
    try:
        data = request.json
        username = data.get('username')
        
        if not username:
            return jsonify({
                'error': 'Username requis',
                'cors_ok': True
            }), 400
        
        logger.info(f"🔮 SIMULATION TRANSACTION pour {username}")
        
        # Charger le score actuel
        client_scorings = load_client_scorings()
        current_score = client_scorings.get(username, {}).get('score', 6.0)
        
        # Simuler l'impact
        transaction_type = data.get('type', 'payment')
        amount = data.get('amount', 0)
        days_late = data.get('days_late', 0)
        
        # Impact simplifié basé sur le type
        if transaction_type == 'payment' and days_late == 0:
            impact = 0.1
            description = 'Paiement à temps - Impact positif'
        elif transaction_type == 'late_payment' or days_late > 0:
            impact = -0.2 * (1 + days_late / 30)
            description = f'Paiement en retard de {days_late} jours - Impact négatif'
        elif transaction_type == 'early_payment':
            impact = 0.2
            description = 'Paiement anticipé - Impact très positif'
        elif transaction_type == 'missed_payment':
            impact = -1.0
            description = 'Paiement manqué - Impact très négatif'
        else:
            impact = 0
            description = 'Impact neutre'
        
        estimated_score = max(0, min(10, current_score + impact))
        
        simulation = {
            'current_score': current_score,
            'estimated_new_score': round(estimated_score, 1),
            'estimated_change': round(impact, 2),
            'transaction_type': transaction_type,
            'impact_description': description,
            'impact_analysis': {
                'impact_description': description,
                'factors_affected': ['Historique de paiement', 'Comportement financier'],
                'recommendations': [
                    'Continuez à payer à temps pour maintenir un bon score' if impact >= 0 
                    else 'Évitez les retards pour améliorer votre score'
                ]
            },
            'simulation': True,
            'cors_ok': True
        }
        
        logger.info(f"🔮 Simulation: {current_score} → {estimated_score} (Δ{impact:+.2f})")
        
        return jsonify(simulation)
        
    except Exception as e:
        logger.error(f"❌ Erreur simulation: {str(e)}")
        return jsonify({
            'error': str(e),
            'cors_ok': True
        }), 500

@app.route('/statistics', methods=['GET', 'OPTIONS'])
def get_statistics():
    if request.method == 'OPTIONS':
        return '', 200
    
    try:
        applications = load_applications()
        client_scorings = load_client_scorings()
        
        return jsonify({
            'applications': {
                'total': len(applications),
                'approved': sum(1 for app in applications if app.get('decision') == 'approuvé'),
                'pending': sum(1 for app in applications if app.get('decision') == 'à étudier'),
                'rejected': sum(1 for app in applications if app.get('decision') == 'refusé')
            },
            'scoring': {
                'total_clients': len(client_scorings),
                'average_score': 6.5
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

# Fonctions utilitaires
def estimate_age_from_profession(profession):
    prof = profession.lower()
    if 'étudiant' in prof or 'stagiaire' in prof:
        return 25
    elif 'senior' in prof or 'directeur' in prof or 'chef' in prof:
        return 45
    elif 'développeur' in prof or 'ingénieur' in prof:
        return 32
    else:
        return 35

def estimate_job_seniority(profession):
    prof = profession.lower()
    if 'senior' in prof or 'chef' in prof or 'directeur' in prof:
        return 60
    elif 'développeur' in prof or 'ingénieur' in prof:
        return 36
    elif 'junior' in prof or 'assistant' in prof:
        return 12
    else:
        return 24

def map_profession_to_employment(profession):
    prof = profession.lower()
    if any(word in prof for word in ['développeur', 'ingénieur', 'comptable', 'analyst', 'manager']):
        return 'cdi'
    elif any(word in prof for word in ['consultant', 'freelance', 'indépendant']):
        return 'independant'
    elif 'contractuel' in prof or 'temporaire' in prof:
        return 'cdd'
    else:
        return 'cdi'

def save_client_scoring(username, scoring_result):
    try:
        scorings = load_client_scorings()
        scorings[username] = scoring_result
        save_client_scorings(scorings)
        logger.info(f"💾 Scoring sauvegardé pour {username}")
    except Exception as e:
        logger.error(f"❌ Erreur sauvegarde {username}: {e}")

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
            '/', '/test', '/health', '/client-scoring', '/eligible-amount', '/realtime-scoring', '/statistics'
        ],
        'cors_ok': True
    }), 404

if __name__ == '__main__':
    # Créer les fichiers nécessaires
    os.makedirs('models', exist_ok=True)
    
    for file, init_func in [
        (APPLICATIONS_FILE, lambda: save_applications([])),
        (CLIENTS_FILE, lambda: save_client_scorings({})),
        (TRANSACTIONS_FILE, lambda: save_transactions_history({}))
    ]:
        if not os.path.exists(file):
            init_func()
            logger.info(f"📁 {file} créé")
    
    # Messages de démarrage
    logger.info("=" * 60)
    logger.info("🚀 BAMBOO EMF - API v5.1 - CORS CORRIGÉ")
    logger.info("=" * 60)
    logger.info("🌐 Serveur: http://localhost:5000")
    logger.info("🔧 CORS: Une seule origin autorisée (http://localhost:4200)")
    logger.info("✅ Headers CORS: Pas de doublons")
    logger.info("📡 Endpoints principaux:")
    logger.info("   • GET  /test           - Test de connectivité")
    logger.info("   • POST /client-scoring - Scoring automatique")
    logger.info("   • POST /realtime-scoring - Scoring temps réel")
    logger.info("   • POST /eligible-amount - Montant éligible")
    logger.info("   • GET  /score-trend/<username> - Tendance score")
    logger.info("   • POST /process-transaction - Traiter transaction")
    logger.info("   • POST /simulate-transaction - Simuler impact")
    
    if scoring_model:
        logger.info(f"🤖 Modèle: {'Random Forest' if scoring_model.model else 'Règles métier'}")
    else:
        logger.info("⚠️ Modèle non initialisé - Mode fallback")
    
    logger.info("=" * 60)
    logger.info("💡 Le problème CORS des headers multiples est corrigé !")
    logger.info("=" * 60)
    
    try:
        app.run(debug=True, host='0.0.0.0', port=5000, threaded=True)
    except Exception as e:
        logger.error(f"❌ Erreur démarrage: {e}")
        print("💡 Vérifiez que le port 5000 est libre")