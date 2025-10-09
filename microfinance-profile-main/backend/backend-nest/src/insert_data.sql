-- ============================================================================
-- BASE DE DONNÉES : SYSTÈME DE CRÉDIT AVEC SCORING - BAMBOO EMF GABON
-- ============================================================================
-- Version: 2.1 CORRIGÉE
-- Date: 2025
-- Description: Base enrichie avec 100+ clients gabonais et historiques complets
-- ============================================================================

-- Déconnecter toutes les sessions actives
SELECT pg_terminate_backend(pid) 
FROM pg_stat_activity 
WHERE datname = 'credit_scoring' AND pid <> pg_backend_pid();

-- Suppression et recréation de la base
DROP DATABASE IF EXISTS credit_scoring;
CREATE DATABASE credit_scoring;
\c credit_scoring;

-- Extensions nécessaires
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- TYPES ÉNUMÉRÉS
-- ============================================================================

CREATE TYPE type_emploi AS ENUM ('cdi', 'cdd', 'independant', 'fonctionnaire', 'autre');
CREATE TYPE statut_utilisateur AS ENUM ('actif', 'inactif', 'suspendu', 'bloque');
CREATE TYPE type_credit AS ENUM (
    'consommation_generale', 
    'avance_salaire', 
    'depannage', 
    'investissement',
    'tontine',
    'retraite'
);
CREATE TYPE statut_credit AS ENUM ('actif', 'solde', 'en_retard', 'defaut');
CREATE TYPE niveau_risque AS ENUM ('tres_bas', 'bas', 'moyen', 'eleve', 'tres_eleve');
CREATE TYPE type_paiement AS ENUM ('a_temps', 'en_retard', 'manque', 'anticipe');

-- ============================================================================
-- TABLE 1: UTILISATEURS (clients)
-- ============================================================================

CREATE TABLE utilisateurs (
    id SERIAL PRIMARY KEY,
    uuid UUID DEFAULT uuid_generate_v4() UNIQUE,
    
    -- Informations personnelles
    nom VARCHAR(100) NOT NULL,
    prenom VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    telephone VARCHAR(20) UNIQUE NOT NULL,
    mot_de_passe_hash VARCHAR(255) NOT NULL,
    
    -- Informations géographiques (Gabon)
    ville VARCHAR(100) DEFAULT 'Libreville',
    quartier VARCHAR(100),
    province VARCHAR(50) DEFAULT 'Estuaire',
    
    -- Informations professionnelles
    profession VARCHAR(255),
    employeur VARCHAR(255),
    statut_emploi type_emploi DEFAULT 'cdi',
    revenu_mensuel DECIMAL(12,2) NOT NULL CHECK (revenu_mensuel >= 0),
    anciennete_mois INTEGER DEFAULT 0 CHECK (anciennete_mois >= 0),
    
    -- Informations financières
    charges_mensuelles DECIMAL(12,2) DEFAULT 0,
    dettes_existantes DECIMAL(12,2) DEFAULT 0,
    
    -- Scoring
    score_credit DECIMAL(3,1) DEFAULT 6.0 CHECK (score_credit >= 0 AND score_credit <= 10),
    score_850 INTEGER DEFAULT 650 CHECK (score_850 >= 300 AND score_850 <= 850),
    niveau_risque niveau_risque DEFAULT 'moyen',
    montant_eligible DECIMAL(12,2) DEFAULT 0,
    
    -- Métadonnées
    statut statut_utilisateur DEFAULT 'actif',
    date_creation TIMESTAMP DEFAULT NOW(),
    date_modification TIMESTAMP DEFAULT NOW(),
    derniere_connexion TIMESTAMP,
    
    CONSTRAINT revenu_positif CHECK (revenu_mensuel > 0)
);

-- Index pour performances
CREATE INDEX idx_utilisateurs_email ON utilisateurs(email);
CREATE INDEX idx_utilisateurs_telephone ON utilisateurs(telephone);
CREATE INDEX idx_utilisateurs_score ON utilisateurs(score_credit DESC);
CREATE INDEX idx_utilisateurs_statut ON utilisateurs(statut);

COMMENT ON TABLE utilisateurs IS 'Table principale des clients avec informations personnelles et scoring';
COMMENT ON COLUMN utilisateurs.score_credit IS 'Score sur 10 calculé par le modèle ML';
COMMENT ON COLUMN utilisateurs.score_850 IS 'Score traditionnel FICO-like (300-850)';
COMMENT ON COLUMN utilisateurs.montant_eligible IS 'Montant maximum empruntable selon le profil';

-- ============================================================================
-- TABLE 2: CREDITS_ENREGISTRES
-- ============================================================================

CREATE TABLE credits_enregistres (
    id SERIAL PRIMARY KEY,
    utilisateur_id INTEGER NOT NULL REFERENCES utilisateurs(id) ON DELETE CASCADE,
    
    -- Détails du crédit
    type_credit type_credit NOT NULL,
    montant_principal DECIMAL(12,2) NOT NULL CHECK (montant_principal > 0),
     montant_total DECIMAL(12,2) NOT NULL CHECK (montant_total >= 0),
    montant_restant DECIMAL(12,2) NOT NULL CHECK (montant_restant >= 0),
    
    -- Taux et durée
    taux_interet DECIMAL(5,2) NOT NULL CHECK (taux_interet >= 0),
    duree_mois INTEGER NOT NULL CHECK (duree_mois > 0),
    
    -- Statut et dates
    statut statut_credit DEFAULT 'actif',
    date_approbation TIMESTAMP NOT NULL DEFAULT NOW(),
    date_echeance TIMESTAMP NOT NULL,
    date_prochain_paiement TIMESTAMP,
    montant_prochain_paiement DECIMAL(12,2),
    
    -- Métadonnées
    date_creation TIMESTAMP DEFAULT NOW(),
    date_modification TIMESTAMP DEFAULT NOW(),
    
CONSTRAINT montant_restant_coherent CHECK (montant_restant <= montant_total OR montant_total = 0)
);

-- Index
CREATE INDEX idx_credits_utilisateur ON credits_enregistres(utilisateur_id);
CREATE INDEX idx_credits_statut ON credits_enregistres(statut);
CREATE INDEX idx_credits_date_echeance ON credits_enregistres(date_echeance);

COMMENT ON TABLE credits_enregistres IS 'Tous les crédits accordés - historique complet';
COMMENT ON COLUMN credits_enregistres.montant_restant IS 'Solde restant à rembourser';

-- ============================================================================
-- TABLE 3: HISTORIQUE_PAIEMENTS
-- ============================================================================

CREATE TABLE historique_paiements (
    id SERIAL PRIMARY KEY,
    credit_id INTEGER NOT NULL REFERENCES credits_enregistres(id) ON DELETE CASCADE,
    utilisateur_id INTEGER NOT NULL REFERENCES utilisateurs(id) ON DELETE CASCADE,
    
    -- Détails du paiement
    -- APRÈS
    montant DECIMAL(12,2) NOT NULL CHECK (montant >= 0),
    date_paiement TIMESTAMP NOT NULL DEFAULT NOW(),
    date_prevue TIMESTAMP NOT NULL,
    
    -- Analyse du retard
    jours_retard INTEGER DEFAULT 0 CHECK (jours_retard >= 0),
    type_paiement type_paiement NOT NULL,
    
    -- Frais
    frais_retard DECIMAL(10,2) DEFAULT 0,
    
    -- Métadonnées
    date_creation TIMESTAMP DEFAULT NOW()
);

-- Index pour analyses ML
CREATE INDEX idx_paiements_utilisateur ON historique_paiements(utilisateur_id);
CREATE INDEX idx_paiements_credit ON historique_paiements(credit_id);
CREATE INDEX idx_paiements_date ON historique_paiements(date_paiement DESC);
CREATE INDEX idx_paiements_type ON historique_paiements(type_paiement);

COMMENT ON TABLE historique_paiements IS 'Historique complet des paiements - données ML';
COMMENT ON COLUMN historique_paiements.jours_retard IS 'Nombre de jours de retard (0 = à temps)';

-- ============================================================================
-- TABLE 4: HISTORIQUE_SCORES
-- ============================================================================

CREATE TABLE historique_scores (
    id SERIAL PRIMARY KEY,
    utilisateur_id INTEGER NOT NULL REFERENCES utilisateurs(id) ON DELETE CASCADE,
    
    -- Scores
    score_credit DECIMAL(3,1) NOT NULL,
    score_850 INTEGER NOT NULL,
    score_precedent DECIMAL(3,1),
    changement DECIMAL(3,1),
    
    -- Contexte
    niveau_risque niveau_risque NOT NULL,
    montant_eligible DECIMAL(12,2),
    evenement_declencheur VARCHAR(200),
    
    -- Analyse comportementale
    ratio_paiements_temps DECIMAL(5,2),
    tendance VARCHAR(20),
    
    -- Métadonnées
    date_calcul TIMESTAMP DEFAULT NOW()
);

-- Index
CREATE INDEX idx_scores_utilisateur ON historique_scores(utilisateur_id);
CREATE INDEX idx_scores_date ON historique_scores(date_calcul DESC);

COMMENT ON TABLE historique_scores IS 'Évolution temporelle des scores de crédit';
COMMENT ON COLUMN historique_scores.evenement_declencheur IS 'Ce qui a causé le recalcul (paiement, nouveau crédit, etc.)';

-- ============================================================================
-- TABLE 5: RESTRICTIONS_CREDIT
-- ============================================================================

