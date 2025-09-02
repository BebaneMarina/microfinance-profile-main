-- Insert sample credit types
INSERT INTO credit_types (type_name, max_amount, max_duration, description) VALUES
('CREDIT_CONSOMMATION', 5000000, 36, 'Crédit à la consommation'),
('CREDIT_INVESTISSEMENT', 100000000, 36, 'Crédit investissement'),
('CREDIT_AVANCE_FACTURE', 10000000, 12, 'Avance sur facture'),
('CREDIT_TONTINE', 5000000, 24, 'Crédit tontine'),
('CREDIT_RETRAITE', 3000000, 12, 'Crédit retraité'),
('CREDIT_SPOT', 100000000, 3, 'Crédit spot');

-- Insert 20 sample applications with related data
-- 1. Crédit Consommation - Bon profil
INSERT INTO personal_info VALUES (1, 'Jean Ndong', 'CNI', '074123456', 'jean.ndong@email.com', 'Libreville');
INSERT INTO income_info VALUES (1, 1, 850000, 150000, 'Salaire + Location');
INSERT INTO employment_info VALUES (1, 1, 'SEEG', 'CDI', 60, 'Ingénieur');
INSERT INTO credit_applications VALUES (1, 1, 1, 2000000, 24, '2025-07-07', 'APPROVED', 850, 'LOW_RISK');

-- 2. Crédit Investissement - Entreprise établie
INSERT INTO personal_info VALUES (2, 'Marie Obone', 'CNI', '066789012', 'marie.obone@email.com', 'Port-Gentil');
INSERT INTO income_info VALUES (2, 2, 0, 5000000, 'Bénéfices entreprise');
INSERT INTO employment_info VALUES (2, 2, 'Obone & Fils SARL', 'GERANT', 96, 'Directrice');
INSERT INTO credit_applications VALUES (2, 2, 2, 50000000, 36, '2025-07-07', 'APPROVED', 920, 'LOW_RISK');

-- 3. Crédit Avance Facture - État
INSERT INTO personal_info VALUES (3, 'Pierre Mba', 'CNI', '077456789', 'pierre.mba@email.com', 'Oyem');
INSERT INTO income_info VALUES (3, 3, 0, 3000000, 'Entreprise');
INSERT INTO employment_info VALUES (3, 3, 'Mba Services', 'GERANT', 48, 'Directeur');
INSERT INTO credit_applications VALUES (3, 3, 3, 7000000, 6, '2025-07-07', 'APPROVED', 780, 'MEDIUM_RISK');

-- 4. Crédit Tontine - Bon historique
INSERT INTO personal_info VALUES (4, 'Sophie Aubame', 'CNI', '066234567', 'sophie.aubame@email.com', 'Franceville');
INSERT INTO income_info VALUES (4, 4, 450000, 200000, 'Salaire + Tontine');
INSERT INTO employment_info VALUES (4, 4, 'Ministère Education', 'FONCTIONNAIRE', 84, 'Enseignante');
INSERT INTO credit_applications VALUES (4, 4, 4, 3000000, 12, '2025-07-07', 'APPROVED', 820, 'LOW_RISK');

-- 5. Crédit Retraite - CPPG
INSERT INTO personal_info VALUES (5, 'Robert Ondo', 'CNI', '074890123', 'robert.ondo@email.com', 'Libreville');
INSERT INTO income_info VALUES (5, 5, 380000, 0, 'Pension CPPG');
INSERT INTO employment_info VALUES (5, 5, 'CPPG', 'RETRAITE', 0, 'Retraité');
INSERT INTO credit_applications VALUES (5, 5, 5, 1000000, 12, '2025-07-07', 'APPROVED', 750, 'MEDIUM_RISK');

-- 6. Crédit Spot - Urgence médicale
INSERT INTO personal_info VALUES (6, 'Claire Mboumba', 'PASSPORT', '066345678', 'claire.mboumba@email.com', 'Port-Gentil');
INSERT INTO income_info VALUES (6, 6, 1200000, 300000, 'Salaire + Commerce');
INSERT INTO employment_info VALUES (6, 6, 'Total Gabon', 'CDI', 120, 'Cadre');
INSERT INTO credit_applications VALUES (6, 6, 6, 5000000, 3, '2025-07-07', 'APPROVED', 890, 'LOW_RISK');

-- 7. Crédit Consommation - Profil moyen
INSERT INTO personal_info VALUES (7, 'Marc Ekomi', 'CNI', '074567890', 'marc.ekomi@email.com', 'Moanda');
INSERT INTO income_info VALUES (7, 7, 550000, 0, 'Salaire');
INSERT INTO employment_info VALUES (7, 7, 'COMILOG', 'CDD', 24, 'Technicien');
INSERT INTO credit_applications VALUES (7, 7, 1, 1500000, 24, '2025-07-07', 'PENDING', 680, 'MEDIUM_RISK');

