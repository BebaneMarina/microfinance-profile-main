from flask import Flask, request, jsonify
from flask_cors import CORS
import logging
from datetime import datetime
import os
from scoring_model import PostgresCreditScoringModel

app = Flask(__name__)

CORS(app, 
     origins=["http://localhost:4200"],
     methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
     allow_headers=["Content-Type", "Authorization"],
     supports_credentials=True,
     max_age=86400
)

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

# Initialiser le modele
try:
    scoring_model = PostgresCreditScoringModel(DB_CONFIG)
    logger.info("Modele de scoring initialise avec succes")
except Exception as e:
    logger.error(f"Erreur initialisation modele: {str(e)}")
    scoring_model = None


@app.route('/')
def home():
    return jsonify({
        'message': 'API de Scoring de Credit - Bamboo EMF',
        'version': '8.0 - Auto-recalcul avec notifications',
        'status': 'running',
        'database': 'PostgreSQL',
        'model_type': 'Random Forest' if (scoring_model and scoring_model.model) else 'Regles metier',
        'features': {
            'auto_recalculation': True,
            'notifications': True,
            'real_time_scoring': True,
            'payment_tracking': True
        }
    })


@app.route('/test', methods=['GET'])
def test():
    return jsonify({
        'status': 'ok',
        'timestamp': datetime.now().isoformat(),
        'database_status': 'connected' if scoring_model else 'disconnected'
    })


@app.route('/health', methods=['GET'])
def health_check():
    try:
        db_status = 'ok'
        model_status = 'inactive'
        
        if scoring_model:
            try:
                with scoring_model.get_db_connection() as conn:
                    with conn.cursor() as cur:
                        cur.execute("SELECT 1")
                db_status = 'ok'
                
                if scoring_model.model is not None:
                    model_status = 'random_forest'
                else:
                    model_status = 'rule_based'
                    
            except Exception as e:
                db_status = f'error: {str(e)}'
        
        return jsonify({
            'status': 'healthy',
            'timestamp': datetime.now().isoformat(),
            'components': {
                'model': model_status,
                'database': db_status,
                'api': 'ok'
            }
        })
    except Exception as e:
        return jsonify({
            'status': 'unhealthy',
            'error': str(e)
        }), 500


# ==========================================
# ENDPOINT PRINCIPAL - SCORE AVEC AUTO-RECALCUL
# ==========================================

@app.route('/client-scoring/<int:user_id>', methods=['GET'])
def get_client_scoring(user_id):
    """
    Recupere le score avec recalcul automatique si necessaire
    """
    try:
        logger.info(f"Recuperation score pour user_id: {user_id}")
        
        if not scoring_model:
            return jsonify({'error': 'Modele non disponible'}), 500
        
        force_recalculate = request.args.get('recalculate', 'false').lower() == 'true'
        
        # RECALCUL AUTOMATIQUE AU LOGIN
        if force_recalculate:
            score_data = scoring_model.calculate_comprehensive_score(user_id)
            scoring_model.update_user_score_in_db(user_id, score_data)
        else:
            # Recalcul intelligent (si derniere maj > 1h)
            score_data = scoring_model.recalculate_on_login(user_id)
        
        if not score_data:
            return jsonify({'error': f'Utilisateur {user_id} non trouve'}), 404
        
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
            'recommendations': score_data.get('recommendations', [])
        }
        
        logger.info(f"Score recupere: {result['score']}/10")
        
        return jsonify(result)
        
    except Exception as e:
        logger.error(f"Erreur recuperation score: {str(e)}")
        return jsonify({'error': str(e)}), 500