CREATE TABLE restrictions_credit (
    id SERIAL PRIMARY KEY,
    utilisateur_id INTEGER NOT NULL UNIQUE REFERENCES utilisateurs(id) ON DELETE CASCADE,
    
    -- Règles
    peut_emprunter BOOLEAN DEFAULT TRUE,
    credits_actifs_count INTEGER DEFAULT 0,
    credits_max_autorises INTEGER DEFAULT 2,
    
    -- Calculs financiers
    dette_totale_active DECIMAL(12,2) DEFAULT 0,
    ratio_endettement DECIMAL(5,2) DEFAULT 0,
    
    -- Délais
    date_derniere_demande TIMESTAMP,
    date_prochaine_eligibilite TIMESTAMP,
    jours_avant_prochaine_demande INTEGER,
    
    -- Raison du blocage
    raison_blocage TEXT,
    
    -- Métadonnées
    date_creation TIMESTAMP DEFAULT NOW(),
    date_modification TIMESTAMP DEFAULT NOW()
);

-- Index
CREATE INDEX idx_restrictions_utilisateur ON restrictions_credit(utilisateur_id);
CREATE INDEX idx_restrictions_peut_emprunter ON restrictions_credit(peut_emprunter);

COMMENT ON TABLE restrictions_credit IS 'Gestion des règles et restrictions de crédit par client';

-- ============================================================================
-- TABLE 6: DEMANDES_CREDIT_LONGUES
-- ============================================================================

CREATE TABLE demandes_credit_longues (
    id SERIAL PRIMARY KEY,
    numero_demande VARCHAR(50) UNIQUE NOT NULL,
    utilisateur_id INTEGER NOT NULL REFERENCES utilisateurs(id) ON DELETE CASCADE,
    
    -- Informations demande
    type_credit type_credit NOT NULL,
    montant_demande DECIMAL(12,2) NOT NULL,
    duree_mois INTEGER NOT NULL,
    objectif TEXT NOT NULL,
    
    -- Statut workflow
    statut VARCHAR(50) DEFAULT 'soumise',
    date_soumission TIMESTAMP DEFAULT NOW(),
    date_decision TIMESTAMP,
    decideur_id INTEGER REFERENCES utilisateurs(id),
    
    -- Décision
    montant_approuve DECIMAL(12,2),
    taux_approuve DECIMAL(5,2),
    notes_decision TEXT,
    
    -- Scoring au moment de la demande
    score_au_moment_demande DECIMAL(3,1),
    niveau_risque_evaluation niveau_risque,
    
    -- Métadonnées
    date_creation TIMESTAMP DEFAULT NOW(),
    date_modification TIMESTAMP DEFAULT NOW()
);

-- Index
CREATE INDEX idx_demandes_longues_utilisateur ON demandes_credit_longues(utilisateur_id);
CREATE INDEX idx_demandes_longues_statut ON demandes_credit_longues(statut);

COMMENT ON TABLE demandes_credit_longues IS 'Demandes de crédit complexes avec workflow back-office';

-- ============================================================================
-- FONCTIONS UTILITAIRES
-- ============================================================================

-- Fonction: Calcul automatique du ratio d'endettement
CREATE OR REPLACE FUNCTION calculer_ratio_endettement(p_utilisateur_id INTEGER)
RETURNS DECIMAL(5,2) AS $$
DECLARE
    v_revenu DECIMAL(12,2);
    v_dette_totale DECIMAL(12,2);
    v_ratio DECIMAL(5,2);
BEGIN
    SELECT revenu_mensuel INTO v_revenu 
    FROM utilisateurs 
    WHERE id = p_utilisateur_id;
    
    SELECT COALESCE(SUM(montant_restant), 0) INTO v_dette_totale
    FROM credits_enregistres
    WHERE utilisateur_id = p_utilisateur_id AND statut = 'actif';
    
    IF v_revenu > 0 THEN
        v_ratio := (v_dette_totale / v_revenu) * 100;
    ELSE
        v_ratio := 0;
    END IF;
    
    RETURN v_ratio;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION calculer_ratio_endettement IS 'Calcule le ratio dette/revenu en pourcentage';

-- Fonction: Mise à jour automatique des timestamps
CREATE OR REPLACE FUNCTION maj_date_modification()
RETURNS TRIGGER AS $$
BEGIN
    NEW.date_modification = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers pour date_modification
CREATE TRIGGER trigger_maj_utilisateurs
    BEFORE UPDATE ON utilisateurs
    FOR EACH ROW EXECUTE FUNCTION maj_date_modification();

CREATE TRIGGER trigger_maj_credits
    BEFORE UPDATE ON credits_enregistres
    FOR EACH ROW EXECUTE FUNCTION maj_date_modification();

CREATE TRIGGER trigger_maj_restrictions
    BEFORE UPDATE ON restrictions_credit
    FOR EACH ROW EXECUTE FUNCTION maj_date_modification();

-- ============================================================================
-- GÉNÉRATION DES DONNÉES RÉALISTES - 100 CLIENTS GABONAIS
-- ============================================================================

-- ÉTAPE 1: Insertion des utilisateurs avec profils variés

INSERT INTO utilisateurs (nom, prenom, email, telephone, mot_de_passe_hash, ville, quartier, province, profession, employeur, statut_emploi, revenu_mensuel, anciennete_mois, charges_mensuelles, dettes_existantes, score_credit, score_850, niveau_risque, montant_eligible) VALUES

