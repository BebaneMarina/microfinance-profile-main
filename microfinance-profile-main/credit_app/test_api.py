import requests
import json

BASE_URL = "http://localhost:5000"

def test_api():
    print("Test de l'API Bamboo EMF")
    print("-" * 50)
    
    # Test 1: Route principale
    print("\n1. Test de la route principale")
    response = requests.get(f"{BASE_URL}/")
    print(f"Status: {response.status_code}")
    print(f"Response: {response.json()}")
    
    # Test 2: Route de test
    print("\n2. Test de la route /test")
    response = requests.get(f"{BASE_URL}/test")
    print(f"Status: {response.status_code}")
    print(f"Response: {response.json()}")
    
    # Test 3: Prédiction de score
    print("\n3. Test de prédiction de score")
    test_data = {
        "age": 35,
        "employment_status": "cdi",
        "job_seniority": 5,
        "monthly_income": 800000,
        "other_income": 100000,
        "existing_debts": 200000,
        "loan_amount": 2000000,
        "loan_duration": 24,
        "credit_type": "consommation"
    }
    response = requests.post(f"{BASE_URL}/predict", json=test_data)
    print(f"Status: {response.status_code}")
    print(f"Response: {response.json()}")
    
    # Test 4: Liste des applications
    print("\n4. Test de récupération des applications")
    response = requests.get(f"{BASE_URL}/api/applications")
    print(f"Status: {response.status_code}")
    print(f"Response: {response.json()}")
    
    # Test 5: Création d'une application
    print("\n5. Test de création d'une application")
    new_app = {
        "creditType": "consommation",
        "personalInfo": {
            "fullName": "Test User",
            "email": "test@example.com",
            "phoneNumber": "0612345678"
        },
        "financialInfo": {
            "monthlySalary": 800000,
            "employerName": "Test Company"
        },
        "creditDetails": {
            "requestedAmount": 2000000,
            "duration": 24,
            "creditPurpose": "Test purpose",
            "repaymentMode": "mensuel"
        },
        "creditScore": 750,
        "riskLevel": "moyen",
        "creditProbability": 0.75,
        "status": "en-cours"
    }
    response = requests.post(f"{BASE_URL}/api/applications", json=new_app)
    print(f"Status: {response.status_code}")
    print(f"Response: {response.json()}")

if __name__ == "__main__":
    test_api()