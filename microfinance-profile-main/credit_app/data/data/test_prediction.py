#!/usr/bin/env python3
"""
Script de test pour les prédictions avec le modèle réentraîné
"""

import requests
import json
import pandas as pd
import numpy as np

def test_prediction_api():
    """Test de l'API de prédiction"""
    
    # Exemple de données client basé sur votre structure
    sample_data = {
        "age": 35,
        "sexe": "M",
        "situation_familiale": "marie",
        "nombre_enfants": 2,
        "niveau_etude": "superieur",
        "type_emploi": "salarie_prive",
        "secteur_activite": "commerce",
        "anciennete_emploi": 5.5,
        "type_contrat": "CDI",
        "revenu_mensuel": 250000,
        "autres_revenus": 50000,
        "charges_mensuelles": 150000,
        "nombre_dependants": 2,
        "anciennete_banque": 3.2,
        "solde_moyen": 80000,
        "decouvert_frequence": 1,
        "incidents_paiement": 0,
        "historique_credit": 1,
        "type_credit": "consommation",
        "montant_demande": 500000,
        "duree_demande": 12,
        "objet_credit": "consommation",
        "garanties_physiques": 0,
        "avaliste": 0,
        "domiciliation_salaire": 1,
        "utilisation_mobile_banking": 1,
        "frequence_transactions": 15,
        "epargne_reguliere": 1,
        "participation_tontine": 0,
        "verification_identite": 1,
        "verification_revenus": 1,
        "score_bureaux_credit": 600,
        "region": "Port-Gentil",
        "zone_residence": "urbaine",
        "taux_endettement": 0.6,
        "ratio_montant_revenu": 2.0,
        "score_credit": 400
    }
    
    url = "http://localhost:5000/predict"
    
    try:
        print("🔮 Test de prédiction...")
        print("📋 Données client:")
        for key, value in sample_data.items():
            print(f"  {key}: {value}")
        
        response = requests.post(url, json=sample_data)
        
        if response.status_code == 200:
            result = response.json()
            print("\n✅ Prédiction réussie!")
            print(f"📊 Score: {result['score']:.2f}")
            print(f"📊 Probabilité: {result['probability']:.4f}")
            print(f"🔖 Version du modèle: {result['modelVersion']}")
            print(f"📅 Timestamp: {result['timestamp']}")
            
            if 'factors' in result:
                print("🎯 Facteurs influençant la décision:")
                for factor in result['factors']:
                    print(f"  • {factor}")
                    
        else:
            print(f"❌ Erreur: {response.status_code}")
            print(response.text)
            
    except Exception as e:
        print(f"❌ Erreur lors du test: {str(e)}")

def test_multiple_predictions():
    """Test avec plusieurs prédictions"""
    
    # Générer des données de test variées
    test_cases = [
        {
            "name": "Client à faible risque",
            "data": {
                "age": 40,
                "sexe": "M",
                "situation_familiale": "marie",
                "nombre_enfants": 1,
                "niveau_etude": "superieur",
                "type_emploi": "salarie_prive",
                "secteur_activite": "banque",
                "anciennete_emploi": 8.0,
                "type_contrat": "CDI",
                "revenu_mensuel": 400000,
                "autres_revenus": 100000,
                "charges_mensuelles": 200000,
                "nombre_dependants": 1,
                "anciennete_banque": 5.0,
                "solde_moyen": 150000,
                "decouvert_frequence": 0,
                "incidents_paiement": 0,
                "historique_credit": 1,
                "type_credit": "consommation",
                "montant_demande": 300000,
                "duree_demande": 12,
                "objet_credit": "consommation",
                "garanties_physiques": 1,
                "avaliste": 1,
                "domiciliation_salaire": 1,
                "utilisation_mobile_banking": 1,
                "frequence_transactions": 20,
                "epargne_reguliere": 1,
                "participation_tontine": 1,
                "verification_identite": 1,
                "verification_revenus": 1,
                "score_bureaux_credit": 750,
                "region": "Libreville",
                "zone_residence": "urbaine",
                "taux_endettement": 0.4,
                "ratio_montant_revenu": 0.75,
                "score_credit": 650
            }
        },
        {
            "name": "Client à risque élevé",
            "data": {
                "age": 25,
                "sexe": "F",
                "situation_familiale": "celibataire",
                "nombre_enfants": 0,
                "niveau_etude": "secondaire",
                "type_emploi": "independant",
                "secteur_activite": "agriculture",
                "anciennete_emploi": 1.0,
                "type_contrat": "freelance",
                "revenu_mensuel": 150000,
                "autres_revenus": 0,
                "charges_mensuelles": 100000,
                "nombre_dependants": 0,
                "anciennete_banque": 0.5,
                "solde_moyen": 20000,
                "decouvert_frequence": 5,
                "incidents_paiement": 3,
                "historique_credit": 0,
                "type_credit": "consommation",
                "montant_demande": 800000,
                "duree_demande": 24,
                "objet_credit": "urgence",
                "garanties_physiques": 0,
                "avaliste": 0,
                "domiciliation_salaire": 0,
                "utilisation_mobile_banking": 0,
                "frequence_transactions": 5,
                "epargne_reguliere": 0,
                "participation_tontine": 0,
                "verification_identite": 0,
                "verification_revenus": 0,
                "score_bureaux_credit": 300,
                "region": "Franceville",
                "zone_residence": "rurale",
                "taux_endettement": 0.9,
                "ratio_montant_revenu": 5.33,
                "score_credit": 250
            }
        },
        {
            "name": "Client risque moyen",
            "data": {
                "age": 32,
                "sexe": "M",
                "situation_familiale": "marie",
                "nombre_enfants": 2,
                "niveau_etude": "superieur",
                "type_emploi": "salarie_public",
                "secteur_activite": "administration",
                "anciennete_emploi": 4.5,
                "type_contrat": "CDI",
                "revenu_mensuel": 300000,
                "autres_revenus": 50000,
                "charges_mensuelles": 180000,
                "nombre_dependants": 2,
                "anciennete_banque": 2.5,
                "solde_moyen": 100000,
                "decouvert_frequence": 2,
                "incidents_paiement": 1,
                "historique_credit": 1,
                "type_credit": "immobilier",
                "montant_demande": 2000000,
                "duree_demande": 60,
                "objet_credit": "immobilier",
                "garanties_physiques": 1,
                "avaliste": 0,
                "domiciliation_salaire": 1,
                "utilisation_mobile_banking": 1,
                "frequence_transactions": 12,
                "epargne_reguliere": 1,
                "participation_tontine": 1,
                "verification_identite": 1,
                "verification_revenus": 1,
                "score_bureaux_credit": 500,
                "region": "Port-Gentil",
                "zone_residence": "urbaine",
                "taux_endettement": 0.6,
                "ratio_montant_revenu": 5.71,
                "score_credit": 450
            }
        }
    ]
    
    url = "http://localhost:5000/predict"
    
    print("🔮 Test de prédictions multiples...")
    print("=" * 60)
    
    for i, test_case in enumerate(test_cases, 1):
        print(f"\n{i}️⃣ {test_case['name']}:")
        
        try:
            response = requests.post(url, json=test_case['data'])
            
            if response.status_code == 200:
                result = response.json()
                print(f"  📊 Score: {result['score']:.2f}")
                print(f"  📊 Probabilité: {result['probability']:.4f}")
                
                # Interprétation simple du score
                if result['score'] >= 600:
                    risk_level = "🟢 Faible risque"
                elif result['score'] >= 400:
                    risk_level = "🟡 Risque moyen"
                else:
                    risk_level = "🔴 Risque élevé"
                
                print(f"  🎯 Niveau de risque: {risk_level}")
                
            else:
                print(f"  ❌ Erreur: {response.status_code}")
                
        except Exception as e:
            print(f"  ❌ Erreur: {str(e)}")