-- === PROFILS EXCELLENTS (score 8-10) - 30 clients ===
('OBAME', 'Jean-Pierre', 'jp.obame@email.ga', '077111001', '$2b$10$hash1', 'Libreville', 'Glass', 'Estuaire', 'Ingénieur Pétrole', 'Total Gabon', 'cdi', 2500000, 72, 800000, 0, 9.2, 780, 'tres_bas', 2000000),
('NGUEMA', 'Marie-Claire', 'mc.nguema@email.ga', '077111002', '$2b$10$hash2', 'Libreville', 'NombakéLé', 'Estuaire', 'Directrice RH', 'Banque Gabonaise', 'cdi', 1800000, 96, 600000, 0, 8.9, 750, 'tres_bas', 1500000),
('MBOUMBA', 'Patrick', 'p.mboumba@email.ga', '077111003', '$2b$10$hash3', 'Libreville', 'Batterie IV', 'Estuaire', 'Manager IT', 'Gabon Telecom', 'cdi', 1500000, 60, 500000, 200000, 8.5, 720, 'bas', 1200000),
('MINTSA', 'Sylvie', 's.mintsa@email.ga', '077111004', '$2b$10$hash4', 'Port-Gentil', 'Cité', 'Ogooué-Maritime', 'Comptable Senior', 'Perenco', 'cdi', 1200000, 84, 400000, 0, 8.7, 740, 'tres_bas', 1000000),
('ONDO', 'François', 'f.ondo@email.ga', '077111005', '$2b$10$hash5', 'Libreville', 'Lalala', 'Estuaire', 'Médecin', 'Centre Hospitalier', 'fonctionnaire', 2000000, 120, 700000, 300000, 8.3, 710, 'bas', 1600000),
('MOUSSAVOU', 'Georgette', 'g.moussavou@email.ga', '077111006', '$2b$10$hash6', 'Franceville', 'Potos', 'Haut-Ogooué', 'Pharmacienne', 'Pharmacie Centrale', 'independant', 1400000, 48, 450000, 150000, 8.6, 730, 'bas', 1100000),
('BOULINGUI', 'Marcel', 'm.boulingui@email.ga', '077111007', '$2b$10$hash7', 'Libreville', 'Akanda', 'Estuaire', 'Avocat', 'Cabinet Juridique', 'independant', 1900000, 60, 650000, 0, 8.8, 745, 'tres_bas', 1550000),
('NZAMBA', 'Christelle', 'c.nzamba@email.ga', '077111008', '$2b$10$hash8', 'Libreville', 'Mont-Bouët', 'Estuaire', 'Chef de Projet', 'Ministère Économie', 'fonctionnaire', 1100000, 72, 380000, 100000, 8.4, 715, 'bas', 900000),
('EYEGHE', 'Antoine', 'a.eyeghe@email.ga', '077111009', '$2b$10$hash9', 'Libreville', 'Okala', 'Estuaire', 'Architecte', 'Bureau Études', 'cdi', 1600000, 54, 520000, 250000, 8.2, 705, 'bas', 1300000),
('NDONG BEKALE', 'Pauline', 'p.ndongbekale@email.ga', '077111010', '$2b$10$hash10', 'Port-Gentil', 'Quartier Basse', 'Ogooué-Maritime', 'Ingénieur Logistique', 'Bolloré', 'cdi', 1350000, 66, 440000, 0, 8.7, 738, 'tres_bas', 1080000),
('IVANGA', 'Rodrigue', 'r.ivanga@email.ga', '077111011', '$2b$10$hash11', 'Libreville', 'Nzeng-Ayong', 'Estuaire', 'Contrôleur Financier', 'Assala Energy', 'cdi', 1450000, 78, 480000, 0, 8.9, 752, 'tres_bas', 1160000),
('MASSALA', 'Henriette', 'h.massala@email.ga', '077111012', '$2b$10$hash12', 'Libreville', 'Alibandeng', 'Estuaire', 'Professeur Université', 'Université Omar Bongo', 'fonctionnaire', 950000, 144, 320000, 0, 8.1, 698, 'bas', 760000),
('KOMBILA', 'Serge', 's.kombila@email.ga', '077111013', '$2b$10$hash13', 'Oyem', 'Centre-Ville', 'Woleu-Ntem', 'Directeur École', 'Éducation Nationale', 'fonctionnaire', 850000, 108, 290000, 50000, 8.0, 690, 'bas', 680000),
('BOUNDA', 'Jacqueline', 'j.bounda@email.ga', '077111014', '$2b$10$hash14', 'Libreville', 'Akébé', 'Estuaire', 'Responsable Achats', 'BGFI Bank', 'cdi', 1280000, 60, 420000, 180000, 8.3, 708, 'bas', 1020000),
('KOUMBA', 'Ernest', 'e.koumba@email.ga', '077111015', '$2b$10$hash15', 'Libreville', 'PK9', 'Estuaire', 'Chef de Service', 'Gabon Oil', 'cdi', 1550000, 90, 510000, 0, 8.6, 733, 'tres_bas', 1240000),
('LEKOGO', 'Sandrine', 's.lekogo@email.ga', '077111016', '$2b$10$hash16', 'Libreville', 'Oloumi', 'Estuaire', 'Analyste Crédit', 'UGB Gabon', 'cdi', 1150000, 48, 380000, 120000, 8.2, 703, 'bas', 920000),
('MOUNDOUNGA', 'Victor', 'v.moundounga@email.ga', '077111017', '$2b$10$hash17', 'Mouila', 'Sangatanga', 'Ngounié', 'Entrepreneur BTP', 'Auto-entrepreneur', 'independant', 1680000, 72, 560000, 400000, 8.0, 692, 'bas', 1340000),
('NZIENGUI', 'Diane', 'd.nziengui@email.ga', '077111018', '$2b$10$hash18', 'Libreville', 'Louis', 'Estuaire', 'DRH Adjointe', 'BGFIBank', 'cdi', 1420000, 66, 470000, 0, 8.5, 725, 'bas', 1140000),
('MAGANGA', 'Jules', 'j.maganga@email.ga', '077111019', '$2b$10$hash19', 'Libreville', 'Charbonnages', 'Estuaire', 'Pilote Hélicoptère', 'Air Services', 'cdi', 2100000, 84, 700000, 500000, 8.1, 695, 'bas', 1680000),
('OVONO', 'Laurence', 'l.ovono@email.ga', '077111020', '$2b$10$hash20', 'Libreville', 'Centre-Ville', 'Estuaire', 'Notaire', 'Étude Notariale', 'independant', 1750000, 96, 580000, 0, 8.8, 748, 'tres_bas', 1400000),
('BOUASSA', 'Raymond', 'r.bouassa@email.ga', '077111021', '$2b$10$hash21', 'Port-Gentil', 'Nouveau Port', 'Ogooué-Maritime', 'Superviseur Offshore', 'Schlumberger', 'cdi', 1880000, 72, 620000, 280000, 8.4, 718, 'bas', 1500000),
('LENDOYE', 'Odette', 'o.lendoye@email.ga', '077111022', '$2b$10$hash22', 'Libreville', 'Atong Abe', 'Estuaire', 'Responsable Marketing', 'Total Gabon', 'cdi', 1320000, 54, 440000, 0, 8.3, 710, 'bas', 1060000),
('NGOMA', 'Thierry', 't.ngoma@email.ga', '077111023', '$2b$10$hash23', 'Libreville', 'Sotega', 'Estuaire', 'Ingénieur Réseau', 'Airtel Gabon', 'cdi', 1480000, 60, 490000, 150000, 8.5, 728, 'bas', 1180000),
('OKOMO', 'Véronique', 'v.okomo@email.ga', '077111024', '$2b$10$hash24', 'Libreville', 'Nzeng-Ayong', 'Estuaire', 'Consultante Finance', 'Cabinet Conseil', 'independant', 1620000, 48, 540000, 0, 8.6, 735, 'bas', 1300000),
('PAMBOU', 'Gérard', 'g.pambou@email.ga', '077111025', '$2b$10$hash25', 'Franceville', 'Bangombé', 'Haut-Ogooué', 'Chef Comptable', 'Comilog', 'cdi', 1190000, 90, 390000, 100000, 8.3, 712, 'bas', 950000),
('TCHOUMBA', 'Agnès', 'a.tchoumba@email.ga', '077111026', '$2b$10$hash26', 'Libreville', 'Toulon', 'Estuaire', 'Responsable Formation', 'CNSS', 'fonctionnaire', 1050000, 84, 350000, 0, 8.2, 705, 'bas', 840000),
('YEMBIT', 'Daniel', 'd.yembit@email.ga', '077111027', '$2b$10$hash27', 'Libreville', 'Bellevue', 'Estuaire', 'Gérant Restaurant', 'Auto-entrepreneur', 'independant', 1350000, 60, 450000, 200000, 8.1, 698, 'bas', 1080000),
('ZOMO', 'Mireille', 'm.zomo@email.ga', '077111028', '$2b$10$hash28', 'Libreville', 'Akanda II', 'Estuaire', 'Chef de Mission Audit', 'KPMG Gabon', 'cdi', 1580000, 66, 520000, 0, 8.7, 740, 'tres_bas', 1260000),
('BEKALE', 'Olivier', 'o.bekale@email.ga', '077111029', '$2b$10$hash29', 'Port-Gentil', 'Cap Lopez', 'Ogooué-Maritime', 'Cadre Bancaire', 'BICIG', 'cdi', 1420000, 78, 470000, 120000, 8.4, 720, 'bas', 1140000),
('NDEMBI', 'Clarisse', 'c.ndembi@email.ga', '077111030', '$2b$10$hash30', 'Libreville', 'Sablière', 'Estuaire', 'Responsable Qualité', 'Ceca-Gadis', 'cdi', 1280000, 54, 420000, 0, 8.6, 733, 'bas', 1020000),

