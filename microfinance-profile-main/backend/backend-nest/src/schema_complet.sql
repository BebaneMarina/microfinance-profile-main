-- =====================================================
-- CRÉATION DE LA BASE DE DONNÉES
-- =====================================================
-- Note: Exécutez ces commandes séparément si nécessaire
-- DROP DATABASE IF EXISTS credit_scoring;
-- CREATE DATABASE credit_scoring;

-- Se connecter à la base de données credit_scoring
\c credit_scoring;

-- =====================================================
-- EXTENSIONS REQUISES
-- =====================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =====================================================
-- ENUM TYPES
-- =====================================================

-- Types d'utilisateurs
CREATE TYPE user_role AS ENUM ('admin', 'agent', 'client', 'super_admin');
CREATE TYPE user_status AS ENUM ('active', 'inactive', 'suspended', 'deleted');

-- Types de crédit
CREATE TYPE credit_type AS ENUM (
    'consommation_generale',
    'avance_salaire',
    'depannage',
    'investissement',
    'avance_facture',
    'avance_commande',
    'tontine',
    'retraite',
    'spot'
);

-- Statuts de demande
CREATE TYPE request_status AS ENUM (
    'draft',
    'submitted',
    'in_review',
    'approved',
    'rejected',
    'cancelled',
    'disbursed',
    'completed'
);

-- Statuts de remboursement
CREATE TYPE payment_status AS ENUM (
    'pending',
    'paid',
    'partial',
    'overdue',
    'defaulted'
);

-- Types de documents
CREATE TYPE document_type AS ENUM (
    'identity',
    'salary_slip',
    'employment_certificate',
    'bank_statement',
    'utility_bill',
    'debt_certificate',
    'other'
);

-- Niveau de risque
CREATE TYPE risk_level AS ENUM (
    'very_low',
    'low',
    'medium',
    'high',
    'very_high'
);

-- =====================================================
-- TABLE: users (Utilisateurs)
-- =====================================================
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    uuid UUID DEFAULT uuid_generate_v4() UNIQUE,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    middle_name VARCHAR(100),
    phone_number VARCHAR(20) UNIQUE,
    phone_number2 VARCHAR(20),
    role user_role DEFAULT 'client',
    status user_status DEFAULT 'active',
    
    -- Informations personnelles
    birth_date DATE,
    birth_place VARCHAR(255),
    nationality VARCHAR(100),
    gender VARCHAR(10),
    marital_status VARCHAR(20),
    dependents INTEGER DEFAULT 0,
    
    -- Adresse
    address TEXT,
    city VARCHAR(100),
    district VARCHAR(100),
    country VARCHAR(100) DEFAULT 'Gabon',
    
    -- Identité
    identity_type VARCHAR(50),
    identity_number VARCHAR(100) UNIQUE,
    identity_issue_date DATE,
    identity_expiry_date DATE,
    
    -- Professionnel
    profession VARCHAR(255),
    employer_name VARCHAR(255),
    employment_status VARCHAR(50),
    monthly_income DECIMAL(12, 2),
    work_experience INTEGER, -- en mois
    
    -- Préférences
    language VARCHAR(10) DEFAULT 'fr',
    currency VARCHAR(10) DEFAULT 'XAF',
    
    -- Sécurité
    two_factor_enabled BOOLEAN DEFAULT FALSE,
    biometric_enabled BOOLEAN DEFAULT FALSE,
    last_login_at TIMESTAMP,
    last_login_ip INET,
    failed_login_attempts INTEGER DEFAULT 0,
    locked_until TIMESTAMP,
    
    -- Métadonnées
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by INTEGER REFERENCES users(id),
    updated_by INTEGER REFERENCES users(id)
);

