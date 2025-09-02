# app.py - Intégration complète du crédit long dans votre API Flask existante

from flask import Flask, request, jsonify
from flask_cors import CORS
import logging
import os
import sys

# Ajouter le chemin des modules de crédit long
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

# Importer votre modèle crédit long existant
try:
    from credit_long_ml_api import (
        CreditLongScoringModel, 
        CreditLongRequest, 
        SimulationResult,
        CreditLongProfitabilityAnalyzer
    )
    print("✅ Modules crédit long importés avec succès")
except ImportError as e:
    print(f"❌ Erreur import crédit long: {e}")
    # Fallback - créer des classes simplifiées
    class CreditLongScoringModel:
        def __init__(self):
            self.risk_rates = {
                'très_faible': 6.0, 'faible': 8.0, 'moyen': 12.0,
                'élevé': 16.0, 'très_élevé': 20.0
            }
        
        def simulate_credit_long(self, request):
            # Simulation basique sans ML
            return type('SimulationResult', (), {
                'score': 6.5,
                'risk_level': 'moyen',
                'recommended_amount': request.requested_amount * 0.9,
                'max_amount': request.monthly_income * 40,
                'suggested_rate': 12.0,
                'monthly_payment': request.requested_amount / request.duration * 1.08,
                'total_interest': request.requested_amount * 0.2,
                'debt_to_income_ratio': 35.0,
                'approval_probability': 0.75,
                'factors': [],
                'recommendations': ['Profil acceptable pour un crédit personnel'],
                'warnings': [],
                'model_confidence': 0.80
            })()
    
    class CreditLongRequest:
        def __init__(self, **kwargs):
            for key, value in kwargs.items():
                setattr(self, key, value)

# Configuration Flask
app = Flask(__name__)
CORS(app, origins="*", allow_headers=["Content-Type", "Authorization"])

# Configuration logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Variables globales
credit_long_model = None
drafts_storage = {}  # En production, utilisez une base de données
requests_storage = {}  # En production, utilisez une base de données

# Initialisation du modèle
def init_credit_long_model():
    global credit_long_model
    try:
        credit_long_model = CreditLongScoringModel()
        logger.info("✅ Modèle crédit long initialisé")
        return True
    except Exception as e:
        logger.error(f"❌ Erreur initialisation modèle: {e}")
        credit_long_model = None
        return False

# Initialiser au démarrage
init_credit_long_model()

# ==================== ROUTES API CRÉDIT LONG ====================

@app.route('/api/credit-long/health', methods=['GET', 'OPTIONS'])
def credit_long_health():
    """Health check pour le service crédit long"""
    if request.method == 'OPTIONS':
        return '', 200
    
    try:
        return jsonify({
            'success': True,
            'status': 'healthy' if credit_long_model else 'degraded',
            'service': 'credit-long',
            'version': '1.0.0',
            'endpoints': [
                'POST /api/credit-long/simulate',
                'POST /api/credit-long/create',
                'GET /api/credit-long/draft/{username}',
                'POST /api/credit-long/draft',
                'GET /api/credit-long/user/{username}'
            ]
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'status': 'unhealthy',
            'error': str(e)
        }), 500

