# scoring/model.py
def calculate(self, client_data):
    """Calcule le score de crédit avec plus de critères"""
    if not self.model:
        raise Exception("Scoring model not loaded")
    
    # Transformation des données en DataFrame
    features = pd.DataFrame([{
        'monthly_income': client_data['monthly_income'],
        'monthly_expenses': client_data['monthly_expenses'],
        'employment_status': client_data['employment_status'],
        'employment_duration': client_data.get('employment_duration', 1),
        'banking_history': client_data.get('banking_history', 'neutral'),
        'active_loans': int(client_data.get('active_loans', False)),
        'existing_debts': client_data.get('existing_debts', 0),
        'has_guarantor': int(bool(client_data.get('guarantor_name')))
    }])
    
    # Application des règles métier
    business_rules_result = apply_business_rules(client_data)
    if not business_rules_result['approved']:
        return business_rules_result
    
    # Prédiction du modèle
    probability = self.model.predict_proba(features)[0][1]
    score = int((1 - probability) * 1000)  # Score sur 1000
    
    return {
        "score": score,
        "risk_level": "bas" if score >= 700 else "moyen" if score >= 500 else "élevé",
        "approved": score >= 600,
        "explanation": self.generate_explanation(score, client_data),
        "probability_default": float(probability)
    }