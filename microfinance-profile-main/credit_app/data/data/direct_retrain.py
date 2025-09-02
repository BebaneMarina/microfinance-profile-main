#!/usr/bin/env python3
"""
Script direct pour réentraîner le modèle de scoring crédit
Utilisez ce script si vous voulez réentraîner sans passer par l'API
"""

import sys
import os
from retrain_model import CreditScoringRetrainer

def main():
    """Fonction principale"""
    
    # Vérifier que les fichiers existent
    required_files = ["training_data.csv", "test_data.csv", "validation_data.csv"]
    
    print("🔍 Vérification des fichiers...")
    for file in required_files:
        if not os.path.exists(file):
            print(f"❌ Fichier manquant: {file}")
            print("Assurez-vous que les fichiers suivants sont présents:")
            for f in required_files:
                print(f"  - {f}")
            return False
        else:
            print(f"✅ {file} trouvé")
    
    # Initialiser le réentraîneur
    print("\n🤖 Initialisation du réentraîneur...")
    retrainer = CreditScoringRetrainer()
    
    try:
        # Lancer le réentraînement complet
        print("🚀 Début du réentraînement...")
        results = retrainer.retrain_complete_pipeline(
            "training_data.csv",
            "test_data.csv", 
            "validation_data.csv"
        )
        
        # Afficher les résultats
        print("\n" + "="*60)
        print("🎉 RÉENTRAÎNEMENT TERMINÉ AVEC SUCCÈS!")
        print("="*60)
        
        print(f"📊 Status: {results['status']}")
        print(f"📅 Timestamp: {results['timestamp']}")
        print(f"🔖 Version du modèle: {results['model_version']}")
        print(f"📈 Échantillons d'entraînement: {results['training_samples']:,}")
        print(f"🎯 Caractéristiques utilisées: {results['features_used']}")
        
        print("\n📋 MÉTRIQUES SUR LES DONNÉES DE VALIDATION:")
        print("-" * 40)
        val_metrics = results['validation_metrics']
        print(f"  Accuracy:  {val_metrics['accuracy']:.4f}")
        print(f"  Precision: {val_metrics['precision']:.4f}")
        print(f"  Recall:    {val_metrics['recall']:.4f}")
        print(f"  F1-Score:  {val_metrics['f1_score']:.4f}")
        if val_metrics['auc_score']:
            print(f"  AUC:       {val_metrics['auc_score']:.4f}")
        
        print("\n💾 FICHIERS SAUVEGARDÉS:")
        print("-" * 40)
        print("  📁 models/credit_scoring_model.pkl")
        print("  📁 models/scaler.pkl")
        print("  📁 models/label_encoders.pkl")
        print("  📁 models/feature_columns.pkl")
        
        # Sauvegarder les métriques dans un fichier JSON
        import json
        metrics_file = f"models/training_metrics_{results['model_version']}.json"
        with open(metrics_file, 'w') as f:
            json.dump(results, f, indent=2)
        print(f"  📁 {metrics_file}")
        
        # Sauvegarder aussi comme dernier entraînement
        with open('models/last_training_metrics.json', 'w') as f:
            json.dump(results, f, indent=2)
        print("  📁 models/last_training_metrics.json")
        
        print("\n✅ Le modèle est prêt à être utilisé!")
        print("💡 Redémarrez votre application Flask pour charger le nouveau modèle.")
        
        return True
        
    except Exception as e:
        print(f"\n❌ ERREUR LORS DU RÉENTRAÎNEMENT:")
        print(f"   {str(e)}")
        print("\n🔍 Vérifiez:")
        print("  - Format des fichiers CSV")
        print("  - Présence des colonnes requises")
        print("  - Qualité des données")
        return False

def show_data_info():
    """Affiche des informations sur les données"""
    import pandas as pd
    
    print("\n📊 INFORMATIONS SUR LES DONNÉES:")
    print("="*50)
    
    files = {
        "Training": "training_data.csv",
        "Test": "test_data.csv", 
        "Validation": "validation_data.csv"
    }
    
    for name, file in files.items():
        if os.path.exists(file):
            try:
                df = pd.read_csv(file)
                print(f"\n📋 {name} ({file}):")
                print(f"  • Lignes: {len(df):,}")
                print(f"  • Colonnes: {len(df.columns)}")
                print(f"  • Valeurs manquantes: {df.isnull().sum().sum():,}")
                
                # Distribution de la variable cible
                if 'decision_credit' in df.columns:
                    target_dist = df['decision_credit'].value_counts()
                    print(f"  • Distribution de decision_credit:")
                    for value, count in target_dist.items():
                        print(f"    - {value}: {count:,} ({count/len(df)*100:.1f}%)")
                
            except Exception as e:
                print(f"  ❌ Erreur lors de la lecture: {str(e)}")
        else:
            print(f"\n❌ {name} ({file}): Fichier non trouvé")

