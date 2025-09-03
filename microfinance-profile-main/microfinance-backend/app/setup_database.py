# setup_database.py - Script complet de création de la base de données
import os
import sys
import psycopg2
from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
import logging

# Configuration des logs
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Configuration de base de données
DB_CONFIG = {
    'host': 'localhost',
    'port': 5432,
    'user': 'postgres',
    'password': 'admin',  # Changez selon votre configuration
    'database': 'credit_scoring2'
}

def create_database():
    """Crée la base de données credit_scoring si elle n'existe pas"""
    try:
        # Connexion au serveur PostgreSQL (base postgres par défaut)
        conn = psycopg2.connect(
            host=DB_CONFIG['host'],
            port=DB_CONFIG['port'],
            user=DB_CONFIG['user'],
            password=DB_CONFIG['password'],
            database='postgres'  # Base par défaut
        )
        conn.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
        cursor = conn.cursor()
        
        # Vérifier si la base existe
        cursor.execute("""
            SELECT 1 FROM pg_catalog.pg_database 
            WHERE datname = %s
        """, (DB_CONFIG['database'],))
        
        exists = cursor.fetchone()
        
        if not exists:
            logger.info(f"Création de la base de données '{DB_CONFIG['database']}'...")
            cursor.execute(f'CREATE DATABASE "{DB_CONFIG["database"]}"')
            logger.info("✅ Base de données créée avec succès")
        else:
            logger.info(f"ℹ️ Base de données '{DB_CONFIG['database']}' existe déjà")
        
        cursor.close()
        conn.close()
        
    except Exception as e:
        logger.error(f"❌ Erreur création base de données: {e}")
        return False
    
    return True

def create_extensions():
    """Crée les extensions PostgreSQL nécessaires"""
    try:
        database_url = f"postgresql://{DB_CONFIG['user']}:{DB_CONFIG['password']}@{DB_CONFIG['host']}:{DB_CONFIG['port']}/{DB_CONFIG['database']}"
        engine = create_engine(database_url)
        
        with engine.connect() as conn:
            # Créer les extensions
            extensions = [
                'CREATE EXTENSION IF NOT EXISTS "uuid-ossp"',
                'CREATE EXTENSION IF NOT EXISTS "pgcrypto"'
            ]
            
            for ext in extensions:
                conn.execute(text(ext))
                conn.commit()
            
            logger.info("✅ Extensions PostgreSQL créées")
        
    except Exception as e:
        logger.error(f"❌ Erreur création extensions: {e}")
        return False
    
    return True

def create_tables():
    """Crée toutes les tables via SQLAlchemy"""
    try:
        # Import des modèles (assurez-vous que le path est correct)
        sys.path.append(os.path.dirname(os.path.abspath(__file__)))
        
        from app.core.database import engine, Base
        from app.models.user import User
        from app.models.credit_cash import CreditCash, CashTransaction
        from app.models.credit_long import CreditLong, CreditLongDocument, CreditLongHistory
        from app.models.scoring import CreditScoring
        
        # Créer toutes les tables
        Base.metadata.create_all(bind=engine)
        logger.info("✅ Toutes les tables ont été créées")
        
    except Exception as e:
        logger.error(f"❌ Erreur création tables: {e}")
        return False
    
    return True

