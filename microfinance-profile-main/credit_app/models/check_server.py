#!/usr/bin/env python3
"""
Script de vérification du serveur Flask
Vérifie que l'API fonctionne correctement et résout les problèmes CORS
"""

import requests
import json
import time
import sys
from datetime import datetime

API_BASE = 'http://localhost:5000'

def check_server_status():
    """Vérifie si le serveur est démarré"""
    try:
        response = requests.get(f'{API_BASE}/', timeout=5)
        if response.status_code == 200:
            print("✅ Serveur Flask démarré et accessible")
            return True
        else:
            print(f"⚠️ Serveur répond avec le code {response.status_code}")
            return False
    except requests.exceptions.ConnectionError:
        print("❌ Serveur Flask non accessible - Vérifiez qu'il est démarré")
        return False
    except Exception as e:
        print(f"❌ Erreur lors de la vérification: {e}")
        return False

def check_cors_headers():
    """Vérifie les headers CORS"""
    try:
        # Test de requête OPTIONS (preflight)
        headers = {
            'Origin': 'http://localhost:4200',
            'Access-Control-Request-Method': 'POST',
            'Access-Control-Request-Headers': 'Content-Type'
        }
        
        response = requests.options(f'{API_BASE}/test', headers=headers, timeout=5)
        
        if response.status_code == 200:
            cors_headers = response.headers
            print("✅ Requête OPTIONS (preflight) réussie")
            print(f"   Access-Control-Allow-Origin: {cors_headers.get('Access-Control-Allow-Origin', 'NON DÉFINI')}")
            print(f"   Access-Control-Allow-Methods: {cors_headers.get('Access-Control-Allow-Methods', 'NON DÉFINI')}")
            print(f"   Access-Control-Allow-Headers: {cors_headers.get('Access-Control-Allow-Headers', 'NON DÉFINI')}")
            return True
        else:
            print(f"❌ Requête OPTIONS échoue avec le code {response.status_code}")
            return False
            
    except Exception as e:
        print(f"❌ Erreur test CORS: {e}")
        return False

def test_endpoints():
    """Test des endpoints principaux"""
    endpoints_to_test = [
        ('GET', '/'),
        ('GET', '/health'),
        ('GET', '/test'),
        ('POST', '/client-scoring'),
        ('POST', '/eligible-amount')
    ]
    
    success_count = 0
    
    for method, endpoint in endpoints_to_test:
        try:
            url = f'{API_BASE}{endpoint}'
            headers = {
                'Content-Type': 'application/json',
                'Origin': 'http://localhost:4200'
            }
            
            if method == 'GET':
                response = requests.get(url, headers=headers, timeout=10)
            elif method == 'POST':
                # Données de test
                test_data = {
                    'username': 'test_user',
                    'monthly_income': 750000,
                    'profession': 'Développeur',
                    'company': 'Tech Solutions',
                    'employment_status': 'cdi',
                    'job_seniority': 36
                }
                response = requests.post(url, json=test_data, headers=headers, timeout=10)
            
            if response.status_code in [200, 201]:
                print(f"✅ {method} {endpoint} - Code {response.status_code}")
                success_count += 1
            else:
                print(f"⚠️ {method} {endpoint} - Code {response.status_code}")
                if response.text:
                    try:
                        error_data = response.json()
                        print(f"   Erreur: {error_data.get('message', 'Inconnue')}")
                    except:
                        print(f"   Réponse: {response.text[:100]}...")
                        
        except requests.exceptions.Timeout:
            print(f"⏱️ {method} {endpoint} - Timeout")
        except requests.exceptions.ConnectionError:
            print(f"❌ {method} {endpoint} - Connexion impossible")
        except Exception as e:
            print(f"❌ {method} {endpoint} - Erreur: {e}")
    
    print(f"\n📊 Résultat: {success_count}/{len(endpoints_to_test)} endpoints fonctionnels")
    return success_count == len(endpoints_to_test)