def validate_data_structure():
    """Valide la structure des données"""
    print("\n🔍 VALIDATION DE LA STRUCTURE DES DONNÉES:")
    print("="*50)
    
    required_columns = [
        'age', 'sexe', 'situation_familiale', 'nombre_enfants', 'niveau_etude',
        'type_emploi', 'secteur_activite', 'anciennete_emploi', 'type_contrat',
        'revenu_mensuel', 'autres_revenus', 'charges_mensuelles', 'nombre_dependants',
        'anciennete_banque', 'solde_moyen', 'decouvert_frequence', 'incidents_paiement',
        'historique_credit', 'type_credit', 'montant_demande', 'duree_demande',
        'objet_credit', 'garanties_physiques', 'avaliste', 'domiciliation_salaire',
        'utilisation_mobile_banking', 'frequence_transactions', 'epargne_reguliere',
        'participation_tontine', 'verification_identite', 'verification_revenus',
        'score_bureaux_credit', 'region', 'zone_residence', 'taux_endettement',
        'ratio_montant_revenu', 'score_credit', 'niveau_risque', 'decision_credit'
    ]
    
    import pandas as pd
    
    files = ["training_data.csv", "test_data.csv", "validation_data.csv"]
    all_valid = True
    
    for file in files:
        if os.path.exists(file):
            try:
                df = pd.read_csv(file)
                print(f"\n📋 {file}:")
                
                missing_cols = [col for col in required_columns if col not in df.columns]
                extra_cols = [col for col in df.columns if col not in required_columns]
                
                if missing_cols:
                    print(f"  ❌ Colonnes manquantes: {missing_cols}")
                    all_valid = False
                
                if extra_cols:
                    print(f"  ⚠️  Colonnes supplémentaires: {extra_cols}")
                
                if not missing_cols and not extra_cols:
                    print("  ✅ Structure correcte")
                elif not missing_cols:
                    print("  ✅ Toutes les colonnes requises présentes")
                    
            except Exception as e:
                print(f"  ❌ Erreur: {str(e)}")
                all_valid = False
    
    return all_valid

if __name__ == "__main__":
    print("🎯 RÉENTRAÎNEMENT DU MODÈLE DE SCORING CRÉDIT")
    print("=" * 60)
    
    # Vérifier les arguments
    if len(sys.argv) > 1:
        if sys.argv[1] == "--info":
            show_data_info()
            sys.exit(0)
        elif sys.argv[1] == "--validate":
            if validate_data_structure():
                print("\n✅ Validation réussie! Vous pouvez procéder au réentraînement.")
            else:
                print("\n❌ Validation échouée! Corrigez les problèmes avant de continuer.")
            sys.exit(0)
        elif sys.argv[1] == "--help":
            print("\nUtilisation:")
            print("  python direct_retrain.py           # Réentraîner le modèle")
            print("  python direct_retrain.py --info    # Afficher infos sur les données")
            print("  python direct_retrain.py --validate # Valider la structure des données")
            print("  python direct_retrain.py --help    # Afficher cette aide")
            sys.exit(0)
    
    # Validation préalable
    print("1️⃣ Validation de la structure des données...")
    if not validate_data_structure():
        print("\n❌ Validation échouée! Corrigez les problèmes avant de continuer.")
        sys.exit(1)
    
    # Afficher les informations sur les données
    show_data_info()
    
    # Demander confirmation
    print("\n⚠️  ATTENTION: Le réentraînement va remplacer le modèle actuel.")
    response = input("Voulez-vous continuer? (oui/non): ").lower().strip()
    
    if response not in ['oui', 'o', 'yes', 'y']:
        print("❌ Réentraînement annulé.")
        sys.exit(0)
    
    # Lancer le réentraînement
    print("\n2️⃣ Début du réentraînement...")
    success = main()
    
    if success:
        print("\n🎉 RÉENTRAÎNEMENT TERMINÉ AVEC SUCCÈS!")
        sys.exit(0)
    else:
        print("\n❌ RÉENTRAÎNEMENT ÉCHOUÉ!")
        sys.exit(1) 
        print("-" * 40)
        test_metrics = results['test_metrics']
        print(f"  Accuracy:  {test_metrics['accuracy']:.4f}")
        print(f"  Precision: {test_metrics['precision']:.4f}")
        print(f"  Recall:    {test_metrics['recall']:.4f}")
        print(f"  F1-Score:  {test_metrics['f1_score']:.4f}")
        if test_metrics['auc_score']:
            print(f"  AUC:       {test_metrics['auc_score']:.4f}")
        
        print("\n📋 MÉTRIQUES SUR LES DONNÉES DE test:")