@app.route('/api/credit-long/simulate', methods=['POST', 'OPTIONS'])
def simulate_credit_long():
    """Simulation de crédit long"""
    if request.method == 'OPTIONS':
        return '', 200
    
    try:
        data = request.json
        logger.info(f"📊 Nouvelle simulation crédit long reçue")
        
        # Validation des données de base
        if not data:
            return jsonify({
                'success': False,
                'error': 'Données manquantes'
            }), 400
        
        requested_amount = float(data.get('requestedAmount', 0))
        duration = int(data.get('duration', 12))
        
        if requested_amount <= 0:
            return jsonify({
                'success': False,
                'error': 'Montant invalide'
            }), 400
        
        # Données client
        client_profile = data.get('clientProfile', {})
        financial_details = data.get('financialDetails', {})
        
        monthly_income = float(client_profile.get('monthlyIncome', 500000))
        
        # Construire l'objet de demande
        credit_request = CreditLongRequest(
            requested_amount=requested_amount,
            duration=duration,
            monthly_income=monthly_income,
            monthly_expenses=float(financial_details.get('monthlyExpenses', monthly_income * 0.4)),
            existing_debts=0,  # À calculer depuis existingLoans
            job_seniority=int(financial_details.get('employmentDetails', {}).get('seniority', 24)),
            employment_type=financial_details.get('employmentDetails', {}).get('contractType', 'CDI'),
            age=int(client_profile.get('age', 35)),
            dependents=int(client_profile.get('dependents', 0)),
            other_incomes=financial_details.get('otherIncomes', []),
            existing_loans=financial_details.get('existingLoans', []),
            assets=financial_details.get('assets', []),
            purpose=data.get('purpose', 'Crédit personnel'),
            collateral_value=0,
            guarantor_score=6.0
        )
        
        # Effectuer la simulation
        if credit_long_model:
            result = credit_long_model.simulate_credit_long(credit_request)
        else:
            # Simulation fallback sans ML
            monthly_payment = calculate_monthly_payment(requested_amount, 12, duration)
            result = type('Result', (), {
                'score': 6.5,
                'risk_level': 'moyen',
                'recommended_amount': min(requested_amount, monthly_income * 30),
                'max_amount': monthly_income * 40,
                'suggested_rate': 12.0,
                'monthly_payment': monthly_payment,
                'total_interest': (monthly_payment * duration) - requested_amount,
                'debt_to_income_ratio': (monthly_payment / monthly_income) * 100,
                'approval_probability': 0.75,
                'factors': [
                    {'name': 'monthly_income', 'value': 75, 'impact': 20, 'description': f'Revenus: {monthly_income:,.0f} FCFA'},
                    {'name': 'employment_status', 'value': 80, 'impact': 15, 'description': 'Emploi stable'}
                ],
                'recommendations': [
                    '✅ Profil éligible pour un crédit personnel',
                    '💡 Durée optimale pour vos revenus'
                ],
                'warnings': [] if monthly_payment < monthly_income * 0.35 else ['⚠️ Mensualité élevée par rapport aux revenus'],
                'model_confidence': 0.80
            })()
        
        # Formater la réponse selon l'interface attendue
        simulation_response = {
            'success': True,
            'requestedAmount': requested_amount,
            'duration': duration,
            'clientProfile': client_profile,
            'results': {
                'score': result.score,
                'riskLevel': result.risk_level,
                'recommendedAmount': result.recommended_amount,
                'maxAmount': result.max_amount,
                'suggestedRate': result.suggested_rate,
                'monthlyPayment': result.monthly_payment,
                'totalAmount': result.monthly_payment * duration,
                'totalInterest': result.total_interest,
                'debtToIncomeRatio': result.debt_to_income_ratio,
                'approvalProbability': result.approval_probability,
                'keyFactors': [
                    {
                        'factor': factor['name'],
                        'impact': 'positive' if factor['value'] > 60 else 'negative',
                        'description': factor['description']
                    } for factor in result.factors
                ],
                'recommendations': result.recommendations,
                'warnings': result.warnings
            },
            'modelUsed': 'credit_long_ml' if credit_long_model else 'fallback',
            'timestamp': '2024-01-01T00:00:00Z'
        }
        
        logger.info(f"✅ Simulation réussie - Score: {result.score}")
        return jsonify(simulation_response)
        
    except Exception as e:
        logger.error(f"❌ Erreur simulation: {str(e)}")
        return jsonify({
            'success': False,
            'error': str(e),
            'message': 'Erreur lors de la simulation'
        }), 500