-- === PROFILS BONS (score 6-8) - 40 clients ===
('BOUYOU', 'Michel', 'm.bouyou@email.ga', '077222001', '$2b$10$hash31', 'Libreville', 'Lalala', 'Estuaire', 'Technicien Informatique', 'SOBRAGA', 'cdi', 680000, 36, 250000, 180000, 7.2, 640, 'moyen', 550000),
('DITEEKE', 'Albertine', 'a.diteeke@email.ga', '077222002', '$2b$10$hash32', 'Libreville', 'PK8', 'Estuaire', 'Secrétaire Direction', 'Ministère Santé', 'fonctionnaire', 520000, 48, 200000, 100000, 6.8, 610, 'moyen', 420000),
('ENGONE', 'Léon', 'l.engone@email.ga', '077222003', '$2b$10$hash33', 'Libreville', 'Mont-Bouët', 'Estuaire', 'Commercial', 'Orange Gabon', 'cdi', 750000, 30, 280000, 220000, 7.0, 625, 'moyen', 600000),
('FOGUE', 'Roseline', 'r.fogue@email.ga', '077222004', '$2b$10$hash34', 'Port-Gentil', 'Madagascar', 'Ogooué-Maritime', 'Agent Administratif', 'Mairie Port-Gentil', 'fonctionnaire', 480000, 60, 190000, 120000, 6.9, 618, 'moyen', 380000),
('GANDZIAMI', 'Prosper', 'p.gandziami@email.ga', '077222005', '$2b$10$hash35', 'Libreville', 'Sibang', 'Estuaire', 'Chauffeur Poids Lourds', 'SETRAG', 'cdi', 620000, 42, 240000, 150000, 7.1, 632, 'moyen', 500000),
('IKAPI', 'Blaise', 'b.ikapi@email.ga', '077222007', '$2b$10$hash37', 'Libreville', 'Okala', 'Estuaire', 'Électricien', 'Gabon Électricité', 'cdi', 640000, 36, 240000, 160000, 6.9, 620, 'moyen', 510000),
('KAYA', 'Élise', 'e.kaya@email.ga', '077222008', '$2b$10$hash38', 'Libreville', 'NombakéLé', 'Estuaire', 'Assistante Comptable', 'PME Locale', 'cdd', 550000, 24, 210000, 130000, 6.7, 605, 'moyen', 440000),
('LEBIGUI', 'Arsène', 'a.lebigui@email.ga', '077222009', '$2b$10$hash39', 'Franceville', 'Ogoua', 'Haut-Ogooué', 'Agent de Maîtrise', 'Comilog', 'cdi', 720000, 48, 270000, 190000, 7.2, 638, 'moyen', 580000),
('MAKOSSO', 'Joséphine', 'j.makosso@email.ga', '077222010', '$2b$10$hash40', 'Libreville', 'Batterie IV', 'Estuaire', 'Vendeuse', 'Supermarché Score', 'cdi', 480000, 30, 190000, 110000, 6.6, 598, 'moyen', 380000),
('NANG', 'Bernard', 'b.nang@email.ga', '077222011', '$2b$10$hash41', 'Libreville', 'Awendjé', 'Estuaire', 'Plombier', 'Auto-entrepreneur', 'independant', 590000, 60, 230000, 150000, 7.0, 628, 'moyen', 470000),
('OBIANG', 'Fernande', 'f.obiang@email.ga', '077222012', '$2b$10$hash42', 'Libreville', 'Glass', 'Estuaire', 'Enseignante Primaire', 'Éducation Nationale', 'fonctionnaire', 650000, 72, 250000, 170000, 7.3, 642, 'moyen', 520000),
('PAMBOU', 'Christian', 'c.pambou@email.ga', '077222013', '$2b$10$hash43', 'Port-Gentil', 'Boulingui', 'Ogooué-Maritime', 'Mécanicien Auto', 'Garage Privé', 'cdi', 560000, 42, 220000, 140000, 6.8, 612, 'moyen', 450000),
('QUEMBO', 'Angélique', 'a.quembo@email.ga', '077222014', '$2b$10$hash44', 'Libreville', 'PK5', 'Estuaire', 'Coiffeuse', 'Salon de Beauté', 'independant', 420000, 36, 170000, 90000, 6.5, 590, 'moyen', 340000),
('RETENO', 'Faustin', 'f.reteno@email.ga', '077222015', '$2b$10$hash45', 'Libreville', 'Ancien Chantier', 'Estuaire', 'Agent de Sécurité', 'Société Sécurité', 'cdi', 450000, 48, 180000, 100000, 6.7, 608, 'moyen', 360000),
('SAMBA', 'Gisèle', 'g.samba@email.ga', '077222016', '$2b$10$hash46', 'Libreville', 'Nzeng-Ayong', 'Estuaire', 'Caissière', 'Station Service', 'cdi', 380000, 24, 160000, 80000, 6.4, 585, 'moyen', 300000),
('TCHIBINTA', 'Armand', 'a.tchibinta@email.ga', '077222017', '$2b$10$hash47', 'Libreville', 'Akanda', 'Estuaire', 'Technicien Maintenance', 'SEEG', 'cdi', 670000, 54, 260000, 180000, 7.1, 635, 'moyen', 540000),
('UROBO', 'Valérie', 'v.urobo@email.ga', '077222018', '$2b$10$hash48', 'Libreville', 'Alibandeng', 'Estuaire', 'Aide-Soignante', 'Clinique Privée', 'cdd', 460000, 18, 185000, 105000, 6.5, 592, 'moyen', 370000),
('VIDJABO', 'Paul', 'p.vidjabo@email.ga', '077222019', '$2b$10$hash49', 'Oyem', 'Centre', 'Woleu-Ntem', 'Chauffeur Taxi', 'Auto-entrepreneur', 'independant', 520000, 48, 210000, 130000, 6.8, 615, 'moyen', 420000),
('WORA', 'Brigitte', 'b.wora@email.ga', '077222020', '$2b$10$hash50', 'Libreville', 'Sibang', 'Estuaire', 'Serveuse Restaurant', 'Restaurant Local', 'autre', 340000, 12, 150000, 70000, 6.2, 575, 'moyen', 270000),
('YEMBA', 'Gilbert', 'g.yemba@email.ga', '077222021', '$2b$10$hash51', 'Libreville', 'Charbonnages', 'Estuaire', 'Ouvrier BTP', 'Entreprise Construction', 'cdd', 490000, 30, 200000, 120000, 6.6, 600, 'moyen', 390000),
('ZINGA', 'Martine', 'm.zinga@email.ga', '077222022', '$2b$10$hash52', 'Libreville', 'Akébé', 'Estuaire', 'Employée Bureau', 'Cabinet Avocat', 'cdi', 540000, 36, 215000, 135000, 6.9, 622, 'moyen', 430000),
('ALLOGO', 'Hervé', 'h.allogo@email.ga', '077222023', '$2b$10$hash53', 'Libreville', 'Atong Abe', 'Estuaire', 'Gardien Immeuble', 'Copropriété', 'cdi', 360000, 60, 155000, 75000, 6.3, 580, 'moyen', 290000),
('BINET', 'Stéphanie', 's.binet@email.ga', '077222024', '$2b$10$hash54', 'Port-Gentil', 'Grand Village', 'Ogooué-Maritime', 'Réceptionniste', 'Hôtel Atlantique', 'cdi', 470000, 42, 190000, 110000, 6.7, 610, 'moyen', 380000),
('COMBO', 'Édouard', 'e.combo@email.ga', '077222025', '$2b$10$hash55', 'Libreville', 'Oloumi', 'Estuaire', 'Maçon', 'Auto-entrepreneur', 'independant', 550000, 48, 220000, 145000, 6.9, 618, 'moyen', 440000),
('DIKAMONA', 'Lydie', 'l.dikamona@email.ga', '077222026', '$2b$10$hash56', 'Libreville', 'Louis', 'Estuaire', 'Agent Entretien', 'Entreprise Nettoyage', 'cdi', 350000, 36, 150000, 72000, 6.2, 578, 'moyen', 280000),
('EBANG', 'Robert', 'r.ebang@email.ga', '077222027', '$2b$10$hash57', 'Libreville', 'PK9', 'Estuaire', 'Menuisier', 'Atelier Privé', 'independant', 580000, 54, 230000, 155000, 7.0, 625, 'moyen', 460000),
('FILA', 'Annette', 'a.fila@email.ga', '077222028', '$2b$10$hash58', 'Libreville', 'Nzeng-Ayong', 'Estuaire', 'Standardiste', 'Société Privée', 'cdi', 420000, 30, 175000, 95000, 6.5, 595, 'moyen', 340000),
('GASSAMA', 'Léonard', 'l.gassama@email.ga', '077222029', '$2b$10$hash59', 'Libreville', 'Batterie IV', 'Estuaire', 'Cuisinier', 'Restaurant Touristique', 'cdi', 510000, 36, 205000, 125000, 6.8, 612, 'moyen', 410000),
('HONGUI', 'Sophie', 's.hongui@email.ga', '077222030', '$2b$10$hash60', 'Libreville', 'Sotega', 'Estuaire', 'Vendeuse Boutique', 'Commerce Local', 'cdi', 390000, 24, 165000, 85000, 6.4, 588, 'moyen', 310000),
('ITSOUA', 'Maxime', 'm.itsoua@email.ga', '077222031', '$2b$10$hash61', 'Libreville', 'Akanda II', 'Estuaire', 'Magasinier', 'Société Import', 'cdi', 520000, 48, 210000, 130000, 6.9, 620, 'moyen', 420000),
('JIBIA', 'Rachel', 'r.jibia@email.ga', '077222032', '$2b$10$hash62', 'Libreville', 'Bellevue', 'Estuaire', 'Animatrice Radio', 'Radio Locale', 'cdd', 600000, 30, 240000, 160000, 7.1, 630, 'moyen', 480000),
('KOUMOU', 'Alphonse', 'a.koumou@email.ga', '077222033', '$2b$10$hash63', 'Franceville', 'Bel-Air', 'Haut-Ogooué', 'Agent Logistique', 'Société Minière', 'cdi', 680000, 42, 265000, 185000, 7.2, 640, 'moyen', 540000),
('LIBALA', 'Martine', 'm.libala@email.ga', '077222034', '$2b$10$hash64', 'Libreville', 'Toulon', 'Estuaire', 'Agent Commercial', 'Assurance GAB', 'cdi', 620000, 36, 245000, 155000, 7.0, 628, 'moyen', 500000),
('MABIALA', 'Jacques', 'j.mabiala@email.ga', '077222035', '$2b$10$hash65', 'Port-Gentil', 'Aviation', 'Ogooué-Maritime', 'Contrôleur Bus', 'Société Transport', 'cdi', 440000, 48, 180000, 100000, 6.6, 602, 'moyen', 350000),
('NDAMBA', 'Cécile', 'c.ndamba@email.ga', '077222036', '$2b$10$hash66', 'Libreville', 'Akébé Plaine', 'Estuaire', 'Secrétaire Médicale', 'Cabinet Médical', 'cdi', 500000, 42, 200000, 120000, 6.8, 615, 'moyen', 400000),
('OBANDA', 'Justin', 'j.obanda@email.ga', '077222037', '$2b$10$hash67', 'Libreville', 'Sablière', 'Estuaire', 'Technicien Froid', 'Société Climatisation', 'independant', 620000, 54, 245000, 165000, 7.1, 632, 'moyen', 500000),
('PAMBOU', 'Delphine', 'd.pambou2@email.ga', '077222038', '$2b$10$hash68', 'Libreville', 'Mont-Bouët', 'Estuaire', 'Gérante Boutique', 'Auto-entrepreneur', 'independant', 550000, 36, 225000, 140000, 6.9, 620, 'moyen', 440000),
('QUILLARD', 'Thomas', 't.quillard@email.ga', '077222039', '$2b$10$hash69', 'Libreville', 'Lalala', 'Estuaire', 'Livreur', 'Société Livraison', 'cdd', 380000, 18, 160000, 80000, 6.3, 582, 'moyen', 300000),
('ROGOMBE', 'Jeanne', 'j.rogombe@email.ga', '077222040', '$2b$10$hash70', 'Libreville', 'PK12', 'Estuaire', 'Agent Accueil', 'Clinique Privée', 'cdi', 460000, 30, 185000, 105000, 6.7, 608, 'moyen', 370000),

