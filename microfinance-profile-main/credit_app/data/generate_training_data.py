"""
Générateur de données d'entraînement pour le modèle de scoring
"""
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import random
import os

def generate_training_data(n_samples=10000):
    """Génère des données d'entraînement simulées pour le modèle de scoring"""
    
    np.random.seed(42)
    random.seed(42)
    
    # Données de base
    data = {
        'client_id': [f'CLI_{i:06d}' for i in range(1, n_samples + 1)],
        'date_demande': [
            (datetime.now() - timedelta(days=random.randint(0, 365))).strftime('%Y-%m-%d')
            for _ in range(n_samples)
        ],
        
        # Informations personnelles
        'age': np.random.normal(35, 10, n_samples).astype(int),
        'sexe': np.random.choice(['M', 'F'], n_samples, p=[0.6, 0.4]),
        'situation_familiale': np.random.choice(
            ['celibataire', 'marie', 'divorce', 'veuf'], 
            n_samples, 
            p=[0.3, 0.5, 0.15, 0.05]
        ),
        'nombre_enfants': np.random.poisson(2, n_samples),
        'niveau_etude': np.random.choice(
            ['primaire', 'secondaire', 'superieur'], 
            n_samples, 
            p=[0.2, 0.5, 0.3]
        ),
        
        # Informations professionnelles
        'type_emploi': np.random.choice(
            ['salarie_prive', 'salarie_public', 'independant', 'retraite'], 
            n_samples, 
            p=[0.4, 0.3, 0.25, 0.05]
        ),
        'secteur_activite': np.random.choice(
            ['commerce', 'industrie', 'services', 'agriculture', 'administration'], 
            n_samples, 
            p=[0.25, 0.15, 0.3, 0.15, 0.15]
        ),
        'anciennete_emploi': np.random.exponential(3, n_samples),
        'type_contrat': np.random.choice(
            ['CDI', 'CDD', 'freelance', 'retraite'], 
            n_samples, 
            p=[0.5, 0.2, 0.25, 0.05]
        ),
        
        # Informations financières
        'revenu_mensuel': np.random.lognormal(12.5, 0.8, n_samples),
        'autres_revenus': np.random.exponential(50000, n_samples),
        'charges_mensuelles': np.random.lognormal(11.8, 0.6, n_samples),
        'nombre_dependants': np.random.poisson(2, n_samples),
        
        # Historique bancaire
        'anciennete_banque': np.random.exponential(2, n_samples),
        'solde_moyen': np.random.lognormal(11, 1.2, n_samples),
        'decouvert_frequence': np.random.poisson(2, n_samples),
        'incidents_paiement': np.random.poisson(0.5, n_samples),
        'historique_credit': np.random.choice([0, 1], n_samples, p=[0.3, 0.7]),
        
        # Informations sur le crédit demandé
        'type_credit': np.random.choice(
            ['consommation', 'investissement', 'avance_facture', 'avance_commande', 'tontine', 'retraite', 'spot'],
            n_samples,
            p=[0.35, 0.15, 0.15, 0.10, 0.10, 0.05, 0.10]
        ),
        'montant_demande': np.random.lognormal(13.5, 1, n_samples),
        'duree_demande': np.random.choice(
            [3, 6, 12, 18, 24, 36], 
            n_samples, 
            p=[0.1, 0.15, 0.3, 0.2, 0.15, 0.1]
        ),
        'objet_credit': np.random.choice(
            ['equipement', 'immobilier', 'consommation', 'urgence', 'investissement'],
            n_samples,
            p=[0.2, 0.15, 0.35, 0.15, 0.15]
        ),
        
        # Garanties
        'garanties_physiques': np.random.choice([0, 1], n_samples, p=[0.6, 0.4]),
        'avaliste': np.random.choice([0, 1], n_samples, p=[0.7, 0.3]),
        'domiciliation_salaire': np.random.choice([0, 1], n_samples, p=[0.4, 0.6]),
        
        # Données comportementales
        'utilisation_mobile_banking': np.random.choice([0, 1], n_samples, p=[0.3, 0.7]),
        'frequence_transactions': np.random.poisson(10, n_samples),
        'epargne_reguliere': np.random.choice([0, 1], n_samples, p=[0.6, 0.4]),
        'participation_tontine': np.random.choice([0, 1], n_samples, p=[0.7, 0.3]),
        
        # Données externes
        'verification_identite': np.random.choice([0, 1], n_samples, p=[0.05, 0.95]),
        'verification_revenus': np.random.choice([0, 1], n_samples, p=[0.1, 0.9]),
        'score_bureaux_credit': np.random.normal(500, 150, n_samples),
        
        # Variables géographiques
        'region': np.random.choice(
            ['Libreville', 'Port-Gentil', 'Franceville', 'Oyem', 'Mouila', 'Lambarene'],
            n_samples,
            p=[0.4, 0.2, 0.1, 0.1, 0.1, 0.1]
        ),
        'zone_residence': np.random.choice(
            ['urbaine', 'semi_urbaine', 'rurale'], 
            n_samples, 
            p=[0.6, 0.25, 0.15]
        ),
    }
    
    # Création du DataFrame
    df = pd.DataFrame(data)
    
    # Nettoyage et ajustements
    df['age'] = np.clip(df['age'], 18, 70)
    df['nombre_enfants'] = np.clip(df['nombre_enfants'], 0, 8)
    df['nombre_dependants'] = np.clip(df['nombre_dependants'], 0, 10)
    df['anciennete_emploi'] = np.clip(df['anciennete_emploi'], 0, 40)
    df['anciennete_banque'] = np.clip(df['anciennete_banque'], 0, 30)
    df['decouvert_frequence'] = np.clip(df['decouvert_frequence'], 0, 12)
    df['incidents_paiement'] = np.clip(df['incidents_paiement'], 0, 10)
    df['frequence_transactions'] = np.clip(df['frequence_transactions'], 0, 50)
    df['score_bureaux_credit'] = np.clip(df['score_bureaux_credit'], 200, 800)
    
    # Ajustements logiques
    df.loc[df['type_emploi'] == 'retraite', 'age'] = np.clip(
        np.random.normal(65, 5, sum(df['type_emploi'] == 'retraite')), 60, 80
    )
    
    df.loc[df['type_emploi'] == 'retraite', 'type_contrat'] = 'retraite'
    df.loc[df['type_contrat'] == 'CDI', 'anciennete_emploi'] = np.maximum(
        df.loc[df['type_contrat'] == 'CDI', 'anciennete_emploi'], 1
    )
    
    # Calcul du taux d'endettement
    df['taux_endettement'] = (df['charges_mensuelles'] / df['revenu_mensuel']).fillna(0)
    df['taux_endettement'] = np.clip(df['taux_endettement'], 0, 1)
    
    # Calcul du ratio montant/revenu
    df['ratio_montant_revenu'] = df['montant_demande'] / (df['revenu_mensuel'] * 12)
    
    # Génération du score de crédit (variable cible)
    df['score_credit'] = calculate_credit_score(df)
    
    # Classification du risque
    df['niveau_risque'] = pd.cut(
        df['score_credit'],
        bins=[0, 350, 500, 650, 1000],
        labels=['tres_eleve', 'eleve', 'moyen', 'faible']
    )
    
    # Décision de crédit (variable cible pour classification)
    df['decision_credit'] = np.where(
        df['score_credit'] >= 450, 'accepte',
        np.where(df['score_credit'] >= 300, 'revue_manuelle', 'refuse')
    )
    
    # Simulation du comportement de remboursement
    df['remboursement_ok'] = simulate_repayment_behavior(df)
    
    return df