-- =====================================================
-- TABLE: credit_requests (Demandes de crédit)
-- =====================================================
CREATE TABLE credit_requests (
    id SERIAL PRIMARY KEY,
    request_number VARCHAR(50) UNIQUE NOT NULL,
    user_id INTEGER NOT NULL REFERENCES users(id),
    credit_type credit_type NOT NULL,
    status request_status DEFAULT 'draft',
    
    -- Montants et durées
    requested_amount DECIMAL(12, 2) NOT NULL,
    approved_amount DECIMAL(12, 2),
    duration_months INTEGER NOT NULL,
    interest_rate DECIMAL(5, 2),
    
    -- Détails du crédit
    purpose TEXT NOT NULL,
    repayment_mode VARCHAR(50),
    repayment_frequency VARCHAR(50),
    
    -- Champs spécifiques dépannage
    liquidity_problem TEXT,
    urgency_justification TEXT,
    solutions_envisaged TEXT,
    cash_flow_status VARCHAR(50),
    
    -- Scoring et décision
    credit_score INTEGER,
    risk_level risk_level,
    probability DECIMAL(5, 2),
    decision VARCHAR(50),
    decision_date TIMESTAMP,
    decision_by INTEGER REFERENCES users(id),
    decision_notes TEXT,
    
    -- Documents et vérifications
    kyc_verified BOOLEAN DEFAULT FALSE,
    kyc_verified_date TIMESTAMP,
    kyc_verified_by INTEGER REFERENCES users(id),
    
    -- Décaissement
    disbursement_date TIMESTAMP,
    disbursement_method VARCHAR(50),
    disbursement_reference VARCHAR(100),
    
    -- Métadonnées
    submission_date TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Contraintes
    CONSTRAINT chk_amounts CHECK (requested_amount > 0),
    CONSTRAINT chk_duration CHECK (duration_months > 0)
);

-- =====================================================
-- TABLE: credit_scoring (Historique de scoring)
-- =====================================================
CREATE TABLE credit_scoring (
    id SERIAL PRIMARY KEY,
    credit_request_id INTEGER REFERENCES credit_requests(id),
    user_id INTEGER NOT NULL REFERENCES users(id),
    
    -- Résultats du scoring
    total_score INTEGER NOT NULL,
    risk_level risk_level NOT NULL,
    probability DECIMAL(5, 2),
    decision VARCHAR(50),
    
    -- Détails du calcul
    income_score INTEGER,
    employment_score INTEGER,
    debt_ratio_score INTEGER,
    credit_history_score INTEGER,
    behavioral_score INTEGER,
    
    -- Facteurs
    factors JSONB,
    recommendations TEXT[],
    
    -- ML Model info
    model_version VARCHAR(50),
    processing_time DECIMAL(5, 2), -- en secondes
    
    -- Métadonnées
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by INTEGER REFERENCES users(id)
);

-- =====================================================
-- TABLE: loan_contracts (Contrats de prêt)
-- =====================================================
CREATE TABLE loan_contracts (
    id SERIAL PRIMARY KEY,
    contract_number VARCHAR(50) UNIQUE NOT NULL,
    credit_request_id INTEGER UNIQUE REFERENCES credit_requests(id),
    user_id INTEGER NOT NULL REFERENCES users(id),
    
    -- Détails du contrat
    loan_amount DECIMAL(12, 2) NOT NULL,
    interest_rate DECIMAL(5, 2) NOT NULL,
    duration_months INTEGER NOT NULL,
    monthly_payment DECIMAL(12, 2) NOT NULL,
    total_amount DECIMAL(12, 2) NOT NULL,
    total_interest DECIMAL(12, 2) NOT NULL,
    
    -- Dates importantes
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    first_payment_date DATE NOT NULL,
    
    -- Statut
    status VARCHAR(50) DEFAULT 'active',
    early_settlement_date DATE,
    early_settlement_amount DECIMAL(12, 2),
    
    -- Signature
    signed_date TIMESTAMP,
    signature_method VARCHAR(50),
    
    -- Métadonnées
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- TABLE: repayment_schedule (Échéancier)
-- =====================================================
CREATE TABLE repayment_schedule (
    id SERIAL PRIMARY KEY,
    loan_contract_id INTEGER NOT NULL REFERENCES loan_contracts(id),
    
    -- Détails de l'échéance
    payment_number INTEGER NOT NULL,
    due_date DATE NOT NULL,
    principal_amount DECIMAL(12, 2) NOT NULL,
    interest_amount DECIMAL(12, 2) NOT NULL,
    total_amount DECIMAL(12, 2) NOT NULL,
    remaining_balance DECIMAL(12, 2) NOT NULL,
    
    -- Statut
    status payment_status DEFAULT 'pending',
    paid_date TIMESTAMP,
    paid_amount DECIMAL(12, 2),
    
    -- Retard
    days_overdue INTEGER DEFAULT 0,
    late_fee DECIMAL(12, 2) DEFAULT 0,
    
    -- Métadonnées
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Contrainte unique
    UNIQUE(loan_contract_id, payment_number)
);

-- =====================================================
-- TABLE: payments (Paiements effectués)
-- =====================================================
CREATE TABLE payments (
    id SERIAL PRIMARY KEY,
    payment_reference VARCHAR(100) UNIQUE NOT NULL,
    loan_contract_id INTEGER NOT NULL REFERENCES loan_contracts(id),
    repayment_schedule_id INTEGER REFERENCES repayment_schedule(id),
    user_id INTEGER NOT NULL REFERENCES users(id),
    
    -- Détails du paiement
    amount DECIMAL(12, 2) NOT NULL,
    payment_date TIMESTAMP NOT NULL,
    payment_method VARCHAR(50) NOT NULL,
    
    -- Répartition
    principal_paid DECIMAL(12, 2),
    interest_paid DECIMAL(12, 2),
    late_fee_paid DECIMAL(12, 2),
    
    -- Transaction
    transaction_id VARCHAR(100),
    transaction_status VARCHAR(50),
    
    -- Métadonnées
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by INTEGER REFERENCES users(id)
);

-- =====================================================
-- TABLE: credit_simulations (Simulations de crédit)
-- =====================================================
CREATE TABLE credit_simulations (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    
    -- Données de simulation
    client_type VARCHAR(50),
    credit_type VARCHAR(50),
    monthly_income DECIMAL(12, 2),
    requested_amount DECIMAL(12, 2),
    duration_months INTEGER,
    
    -- Résultats
    monthly_payment DECIMAL(12, 2),
    total_amount DECIMAL(12, 2),
    interest_rate DECIMAL(5, 2),
    total_interest DECIMAL(12, 2),
    is_eligible BOOLEAN,
    max_borrowing_capacity DECIMAL(12, 2),
    
    -- Recommandations
    recommendations JSONB,
    
    -- Métadonnées
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ip_address INET,
    user_agent TEXT
);

-- =====================================================
-- TABLE: notifications (Notifications)
-- =====================================================
CREATE TABLE notifications (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id),
    
    -- Contenu
    type VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    
    -- Canaux
    channel VARCHAR(50) DEFAULT 'in_app',
    
    -- Statut
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMP,
    
    -- Référence
    reference_type VARCHAR(50),
    reference_id INTEGER,
    
    -- Métadonnées
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    sent_at TIMESTAMP
);