-- === PROFILS MOYENS (score 4-6) - 20 clients ===
('SAMBA BIYO', 'André', 'a.sambabiyo@email.ga', '077333001', '$2b$10$hash71', 'Libreville', 'Awendjé', 'Estuaire', 'Vendeur Marché', 'Auto-entrepreneur', 'independant', 280000, 24, 140000, 120000, 5.2, 480, 'moyen', 220000),
('TCHOUMBA', 'Marie', 'm.tchoumba@email.ga', '077333002', '$2b$10$hash72', 'Libreville', 'Nzeng-Ayong', 'Estuaire', 'Ménagère', 'Particuliers', 'autre', 180000, 12, 95000, 60000, 4.8, 450, 'eleve', 140000),
('UROBO', 'Francis', 'f.urobo@email.ga', '077333003', '$2b$10$hash73', 'Libreville', 'PK8', 'Estuaire', 'Aide Maçon', 'Chantiers', 'autre', 220000, 18, 115000, 85000, 4.5, 430, 'eleve', 180000),
('VIEIRA', 'Lucie', 'l.vieira@email.ga', '077333004', '$2b$10$hash74', 'Port-Gentil', 'Cité Nouvelle', 'Ogooué-Maritime', 'Vendeuse Ambulante', 'Auto-entrepreneur', 'independant', 190000, 36, 100000, 70000, 4.6, 435, 'eleve', 150000),
('WAMBA', 'Pierre', 'p.wamba@email.ga', '077333005', '$2b$10$hash75', 'Libreville', 'Okala', 'Estuaire', 'Gardien', 'Immeuble Privé', 'autre', 240000, 30, 125000, 95000, 4.9, 455, 'eleve', 190000),
('YAYI', 'Georgette', 'g.yayi@email.ga', '077333006', '$2b$10$hash76', 'Libreville', 'Alibandeng', 'Estuaire', 'Vendeuse Poisson', 'Marché Local', 'independant', 210000, 48, 110000, 80000, 5.0, 460, 'moyen', 170000),
('ZIGHA', 'Samuel', 's.zigha@email.ga', '077333007', '$2b$10$hash77', 'Libreville', 'Sibang', 'Estuaire', 'Apprenti Électricien', 'Formation', 'autre', 160000, 6, 90000, 50000, 4.3, 415, 'eleve', 130000),
('ABAGA', 'Solange', 's.abaga@email.ga', '077333008', '$2b$10$hash78', 'Libreville', 'Ancien Chantier', 'Estuaire', 'Revendeuse', 'Commerce Informel', 'independant', 200000, 24, 105000, 75000, 4.7, 440, 'eleve', 160000),
('BIVIGOU', 'Étienne', 'e.bivigou@email.ga', '077333009', '$2b$10$hash79', 'Libreville', 'Charbonnages', 'Estuaire', 'Manœuvre', 'Société BTP', 'cdd', 250000, 12, 130000, 100000, 5.1, 470, 'moyen', 200000),
('COMLAN', 'Émilienne', 'e.comlan@email.ga', '077333010', '$2b$10$hash80', 'Libreville', 'Batterie IV', 'Estuaire', 'Couturière', 'Atelier Couture', 'independant', 230000, 36, 120000, 90000, 5.0, 465, 'moyen', 180000),
('DEMBA', 'Julien', 'j.demba@email.ga', '077333011', '$2b$10$hash81', 'Libreville', 'Akébé', 'Estuaire', 'Apprenti Mécanicien', 'Garage Local', 'autre', 170000, 8, 92000, 55000, 4.4, 420, 'eleve', 140000),
('ESSONE', 'Paulette', 'p.essone@email.ga', '077333012', '$2b$10$hash82', 'Libreville', 'Oloumi', 'Estuaire', 'Agent Entretien', 'Société Nettoyage', 'cdd', 260000, 18, 135000, 105000, 5.3, 485, 'moyen', 210000),
('FOUNDOU', 'César', 'c.foundou@email.ga', '077333013', '$2b$10$hash83', 'Libreville', 'Louis', 'Estuaire', 'Laveur Voitures', 'Auto-entrepreneur', 'independant', 185000, 30, 98000, 68000, 4.6, 438, 'eleve', 150000),
('GOMA', 'Sylvie', 's.goma@email.ga', '077333014', '$2b$10$hash84', 'Libreville', 'Sotega', 'Estuaire', 'Aide Cuisinière', 'Restaurant', 'autre', 195000, 12, 102000, 72000, 4.7, 442, 'eleve', 155000),
('HOUSSOU', 'Raoul', 'r.houssou@email.ga', '077333015', '$2b$10$hash85', 'Port-Gentil', 'Basse-Pointe', 'Ogooué-Maritime', 'Pêcheur', 'Auto-entrepreneur', 'independant', 270000, 48, 140000, 110000, 5.4, 495, 'moyen', 220000),
('IBAKA', 'Nadine', 'n.ibaka@email.ga', '077333016', '$2b$10$hash86', 'Libreville', 'Akanda', 'Estuaire', 'Caissière Buvette', 'Petit Commerce', 'autre', 175000, 18, 93000, 58000, 4.5, 428, 'eleve', 140000),
('JOCKTANE', 'Albert', 'a.jocktane@email.ga', '077333017', '$2b$10$hash87', 'Libreville', 'PK5', 'Estuaire', 'Plongeur Restaurant', 'Restaurant Local', 'autre', 155000, 10, 88000, 48000, 4.2, 410, 'eleve', 125000),
('KOUMBA', 'Hortense', 'h.koumba@email.ga', '077333018', '$2b$10$hash88', 'Libreville', 'Nzeng-Ayong', 'Estuaire', 'Repasseuse', 'Pressing Quartier', 'independant', 205000, 24, 108000, 78000, 4.8, 448, 'eleve', 165000),
('LOUBAKI', 'Norbert', 'n.loubaki@email.ga', '077333019', '$2b$10$hash89', 'Libreville', 'Mont-Bouët', 'Estuaire', 'Chauffeur Moto-Taxi', 'Auto-entrepreneur', 'independant', 290000, 36, 150000, 125000, 5.5, 500, 'moyen', 230000),
('MABIKA', 'Colette', 'c.mabika@email.ga', '077333020', '$2b$10$hash90', 'Libreville', 'Bellevue', 'Estuaire', 'Vendeuse Tissu', 'Marché', 'independant', 220000, 42, 115000, 88000, 5.1, 472, 'moyen', 175000),

-- === PROFILS À RISQUE (score <4) - 10 clients ===
-- CORRECTION: Score 850 minimum = 300
('NDOUMBA', 'Jacques', 'j.ndoumba@email.ga', '077444001', '$2b$10$hash91', 'Libreville', 'Nzeng-Ayong', 'Estuaire', 'Sans Emploi', 'Aucun', 'autre', 120000, 0, 75000, 95000, 3.2, 350, 'tres_eleve', 0),
('OBAME', 'Marguerite', 'm.obame2@email.ga', '077444002', '$2b$10$hash92', 'Libreville', 'Awendjé', 'Estuaire', 'Petits Boulots', 'Occasionnel', 'autre', 95000, 3, 65000, 110000, 2.8, 320, 'tres_eleve', 0),
('PAMBOU', 'Théodore', 't.pambou@email.ga', '077444003', '$2b$10$hash93', 'Libreville', 'PK8', 'Estuaire', 'Aide Familial', 'Sans Revenu Fixe', 'autre', 80000, 6, 55000, 75000, 2.5, 305, 'tres_eleve', 0),
('QUEMBO', 'Irène', 'i.quembo@email.ga', '077444004', '$2b$10$hash94', 'Port-Gentil', 'Quartier', 'Ogooué-Maritime', 'Vendeuse Rue', 'Informel', 'independant', 105000, 12, 70000, 90000, 3.0, 330, 'tres_eleve', 0),
('RETENO', 'Bruno', 'b.reteno@email.ga', '077444005', '$2b$10$hash95', 'Libreville', 'Okala', 'Estuaire', 'Apprenti', 'Sans Contrat', 'autre', 130000, 4, 80000, 105000, 3.4, 365, 'tres_eleve', 100000),
('SAMBA', 'Félicité', 'f.samba@email.ga', '077444006', '$2b$10$hash96', 'Libreville', 'Sibang', 'Estuaire', 'Aide Ménagère', 'Occasionnel', 'autre', 90000, 8, 62000, 85000, 2.7, 315, 'tres_eleve', 0),
('TCHIBINTA', 'Gaston', 'g.tchibinta@email.ga', '077444007', '$2b$10$hash97', 'Libreville', 'Alibandeng', 'Estuaire', 'Gardien Nuit', 'Sans Contrat', 'autre', 140000, 10, 85000, 115000, 3.5, 370, 'tres_eleve', 110000),
('UROBO', 'Denise', 'd.urobo@email.ga', '077444008', '$2b$10$hash98', 'Libreville', 'Ancien Chantier', 'Estuaire', 'Revendeuse', 'Informel', 'independant', 110000, 15, 72000, 95000, 3.1, 340, 'tres_eleve', 90000),
('VIDJABO', 'Firmin', 'f.vidjabo@email.ga', '077444009', '$2b$10$hash99', 'Libreville', 'Charbonnages', 'Estuaire', 'Chômeur', 'Sans Emploi', 'autre', 75000, 0, 50000, 80000, 2.3, 300, 'tres_eleve', 0),
('WORA', 'Lucie', 'l.wora@email.ga', '077444010', '$2b$10$hash100', 'Libreville', 'Batterie IV', 'Estuaire', 'Aide Occasionnelle', 'Sans Revenu', 'autre', 85000, 5, 58000, 88000, 2.6, 310, 'tres_eleve', 0);

-- ============================================================================
-- ÉTAPE 2: Génération des crédits enregistrés (200+ crédits)
-- ============================================================================

-- Fonction auxiliaire pour générer une date aléatoire dans le passé
CREATE OR REPLACE FUNCTION date_aleatoire_passe(jours_max INTEGER)
RETURNS TIMESTAMP AS $$
BEGIN
    RETURN NOW() - (RANDOM() * jours_max || ' days')::INTERVAL;
END;
$$ LANGUAGE plpgsql;

-- CRÉDITS POUR PROFILS EXCELLENTS (30 clients - 60 crédits au total)
-- CORRECTION: Cast explicite vers type_credit