def calculate_credit_score(df):
    """Calcule le score de crédit basé sur les règles métier"""
    
    score = np.zeros(len(df))
    
    # Score basé sur les revenus (0-200 points)
    score += np.clip(df['revenu_mensuel'] / 3000, 0, 200)
    
    # Score basé sur la stabilité de l'emploi (0-150 points)
    emploi_stable = df['type_contrat'].isin(['CDI', 'retraite'])
    score += emploi_stable * 50
    score += np.clip(df['anciennete_emploi'] * 10, 0, 100)
    
    # Score basé sur le taux d'endettement (0-150 points)
    score += np.clip((0.5 - df['taux_endettement']) * 300, 0, 150)
    
    # Score basé sur l'historique bancaire (0-200 points)
    score += np.clip(df['anciennete_banque'] * 20, 0, 100)
    score += np.clip((5 - df['incidents_paiement']) * 20, 0, 100)
    
    # Score basé sur les garanties (0-100 points)
    score += df['garanties_physiques'] * 30
    score += df['avaliste'] * 30
    score += df['domiciliation_salaire'] * 40
    
    # Score basé sur le comportement (0-100 points)
    score += df['utilisation_mobile_banking'] * 25
    score += df['epargne_reguliere'] * 35
    score += df['participation_tontine'] * 25
    score += np.clip(df['frequence_transactions'] * 2, 0, 15)
    
    # Pénalités
    score -= df['decouvert_frequence'] * 10
    score -= np.clip(df['ratio_montant_revenu'] * 100, 0, 100)
    
    # Score externe des bureaux de crédit
    score += (df['score_bureaux_credit'] - 500) * 0.2
    
    # Ajustements selon l'âge
    age_penalty = np.where(df['age'] < 25, 50, 0) + np.where(df['age'] > 60, 30, 0)
    score -= age_penalty
    
    # Normalisation finale
    score = np.clip(score, 200, 1000)
    
    return score