-- 8. Crédit Investissement - Startup
INSERT INTO personal_info VALUES (8, 'Sylvie Nzue', 'CNI', '066456789', 'sylvie.nzue@email.com', 'Libreville');
INSERT INTO income_info VALUES (8, 8, 0, 2000000, 'Startup');
INSERT INTO employment_info VALUES (8, 8, 'Tech Solutions Gabon', 'GERANT', 18, 'CEO');
INSERT INTO credit_applications VALUES (8, 8, 2, 25000000, 36, '2025-07-07', 'PENDING', 650, 'HIGH_RISK');

-- 9. Crédit Avance Facture - Secteur privé
INSERT INTO personal_info VALUES (9, 'Paul Mengue', 'CNI', '077678901', 'paul.mengue@email.com', 'Port-Gentil');
INSERT INTO income_info VALUES (9, 9, 0, 4000000, 'Entreprise');
INSERT INTO employment_info VALUES (9, 9, 'Mengue & Co', 'GERANT', 36, 'Directeur');
INSERT INTO credit_applications VALUES (9, 9, 3, 8000000, 6, '2025-07-07', 'APPROVED', 800, 'LOW_RISK');

-- 10. Crédit Tontine - Nouveau membre
INSERT INTO personal_info VALUES (10, 'Anne Obiang', 'CNI', '074234567', 'anne.obiang@email.com', 'Lambaréné');
INSERT INTO income_info VALUES (10, 10, 320000, 100000, 'Salaire + Tontine');
INSERT INTO employment_info VALUES (10, 10, 'Pharmacie Centrale', 'CDI', 12, 'Vendeuse');
INSERT INTO credit_applications VALUES (10, 10, 4, 1500000, 12, '2025-07-07', 'PENDING', 620, 'HIGH_RISK');

-- 11. Crédit Retraite - CNSS
INSERT INTO personal_info VALUES (11, 'Michel Nguema', 'CNI', '066567890', 'michel.nguema@email.com', 'Libreville');
INSERT INTO income_info VALUES (11, 11, 420000, 150000, 'Pension CNSS + Location');
INSERT INTO employment_info VALUES (11, 11, 'CNSS', 'RETRAITE', 0, 'Retraité');
INSERT INTO credit_applications VALUES (11, 11, 5, 1200000, 12, '2025-07-07', 'APPROVED', 780, 'MEDIUM_RISK');

-- 12. Crédit Spot - Opportunité commerciale
INSERT INTO personal_info VALUES (12, 'Estelle Koumba', 'CNI', '077345678', 'estelle.koumba@email.com', 'Oyem');
INSERT INTO income_info VALUES (12, 12, 0, 6000000, 'Commerce');
INSERT INTO employment_info VALUES (12, 12, 'Import-Export Koumba', 'GERANT', 60, 'Gérante');
INSERT INTO credit_applications VALUES (12, 12, 6, 15000000, 3, '2025-07-07', 'APPROVED', 850, 'LOW_RISK');

-- 13. Crédit Consommation - Premier crédit
INSERT INTO personal_info VALUES (13, 'Alice Mezui', 'CNI', '074678901', 'alice.mezui@email.com', 'Port-Gentil');
INSERT INTO income_info VALUES (13, 13, 650000, 0, 'Salaire');
INSERT INTO employment_info VALUES (13, 13, 'Bank Of Africa', 'CDI', 8, 'Conseillère');
INSERT INTO credit_applications VALUES (13, 13, 1, 1800000, 24, '2025-07-07', 'PENDING', 700, 'MEDIUM_RISK');

-- 14. Crédit Investissement - Expansion
INSERT INTO personal_info VALUES (14, 'Thomas Bivigou', 'PASSPORT', '066789012', 'thomas.bivigou@email.com', 'Libreville');
INSERT INTO income_info VALUES (14, 14, 0, 8000000, 'Entreprise');
INSERT INTO employment_info VALUES (14, 14, 'Bivigou Construction', 'GERANT', 84, 'Directeur');
INSERT INTO credit_applications VALUES (14, 14, 2, 75000000, 36, '2025-07-07', 'APPROVED', 880, 'LOW_RISK');

-- 15. Crédit Avance Facture - Nouveau contrat
INSERT INTO personal_info VALUES (15, 'Catherine Ndong', 'CNI', '077456789', 'catherine.ndong@email.com', 'Franceville');
INSERT INTO income_info VALUES (15, 15, 0, 2500000, 'Entreprise');
INSERT INTO employment_info VALUES (15, 15, 'Ndong Services', 'GERANT', 24, 'Directrice');
INSERT INTO credit_applications VALUES (15, 15, 3, 5000000, 6, '2025-07-07', 'PENDING', 680, 'MEDIUM_RISK');

