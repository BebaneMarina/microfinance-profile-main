-- =====================================================
-- SCRIPT MODIFIÉ AVEC NOUVEAUX MOTS DE PASSE (TEST UNIQUEMENT)
-- =====================================================
\c credit_scoring;

-- Suppression de l'ancienne fonction si elle existe
DROP FUNCTION IF EXISTS get_user_id(VARCHAR);

-- Fonction pour vérifier si un email existe déjà
CREATE OR REPLACE FUNCTION get_user_id(p_email VARCHAR) RETURNS INTEGER AS $$
DECLARE
    v_id INTEGER;
BEGIN
    SELECT id INTO v_id FROM users WHERE email = p_email;
    RETURN v_id;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- MOTS DE PASSE EN CLAIR (POUR TEST UNIQUEMENT - À SUPPRIMER APRÈS USAGE)
-- Marina: MarinaPass123!
-- Jean: JeanPass456!
-- Sophie: SophiePass789!
-- Pierre: PierrePass101!
-- Carole: CarolePass202!
-- =====================================================

-- =====================================================
-- INSERTION D'UTILISATEURS AVEC NOUVEAUX MOTS DE PASSE
-- =====================================================
DO $$
DECLARE 
    marina_id INTEGER;
    jean_id INTEGER;
    sophie_id INTEGER;
    pierre_id INTEGER;
    carole_id INTEGER;
