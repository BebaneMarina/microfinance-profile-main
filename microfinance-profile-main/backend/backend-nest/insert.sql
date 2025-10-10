-- Script pour creer des paiements complets pour les bons clients
-- A executer apres insert_data.sql

DO $$
DECLARE
    v_credit_id INTEGER;
    v_montant_total DECIMAL(12,2);
    v_montant_restant DECIMAL(12,2);
    v_utilisateur_id INTEGER;
    v_date_approbation TIMESTAMP;
    v_score_credit DECIMAL(3,1);
BEGIN
    -- Pour chaque credit des clients avec score >= 7
    FOR v_credit_id, v_montant_total, v_montant_restant, v_utilisateur_id, 
        v_date_approbation, v_score_credit IN
        SELECT 
            c.id,
            c.montant_total,
            c.montant_restant,
            c.utilisateur_id,
            c.date_approbation,
            u.score_credit
        FROM credits_enregistres c
        JOIN utilisateurs u ON c.utilisateur_id = u.id
        WHERE u.score_credit >= 7.0
        AND c.statut = 'actif'
        AND c.montant_restant > 0
    LOOP
        -- Payer completement le credit
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
            v_credit_id,
            v_utilisateur_id,
            v_montant_restant,
            NOW() - INTERVAL '5 days',
            v_date_approbation + INTERVAL '30 days',
            0,
            'a_temps',
            0
        );
        
        -- Mettre a jour le credit
        UPDATE credits_enregistres
        SET 
            montant_restant = 0,
            statut = 'solde',
            date_modification = NOW()
        WHERE id = v_credit_id;
        
        RAISE NOTICE 'Credit % paye completement pour user %', v_credit_id, v_utilisateur_id;
    END LOOP;
    
    -- Recalculer les dettes pour tous les utilisateurs
    UPDATE utilisateurs u
    SET dettes_existantes = (
        SELECT COALESCE(SUM(c.montant_restant), 0)
        FROM credits_enregistres c
        WHERE c.utilisateur_id = u.id
        AND c.statut = 'actif'
    ),
    date_modification = NOW();
    
    -- Mettre a jour les restrictions
    UPDATE restrictions_credit r
    SET 
        dette_totale_active = (
            SELECT COALESCE(SUM(c.montant_restant), 0)
            FROM credits_enregistres c
            WHERE c.utilisateur_id = r.utilisateur_id
            AND c.statut = 'actif'
        ),
        credits_actifs_count = (
            SELECT COUNT(*)
            FROM credits_enregistres c
            WHERE c.utilisateur_id = r.utilisateur_id
            AND c.statut = 'actif'
        ),
        ratio_endettement = (
            SELECT CASE 
                WHEN u.revenu_mensuel > 0 THEN
                    (COALESCE(SUM(c.montant_restant), 0) / u.revenu_mensuel) * 100
                ELSE 0
            END
            FROM credits_enregistres c
            JOIN utilisateurs u ON c.utilisateur_id = r.utilisateur_id
            WHERE c.utilisateur_id = r.utilisateur_id
            AND c.statut = 'actif'
        ),
        peut_emprunter = CASE
            WHEN (
                SELECT COUNT(*)
                FROM credits_enregistres c
                WHERE c.utilisateur_id = r.utilisateur_id
                AND c.statut = 'actif'
            ) < 2 THEN TRUE
            ELSE FALSE
        END,
        raison_blocage = CASE
            WHEN (
                SELECT COUNT(*)
                FROM credits_enregistres c
                WHERE c.utilisateur_id = r.utilisateur_id
                AND c.statut = 'actif'
            ) >= 2 THEN 'Maximum de credits actifs atteint'
            ELSE NULL
        END,
        date_modification = NOW()
    WHERE EXISTS (
        SELECT 1 FROM utilisateurs u WHERE u.id = r.utilisateur_id
    );
    
    RAISE NOTICE 'Paiements complets crees pour les bons clients';
END $$;

-- Afficher statistiques
SELECT 
    'Credits soldes' as statut,
    COUNT(*) as nombre,
    ROUND(AVG(u.score_credit), 2) as score_moyen
FROM credits_enregistres c
JOIN utilisateurs u ON c.utilisateur_id = u.id
WHERE c.statut = 'solde'

UNION ALL

SELECT 
    'Credits actifs' as statut,
    COUNT(*) as nombre,
    ROUND(AVG(u.score_credit), 2) as score_moyen
FROM credits_enregistres c
JOIN utilisateurs u ON c.utilisateur_id = u.id
WHERE c.statut = 'actif';