def simulate_repayment_behavior(df):
    """Simule le comportement de remboursement basé sur le score"""
    
    # Probabilité de bon remboursement basée sur le score
    prob_success = np.clip((df['score_credit'] - 200) / 600, 0.1, 0.95)
    
    # Ajustements selon d'autres facteurs
    prob_success *= np.where(df['garanties_physiques'] == 1, 1.1, 1.0)
    prob_success *= np.where(df['domiciliation_salaire'] == 1, 1.05, 1.0)
    prob_success *= np.where(df['incidents_paiement'] > 2, 0.8, 1.0)
    
    prob_success = np.clip(prob_success, 0.05, 0.98)
    
    return np.random.binomial(1, prob_success, len(df))

def generate_sample_data_files():
    """Génère tous les fichiers de données nécessaires"""
    
    # Créer le répertoire data s'il n'existe pas
    data_dir = 'data'
    if not os.path.exists(data_dir):
        os.makedirs(data_dir)
    
    # Générer les données d'entraînement
    print("Génération des données d'entraînement...")
    train_data = generate_training_data(10000)
    train_data.to_csv(os.path.join(data_dir, 'training_data.csv'), index=False)
    print(f"✓ Données d'entraînement générées: {len(train_data)} échantillons")
    
    # Générer les données de test
    print("Génération des données de test...")
    test_data = generate_training_data(2000)
    test_data.to_csv(os.path.join(data_dir, 'test_data.csv'), index=False)
    print(f"✓ Données de test générées: {len(test_data)} échantillons")
    
    # Générer des données de validation
    print("Génération des données de validation...")
    val_data = generate_training_data(1000)
    val_data.to_csv(os.path.join(data_dir, 'validation_data.csv'), index=False)
    print(f"✓ Données de validation générées: {len(val_data)} échantillons")
    
    # Statistiques descriptives
    print("\n=== Statistiques des données d'entraînement ===")
    print(f"Score moyen: {train_data['score_credit'].mean():.2f}")
    print(f"Score médian: {train_data['score_credit'].median():.2f}")
    print(f"Écart-type: {train_data['score_credit'].std():.2f}")
    print(f"Revenu moyen: {train_data['revenu_mensuel'].mean():.0f} FCFA")
    print(f"Taux d'endettement moyen: {train_data['taux_endettement'].mean():.2%}")
    
    print("\nRépartition des décisions:")
    print(train_data['decision_credit'].value_counts())
    
    print("\nRépartition des niveaux de risque:")
    print(train_data['niveau_risque'].value_counts())
    
    print("\nRépartition des types de crédit:")
    print(train_data['type_credit'].value_counts())

if __name__ == "__main__":
    generate_sample_data_files()