def create_sample_users():
    """Crée des utilisateurs de test avec différents profils"""
    try:
        from app.core.database import SessionLocal
        from app.models.user import User
        from app.services.auth_service import auth_service
        
        db = SessionLocal()
        
        # Utilisateurs de test inspirés de vos composants Angular
        test_users = [
            {
                'email': 'client.excellent@microfinance.com',
                'password': 'test123',
                'first_name': 'Marina',
                'last_name': 'Brunette',
                'phone_number': '077123456',
                'monthly_income': 900000,  # Comme dans votre profile.component.ts
                'profession': 'Ingénieur Senior',
                'employer_name': 'Total Energies',
                'employment_status': 'cdi',
                'work_experience': 48,  # 4 ans
                'credit_score': 8.5,
                'risk_level': 'low',
                'eligible_amount_cash': 800000,
                'eligible_amount_long': 15000000
            },
            {
                'email': 'client.moyen@microfinance.com',
                'password': 'test123',
                'first_name': 'Jean',
                'last_name': 'Ndong',
                'phone_number': '074567890',
                'monthly_income': 450000,  # Profil moyen
                'profession': 'Technicien',
                'employer_name': 'Petro Services',
                'employment_status': 'cdd',
                'work_experience': 24,
                'credit_score': 6.2,
                'risk_level': 'medium',
                'eligible_amount_cash': 300000,
                'eligible_amount_long': 3000000
            },
            {
                'email': 'client.faible@microfinance.com',
                'password': 'test123',
                'first_name': 'Sophie',
                'last_name': 'Mfoubou',
                'phone_number': '066789012',
                'monthly_income': 180000,  # Profil plus risqué
                'profession': 'Commerçante',
                'employer_name': 'Auto-entrepreneur',
                'employment_status': 'independant',
                'work_experience': 12,
                'credit_score': 4.1,
                'risk_level': 'high',
                'eligible_amount_cash': 100000,
                'eligible_amount_long': 0
            },
            {
                'email': 'agent@microfinance.com',
                'password': 'agent123',
                'first_name': 'Pierre',
                'last_name': 'Agent',
                'phone_number': '077999888',
                'monthly_income': 600000,
                'profession': 'Agent Commercial',
                'employment_status': 'cdi',
                'work_experience': 36,
                'credit_score': 7.0,
                'risk_level': 'low'
            }
        ]
        
        for user_data in test_users:
            # Vérifier si l'utilisateur existe déjà
            existing_user = db.query(User).filter(User.email == user_data['email']).first()
            
            if not existing_user:
                # Créer l'utilisateur
                user = User(
                    email=user_data['email'],
                    password_hash=auth_service.get_password_hash(user_data['password']),
                    first_name=user_data['first_name'],
                    last_name=user_data['last_name'],
                    phone_number=user_data['phone_number'],
                    monthly_income=user_data['monthly_income'],
                    profession=user_data['profession'],
                    employer_name=user_data.get('employer_name'),
                    employment_status=user_data['employment_status'],
                    work_experience=user_data['work_experience'],
                    credit_score=user_data.get('credit_score', 6.0),
                    risk_level=user_data.get('risk_level', 'medium'),
                    eligible_amount_cash=user_data.get('eligible_amount_cash', 0),
                    eligible_amount_long=user_data.get('eligible_amount_long', 0)
                )
                
                db.add(user)
                logger.info(f"✅ Utilisateur créé: {user_data['email']}")
            else:
                logger.info(f"ℹ️ Utilisateur existe déjà: {user_data['email']}")
        
        db.commit()
        db.close()
        
        # Afficher les comptes de test
        print("\n" + "="*60)
        print("🎯 COMPTES DE TEST CRÉÉS")
        print("="*60)
        print("1. Client Excellent Score:")
        print("   Email: client.excellent@microfinance.com")
        print("   Password: test123")
        print("   Score: 8.5 - Éligible cash: 800k, long: 15M")
        print()
        print("2. Client Score Moyen:")
        print("   Email: client.moyen@microfinance.com") 
        print("   Password: test123")
        print("   Score: 6.2 - Éligible cash: 300k, long: 3M")
        print()
        print("3. Client Score Faible:")
        print("   Email: client.faible@microfinance.com")
        print("   Password: test123")
        print("   Score: 4.1 - Éligible cash: 100k seulement")
        print()
        print("4. Agent:")
        print("   Email: agent@microfinance.com")
        print("   Password: agent123")
        print("="*60)
        
    except Exception as e:
        logger.error(f"❌ Erreur création utilisateurs: {e}")
        return False
    
    return True

