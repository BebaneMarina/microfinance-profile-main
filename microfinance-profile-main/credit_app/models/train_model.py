# train_model.py
"""
Script pour entraîner le modèle Random Forest
"""
from scoring_model import PostgresCreditScoringModel

if __name__ == "__main__":
    # Configuration PostgreSQL
    db_config = {
        'host': 'localhost',
        'database': 'credit_scoring',
        'user': 'postgres',
        'password': 'admin',
        'port': 5432
    }
    
    print("=" * 60)
    print("🚀 ENTRAÎNEMENT DU MODÈLE RANDOM FOREST")
    print("=" * 60)
    
    # Initialiser et entraîner
    model = PostgresCreditScoringModel(db_config)
    
    # Tester sur quelques utilisateurs
    print("\n" + "=" * 60)
    print("🧪 TEST DU MODÈLE")
    print("=" * 60)
    
    for user_id in [1, 2, 3, 31, 71, 91]:
        try:
            result = model.calculate_comprehensive_score(user_id)
            print(f"\n👤 Utilisateur {user_id}:")
            print(f"   Score: {result['score']}/10")
            print(f"   Risque: {result['niveau_risque']}")
            print(f"   Montant éligible: {result['montant_eligible']:,} FCFA")
            print(f"   Modèle: {result['model_type']}")
        except Exception as e:
            print(f"   ❌ Erreur: {e}")
    
    print("\n" + "=" * 60)
    print("✅ ENTRAÎNEMENT TERMINÉ")
    print("=" * 60)