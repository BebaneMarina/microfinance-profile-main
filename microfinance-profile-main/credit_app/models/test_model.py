from scoring_model import CreditScoringModel
import json

# Créer une instance du modèle
print("Initialisation du modèle...")
model = CreditScoringModel()

# Données de test
test_data = {
    'age': 35,
    'monthly_income': 500000,
    'other_income': 50000,
    'monthly_charges': 150000,
    'existing_debts': 50000,
    'job_seniority': 24,
    'employment_status': 'cdi',
    'loan_amount': 1000000,
    'loan_duration': 1,
    'credit_type': 'consommation_generale',
    'marital_status': 'marie',
    'education': 'superieur',
    'dependents': 2,
    'repayment_frequency': 'mensuel'
}

print("\nTest de prédiction...")
result = model.predict(test_data)
print(json.dumps(result, indent=2))

print("\nTest de validation...")
validation = model.validate_credit_request(test_data)
print(json.dumps(validation, indent=2))