def create_sample_credit_types():
    """Crée les types de crédit disponibles (table de référence)"""
    try:
        from app.core.database import SessionLocal
        
        db = SessionLocal()
        
        # Créer une table simple pour les types de crédit si nécessaire
        # Inspiré de votre creditTypes dans profile.component.ts
        credit_types_sql = """
        CREATE TABLE IF NOT EXISTS credit_types (
            id VARCHAR(50) PRIMARY KEY,
            name VARCHAR(100) NOT NULL,
            description TEXT,
            max_amount INTEGER,
            max_duration INTEGER, -- en mois
            interest_rate DECIMAL(5,4),
            available_for_particulier BOOLEAN DEFAULT true,
            available_for_entreprise BOOLEAN DEFAULT false,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
        """
        
        db.execute(text(credit_types_sql))
        
        # Insérer les types de crédit de votre composant Angular
        credit_types_data = """
        INSERT INTO credit_types (id, name, description, max_amount, max_duration, interest_rate, available_for_particulier, available_for_entreprise)
        VALUES 
        ('consommation_generale', 'Crédit Consommation', 'Pour vos besoins personnels', 2000000, 1, 0.0500, true, false),
        ('avance_salaire', 'Avance sur Salaire', 'Jusqu''à 70% de votre salaire net', 2000000, 1, 0.0300, true, false),
        ('depannage', 'Crédit Dépannage', 'Solution urgente pour liquidités', 2000000, 1, 0.0400, true, false),
        ('investissement', 'Crédit Investissement', 'Pour les entreprises uniquement', 100000000, 36, 0.0800, false, true),
        ('tontine', 'Crédit Tontine', 'Réservé aux membres cotisants', 5000000, 12, 0.0600, true, false),
        ('retraite', 'Crédit Retraite', 'Pour les retraités CNSS/CPPF', 2000000, 12, 0.0400, true, false)
        ON CONFLICT (id) DO NOTHING;
        """
        
        db.execute(text(credit_types_data))
        db.commit()
        db.close()
        
        logger.info("✅ Types de crédit créés (inspirés de votre Angular)")
        
    except Exception as e:
        logger.error(f"❌ Erreur création types de crédit: {e}")
        return False
    
    return True

def verify_setup():
    """Vérifie que tout est correctement configuré"""
    try:
        from app.core.database import SessionLocal
        from app.models.user import User
        from app.models.credit_cash import CreditCash
        from app.models.credit_long import CreditLong
        
        db = SessionLocal()
        
        # Compter les utilisateurs
        user_count = db.query(User).count()
        cash_count = db.query(CreditCash).count()
        long_count = db.query(CreditLong).count()
        
        print("\n" + "="*50)
        print("📊 VÉRIFICATION DE LA BASE DE DONNÉES")
        print("="*50)
        print(f"👥 Utilisateurs: {user_count}")
        print(f"💰 Crédits cash: {cash_count}")
        print(f"📝 Crédits long: {long_count}")
        print("="*50)
        
        db.close()
        
    except Exception as e:
        logger.error(f"❌ Erreur vérification: {e}")
        return False
    
    return True

def main():
    """Script principal d'initialisation"""
    print("🚀 INITIALISATION DE LA BASE DE DONNÉES MICROFINANCE")
    print("Inspiré de vos composants Angular credit-long-request et profile")
    print("-" * 60)
    
    steps = [
        ("Création de la base de données", create_database),
        ("Création des extensions PostgreSQL", create_extensions), 
        ("Création des tables", create_tables),
        ("Création des types de crédit", create_sample_credit_types),
        ("Création des utilisateurs de test", create_sample_users),
        ("Vérification finale", verify_setup)
    ]
    
    for step_name, step_func in steps:
        print(f"\n📋 {step_name}...")
        if not step_func():
            print(f"❌ Échec: {step_name}")
            sys.exit(1)
    
    print("\n🎉 SUCCÈS - Base de données initialisée!")
    print("\n🌐 Vous pouvez maintenant démarrer l'API:")
    print("   python run.py")
    print("\n📖 Documentation API:")
    print("   http://localhost:8000/docs")

if __name__ == "__main__":
    main()

# requirements_setup.txt - Dépendances pour ce script
"""
psycopg2-binary==2.9.9
sqlalchemy==2.0.23
"""

# Dockerfile pour créer la base automatiquement
# docker_db_setup.dockerfile
"""
FROM postgres:15-alpine

# Copier le script d'initialisation
COPY setup_database.py /docker-entrypoint-initdb.d/
COPY requirements_setup.txt /tmp/

# Installer Python pour exécuter le script
RUN apk add --no-cache python3 py3-pip
RUN pip3 install -r /tmp/requirements_setup.txt

ENV POSTGRES_DB=credit_scoring
ENV POSTGRES_USER=postgres
ENV POSTGRES_PASSWORD=password
"""

# docker-compose-db.yml - Pour démarrer juste la base
"""
version: '3.8'
services:
  postgres:
    build: 
      context: .
      dockerfile: docker_db_setup.dockerfile
    environment:
      POSTGRES_DB: credit_scoring
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: password
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
volumes:
  postgres_data:
"""