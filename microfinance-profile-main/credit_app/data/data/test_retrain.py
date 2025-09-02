import requests
import json
import csv
import os
from datetime import datetime
import matplotlib.pyplot as plt
import numpy as np
import seaborn as sns

# ========== AFFICHAGE & SAUVEGARDE DE LA MATRICE DE CONFUSION ==========
def afficher_et_sauver_matrice_confusion(matrice, titre="Matrice de confusion", nom_fichier="confusion_matrix.png"):
    if not isinstance(matrice, list) or not all(isinstance(row, list) for row in matrice):
        print("⚠️ Matrice de confusion non valide")
        return

    cm = np.array(matrice)

    # Créer le dossier plots/ s'il n'existe pas
    os.makedirs("plots", exist_ok=True)

    plt.figure(figsize=(6, 5))
    sns.heatmap(cm, annot=True, fmt='d', cmap='Blues')
    plt.title(titre)
    plt.xlabel("Prédit")
    plt.ylabel("Réel")
    plt.tight_layout()

    # Sauvegarde
    chemin_fichier = os.path.join("plots", nom_fichier)
    plt.savefig(chemin_fichier)
    print(f"📸 Matrice de confusion sauvegardée dans {chemin_fichier}")

    # Affichage
    plt.show()


# ========== SAUVEGARDE DES MÉTRIQUES DANS CSV ==========
def enregistrer_metrics_csv(result):
    csv_file = "historique_modeles.csv"
    champs = [
        "date",
        "version_modele",
        "accuracy_test",
        "f1_score_test",
        "precision_test",
        "recall_test",
        "accuracy_validation",
        "f1_score_validation",
        "precision_validation",
        "recall_validation"
    ]

    date_now = datetime.now().strftime("%Y-%m-%d %H:%M")
    ligne = {
        "date": date_now,
        "version_modele": result.get("model_version"),
        "accuracy_test": result.get("test_metrics", {}).get("accuracy"),
        "f1_score_test": result.get("test_metrics", {}).get("f1_score"),
        "precision_test": result.get("test_metrics", {}).get("precision"),
        "recall_test": result.get("test_metrics", {}).get("recall"),
        "accuracy_validation": result.get("validation_metrics", {}).get("accuracy"),
        "f1_score_validation": result.get("validation_metrics", {}).get("f1_score"),
        "precision_validation": result.get("validation_metrics", {}).get("precision"),
        "recall_validation": result.get("validation_metrics", {}).get("recall")
    }

    fichier_existe = os.path.isfile(csv_file)
    with open(csv_file, mode='a', newline='', encoding='utf-8') as fichier:
        writer = csv.DictWriter(fichier, fieldnames=champs)
        if not fichier_existe:
            writer.writeheader()
        writer.writerow(ligne)

    print(f"✅ Métriques enregistrées dans {csv_file}")


# ========== RÉENTRAÎNEMENT DU MODÈLE ==========
def test_retrain_with_files():
    url = "http://localhost:5000/retrain"

    files = {
        'training_data': ('training_data.csv', open('training_data.csv', 'rb'), 'text/csv'),
        'test_data': ('test_data.csv', open('test_data.csv', 'rb'), 'text/csv'),
        'validation_data': ('validation_data.csv', open('validation_data.csv', 'rb'), 'text/csv')
    }

    try:
        print("Envoi des fichiers pour réentraînement...")
        response = requests.post(url, files=files)

        if response.status_code == 200:
            result = response.json()
            print("✅ Réentraînement réussi!")
            print(f"Version du modèle: {result['model_version']}")
            print(f"Échantillons d'entraînement: {result['training_samples']}")
            print(f"Caractéristiques utilisées: {result['features_used']}")

            print("\n📊 Métriques sur les données de test:")
            test_metrics = result.get('test_metrics', {})
            for metric, value in test_metrics.items():
                if metric == 'confusion_matrix':
                    afficher_et_sauver_matrice_confusion(
                        value,
                        titre="Matrice de confusion - Test",
                        nom_fichier="confusion_matrix_test.png"
                    )
                elif isinstance(value, (int, float)):
                    print(f"  {metric}: {value:.4f}")
                else:
                    print(f"  {metric}: N/A")

            print("\n📊 Métriques sur les données de validation:")
            val_metrics = result.get('validation_metrics', {})
            for metric, value in val_metrics.items():
                if metric == 'confusion_matrix':
                    afficher_et_sauver_matrice_confusion(
                        value,
                        titre="Matrice de confusion - Validation",
                        nom_fichier="confusion_matrix_validation.png"
                    )
                elif isinstance(value, (int, float)):
                    print(f"  {metric}: {value:.4f}")
                else:
                    print(f"  {metric}: N/A")

            enregistrer_metrics_csv(result)

        else:
            print(f"❌ Erreur: {response.status_code}")
            print(response.text)

    except Exception as e:
        print(f"❌ Erreur lors du test: {str(e)}")

    finally:
        for file_obj in files.values():
            file_obj[1].close()


# ========== INFOS SYSTÈME ==========
def test_health_check():
    url = "http://localhost:5000/health"
    try:
        response = requests.get(url)
        if response.status_code == 200:
            result = response.json()
            print("✅ Service en ligne")
            print(f"Version: {result['version']}")
            print(f"Modèle chargé: {result['model_loaded']}")
        else:
            print(f"❌ Service non disponible: {response.status_code}")
    except Exception as e:
        print(f"❌ Erreur de connexion: {str(e)}")


def test_model_info():
    url = "http://localhost:5000/model/info"
    try:
        response = requests.get(url)
        if response.status_code == 200:
            result = response.json()
            print("✅ Informations du modèle:")
            print(json.dumps(result, indent=2))
        else:
            print(f"❌ Erreur: {response.status_code}")
    except Exception as e:
        print(f"❌ Erreur: {str(e)}")


# ========== LANCEMENT ==========
if __name__ == "__main__":
    print("🔄 Test du système de réentraînement")
    print("=" * 50)

    print("\n1. Vérification du service...")
    test_health_check()

    print("\n2. Informations du modèle actuel...")
    test_model_info()

    print("\n3. Test du réentraînement...")
    test_retrain_with_files()

    print("\n4. Vérification après réentraînement...")
    test_model_info()
