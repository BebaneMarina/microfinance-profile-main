def apply_business_rules(client_data):
    """Applique les règles métier avant le scoring"""
    # Calcul du taux d'endettement
    debt_ratio = client_data['monthly_expenses'] / client_data['monthly_income']
    
    # Règle 1: Taux d'endettement max 33%
    if debt_ratio > 0.33:
        return {
            "approved": False,
            "reason": f"Taux d'endettement de {debt_ratio:.0%} supérieur au seuil de 33%",
            "score": 0,
            "risk_level": "élevé"
        }
    
    # Règle 2: Revenu minimum
    if client_data['monthly_income'] < 100000:
        return {
            "approved": False,
            "reason": "Revenus mensuels insuffisants (< 100 000 FCFA)",
            "score": 0,
            "risk_level": "élévé"
        }
    
    # Règle 3: Ancienneté pour CDI
    if client_data['employment_status'] == 'CDI' and client_data['employment_duration'] < 1:
        return {
            "approved": False,
            "reason": "Ancienneté insuffisante en CDI (< 1 an)",
            "score": 0,
            "risk_level": "moyen"
        }
    
    return {"approved": True}