@app.route('/recalculate-score/<int:user_id>', methods=['POST'])
def recalculate_score(user_id):
    """Force le recalcul du score"""
    try:
        logger.info(f"Recalcul force pour user_id: {user_id}")
        
        if not scoring_model:
            return jsonify({'error': 'Modele non disponible'}), 500
        
        score_data = scoring_model.get_or_calculate_score(user_id, force_recalculate=True)
        
        if not score_data:
            return jsonify({'error': f'Utilisateur {user_id} non trouve'}), 404
        
        result = {
            'success': True,
            'user_id': user_id,
            'score': score_data.get('score'),
            'score_850': score_data.get('score_850'),
            'risk_level': score_data.get('niveau_risque'),
            'eligible_amount': score_data.get('montant_eligible'),
            'model_used': score_data.get('model_type'),
            'model_confidence': score_data.get('model_confidence'),
            'recalculated_at': datetime.now().isoformat()
        }
        
        logger.info(f"Score recalcule: {result['score']}/10")
        
        return jsonify(result)
        
    except Exception as e:
        logger.error(f"Erreur recalcul: {str(e)}")
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/check-eligibility/<int:user_id>', methods=['GET'])
def check_eligibility(user_id):
    """Verifie eligibilite"""
    try:
        if not scoring_model:
            return jsonify({'error': 'Modele non disponible'}), 500
        
        eligibility = scoring_model.check_eligibility(user_id)
        
        return jsonify({
            'user_id': user_id,
            'eligible': eligibility.get('eligible', False),
            'raison': eligibility.get('raison'),
            'montant_eligible': eligibility.get('montant_eligible', 0),
            'score': eligibility.get('score')
        })
        
    except Exception as e:
        logger.error(f"Erreur eligibilite: {str(e)}")
        return jsonify({'error': str(e)}), 500


@app.route('/payment-analysis/<int:user_id>', methods=['GET'])
def payment_analysis(user_id):
    """Analyse des paiements"""
    try:
        if not scoring_model:
            return jsonify({'error': 'Modele non disponible'}), 500
        
        user_data = scoring_model._get_user_complete_data(user_id)
        
        if not user_data:
            return jsonify({'error': f'Utilisateur {user_id} non trouve'}), 404
        
        return jsonify({
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
            'active_credits': user_data.get('credits_actifs_count', 0)
        })
        
    except Exception as e:
        logger.error(f"Erreur analyse paiements: {str(e)}")
        return jsonify({'error': str(e)}), 500


# ==========================================
# ENDPOINTS NOTIFICATIONS
# ==========================================

@app.route('/notifications/<int:user_id>', methods=['GET'])
def get_notifications(user_id):
    """Recupere les notifications d'un utilisateur"""
    try:
        if not scoring_model:
            return jsonify({'error': 'Modele non disponible'}), 500
        
        unread_only = request.args.get('unread_only', 'false').lower() == 'true'
        limit = int(request.args.get('limit', 20))
        
        with scoring_model.get_db_connection() as conn:
            with conn.cursor() as cur:
                query = """
                    SELECT 
                        id,
                        type,
                        titre,
                        message,
                        lu,
                        date_creation,
                        date_lecture
                    FROM notifications
                    WHERE utilisateur_id = %s
                """
                
                if unread_only:
                    query += " AND lu = FALSE"
                
                query += " ORDER BY date_creation DESC LIMIT %s"
                
                cur.execute(query, (user_id, limit))
                
                notifications = []
                for row in cur.fetchall():
                    notifications.append({
                        'id': row[0],
                        'type': row[1],
                        'titre': row[2],
                        'message': row[3],
                        'lu': row[4],
                        'date_creation': row[5].isoformat() if row[5] else None,
                        'date_lecture': row[6].isoformat() if row[6] else None
                    })
        
        return jsonify({
            'user_id': user_id,
            'notifications': notifications,
            'total': len(notifications),
            'unread_count': sum(1 for n in notifications if not n['lu'])
        })
        
    except Exception as e:
        logger.error(f"Erreur recuperation notifications: {str(e)}")
        return jsonify({'error': str(e)}), 500


@app.route('/notifications/<int:notification_id>/mark-read', methods=['POST'])
def mark_notification_read(notification_id):
    """Marque une notification comme lue"""
    try:
        if not scoring_model:
            return jsonify({'error': 'Modele non disponible'}), 500
        
        with scoring_model.get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    UPDATE notifications
                    SET lu = TRUE, date_lecture = NOW()
                    WHERE id = %s
                    RETURNING utilisateur_id
                """, (notification_id,))
                
                result = cur.fetchone()
                
                if not result:
                    return jsonify({'error': 'Notification non trouvee'}), 404
                
                conn.commit()
        
        return jsonify({
            'success': True,
            'notification_id': notification_id
        })
        
    except Exception as e:
        logger.error(f"Erreur marquage notification: {str(e)}")
        return jsonify({'error': str(e)}), 500


@app.route('/notifications/<int:user_id>/mark-all-read', methods=['POST'])
def mark_all_notifications_read(user_id):
    """Marque toutes les notifications comme lues"""
    try:
        if not scoring_model:
            return jsonify({'error': 'Modele non disponible'}), 500
        
        with scoring_model.get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    UPDATE notifications
                    SET lu = TRUE, date_lecture = NOW()
                    WHERE utilisateur_id = %s AND lu = FALSE
                """, (user_id,))
                
                updated_count = cur.rowcount
                conn.commit()
        
        return jsonify({
            'success': True,
            'user_id': user_id,
            'updated_count': updated_count
        })
        
    except Exception as e:
        logger.error(f"Erreur marquage notifications: {str(e)}")
        return jsonify({'error': str(e)}), 500