INSERT INTO credits_enregistres (utilisateur_id, type_credit, montant_principal, montant_total, montant_restant, taux_interet, duree_mois, statut, date_approbation, date_echeance, date_prochain_paiement, montant_prochain_paiement)
SELECT 
    u.id,
    CASE 
        WHEN RANDOM() < 0.5 THEN 'consommation_generale'::type_credit
        ELSE 'avance_salaire'::type_credit
    END,
    FLOOR(RANDOM() * 1500000 + 500000),
    0,
    0,
    CASE 
        WHEN RANDOM() < 0.5 THEN 0.05
        ELSE 0.03
    END,
    CASE 
        WHEN RANDOM() < 0.7 THEN 1
        ELSE FLOOR(RANDOM() * 3 + 1)::INTEGER
    END,
    CASE 
        WHEN RANDOM() < 0.6 THEN 'solde'::statut_credit
        ELSE 'actif'::statut_credit
    END,
    date_aleatoire_passe(365),
    NOW() + (RANDOM() * 180 || ' days')::INTERVAL,
    NOW() + (RANDOM() * 30 || ' days')::INTERVAL,
    0
FROM utilisateurs u
WHERE u.id <= 30;

-- Ajout de seconds crédits pour certains profils excellents
INSERT INTO credits_enregistres (utilisateur_id, type_credit, montant_principal, montant_total, montant_restant, taux_interet, duree_mois, statut, date_approbation, date_echeance, date_prochain_paiement, montant_prochain_paiement)
SELECT 
    u.id,
    'depannage'::type_credit,
    FLOOR(RANDOM() * 800000 + 200000),
    0,
    0,
    0.04,
    1,
    'actif'::statut_credit,
    date_aleatoire_passe(90),
    NOW() + (RANDOM() * 60 || ' days')::INTERVAL,
    NOW() + (RANDOM() * 15 || ' days')::INTERVAL,
    0
FROM utilisateurs u
WHERE u.id <= 15;

-- CRÉDITS POUR PROFILS BONS (40 clients - 60 crédits)
INSERT INTO credits_enregistres (utilisateur_id, type_credit, montant_principal, montant_total, montant_restant, taux_interet, duree_mois, statut, date_approbation, date_echeance, date_prochain_paiement, montant_prochain_paiement)
SELECT 
    u.id,
    CASE 
        WHEN RANDOM() < 0.33 THEN 'consommation_generale'::type_credit
        WHEN RANDOM() < 0.66 THEN 'avance_salaire'::type_credit
        ELSE 'depannage'::type_credit
    END,
    FLOOR(RANDOM() * 600000 + 200000),
    0,
    0,
    CASE 
        WHEN RANDOM() < 0.4 THEN 0.05
        WHEN RANDOM() < 0.7 THEN 0.03
        ELSE 0.04
    END,
    FLOOR(RANDOM() * 2 + 1)::INTEGER,
    CASE 
        WHEN RANDOM() < 0.5 THEN 'solde'::statut_credit
        WHEN RANDOM() < 0.85 THEN 'actif'::statut_credit
        ELSE 'en_retard'::statut_credit
    END,
    date_aleatoire_passe(270),
    NOW() + (RANDOM() * 120 || ' days')::INTERVAL,
    NOW() + (RANDOM() * 25 || ' days')::INTERVAL,
    0
FROM utilisateurs u
WHERE u.id BETWEEN 31 AND 70;

-- Seconds crédits pour certains profils bons
INSERT INTO credits_enregistres (utilisateur_id, type_credit, montant_principal, montant_total, montant_restant, taux_interet, duree_mois, statut, date_approbation, date_echeance, date_prochain_paiement, montant_prochain_paiement)
SELECT 
    u.id,
    'depannage'::type_credit,
    FLOOR(RANDOM() * 400000 + 150000),
    0,
    0,
    0.04,
    1,
    CASE 
        WHEN RANDOM() < 0.7 THEN 'actif'::statut_credit
        ELSE 'en_retard'::statut_credit
    END,
    date_aleatoire_passe(120),
    NOW() + (RANDOM() * 45 || ' days')::INTERVAL,
    NOW() + (RANDOM() * 20 || ' days')::INTERVAL,
    0
FROM utilisateurs u
WHERE u.id BETWEEN 31 AND 50;

-- CRÉDITS POUR PROFILS MOYENS (20 clients - 35 crédits)
INSERT INTO credits_enregistres (utilisateur_id, type_credit, montant_principal, montant_total, montant_restant, taux_interet, duree_mois, statut, date_approbation, date_echeance, date_prochain_paiement, montant_prochain_paiement)
SELECT 
    u.id,
    CASE 
        WHEN RANDOM() < 0.33 THEN 'consommation_generale'::type_credit
        WHEN RANDOM() < 0.66 THEN 'avance_salaire'::type_credit
        ELSE 'depannage'::type_credit
    END,
    FLOOR(RANDOM() * 350000 + 100000),
    0,
    0,
    CASE 
        WHEN RANDOM() < 0.3 THEN 0.05
        WHEN RANDOM() < 0.6 THEN 0.03
        ELSE 0.04
    END,
    1,
    CASE 
        WHEN RANDOM() < 0.3 THEN 'solde'::statut_credit
        WHEN RANDOM() < 0.75 THEN 'actif'::statut_credit
        ELSE 'en_retard'::statut_credit
    END,
    date_aleatoire_passe(200),
    NOW() + (RANDOM() * 90 || ' days')::INTERVAL,
    NOW() + (RANDOM() * 30 || ' days')::INTERVAL,
    0
FROM utilisateurs u
WHERE u.id BETWEEN 71 AND 90;

-- Seconds crédits pour certains profils moyens
INSERT INTO credits_enregistres (utilisateur_id, type_credit, montant_principal, montant_total, montant_restant, taux_interet, duree_mois, statut, date_approbation, date_echeance, date_prochain_paiement, montant_prochain_paiement)
SELECT 
    u.id,
    'depannage'::type_credit,
    FLOOR(RANDOM() * 250000 + 100000),
    0,
    0,
    0.04,
    1,
    'en_retard'::statut_credit,
    date_aleatoire_passe(60),
    NOW() - (RANDOM() * 15 || ' days')::INTERVAL,
    NOW() - (RANDOM() * 10 || ' days')::INTERVAL,
    0
FROM utilisateurs u
WHERE u.id BETWEEN 75 AND 85;

-- CRÉDITS POUR PROFILS À RISQUE (10 clients - 15 crédits)
INSERT INTO credits_enregistres (utilisateur_id, type_credit, montant_principal, montant_total, montant_restant, taux_interet, duree_mois, statut, date_approbation, date_echeance, date_prochain_paiement, montant_prochain_paiement)
SELECT 
    u.id,
    CASE 
        WHEN RANDOM() < 0.5 THEN 'avance_salaire'::type_credit
        ELSE 'depannage'::type_credit
    END,
    FLOOR(RANDOM() * 200000 + 80000),
    0,
    0,
    CASE 
        WHEN RANDOM() < 0.5 THEN 0.03
        ELSE 0.04
    END,
    1,
    CASE 
        WHEN RANDOM() < 0.7 THEN 'en_retard'::statut_credit
        ELSE 'defaut'::statut_credit
    END,
    date_aleatoire_passe(180),
    NOW() - (RANDOM() * 45 || ' days')::INTERVAL,
    NOW() - (RANDOM() * 30 || ' days')::INTERVAL,
    0
FROM utilisateurs u
WHERE u.id BETWEEN 91 AND 100;

-- Seconds crédits pour profils à risque
INSERT INTO credits_enregistres (utilisateur_id, type_credit, montant_principal, montant_total, montant_restant, taux_interet, duree_mois, statut, date_approbation, date_echeance, date_prochain_paiement, montant_prochain_paiement)
SELECT 
    u.id,
    'depannage'::type_credit,
    FLOOR(RANDOM() * 150000 + 50000),
    0,
    0,
    0.04,
    1,
    'defaut'::statut_credit,
    date_aleatoire_passe(90),
    NOW() - (RANDOM() * 60 || ' days')::INTERVAL,
    NOW() - (RANDOM() * 45 || ' days')::INTERVAL,
    0
FROM utilisateurs u
WHERE u.id BETWEEN 91 AND 95;

-- CORRECTION: Calcul des montants avec CAST explicite vers NUMERIC
UPDATE credits_enregistres
SET 
    montant_total = (montant_principal * (1 + taux_interet * duree_mois))::NUMERIC(12,2),
    montant_restant = CASE 
        WHEN statut = 'solde' THEN 0
        WHEN statut = 'actif' THEN (montant_principal * (1 + taux_interet * duree_mois) * RANDOM() * 0.7)::NUMERIC(12,2)
        WHEN statut = 'en_retard' THEN (montant_principal * (1 + taux_interet * duree_mois) * (0.5 + RANDOM() * 0.4))::NUMERIC(12,2)
        ELSE (montant_principal * (1 + taux_interet * duree_mois))::NUMERIC(12,2)
    END,
    montant_prochain_paiement = CASE 
        WHEN statut IN ('actif', 'en_retard') THEN (montant_principal * 0.3 * (1 + RANDOM() * 0.5))::NUMERIC(12,2)
        ELSE NULL
    END
WHERE montant_total = 0;

-- ============================================================================
-- ÉTAPE 3: Génération de l'historique des paiements (1000+ paiements)
-- ============================================================================

CREATE OR REPLACE FUNCTION generer_paiements_credit(p_credit_id INTEGER)
RETURNS VOID AS $$
DECLARE
    v_credit RECORD;
    v_date_paiement TIMESTAMP;
    v_montant_paiement DECIMAL(12,2);
    v_nb_paiements INTEGER;
    v_i INTEGER;
    v_jours_retard INTEGER;
    v_type_paiement type_paiement;
