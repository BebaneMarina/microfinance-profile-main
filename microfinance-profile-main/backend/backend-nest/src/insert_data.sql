-- =====================================================
-- SCRIPT D'INSERTION DE DONNÉES AVEC GESTION DES ERREURS
-- =====================================================
\c credit_scoring;

-- =====================================================
-- OBTENIR LES ID EXISTANTS
-- =====================================================
-- Créons une fonction pour vérifier si un email existe déjà
CREATE OR REPLACE FUNCTION get_user_id(p_email VARCHAR) RETURNS INTEGER AS $$
DECLARE
    v_id INTEGER;
BEGIN
    SELECT id INTO v_id FROM users WHERE email = p_email;
    RETURN v_id;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- INSERTION D'UTILISATEURS (CLIENTS)
-- =====================================================
DO $$
DECLARE 
    marina_id INTEGER;
    jean_id INTEGER;
    sophie_id INTEGER;
    pierre_id INTEGER;
    carole_id INTEGER;
BEGIN
    -- Vérifier si Marina existe déjà
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
            '$2b$10$FGdP8.kFYU3K3T2Q0Xd5AuFzZoY6DZU5dXV.N5yW6L5nQ5TQEjH3a', 
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
    ELSE
        -- Mettre à jour les informations de Marina si nécessaire
        UPDATE users SET 
            monthly_income = 900000,
            employment_status = 'cdi',
            work_experience = 36
        WHERE id = marina_id;
    END IF;

    -- Insérer Jean (s'il n'existe pas)
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
            '$2b$10$FGdP8.kFYU3K3T2Q0Xd5AuFzZoY6DZU5dXV.N5yW6L5nQ5TQEjH3a', 
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

    -- Insérer Sophie (s'il n'existe pas)
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
            '$2b$10$FGdP8.kFYU3K3T2Q0Xd5AuFzZoY6DZU5dXV.N5yW6L5nQ5TQEjH3a', 
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

    -- Insérer Pierre (s'il n'existe pas)
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
            '$2b$10$FGdP8.kFYU3K3T2Q0Xd5AuFzZoY6DZU5dXV.N5yW6L5nQ5TQEjH3a', 
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

    -- Insérer Carole (s'il n'existe pas)
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
            '$2b$10$FGdP8.kFYU3K3T2Q0Xd5AuFzZoY6DZU5dXV.N5yW6L5nQ5TQEjH3a', 
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

    -- Créer des paramètres utilisateurs pour les nouveaux clients
    INSERT INTO user_settings (user_id)
    SELECT id FROM users WHERE id NOT IN (SELECT user_id FROM user_settings);

    -- =====================================================
    -- INSERTION DE DEMANDES DE CRÉDIT
    -- =====================================================
    -- Supprimer les anciennes demandes pour éviter les doublons
    DELETE FROM credit_scoring WHERE credit_request_id IN (
        SELECT id FROM credit_requests WHERE user_id IN (marina_id, jean_id, sophie_id, pierre_id, carole_id)
    );
    DELETE FROM payments WHERE user_id IN (marina_id, jean_id, sophie_id, pierre_id, carole_id);
    DELETE FROM repayment_schedule WHERE loan_contract_id IN (
        SELECT id FROM loan_contracts WHERE user_id IN (marina_id, jean_id, sophie_id, pierre_id, carole_id)
    );
    DELETE FROM loan_contracts WHERE user_id IN (marina_id, jean_id, sophie_id, pierre_id, carole_id);
    DELETE FROM credit_requests WHERE user_id IN (marina_id, jean_id, sophie_id, pierre_id, carole_id);

    -- Insérer les demandes de crédit
    -- Marina
    INSERT INTO credit_requests (
        request_number, user_id, credit_type, status, 
        requested_amount, approved_amount, duration_months, interest_rate,
        purpose, repayment_mode, repayment_frequency,
        credit_score, risk_level, probability, decision,
        submission_date, created_at
    ) VALUES (
        'REQ-20240715-000001',
        marina_id,
        'consommation_generale',
        'approved',
        500000,
        500000,
        12,
        0.05,
        'Achat d''équipement électroménager',
        'mensuel',
        'mensuel',
        8,
        'low',
        0.85,
        'approuvé',
        '2024-07-15 10:30:00',
        '2024-07-15 10:30:00'
    );

    -- Jean
    INSERT INTO credit_requests (
        request_number, user_id, credit_type, status, 
        requested_amount, approved_amount, duration_months, interest_rate,
        purpose, repayment_mode, repayment_frequency,
        credit_score, risk_level, probability, decision,
        submission_date, created_at
    ) VALUES (
        'REQ-20240720-000002',
        jean_id,
        'avance_salaire',
        'in_review',
        200000,
        NULL,
        1,
        0.03,
        'Avance sur salaire pour frais médicaux',
        'fin_du_mois',
        'fin_du_mois',
        5,
        'medium',
        0.65,
        'à étudier',
        '2024-07-20 14:45:00',
        '2024-07-20 14:45:00'
    );

    -- Sophie
    INSERT INTO credit_requests (
        request_number, user_id, credit_type, status, 
        requested_amount, approved_amount, duration_months, interest_rate,
        purpose, repayment_mode, repayment_frequency,
        credit_score, risk_level, probability, decision,
        submission_date, created_at
    ) VALUES (
        'REQ-20240710-000003',
        sophie_id,
        'depannage',
        'rejected',
        300000,
        NULL,
        1,
        0.04,
        'Dépannage pour paiement de loyer',
        'fin_du_mois',
        'fin_du_mois',
        3,
        'high',
        0.35,
        'refusé',
        '2024-07-10 09:15:00',
        '2024-07-10 09:15:00'
    );

    -- Pierre
    INSERT INTO credit_requests (
        request_number, user_id, credit_type, status, 
        requested_amount, approved_amount, duration_months, interest_rate,
        purpose, repayment_mode, repayment_frequency,
        credit_score, risk_level, probability, decision,
        submission_date, created_at
    ) VALUES (
        'REQ-20240705-000004',
        pierre_id,
        'consommation_generale',
        'approved',
        1000000,
        1000000,
        24,
        0.05,
        'Achat de mobilier pour la maison',
        'mensuel',
        'mensuel',
        9,
        'very_low',
        0.95,
        'approuvé',
        '2024-07-05 11:20:00',
        '2024-07-05 11:20:00'
    );

    -- Carole
    INSERT INTO credit_requests (
        request_number, user_id, credit_type, status, 
        requested_amount, approved_amount, duration_months, interest_rate,
        purpose, repayment_mode, repayment_frequency,
        credit_score, risk_level, probability, decision,
        submission_date, created_at
    ) VALUES (
        'REQ-20240718-000005',
        carole_id,
        'avance_salaire',
        'rejected',
        100000,
        NULL,
        1,
        0.03,
        'Avance sur salaire pour frais scolaires',
        'fin_du_mois',
        'fin_du_mois',
        2,
        'very_high',
        0.25,
        'refusé',
        '2024-07-18 16:30:00',
        '2024-07-18 16:30:00'
    );

    -- =====================================================
    -- INSERTION DE CONTRATS DE PRÊT
    -- =====================================================

    -- Récupérer les IDs des demandes
    DECLARE
        marina_req_id INTEGER;
        pierre_req_id INTEGER;
        marina_loan_id INTEGER;
        pierre_loan_id INTEGER;
    BEGIN
        SELECT id INTO marina_req_id FROM credit_requests WHERE user_id = marina_id AND status = 'approved';
        SELECT id INTO pierre_req_id FROM credit_requests WHERE user_id = pierre_id AND status = 'approved';

        -- Contrat pour Marina
        INSERT INTO loan_contracts (
            contract_number, credit_request_id, user_id,
            loan_amount, interest_rate, duration_months,
            monthly_payment, total_amount, total_interest,
            start_date, end_date, first_payment_date,
            status, signed_date
        ) VALUES (
            'CTR-20240716-000001',
            marina_req_id,
            marina_id,
            500000,
            0.05,
            12,
            43750,
            525000,
            25000,
            '2024-07-16',
            '2025-07-15',
            '2024-08-15',
            'active',
            '2024-07-16 14:30:00'
        );
        
        SELECT id INTO marina_loan_id FROM loan_contracts WHERE credit_request_id = marina_req_id;
        
        -- Contrat pour Pierre
        INSERT INTO loan_contracts (
            contract_number, credit_request_id, user_id,
            loan_amount, interest_rate, duration_months,
            monthly_payment, total_amount, total_interest,
            start_date, end_date, first_payment_date,
            status, signed_date
        ) VALUES (
            'CTR-20240706-000002',
            pierre_req_id,
            pierre_id,
            1000000,
            0.05,
            24,
            45833,
            1100000,
            100000,
            '2024-07-06',
            '2026-07-05',
            '2024-08-05',
            'active',
            '2024-07-06 15:45:00'
        );
        
        SELECT id INTO pierre_loan_id FROM loan_contracts WHERE credit_request_id = pierre_req_id;

        -- =====================================================
        -- INSERTION D'ÉCHÉANCIERS DE REMBOURSEMENT
        -- =====================================================
        
        -- Pour Marina (12 échéances mensuelles)
        INSERT INTO repayment_schedule (
            loan_contract_id, payment_number, due_date,
            principal_amount, interest_amount, total_amount, remaining_balance,
            status
        ) VALUES
        -- Première échéance (payée)
        (
            marina_loan_id, 1, '2024-08-15',
            39583, 4167, 43750, 460417,
            'paid'
        ),
        -- Deuxième échéance (payée)
        (
            marina_loan_id, 2, '2024-09-15',
            39913, 3837, 43750, 420504,
            'paid'
        ),
        -- Troisième échéance (payée)
        (
            marina_loan_id, 3, '2024-10-15',
            40245, 3505, 43750, 380259,
            'paid'
        ),
        -- Quatrième échéance (en cours)
        (
            marina_loan_id, 4, '2024-11-15',
            40581, 3169, 43750, 339678,
            'pending'
        ),
        -- Cinquième échéance
        (
            marina_loan_id, 5, '2024-12-15',
            40919, 2831, 43750, 298759,
            'pending'
        ),
        -- Sixième échéance
        (
            marina_loan_id, 6, '2025-01-15',
            41260, 2490, 43750, 257499,
            'pending'
        ),
        -- Septième échéance
        (
            marina_loan_id, 7, '2025-02-15',
            41604, 2146, 43750, 215895,
            'pending'
        ),
        -- Huitième échéance
        (
            marina_loan_id, 8, '2025-03-15',
            41950, 1800, 43750, 173945,
            'pending'
        ),
        -- Neuvième échéance
        (
            marina_loan_id, 9, '2025-04-15',
            42300, 1450, 43750, 131645,
            'pending'
        ),
        -- Dixième échéance
        (
            marina_loan_id, 10, '2025-05-15',
            42652, 1098, 43750, 88993,
            'pending'
        ),
        -- Onzième échéance
        (
            marina_loan_id, 11, '2025-06-15',
            43007, 743, 43750, 45986,
            'pending'
        ),
        -- Douzième échéance
        (
            marina_loan_id, 12, '2025-07-15',
            45986, 383, 46369, 0,
            'pending'
        );

        -- Pour Pierre (premières échéances seulement)
        INSERT INTO repayment_schedule (
            loan_contract_id, payment_number, due_date,
            principal_amount, interest_amount, total_amount, remaining_balance,
            status
        ) VALUES
        -- Première échéance (payée)
        (
            pierre_loan_id, 1, '2024-08-05',
            41667, 4167, 45834, 958333,
            'paid'
        ),
        -- Deuxième échéance (payée)
        (
            pierre_loan_id, 2, '2024-09-05',
            41840, 3993, 45833, 916493,
            'paid'
        ),
        -- Troisième échéance (payée)
        (
            pierre_loan_id, 3, '2024-10-05',
            42015, 3818, 45833, 874478,
            'paid'
        ),
        -- Quatrième échéance (en cours)
        (
            pierre_loan_id, 4, '2024-11-05',
            42190, 3643, 45833, 832288,
            'pending'
        ),
        -- Cinquième échéance
        (
            pierre_loan_id, 5, '2024-12-05',
            42366, 3467, 45833, 789922,
            'pending'
        ),
        -- Sixième échéance
        (
            pierre_loan_id, 6, '2025-01-05',
            42542, 3291, 45833, 747380,
            'pending'
        );

        -- =====================================================
        -- INSERTION DES PAIEMENTS
        -- =====================================================
        
        -- Récupérer les IDs des échéances
        DECLARE
            marina_rep1_id INTEGER;
            marina_rep2_id INTEGER;
            marina_rep3_id INTEGER;
            pierre_rep1_id INTEGER;
            pierre_rep2_id INTEGER;
            pierre_rep3_id INTEGER;
        BEGIN
            SELECT id INTO marina_rep1_id FROM repayment_schedule 
            WHERE loan_contract_id = marina_loan_id AND payment_number = 1;
            
            SELECT id INTO marina_rep2_id FROM repayment_schedule 
            WHERE loan_contract_id = marina_loan_id AND payment_number = 2;
            
            SELECT id INTO marina_rep3_id FROM repayment_schedule 
            WHERE loan_contract_id = marina_loan_id AND payment_number = 3;
            
            SELECT id INTO pierre_rep1_id FROM repayment_schedule 
            WHERE loan_contract_id = pierre_loan_id AND payment_number = 1;
            
            SELECT id INTO pierre_rep2_id FROM repayment_schedule 
            WHERE loan_contract_id = pierre_loan_id AND payment_number = 2;
            
            SELECT id INTO pierre_rep3_id FROM repayment_schedule 
            WHERE loan_contract_id = pierre_loan_id AND payment_number = 3;
            
            -- Paiements de Marina
            INSERT INTO payments (
                payment_reference, loan_contract_id, repayment_schedule_id, user_id,
                amount, payment_date, payment_method,
                principal_paid, interest_paid, late_fee_paid,
                transaction_id, transaction_status
            ) VALUES
            (
                'PAY-20240815-000001',
                marina_loan_id, marina_rep1_id, marina_id,
                43750, '2024-08-15 10:15:00', 'virement_bancaire',
                39583, 4167, 0,
                'TRX123456', 'completed'
            ),
            (
                'PAY-20240915-000002',
                marina_loan_id, marina_rep2_id, marina_id,
                43750, '2024-09-15 09:30:00', 'virement_bancaire',
                39913, 3837, 0,
                'TRX234567', 'completed'
            ),
            (
                'PAY-20241015-000003',
                marina_loan_id, marina_rep3_id, marina_id,
                43750, '2024-10-15 11:20:00', 'virement_bancaire',
                40245, 3505, 0,
                'TRX345678', 'completed'
            );
            
            -- Paiements de Pierre
            INSERT INTO payments (
                payment_reference, loan_contract_id, repayment_schedule_id, user_id,
                amount, payment_date, payment_method,
                principal_paid, interest_paid, late_fee_paid,
                transaction_id, transaction_status
            ) VALUES
            (
                'PAY-20240805-000004',
                pierre_loan_id, pierre_rep1_id, pierre_id,
                45834, '2024-08-05 14:30:00', 'virement_bancaire',
                41667, 4167, 0,
                'TRX456789', 'completed'
            ),
            (
                'PAY-20240905-000005',
                pierre_loan_id, pierre_rep2_id, pierre_id,
                45833, '2024-09-05 16:15:00', 'virement_bancaire',
                41840, 3993, 0,
                'TRX567890', 'completed'
            ),
            (
                'PAY-20241005-000006',
                pierre_loan_id, pierre_rep3_id, pierre_id,
                45833, '2024-10-05 15:45:00', 'virement_bancaire',
                42015, 3818, 0,
                'TRX678901', 'completed'
            );
        END;
        
        -- =====================================================
        -- INSERTION DE RÉSULTATS DE SCORING
        -- =====================================================
        
        -- Récupérer les IDs des demandes pour tous les clients
        DECLARE
            jean_req_id INTEGER;
            sophie_req_id INTEGER;
            carole_req_id INTEGER;
        BEGIN
            SELECT id INTO jean_req_id FROM credit_requests WHERE user_id = jean_id;
            SELECT id INTO sophie_req_id FROM credit_requests WHERE user_id = sophie_id;
            SELECT id INTO carole_req_id FROM credit_requests WHERE user_id = carole_id;
            
            INSERT INTO credit_scoring (
                credit_request_id, user_id,
                total_score, risk_level, probability, decision,
                income_score, employment_score, debt_ratio_score, credit_history_score,
                factors, recommendations,
                model_version, processing_time
            ) VALUES
            -- Scoring Marina Brunelle
            (
                marina_req_id, marina_id,
                8, 'low', 0.85, 'approuvé',
                9, 8, 8, 7,
                '[
                    {"name": "monthly_income", "value": 90, "impact": 3},
                    {"name": "employment_status", "value": 90, "impact": 2},
                    {"name": "job_seniority", "value": 80, "impact": 2},
                    {"name": "debt_ratio", "value": 85, "impact": 3}
                ]',
                ARRAY['Excellent profil ! Vous êtes éligible aux meilleures conditions', 'Votre quotité cessible vous permet d''emprunter jusqu''à 3 600 000 FCFA'],
                'quotite_cessible_v1.0', 0.35
            ),
            -- Scoring Jean Ndong
            (
                jean_req_id, jean_id,
                5, 'medium', 0.65, 'à étudier',
                6, 7, 5, 5,
                '[
                    {"name": "monthly_income", "value": 60, "impact": 2},
                    {"name": "employment_status", "value": 70, "impact": 2},
                    {"name": "job_seniority", "value": 50, "impact": 1},
                    {"name": "debt_ratio", "value": 50, "impact": 1}
                ]',
                ARRAY['Bon profil. Maintenir votre situation actuelle', 'Votre quotité cessible vous permet d''emprunter jusqu''à 900 000 FCFA'],
                'quotite_cessible_v1.0', 0.42
            ),
            -- Scoring Sophie Mfoubou
            (
                sophie_req_id, sophie_id,
                3, 'high', 0.35, 'refusé',
                4, 5, 2, 3,
                '[
                    {"name": "monthly_income", "value": 40, "impact": 1},
                    {"name": "employment_status", "value": 50, "impact": 1},
                    {"name": "job_seniority", "value": 60, "impact": 1},
                    {"name": "debt_ratio", "value": 20, "impact": -2}
                ]',
                ARRAY['Réduire vos dettes existantes pour améliorer votre quotité cessible disponible', 'Augmenter vos revenus mensuels améliorerait votre score'],
                'quotite_cessible_v1.0', 0.38
            ),
            -- Scoring Pierre Moussavou
            (
                pierre_req_id, pierre_id,
                9, 'very_low', 0.95, 'approuvé',
                10, 9, 9, 8,
                '[
                    {"name": "monthly_income", "value": 100, "impact": 3},
                    {"name": "employment_status", "value": 90, "impact": 2},
                    {"name": "job_seniority", "value": 90, "impact": 2},
                    {"name": "debt_ratio", "value": 90, "impact": 3}
                ]',
                ARRAY['Excellent profil ! Vous êtes éligible aux meilleures conditions', 'Votre quotité cessible vous permet d''emprunter jusqu''à 6 000 000 FCFA'],
                'quotite_cessible_v1.0', 0.30
            ),
            -- Scoring Carole Nguema
            (
                carole_req_id, carole_id,
                2, 'very_high', 0.25, 'refusé',
                3, 3, 1, 2,
                '[
                    {"name": "monthly_income", "value": 30, "impact": 1},
                    {"name": "employment_status", "value": 30, "impact": -1},
                    {"name": "job_seniority", "value": 20, "impact": -1},
                    {"name": "debt_ratio", "value": 10, "impact": -3}
                ]',
                ARRAY['Réduire vos dettes existantes pour améliorer votre quotité cessible disponible', 'Augmenter vos revenus mensuels améliorerait votre score', 'Un contrat CDI ou CDD améliorerait significativement votre profil'],
                'quotite_cessible_v1.0', 0.33
            );
        END;
    END;
END;
$$;

-- Afficher un message de confirmation
SELECT 'Données de test insérées avec succès!' as message;