def test_model_info():
    """Test des informations du modèle"""
    url = "http://localhost:5000/model/info"
    
    try:
        print("ℹ️ Informations du modèle...")
        response = requests.get(url)
        
        if response.status_code == 200:
            result = response.json()
            print("✅ Informations récupérées:")
            print(json.dumps(result, indent=2))
        else:
            print(f"❌ Erreur: {response.status_code}")
            print(response.text)
            
    except Exception as e:
        print(f"❌ Erreur: {str(e)}")

def test_batch_predictions_from_csv():
    """Test de prédictions en lot depuis un fichier CSV"""
    
    # Utiliser quelques lignes du fichier de test
    test_file = "test_data.csv"
    
    if not os.path.exists(test_file):
        print(f"❌ Fichier {test_file} non trouvé")
        return
    
    try:
        # Lire quelques lignes du fichier de test
        df = pd.read_csv(test_file)
        sample_df = df.head(5)  # Prendre 5 premiers échantillons
        
        print(f"🔮 Test de prédictions en lot ({len(sample_df)} échantillons)...")
        print("=" * 60)
        
        url = "http://localhost:5000/predict"
        
        for idx, row in sample_df.iterrows():
            print(f"\n📋 Échantillon {idx + 1}:")
            
            # Convertir la ligne en dictionnaire et retirer les colonnes non nécessaires
            data = row.to_dict()
            
            # Retirer les colonnes qui ne sont pas des features
            features_to_remove = ['client_id', 'date_demande', 'niveau_risque', 'decision_credit', 'remboursement_ok']
            for feature in features_to_remove:
                data.pop(feature, None)
            
            # Convertir les valeurs NaN en None
            for key, value in data.items():
                if pd.isna(value):
                    data[key] = None
            
            try:
                response = requests.post(url, json=data)
                
                if response.status_code == 200:
                    result = response.json()
                    actual_decision = row.get('decision_credit', 'N/A')
                    
                    print(f"  📊 Score prédit: {result['score']:.2f}")
                    print(f"  📊 Probabilité: {result['probability']:.4f}")
                    print(f"  📋 Décision réelle: {actual_decision}")
                    
                    # Comparaison simple
                    if result['score'] >= 500:
                        predicted_decision = "approuve"
                    else:
                        predicted_decision = "rejete"
                    
                    if actual_decision != 'N/A':
                        match = "✅" if predicted_decision == actual_decision else "❌"
                        print(f"  🎯 Prédiction: {predicted_decision} {match}")
                    
                else:
                    print(f"  ❌ Erreur: {response.status_code}")
                    
            except Exception as e:
                print(f"  ❌ Erreur: {str(e)}")
                
    except Exception as e:
        print(f"❌ Erreur lors du test en lot: {str(e)}")

if __name__ == "__main__":
    print("🔮 TEST DES PRÉDICTIONS DU MODÈLE DE SCORING")
    print("=" * 60)
    
    import os
    
    # 1. Test de base
    print("\n1️⃣ Test de prédiction basique...")
    test_prediction_api()
    
    # 2. Test des informations du modèle
    print("\n2️⃣ Informations du modèle...")
    test_model_info()
    
    # 3. Test de prédictions multiples
    print("\n3️⃣ Test de prédictions multiples...")
    test_multiple_predictions()
    
    # 4. Test en lot depuis CSV
    print("\n4️⃣ Test de prédictions en lot...")
    test_batch_predictions_from_csv()
    
    print("\n🎉 Tests terminés!")