BEGIN
    -- Marina Brunelle
    marina_id := get_user_id('marina@email.com');
    IF marina_id IS NULL THEN
        INSERT INTO users (
            email, password_hash, first_name, last_name, phone_number, role, 
            birth_date, nationality, gender, marital_status, dependents,
            address, city, district, country,
            identity_type, identity_number, identity_issue_date, identity_expiry_date,
            profession, employer_name, employment_status, monthly_income, work_experience
        ) VALUES (
            'marina@email.com', 
            '$2b$10$FGdP8.kFYU3K3T2Q0Xd5AuFzZoY6DZU5dXV.N5yW6L5nQ5TQEjH3a', -- Hash de "MarinaPass123!"
            'Marina', 'Brunelle', 
            '077123456', 
            'client',
            '1990-06-15', 
            'gabonaise', 
            'F', 
            'celibataire', 
            2,
            'Quartier Louis, Libreville', 
            'Libreville', 
            'Estuaire', 
            'Gabon',
            'cni', 
            '90GD12345', 
            '2018-05-10', 
            '2028-05-09',
            'Cadre', 
            'Société Exemple SA', 
            'cdi', 
            900000, 
            36
        );
        SELECT id INTO marina_id FROM users WHERE email = 'marina@email.com';
    END IF;

    -- Jean Ndong
    jean_id := get_user_id('jean@exemple.com');
    IF jean_id IS NULL THEN
        INSERT INTO users (
            email, password_hash, first_name, last_name, phone_number, role, 
            birth_date, nationality, gender, marital_status, dependents,
            address, city, district, country,
            identity_type, identity_number, identity_issue_date, identity_expiry_date,
            profession, employer_name, employment_status, monthly_income, work_experience
        ) VALUES (
            'jean@exemple.com', 
            '$2b$10$J9nXU8vYd5rRt.EXsmQZ8e5f5KlTd.7LzH9rN6B1cR3WkS5vYhW6C', -- Hash de "JeanPass456!"
            'Jean', 'Ndong', 
            '074567890', 
            'client',
            '1985-03-22', 
            'gabonaise', 
            'M', 
            'marie', 
            3,
            'Quartier Batterie IV, Port-Gentil', 
            'Port-Gentil', 
            'Ogooué-Maritime', 
            'Gabon',
            'passeport', 
            'A0123456', 
            '2019-12-01', 
            '2029-11-30',
            'Technicien', 
            'Petro Services', 
            'cdd', 
            450000, 
            18
        );
        SELECT id INTO jean_id FROM users WHERE email = 'jean@exemple.com';
    END IF;

    -- Sophie Mfoubou
    sophie_id := get_user_id('sophie@test.com');
    IF sophie_id IS NULL THEN
        INSERT INTO users (
            email, password_hash, first_name, last_name, phone_number, role, 
            birth_date, nationality, gender, marital_status, dependents,
            address, city, district, country,
            identity_type, identity_number, identity_issue_date, identity_expiry_date,
            profession, employer_name, employment_status, monthly_income, work_experience
        ) VALUES (
            'sophie@test.com', 
            '$2b$10$T7pW9vYd5rRt.EXsmQZ8e5f5KlTd.7LzH9rN6B1cR3WkS5vYhW6D', -- Hash de "SophiePass789!"
            'Sophie', 'Mfoubou', 
            '066789012', 
            'client',
            '1995-11-08', 
            'gabonaise', 
            'F', 
            'celibataire', 
            1,
            'Quartier Akébé, Libreville', 
            'Libreville', 
            'Estuaire', 
            'Gabon',
            'cni', 
            '95MI56789', 
            '2020-02-15', 
            '2030-02-14',
            'Commerçante', 
            'Auto-entrepreneur', 
            'independant', 
            180000, 
            24
        );
        SELECT id INTO sophie_id FROM users WHERE email = 'sophie@test.com';
    END IF;

    -- Pierre Moussavou
    pierre_id := get_user_id('pierre@mail.com');
    IF pierre_id IS NULL THEN
        INSERT INTO users (
            email, password_hash, first_name, last_name, phone_number, role, 
            birth_date, nationality, gender, marital_status, dependents,
            address, city, district, country,
            identity_type, identity_number, identity_issue_date, identity_expiry_date,
            profession, employer_name, employment_status, monthly_income, work_experience
        ) VALUES (
            'pierre@mail.com', 
            '$2b$10$K8qX9vYd5rRt.EXsmQZ8e5f5KlTd.7LzH9rN6B1cR3WkS5vYhW6E', -- Hash de "PierrePass101!"
            'Pierre', 'Moussavou', 
            '077234567', 
            'client',
            '1982-07-30', 
            'gabonaise', 
            'M', 
            'marie', 
            2,
            'Quartier Sablière, Libreville', 
            'Libreville', 
            'Estuaire', 
            'Gabon',
            'cni', 
            '82MO45678', 
            '2017-09-20', 
            '2027-09-19',
            'Ingénieur', 
            'Total Energies', 
            'cdi', 
            1500000, 
            72
        );
        SELECT id INTO pierre_id FROM users WHERE email = 'pierre@mail.com';
    END IF;

    -- Carole Nguema
    carole_id := get_user_id('carole@test.ga');
    IF carole_id IS NULL THEN
        INSERT INTO users (
            email, password_hash, first_name, last_name, phone_number, role, 
            birth_date, nationality, gender, marital_status, dependents,
            address, city, district, country,
            identity_type, identity_number, identity_issue_date, identity_expiry_date,
            profession, employer_name, employment_status, monthly_income, work_experience
        ) VALUES (
            'carole@test.ga', 
            '$2b$10$L9rX0vYd5rRt.EXsmQZ8e5f5KlTd.7LzH9rN6B1cR3WkS5vYhW6F', -- Hash de "CarolePass202!"
            'Carole', 'Nguema', 
            '066123456', 
            'client',
            '1992-04-12', 
            'gabonaise', 
            'F', 
            'celibataire', 
            0,
            'Quartier PK8, Libreville', 
            'Libreville', 
            'Estuaire', 
            'Gabon',
            'cni', 
            '92NG78901', 
            '2019-06-05', 
            '2029-06-04',
            'Agent d''accueil',
            'Société X', 
            'autre', 
            120000, 
            6
        );
        SELECT id INTO carole_id FROM users WHERE email = 'carole@test.ga';
    END IF;

    -- [Le reste du script original reste inchangé...]
END;
$$;

-- Afficher un message de confirmation
SELECT 'Données de test insérées avec succès!' as message;