-- =====================================================
-- TABLE: audit_logs (Journaux d'audit)
-- =====================================================
CREATE TABLE audit_logs (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    
    -- Action
    action VARCHAR(100) NOT NULL,
    module VARCHAR(50) NOT NULL,
    
    -- Détails
    entity_type VARCHAR(50),
    entity_id INTEGER,
    changes JSONB,
    
    -- Contexte
    ip_address INET,
    user_agent TEXT,
    
    -- Métadonnées
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- TABLE: user_sessions (Sessions utilisateurs)
-- =====================================================
CREATE TABLE user_sessions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id),
    
    -- Session
    session_token VARCHAR(255) UNIQUE NOT NULL,
    refresh_token VARCHAR(255) UNIQUE,
    
    -- Contexte
    ip_address INET,
    user_agent TEXT,
    device_info JSONB,
    
    -- Validité
    expires_at TIMESTAMP NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Métadonnées
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_activity TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- TABLE: settings (Paramètres utilisateur)
-- =====================================================
CREATE TABLE user_settings (
    id SERIAL PRIMARY KEY,
    user_id INTEGER UNIQUE NOT NULL REFERENCES users(id),
    
    -- Notifications
    notification_preferences JSONB DEFAULT '{
        "transactions": {"email": true, "sms": true, "push": true},
        "credits": {"email": true, "sms": false, "push": true},
        "marketing": {"email": false, "sms": false, "push": false},
        "security": {"email": true, "sms": true, "push": true}
    }',
    
    -- Préférences
    theme VARCHAR(20) DEFAULT 'light',
    date_format VARCHAR(20) DEFAULT 'DD/MM/YYYY',
    session_timeout INTEGER DEFAULT 30, -- en minutes
    
    -- Métadonnées
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- INDEX pour les performances
-- =====================================================

-- Index sur les users
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_phone ON users(phone_number);
CREATE INDEX idx_users_status ON users(status);
CREATE INDEX idx_users_role ON users(role);

-- Index sur les credit_requests
CREATE INDEX idx_credit_requests_user_id ON credit_requests(user_id);
CREATE INDEX idx_credit_requests_status ON credit_requests(status);
CREATE INDEX idx_credit_requests_type ON credit_requests(credit_type);
CREATE INDEX idx_credit_requests_submission_date ON credit_requests(submission_date);

-- Index sur les loan_contracts
CREATE INDEX idx_loan_contracts_user_id ON loan_contracts(user_id);
CREATE INDEX idx_loan_contracts_status ON loan_contracts(status);

-- Index sur les repayment_schedule
CREATE INDEX idx_repayment_schedule_loan_id ON repayment_schedule(loan_contract_id);
CREATE INDEX idx_repayment_schedule_due_date ON repayment_schedule(due_date);
CREATE INDEX idx_repayment_schedule_status ON repayment_schedule(status);

-- Index sur les payments
CREATE INDEX idx_payments_loan_id ON payments(loan_contract_id);
CREATE INDEX idx_payments_user_id ON payments(user_id);
CREATE INDEX idx_payments_date ON payments(payment_date);

-- Index sur les notifications
CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_read ON notifications(is_read);

-- Index sur les audit_logs
CREATE INDEX idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at);
CREATE INDEX idx_audit_logs_action ON audit_logs(action);