def test_full_scoring_flow():
    """Test complet du flow de scoring"""
    print("\n🔄 Test du flow complet de scoring...")
    
    test_user = {
        'username': 'marina_brunelle',
        'name': 'BEBANE MOUKOUMBI MARINA BRUNELLE',
        'email': 'marina@email.com',
        'phone': '077123456',
        'profession': 'Cadre',
        'company': 'Société Exemple SA',
        'monthly_income': 900000,
        'monthlyIncome': 900000,
        'employment_status': 'cdi',
        'employmentStatus': 'cdi',
        'job_seniority': 36,
        'jobSeniority': 36,
        'monthlyCharges': 270000,
        'existingDebts': 0,
        'clientType': 'particulier'
    }
    
    headers = {
        'Content-Type': 'application/json',
        'Origin': 'http://localhost:4200'
    }
    
    try:
        # 1. Test scoring client
        print("1️⃣ Test client-scoring...")
        response = requests.post(f'{API_BASE}/client-scoring', json=test_user, headers=headers, timeout=15)
        
        if response.status_code == 200:
            result = response.json()
            print(f"   ✅ Score calculé: {result.get('score', 'N/A')}/10")
            print(f"   ✅ Montant éligible: {result.get('eligible_amount', 'N/A'):,} FCFA")
            print(f"   ✅ Niveau de risque: {result.get('risk_level', 'N/A')}")
            print(f"   ✅ Décision: {result.get('decision', 'N/A')}")
        else:
            print(f"   ❌ Erreur client-scoring: {response.status_code}")
            print(f"   Réponse: {response.text[:200]}...")
            return False
        
        # 2. Test montant éligible
        print("\n2️⃣ Test eligible-amount...")
        response = requests.post(f'{API_BASE}/eligible-amount', json=test_user, headers=headers, timeout=15)
        
        if response.status_code == 200:
            result = response.json()
            print(f"   ✅ Montant éligible: {result.get('eligible_amount', 'N/A'):,} FCFA")
        else:
            print(f"   ❌ Erreur eligible-amount: {response.status_code}")
            return False
        
        # 3. Test temps réel (optionnel)
        print("\n3️⃣ Test realtime-scoring...")
        response = requests.post(f'{API_BASE}/realtime-scoring', json=test_user, headers=headers, timeout=15)
        
        if response.status_code == 200:
            result = response.json()
            print(f"   ✅ Score temps réel: {result.get('score', 'N/A')}/10")
        else:
            print(f"   ⚠️ Realtime-scoring non disponible: {response.status_code}")
        
        print("\n✅ Flow de scoring complet testé avec succès!")
        return True
        
    except Exception as e:
        print(f"\n❌ Erreur dans le test complet: {e}")
        return False

def show_fix_instructions():
    """Affiche les instructions de résolution"""
    print("\n" + "="*60)
    print("🔧 INSTRUCTIONS DE RÉSOLUTION DES ERREURS CORS")
    print("="*60)
    
    print("\n1️⃣ VÉRIFIER QUE LE SERVEUR FLASK EST DÉMARRÉ")
    print("   📂 Ouvrez un terminal dans le dossier de votre projet")
    print("   🐍 Exécutez: python app.py")
    print("   🌐 Vérifiez que le message apparaît: 'Running on http://localhost:5000'")
    
    print("\n2️⃣ SI LE PORT 5000 EST OCCUPÉ")
    print("   🔍 Windows: netstat -ano | findstr :5000")
    print("   🔍 Linux/Mac: lsof -i :5000")
    print("   ⚡ Tuez le processus ou changez de port")
    
    print("\n3️⃣ VÉRIFIER LES DÉPENDANCES PYTHON")
    print("   📦 pip install flask flask-cors numpy pandas scikit-learn")
    
    print("\n4️⃣ VÉRIFIER LE FICHIER app.py")
    print("   ✅ Utilisez le fichier app.py corrigé fourni")
    print("   ✅ CORS doit être configuré pour http://localhost:4200")
    
    print("\n5️⃣ REDÉMARRER ANGULAR")
    print("   🔄 ng serve --port 4200")
    print("   🌐 Vérifiez que Angular fonctionne sur http://localhost:4200")
    
    print("\n6️⃣ TEST DE CONNECTIVITÉ")
    print("   🧪 Ouvrez http://localhost:5000 dans votre navigateur")
    print("   🧪 Vous devriez voir les informations de l'API")
    
    print("="*60)

def main():
    """Fonction principale"""
    print("🚀 VÉRIFICATION DU SERVEUR BAMBOO EMF API")
    print("="*50)
    print(f"📅 {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"🌐 URL de base: {API_BASE}")
    print()
    
    # Étape 1: Vérifier l'état du serveur
    if not check_server_status():
        show_fix_instructions()
        return False
    
    time.sleep(1)
    
    # Étape 2: Vérifier CORS
    print("\n🔍 Vérification des headers CORS...")
    cors_ok = check_cors_headers()
    
    time.sleep(1)
    
    # Étape 3: Tester les endpoints
    print("\n🧪 Test des endpoints...")
    endpoints_ok = test_endpoints()
    
    time.sleep(1)
    
    # Étape 4: Test complet
    flow_ok = test_full_scoring_flow()
    
    # Résumé
    print("\n" + "="*50)
    print("📋 RÉSUMÉ DE LA VÉRIFICATION")
    print("="*50)
    print(f"🌐 Serveur accessible: {'✅' if check_server_status() else '❌'}")
    print(f"🔗 CORS configuré: {'✅' if cors_ok else '❌'}")
    print(f"📡 Endpoints fonctionnels: {'✅' if endpoints_ok else '❌'}")
    print(f"⚡ Flow complet: {'✅' if flow_ok else '❌'}")
    
    all_ok = check_server_status() and cors_ok and endpoints_ok and flow_ok
    
    if all_ok:
        print("\n🎉 TOUS LES TESTS SONT PASSÉS!")
        print("✅ L'API est prête pour Angular")
        print("🔗 Vous pouvez maintenant utiliser votre application Angular")
    else:
        print("\n⚠️ CERTAINS TESTS ONT ÉCHOUÉ")
        print("🔧 Consultez les instructions ci-dessous")
        show_fix_instructions()
    
    return all_ok

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)