BEGIN
    SELECT * INTO v_credit FROM credits_enregistres WHERE id = p_credit_id;
    
    v_nb_paiements := CASE 
        WHEN v_credit.statut = 'solde' THEN v_credit.duree_mois
        WHEN v_credit.statut = 'actif' THEN FLOOR(v_credit.duree_mois * (0.3 + RANDOM() * 0.5))
        WHEN v_credit.statut = 'en_retard' THEN FLOOR(v_credit.duree_mois * (0.2 + RANDOM() * 0.4))
        ELSE FLOOR(v_credit.duree_mois * (0.1 + RANDOM() * 0.3))
    END;
    
    v_montant_paiement := v_credit.montant_total / v_credit.duree_mois;
    
    FOR v_i IN 1..v_nb_paiements LOOP
        v_date_paiement := v_credit.date_approbation + (v_i * 30 || ' days')::INTERVAL;
        
        IF v_credit.statut = 'solde' OR (v_credit.statut = 'actif' AND RANDOM() > 0.2) THEN
            v_jours_retard := 0;
            v_type_paiement := 'a_temps'::type_paiement;
        ELSIF RANDOM() > 0.5 THEN
            v_jours_retard := FLOOR(RANDOM() * 15 + 1);
            v_type_paiement := 'en_retard'::type_paiement;
            v_date_paiement := v_date_paiement + (v_jours_retard || ' days')::INTERVAL;
        ELSE
            v_jours_retard := FLOOR(RANDOM() * 45 + 15);
            v_type_paiement := 'en_retard'::type_paiement;
            v_date_paiement := v_date_paiement + (v_jours_retard || ' days')::INTERVAL;
        END IF;
        
        INSERT INTO historique_paiements (
            credit_id, 
            utilisateur_id, 
            montant, 
            date_paiement, 
            date_prevue,
            jours_retard, 
            type_paiement,
            frais_retard
        ) VALUES (
            p_credit_id,
            v_credit.utilisateur_id,
            v_montant_paiement * (0.9 + RANDOM() * 0.2),
            v_date_paiement,
            v_credit.date_approbation + (v_i * 30 || ' days')::INTERVAL,
            v_jours_retard,
            v_type_paiement,
            CASE WHEN v_jours_retard > 0 THEN v_jours_retard * 500 ELSE 0 END
        );
    END LOOP;
    
    IF v_credit.statut IN ('en_retard', 'defaut') THEN
        FOR v_i IN 1..FLOOR(RANDOM() * 3 + 1) LOOP
            INSERT INTO historique_paiements (
                credit_id, 
                utilisateur_id, 
                montant, 
                date_paiement, 
                date_prevue,
                jours_retard, 
                type_paiement,
                frais_retard
            ) VALUES (
                p_credit_id,
                v_credit.utilisateur_id,
                0,
                v_credit.date_approbation + ((v_nb_paiements + v_i) * 30 || ' days')::INTERVAL,
                v_credit.date_approbation + ((v_nb_paiements + v_i) * 30 || ' days')::INTERVAL,
                FLOOR(RANDOM() * 60 + 30),
                'manque'::type_paiement,
                FLOOR(RANDOM() * 60 + 30) * 500
            );
        END LOOP;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Générer les paiements pour tous les crédits
DO $$
DECLARE
    v_credit_id INTEGER;
BEGIN
    FOR v_credit_id IN SELECT id FROM credits_enregistres ORDER BY id LOOP
        PERFORM generer_paiements_credit(v_credit_id);
    END LOOP;
END;
$$;

-- ============================================================================
-- ÉTAPE 4: Génération de l'historique des scores (500+ entrées)
-- ============================================================================

CREATE OR REPLACE FUNCTION generer_historique_score_utilisateur(p_utilisateur_id INTEGER)
RETURNS VOID AS $$
DECLARE
    v_user RECORD;
    v_nb_entrees INTEGER;
    v_i INTEGER;
    v_date TIMESTAMP;
    v_score DECIMAL(3,1);
    v_score_precedent DECIMAL(3,1);
    v_evenement TEXT;