-- =====================================================
-- FONCTIONS pour mise à jour automatique
-- =====================================================

-- Fonction pour mettre à jour updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers pour updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_credit_requests_updated_at BEFORE UPDATE ON credit_requests
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_loan_contracts_updated_at BEFORE UPDATE ON loan_contracts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_repayment_schedule_updated_at BEFORE UPDATE ON repayment_schedule
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_settings_updated_at BEFORE UPDATE ON user_settings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- VUES pour faciliter les requêtes
-- =====================================================

-- Vue pour le dashboard des demandes de crédit
CREATE VIEW v_credit_requests_dashboard AS
SELECT 
    cr.id,
    cr.request_number,
    cr.credit_type,
    cr.status,
    cr.requested_amount,
    cr.approved_amount,
    cr.duration_months,
    cr.credit_score,
    cr.risk_level,
    cr.submission_date,
    u.id as user_id,
    u.first_name || ' ' || u.last_name as full_name,
    u.email,
    u.phone_number
FROM credit_requests cr
JOIN users u ON cr.user_id = u.id;

-- Vue pour le suivi des remboursements
CREATE VIEW v_repayment_tracking AS
SELECT 
    rs.id,
    rs.loan_contract_id,
    rs.payment_number,
    rs.due_date,
    rs.total_amount,
    rs.status,
    rs.days_overdue,
    lc.contract_number,
    u.id as user_id,
    u.first_name || ' ' || u.last_name as full_name,
    u.email,
    u.phone_number
FROM repayment_schedule rs
JOIN loan_contracts lc ON rs.loan_contract_id = lc.id
JOIN users u ON lc.user_id = u.id
WHERE rs.status != 'paid';

-- =====================================================
-- FONCTIONS UTILES
-- =====================================================

-- Fonction pour générer un numéro de demande
CREATE OR REPLACE FUNCTION generate_request_number()
RETURNS VARCHAR AS $$
DECLARE
    new_number VARCHAR;
BEGIN
    new_number := 'REQ-' || TO_CHAR(CURRENT_DATE, 'YYYYMMDD') || '-' || 
                  LPAD(nextval('credit_requests_id_seq')::text, 6, '0');
    RETURN new_number;
END;
$$ LANGUAGE plpgsql;

-- Fonction pour générer un numéro de contrat
CREATE OR REPLACE FUNCTION generate_contract_number()
RETURNS VARCHAR AS $$
DECLARE
    new_number VARCHAR;
BEGIN
    new_number := 'CTR-' || TO_CHAR(CURRENT_DATE, 'YYYYMMDD') || '-' || 
                  LPAD(nextval('loan_contracts_id_seq')::text, 6, '0');
    RETURN new_number;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- DONNÉES DE TEST
-- =====================================================

-- Insérer des utilisateurs de test
INSERT INTO users (email, password_hash, first_name, last_name, phone_number, role, monthly_income)
VALUES 
    ('admin@bamboo.ci', '$2b$10$FGdP8.kFYU3K3T2Q0Xd5AuFzZoY6DZU5dXV.N5yW6L5nQ5TQEjH3a', 'Admin', 'System', '0777777777', 'admin', 0),
    ('agent@bamboo.ci', '$2b$10$FGdP8.kFYU3K3T2Q0Xd5AuFzZoY6DZU5dXV.N5yW6L5nQ5TQEjH3a', 'Agent', 'Commercial', '0766666666', 'agent', 0),
    ('marina@email.com', '$2b$10$FGdP8.kFYU3K3T2Q0Xd5AuFzZoY6DZU5dXV.N5yW6L5nQ5TQEjH3a', 'Marina', 'Brunelle', '077123456', 'client', 750000);

-- Créer les paramètres par défaut pour les utilisateurs
INSERT INTO user_settings (user_id)
SELECT id FROM users;

-- Afficher le résultat
SELECT 'Base de données créée avec succès!' as message;