@app.route('/api/credit-long/create', methods=['POST', 'OPTIONS'])
def create_credit_request():
    """Crée une nouvelle demande de crédit long"""
    if request.method == 'OPTIONS':
        return '', 200
    
    try:
        data = request.json
        
        # Générer un ID unique
        request_id = f"CR{len(requests_storage) + 1:06d}"
        
        # Créer la demande
        new_request = {
            'id': request_id,
            'userId': data.get('userId'),
            'username': data.get('username'),
            'personalInfo': data.get('personalInfo', {}),
            'creditDetails': data.get('creditDetails', {}),
            'financialDetails': data.get('financialDetails', {}),
            'documents': data.get('documents', {}),
            'simulation': data.get('simulation'),
            'status': 'submitted',
            'submissionDate': '2024-01-01T00:00:00Z',
            'reviewHistory': data.get('reviewHistory', [])
        }
        
        # Sauvegarder
        requests_storage[request_id] = new_request
        
        logger.info(f"✅ Demande créée: {request_id}")
        
        return jsonify({
            'success': True,
            'id': request_id,
            'status': 'submitted',
            'message': 'Demande créée avec succès'
        })
        
    except Exception as e:
        logger.error(f"❌ Erreur création demande: {str(e)}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/credit-long/draft', methods=['POST', 'OPTIONS'])
def save_draft():
    """Sauvegarde un brouillon"""
    if request.method == 'OPTIONS':
        return '', 200
    
    try:
        data = request.json
        username = data.get('username')
        
        if not username:
            return jsonify({
                'success': False,
                'error': 'Username requis'
            }), 400
        
        # Sauvegarder le brouillon
        drafts_storage[username] = data
        
        return jsonify({
            'success': True,
            'message': 'Brouillon sauvegardé'
        })
        
    except Exception as e:
        logger.error(f"❌ Erreur sauvegarde brouillon: {str(e)}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/credit-long/draft/<username>', methods=['GET', 'OPTIONS'])
def get_draft(username):
    """Récupère un brouillon"""
    if request.method == 'OPTIONS':
        return '', 200
    
    try:
        draft = drafts_storage.get(username)
        
        return jsonify({
            'success': True,
            'draft': draft
        })
        
    except Exception as e:
        logger.error(f"❌ Erreur récupération brouillon: {str(e)}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/credit-long/user/<username>', methods=['GET', 'OPTIONS'])
def get_user_requests(username):
    """Récupère toutes les demandes d'un utilisateur"""
    if request.method == 'OPTIONS':
        return '', 200
    
    try:
        # Filtrer les demandes par utilisateur
        user_requests = [
            req for req in requests_storage.values() 
            if req.get('username') == username
        ]
        
        return jsonify({
            'success': True,
            'requests': user_requests
        })
        
    except Exception as e:
        logger.error(f"❌ Erreur récupération demandes: {str(e)}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/credit-long/<request_id>/documents', methods=['POST', 'OPTIONS'])
def upload_document(request_id):
    """Upload un document pour une demande"""
    if request.method == 'OPTIONS':
        return '', 200
    
    try:
        # Simuler l'upload de document
        file = request.files.get('file')
        document_type = request.form.get('type')
        
        if not file:
            return jsonify({
                'success': False,
                'error': 'Fichier manquant'
            }), 400
        
        # En production, sauvegarder le fichier sur disque ou cloud
        logger.info(f"📎 Document uploadé: {document_type} pour {request_id}")
        
        return jsonify({
            'success': True,
            'message': 'Document uploadé avec succès',
            'filename': file.filename,
            'type': document_type
        })
        
    except Exception as e:
        logger.error(f"❌ Erreur upload document: {str(e)}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/credit-long/quick-simulate', methods=['POST', 'OPTIONS'])
def quick_simulation():
    """Simulation rapide avec montant et durée"""
    if request.method == 'OPTIONS':
        return '', 200
    
    try:
        data = request.json
        amount = float(data.get('amount', 0))
        duration = int(data.get('duration', 12))
        username = data.get('username', 'anonymous')
        
        # Calcul rapide
        monthly_payment = calculate_monthly_payment(amount, 12, duration)
        total_amount = monthly_payment * duration
        total_interest = total_amount - amount
        
        return jsonify({
            'success': True,
            'amount': amount,
            'duration': duration,
            'monthlyPayment': monthly_payment,
            'totalAmount': total_amount,
            'totalInterest': total_interest,
            'estimatedRate': 12.0,
            'message': f'Simulation rapide pour {username}'
        })
        
    except Exception as e:
        logger.error(f"❌ Erreur simulation rapide: {str(e)}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

# ==================== FONCTIONS UTILITAIRES ====================

def calculate_monthly_payment(amount, annual_rate, duration_months):
    """Calcule la mensualité d'un prêt"""
    if annual_rate == 0:
        return amount / duration_months
    
    monthly_rate = annual_rate / 100 / 12
    payment = amount * (monthly_rate * (1 + monthly_rate) ** duration_months) / \
             ((1 + monthly_rate) ** duration_months - 1)
    
    return round(payment)

# ==================== ROUTES DE DEBUG ====================

@app.route('/api/credit-long/test', methods=['GET', 'POST', 'OPTIONS'])
def test_credit_long():
    """Route de test pour vérifier que l'API fonctionne"""
    if request.method == 'OPTIONS':
        return '', 200
    
    return jsonify({
        'success': True,
        'message': 'API Crédit Long fonctionnelle',
        'method': request.method,
        'timestamp': '2024-01-01T00:00:00Z',
        'model_loaded': credit_long_model is not None,
        'available_endpoints': [
            '/api/credit-long/simulate',
            '/api/credit-long/create',
            '/api/credit-long/draft',
            '/api/credit-long/quick-simulate',
            '/api/credit-long/health'
        ]
    })

@app.route('/api/test', methods=['GET'])
def test_api():
    """Test général de l'API"""
    return jsonify({
        'success': True,
        'message': 'API principale fonctionnelle',
        'credit_long_available': True
    })

# ==================== GESTION DES ERREURS ====================

@app.errorhandler(404)
def not_found(error):
    return jsonify({
        'success': False,
        'error': 'Endpoint non trouvé',
        'available_endpoints': [
            '/api/credit-long/simulate',
            '/api/credit-long/create',
            '/api/credit-long/draft',
            '/api/credit-long/health',
            '/api/credit-long/test'
        ]
    }), 404

@app.errorhandler(500)
def internal_error(error):
    return jsonify({
        'success': False,
        'error': 'Erreur interne du serveur'
    }), 500

# ==================== DÉMARRAGE ====================

if __name__ == '__main__':
    print("🚀 Démarrage API Crédit Long...")
    print("📋 Endpoints disponibles:")
    print("   • POST /api/credit-long/simulate")
    print("   • POST /api/credit-long/create") 
    print("   • POST /api/credit-long/draft")
    print("   • GET  /api/credit-long/draft/<username>")
    print("   • GET  /api/credit-long/user/<username>")
    print("   • GET  /api/credit-long/health")
    print("   • GET  /api/credit-long/test")
    
    # Démarrer le serveur
    app.run(
        debug=True,
        host='0.0.0.0',
        port=5000,
        threaded=True
    )