# ==========================================
# ENDPOINTS EXISTANTS
# ==========================================

@app.route('/user-profile/<int:user_id>', methods=['GET'])
def get_user_profile(user_id):
    """Profile complet utilisateur"""
    try:
        if not scoring_model:
            return jsonify({'error': 'Modele non disponible'}), 500
        
        profile = scoring_model._get_user_complete_data(user_id)
        
        if not profile:
            return jsonify({'error': f'Utilisateur {user_id} non trouve'}), 404
        
        result = {k: (str(v) if isinstance(v, (datetime,)) else v) 
                  for k, v in profile.items()}
        
        return jsonify(result)
        
    except Exception as e:
        logger.error(f"Erreur profile: {str(e)}")
        return jsonify({'error': str(e)}), 500


@app.route('/score-trend/<username>', methods=['GET'])
def get_score_trend(username):
    """Historique des scores"""
    try:
        if not scoring_model:
            return jsonify({'error': 'Modele non disponible'}), 500
        
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
                        'error': 'Utilisateur non trouve',
                        'recent_transactions': []
                    }), 404
                
                user_id = user[0]
                
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
            'total_records': len(recent_transactions)
        })
        
    except Exception as e:
        logger.error(f"Erreur score-trend: {str(e)}")
        return jsonify({'error': str(e)}), 500


@app.route('/statistics', methods=['GET'])
def get_statistics():
    """Statistiques generales"""
    try:
        if not scoring_model:
            return jsonify({'error': 'Modele non disponible'}), 500
        
        with scoring_model.get_db_connection() as conn:
            with conn.cursor() as cur:
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
                
                cur.execute("""
                    SELECT 
                        niveau_risque,
                        COUNT(*) as count
                    FROM utilisateurs
                    WHERE statut = 'actif'
                    GROUP BY niveau_risque
                """)
                risk_distribution = {row[0]: row[1] for row in cur.fetchall()}
        
        return jsonify({
            'total_users': stats[0] if stats else 0,
            'average_score': round(float(stats[1]), 2) if stats and stats[1] else 0,
            'eligible_users': stats[2] if stats else 0,
            'risk_distribution': risk_distribution,
            'model_info': {
                'type': 'Random Forest' if (scoring_model.model is not None) else 'Regles metier',
                'ml_available': scoring_model.model is not None
            },
            'timestamp': datetime.now().isoformat()
        })
        
    except Exception as e:
        logger.error(f"Erreur statistiques: {str(e)}")
        return jsonify({'error': str(e)}), 500


@app.route('/retrain-model', methods=['POST'])
def retrain_model():
    """Reentraine le modele"""
    try:
        if not scoring_model:
            return jsonify({'error': 'Modele non disponible'}), 500
        
        success = scoring_model.train_model_from_database()
        
        if success:
            return jsonify({
                'success': True,
                'message': 'Modele reentraine avec succes',
                'timestamp': datetime.now().isoformat()
            })
        else:
            return jsonify({
                'success': False,
                'message': 'Echec du reentrainement'
            }), 500
        
    except Exception as e:
        logger.error(f"Erreur reentrainement: {str(e)}")
        return jsonify({'error': str(e)}), 500


@app.errorhandler(Exception)
def handle_error(e):
    logger.error(f"Erreur non geree: {str(e)}")
    return jsonify({
        'error': 'Erreur serveur interne',
        'message': str(e)
    }), 500


@app.errorhandler(404)
def not_found(e):
    return jsonify({
        'error': 'Endpoint non trouve'
    }), 404


if __name__ == '__main__':
    logger.info("=" * 60)
    logger.info("BAMBOO EMF - API v1.0 - Auto-recalcul + Notifications")
    logger.info("=" * 60)
    logger.info("Serveur: http://localhost:5000")
    logger.info("Base de donnees: PostgreSQL")
    logger.info("Machine Learning: Random Forest")
    logger.info("=" * 60)
    
    try:
        app.run(debug=True, host='0.0.0.0', port=5000, threaded=True)
    except Exception as e:
        logger.error(f"Erreur demarrage: {e}")