-- 16. Crédit Tontine - Groupe établi
INSERT INTO personal_info VALUES (16, 'Laurent Mayombo', 'CNI', '074890123', 'laurent.mayombo@email.com', 'Mouila');
INSERT INTO income_info VALUES (16, 16, 480000, 250000, 'Salaire + Tontine');
INSERT INTO employment_info VALUES (16, 16, 'SOGARA', 'CDI', 96, 'Technicien');
INSERT INTO credit_applications VALUES (16, 16, 4, 2500000, 12, '2025-07-07', 'APPROVED', 830, 'LOW_RISK');

-- 17. Crédit Retraite - Ancien fonctionnaire
INSERT INTO personal_info VALUES (17, 'Jeanne Moussavou', 'CNI', '066234567', 'jeanne.moussavou@email.com', 'Libreville');
INSERT INTO income_info VALUES (17, 17, 450000, 200000, 'Pension CPPG + Commerce');
INSERT INTO employment_info VALUES (17, 17, 'CPPG', 'RETRAITE', 0, 'Retraitée');
INSERT INTO credit_applications VALUES (17, 17, 5, 1500000, 12, '2025-07-07', 'APPROVED', 790, 'MEDIUM_RISK');

-- 18. Crédit Spot - Besoin urgent
INSERT INTO personal_info VALUES (18, 'Georges Makaya', 'CNI', '077567890', 'georges.makaya@email.com', 'Port-Gentil');
INSERT INTO income_info VALUES (18, 18, 950000, 0, 'Salaire');
INSERT INTO employment_info VALUES (18, 18, 'Shell Gabon', 'CDI', 48, 'Ingénieur');
INSERT INTO credit_applications VALUES (18, 18, 6, 8000000, 3, '2025-07-07', 'PENDING', 750, 'MEDIUM_RISK');

-- 19. Crédit Consommation - Refinancement
INSERT INTO personal_info VALUES (19, 'Henriette Nzamba', 'CNI', '074345678', 'henriette.nzamba@email.com', 'Libreville');
INSERT INTO income_info VALUES (19, 19, 720000, 100000, 'Salaire + Location');
INSERT INTO employment_info VALUES (19, 19, 'Ministère Santé', 'FONCTIONNAIRE', 120, 'Cadre');
INSERT INTO credit_applications VALUES (19, 19, 1, 2500000, 36, '2025-07-07', 'APPROVED', 820, 'LOW_RISK');

-- 20. Crédit Investissement - Projet innovant
INSERT INTO personal_info VALUES (20, 'Bruno Makanga', 'PASSPORT', '066456789', 'bruno.makanga@email.com', 'Libreville');
INSERT INTO income_info VALUES (20, 20, 0, 4500000, 'Startup Tech');
INSERT INTO employment_info VALUES (20, 20, 'Digital Solutions Gabon', 'GERANT', 24, 'CEO');
INSERT INTO credit_applications VALUES (20, 20, 2, 40000000, 36, '2025-07-07', 'PENDING', 700, 'MEDIUM_RISK');

-- Insert scoring history for each application
INSERT INTO scoring_history (application_id, score_date, final_score, income_score, employment_score, document_score, history_score, guarantee_score)
SELECT 
    application_id,
    '2025-07-07 22:32:09'::TIMESTAMP,
    score,
    FLOOR(RANDOM() * (100-70) + 70),  -- Income score between 70-100
    FLOOR(RANDOM() * (100-60) + 60),  -- Employment score between 60-100
    FLOOR(RANDOM() * (100-80) + 80),  -- Document score between 80-100
    FLOOR(RANDOM() * (100-50) + 50),  -- History score between 50-100
    FLOOR(RANDOM() * (100-70) + 70)   -- Guarantee score between 70-100
FROM credit_applications;

-- Insert risk assessment for each application
INSERT INTO risk_assessment (application_id, risk_level, interest_rate_modifier, assessment_date, notes)
SELECT 
    application_id,
    CASE 
        WHEN score >= 800 THEN 'LOW_RISK'
        WHEN score >= 650 THEN 'MEDIUM_RISK'
        ELSE 'HIGH_RISK'
    END,
    CASE 
        WHEN score >= 800 THEN -0.02
        WHEN score >= 650 THEN 0
        ELSE 0.02
    END,
    '2025-07-07 22:32:09'::TIMESTAMP,
    CASE 
        WHEN score >= 800 THEN 'Excellent profil de risque'
        WHEN score >= 650 THEN 'Profil de risque acceptable'
        ELSE 'Profil de risque élevé - surveillance accrue requise'
    END
FROM credit_applications;