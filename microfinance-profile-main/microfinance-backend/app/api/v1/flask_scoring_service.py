# flask_scoring_service.py - Service Flask minimal pour les tests
from flask import Flask, request, jsonify
from flask_cors import CORS
import random
import time

app = Flask(__name__)
CORS(app)

@app.route('/client-scoring', methods=['POST'])
def client_scoring():
    """Endpoint de scoring principal"""
    data = request.json
    
    # Simuler un délai de traitement
    time.sleep(0.2)
    
    monthly_income = data.get('monthly_income', 0)
    employment_status = data.get('employment_status', 'autre')
    loan_amount = data.get('loan_amount', 0)
    
    # Calcul de score simplifié
    score = 5.0  # Score de base
    
    # Ajustements basés sur les revenus
    if monthly_income >= 500000:
        score += 2.5
    elif monthly_income >= 300000:
        score += 1.5
    elif monthly_income >= 150000:
        score += 0.5
    
    # Ajustements basés sur l'emploi
    if employment_status == 'cdi':
        score += 1.5
    elif employment_status == 'cdd':
        score += 0.5
    
    # Ajustement selon le montant demandé
    if loan_amount > 0 and monthly_income > 0:
        ratio = loan_amount / monthly_income
        if ratio > 3:
            score -= 1.0
        elif ratio > 2:
            score -= 0.5
    
    # Limiter le score entre 0 et 10
    score = max(0, min(10, score))
    
    # Déterminer le niveau de risque
    if score >= 8:
        risk_level = "very_low"
    elif score >= 6:
        risk_level = "low"
    elif score >= 4:
        risk_level = "medium"
    elif score >= 2:
        risk_level = "high"
    else:
        risk_level = "very_high"
    
    # Calculer les montants éligibles
    eligible_cash = min(monthly_income * 0.5, 2000000) if score >= 5 else 0
    eligible_long = min(monthly_income * 3, 10000000) if score >= 6 else 0
    
    # Décision
    if score >= 7:
        decision = "approuvé"
    elif score >= 5:
        decision = "à étudier"
    else:
        decision = "refusé"
    
    return jsonify({
        "score": round(score, 1),
        "risk_level": risk_level,
        "probability": round(score / 10, 2),
        "decision": decision,
        "eligible_amount": int(eligible_cash),
        "eligible_amount_cash": int(eligible_cash),
        "eligible_amount_long": int(eligible_long),
        "factors": [
            {
                "name": "monthly_income",
                "value": min(100, (monthly_income / 10000)),
                "impact": 30
            },
            {
                "name": "employment_status", 
                "value": 90 if employment_status == 'cdi' else (70 if employment_status == 'cdd' else 30),
                "impact": 25
            }
        ],
        "recommendations": [
            "Maintenez votre situation professionnelle stable",
            "Évitez de multiplier les demandes de crédit"
        ],
        "model_version": "test_1.0",
        "processing_time": 0.2
    })

@app.route('/realtime-scoring', methods=['POST'])
def realtime_scoring():
    """Scoring temps réel"""
    data = request.json
    
    # Utiliser le scoring principal avec des ajustements temps réel
    result = client_scoring().get_json()
    
    # Ajouter des données temps réel
    current_score = data.get('current_score', 6.0)
    new_score = result['score']
    
    result.update({
        "is_realtime": True,
        "previous_score": current_score,
        "score_change": round(new_score - current_score, 1),
        "last_updated": "now"
    })
    
    return jsonify(result)

@app.route('/health', methods=['GET'])
def health():
    """Health check"""
    return jsonify({"status": "healthy", "service": "scoring"})

if __name__ == '__main__':
    print("🚀 Service de scoring Flask démarré sur le port 5000")
    app.run(host='0.0.0.0', port=5000, debug=True)