BEGIN
    SELECT * INTO v_user FROM utilisateurs WHERE id = p_utilisateur_id;
    
    v_nb_entrees := FLOOR(RANDOM() * 8 + 3);
    v_score := v_user.score_credit - (RANDOM() * 2 + 1);
    
    FOR v_i IN 1..v_nb_entrees LOOP
        v_score_precedent := v_score;
        v_date := NOW() - ((v_nb_entrees - v_i) * 45 || ' days')::INTERVAL;
        
        v_score := v_score + (v_user.score_credit - v_score) / (v_nb_entrees - v_i + 1) + (RANDOM() - 0.5) * 0.3;
        v_score := GREATEST(0, LEAST(10, v_score));
        
        v_evenement := CASE 
            WHEN RANDOM() < 0.4 THEN 'Paiement à temps'
            WHEN RANDOM() < 0.6 THEN 'Nouveau crédit accordé'
            WHEN RANDOM() < 0.8 THEN 'Crédit remboursé intégralement'
            WHEN RANDOM() < 0.9 THEN 'Paiement en retard'
            ELSE 'Mise à jour automatique'
        END;
        
        INSERT INTO historique_scores (
            utilisateur_id,
            score_credit,
            score_850,
            score_precedent,
            changement,
            niveau_risque,
            montant_eligible,
            evenement_declencheur,
            ratio_paiements_temps,
            tendance,
            date_calcul
        ) VALUES (
            p_utilisateur_id,
            ROUND(v_score, 1),
            300 + FLOOR(v_score * 55),
            ROUND(v_score_precedent, 1),
            ROUND(v_score - v_score_precedent, 1),
            CASE 
                WHEN v_score >= 8 THEN 'bas'::niveau_risque
                WHEN v_score >= 6 THEN 'moyen'::niveau_risque
                WHEN v_score >= 4 THEN 'eleve'::niveau_risque
                ELSE 'tres_eleve'::niveau_risque
            END,
            CASE 
                WHEN v_score >= 8 THEN v_user.revenu_mensuel * 0.7
                WHEN v_score >= 6 THEN v_user.revenu_mensuel * 0.5
                WHEN v_score >= 4 THEN v_user.revenu_mensuel * 0.3
                ELSE 0
            END,
            v_evenement,
            0.65 + v_score * 0.03,
            CASE 
                WHEN v_score > v_score_precedent + 0.2 THEN 'amelioration'
                WHEN v_score < v_score_precedent - 0.2 THEN 'degradation'
                ELSE 'stable'
            END,
            v_date
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Générer l'historique pour tous les utilisateurs
DO $$
DECLARE
    v_user_id INTEGER;
BEGIN
    FOR v_user_id IN SELECT id FROM utilisateurs ORDER BY id LOOP
        PERFORM generer_historique_score_utilisateur(v_user_id);
    END LOOP;
END;
$$;

-- ============================================================================
-- ÉTAPE 5: Génération des restrictions de crédit
-- ============================================================================

INSERT INTO restrictions_credit (
    utilisateur_id,
    peut_emprunter,
    credits_actifs_count,
    credits_max_autorises,
    dette_totale_active,
    ratio_endettement,
    date_derniere_demande,
    date_prochaine_eligibilite,
    jours_avant_prochaine_demande,
    raison_blocage
)
SELECT 
    u.id,
    CASE 
        WHEN COUNT(c.id) FILTER (WHERE c.statut = 'actif') >= 2 THEN FALSE
        WHEN u.score_credit < 4 THEN FALSE
        WHEN COALESCE(SUM(c.montant_restant) FILTER (WHERE c.statut = 'actif'), 0) / NULLIF(u.revenu_mensuel, 0) > 0.7 THEN FALSE
        ELSE TRUE
    END,
    COUNT(c.id) FILTER (WHERE c.statut = 'actif'),
    2,
    COALESCE(SUM(c.montant_restant) FILTER (WHERE c.statut = 'actif'), 0),
    ROUND((COALESCE(SUM(c.montant_restant) FILTER (WHERE c.statut = 'actif'), 0) / NULLIF(u.revenu_mensuel, 0)) * 100, 2),
    MAX(c.date_approbation),
    CASE 
        WHEN COUNT(c.id) FILTER (WHERE c.statut = 'actif') >= 2 THEN NULL
        WHEN MAX(c.date_approbation) IS NOT NULL THEN MAX(c.date_approbation) + INTERVAL '30 days'
        ELSE NULL
    END,
    CASE 
        WHEN MAX(c.date_approbation) IS NOT NULL THEN 
            GREATEST(0, 30 - EXTRACT(DAY FROM NOW() - MAX(c.date_approbation)))::INTEGER
        ELSE NULL
    END,
    CASE 
        WHEN COUNT(c.id) FILTER (WHERE c.statut = 'actif') >= 2 THEN 'Maximum de 2 crédits actifs atteint'
        WHEN u.score_credit < 4 THEN 'Score de crédit insuffisant'
        WHEN COALESCE(SUM(c.montant_restant) FILTER (WHERE c.statut = 'actif'), 0) / NULLIF(u.revenu_mensuel, 0) > 0.7 THEN 'Ratio d''endettement trop élevé (>70%)'
        ELSE NULL
    END
FROM utilisateurs u
LEFT JOIN credits_enregistres c ON u.id = c.utilisateur_id
GROUP BY u.id;

-- ============================================================================
-- ÉTAPE 6: Génération des demandes de crédit longues (30 demandes)
-- ============================================================================

CREATE OR REPLACE FUNCTION generer_numero_demande()
RETURNS VARCHAR(50) AS $$
BEGIN
    RETURN 'LCR-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || 
           LPAD(FLOOR(RANDOM() * 9999 + 1)::TEXT, 4, '0');
END;
$$ LANGUAGE plpgsql;

INSERT INTO demandes_credit_longues (
    numero_demande,
    utilisateur_id,
    type_credit,
    montant_demande,
    duree_mois,
    objectif,
    statut,
    date_soumission,
    date_decision,
    decideur_id,
    montant_approuve,
    taux_approuve,
    notes_decision,
    score_au_moment_demande,
    niveau_risque_evaluation
)
SELECT 
    generer_numero_demande(),
    u.id,
    CASE 
        WHEN RANDOM() < 0.5 THEN 'consommation_generale'::type_credit
        ELSE 'investissement'::type_credit
    END,
    FLOOR(RANDOM() * 3000000 + 1000000),
    FLOOR(RANDOM() * 24 + 12)::INTEGER,
    CASE 
        WHEN RANDOM() < 0.3 THEN 'Achat de véhicule professionnel'
        WHEN RANDOM() < 0.5 THEN 'Développement d''activité commerciale'
        WHEN RANDOM() < 0.7 THEN 'Travaux de rénovation immobilière'
        ELSE 'Investissement dans équipements professionnels'
    END,
    CASE 
        WHEN RANDOM() < 0.3 THEN 'soumise'
        WHEN RANDOM() < 0.5 THEN 'en_examen'
        WHEN RANDOM() < 0.7 THEN 'approuvee'
        WHEN RANDOM() < 0.9 THEN 'rejetee'
        ELSE 'en_attente_documents'
    END,
    date_aleatoire_passe(120),
    CASE WHEN RANDOM() > 0.3 THEN date_aleatoire_passe(60) ELSE NULL END,
    CASE WHEN RANDOM() > 0.3 THEN 2 ELSE NULL END,
    CASE WHEN RANDOM() > 0.5 THEN FLOOR(RANDOM() * 2500000 + 800000) ELSE NULL END,
    CASE WHEN RANDOM() > 0.5 THEN 0.06 + RANDOM() * 0.04 ELSE NULL END,
    CASE 
        WHEN RANDOM() < 0.3 THEN 'Dossier complet - Approbation accordée'
        WHEN RANDOM() < 0.5 THEN 'Revenus insuffisants pour le montant demandé'
        WHEN RANDOM() < 0.7 THEN 'Documents complémentaires requis'
        ELSE 'En cours d''analyse par le comité'
    END,
    u.score_credit,
    u.niveau_risque
FROM utilisateurs u
WHERE u.id IN (
    SELECT id FROM utilisateurs 
    WHERE score_credit >= 5 
    ORDER BY RANDOM() 
    LIMIT 30
);

-- ============================================================================
-- VUES UTILES POUR L'ANALYSE
-- ============================================================================

CREATE OR REPLACE VIEW v_dashboard_utilisateurs AS
SELECT 
    u.id,
    u.nom,
    u.prenom,
    u.email,
    u.telephone,
    u.ville,
    u.profession,
    u.statut_emploi,
    u.revenu_mensuel,
    u.score_credit,
    u.niveau_risque,
    u.montant_eligible,
    r.peut_emprunter,
    r.credits_actifs_count,
    r.dette_totale_active,
    r.ratio_endettement,
    r.raison_blocage,
    COUNT(DISTINCT c.id) FILTER (WHERE c.statut = 'actif') AS credits_actifs,
    COUNT(DISTINCT c.id) FILTER (WHERE c.statut = 'solde') AS credits_soldes,
    COUNT(DISTINCT c.id) FILTER (WHERE c.statut = 'en_retard') AS credits_en_retard,
    COALESCE(SUM(c.montant_restant) FILTER (WHERE c.statut = 'actif'), 0) AS total_dette_active
FROM utilisateurs u
LEFT JOIN restrictions_credit r ON u.id = r.utilisateur_id
LEFT JOIN credits_enregistres c ON u.id = c.utilisateur_id
GROUP BY u.id, r.peut_emprunter, r.credits_actifs_count, r.dette_totale_active, 
         r.ratio_endettement, r.raison_blocage;

COMMENT ON VIEW v_dashboard_utilisateurs IS 'Vue complète de la situation de chaque utilisateur';

CREATE OR REPLACE VIEW v_analyse_paiements AS
SELECT 
    u.id AS utilisateur_id,
    u.nom,
    u.prenom,
    COUNT(hp.id) AS total_paiements,
    COUNT(hp.id) FILTER (WHERE hp.type_paiement = 'a_temps') AS paiements_a_temps,
    COUNT(hp.id) FILTER (WHERE hp.type_paiement = 'en_retard') AS paiements_en_retard,
    COUNT(hp.id) FILTER (WHERE hp.type_paiement = 'manque') AS paiements_manques,
    ROUND(
        COUNT(hp.id) FILTER (WHERE hp.type_paiement = 'a_temps')::NUMERIC / 
        NULLIF(COUNT(hp.id), 0) * 100, 
        2
    ) AS taux_paiements_temps,
    ROUND(AVG(hp.jours_retard), 1) AS moyenne_jours_retard,
    SUM(hp.montant) AS total_paye,
    SUM(hp.frais_retard) AS total_frais_retard
FROM utilisateurs u
LEFT JOIN historique_paiements hp ON u.id = hp.utilisateur_id
GROUP BY u.id, u.nom, u.prenom;

COMMENT ON VIEW v_analyse_paiements IS 'Statistiques de paiement par utilisateur pour ML';

CREATE OR REPLACE VIEW v_evolution_scores AS
SELECT 
    u.id AS utilisateur_id,
    u.nom,
    u.prenom,
    u.score_credit AS score_actuel,
    hs.score_credit AS score_historique,
    hs.changement,
    hs.tendance,
    hs.evenement_declencheur,
    hs.date_calcul,
    ROW_NUMBER() OVER (PARTITION BY u.id ORDER BY hs.date_calcul DESC) AS rang
FROM utilisateurs u
LEFT JOIN historique_scores hs ON u.id = hs.utilisateur_id
ORDER BY u.id, hs.date_calcul DESC;

COMMENT ON VIEW v_evolution_scores IS 'Historique de l''évolution des scores par utilisateur';

-- ============================================================================
-- STATISTIQUES ET VÉRIFICATIONS
-- ============================================================================

CREATE OR REPLACE VIEW v_statistiques_globales AS
SELECT 
    (SELECT COUNT(*) FROM utilisateurs) AS total_utilisateurs,
    (SELECT COUNT(*) FROM credits_enregistres) AS total_credits,
    (SELECT COUNT(*) FROM historique_paiements) AS total_paiements,
    (SELECT COUNT(*) FROM historique_scores) AS total_entrees_score,
    (SELECT COUNT(*) FROM demandes_credit_longues) AS total_demandes_longues,
    (SELECT COUNT(*) FROM utilisateurs WHERE score_credit >= 8) AS utilisateurs_excellents,
    (SELECT COUNT(*) FROM utilisateurs WHERE score_credit BETWEEN 6 AND 7.9) AS utilisateurs_bons,
    (SELECT COUNT(*) FROM utilisateurs WHERE score_credit BETWEEN 4 AND 5.9) AS utilisateurs_moyens,
    (SELECT COUNT(*) FROM utilisateurs WHERE score_credit < 4) AS utilisateurs_risque,
    (SELECT COUNT(*) FROM credits_enregistres WHERE statut = 'actif') AS credits_actifs,
    (SELECT COUNT(*) FROM credits_enregistres WHERE statut = 'solde') AS credits_soldes,
    (SELECT COUNT(*) FROM credits_enregistres WHERE statut = 'en_retard') AS credits_en_retard,
    (SELECT SUM(montant_restant) FROM credits_enregistres WHERE statut = 'actif') AS encours_total,
    (SELECT ROUND(AVG(score_credit), 2) FROM utilisateurs) AS score_moyen,
    (SELECT ROUND(AVG(ratio_endettement), 2) FROM restrictions_credit) AS ratio_endettement_moyen;

-- ============================================================================
-- AFFICHAGE DES STATISTIQUES
-- ============================================================================

SELECT '========================================' AS "STATISTIQUES DE LA BASE";
SELECT * FROM v_statistiques_globales;

SELECT '========================================' AS "RÉPARTITION PAR PROFIL";
SELECT 
    CASE 
        WHEN score_credit >= 8 THEN 'Excellent (8-10)'
        WHEN score_credit >= 6 THEN 'Bon (6-8)'
        WHEN score_credit >= 4 THEN 'Moyen (4-6)'
        ELSE 'À risque (<4)'
    END AS profil,
    COUNT(*) AS nombre,
    ROUND(AVG(revenu_mensuel), 0) AS revenu_moyen,
    ROUND(AVG(score_credit), 2) AS score_moyen,
    COUNT(*) FILTER (WHERE peut_emprunter = TRUE) AS peuvent_emprunter
FROM utilisateurs u
LEFT JOIN restrictions_credit r ON u.id = r.utilisateur_id
GROUP BY 
    CASE 
        WHEN score_credit >= 8 THEN 'Excellent (8-10)'
        WHEN score_credit >= 6 THEN 'Bon (6-8)'
        WHEN score_credit >= 4 THEN 'Moyen (4-6)'
        ELSE 'À risque (<4)'
    END
ORDER BY score_moyen DESC;

SELECT '========================================' AS "RÉPARTITION PAR VILLE";
SELECT 
    ville,
    COUNT(*) AS nombre_clients,
    ROUND(AVG(score_credit), 2) AS score_moyen,
    ROUND(AVG(revenu_mensuel), 0) AS revenu_moyen
FROM utilisateurs
GROUP BY ville
ORDER BY nombre_clients DESC;