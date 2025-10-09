-- Verification complete des donnees

-- 1. Voir tous les credits de l'utilisateur
SELECT id, type_credit, montant_total, montant_restant, statut
FROM credits_enregistres
WHERE utilisateur_id = 1
ORDER BY date_approbation DESC;

-- 2. Voir tous les paiements
SELECT id, credit_id, montant, date_paiement, type_paiement
FROM historique_paiements
WHERE utilisateur_id = 1
ORDER BY date_paiement DESC;

-- 3. Jointure pour voir la relation
SELECT 
    c.id as credit_id,
    c.type_credit,
    c.montant_total,
    c.montant_restant,
    p.id as paiement_id,
    p.montant as montant_paye,
    p.date_paiement
FROM credits_enregistres c
LEFT JOIN historique_paiements p ON c.id = p.credit_id
WHERE c.utilisateur_id = 1
ORDER BY c.id, p.date_paiement DESC;

-- 4. Resume par credit
SELECT 
    c.id,
    c.type_credit,
    c.montant_total,
    c.montant_restant,
    COUNT(p.id) as nombre_paiements,
    COALESCE(SUM(p.montant), 0) as total_paye,
    CASE 
        WHEN c.montant_total > 0 THEN ROUND((COALESCE(SUM(p.montant), 0) / c.montant_total * 100), 1)
        ELSE 0
    END as pourcentage_paye
FROM credits_enregistres c
LEFT JOIN historique_paiements p ON c.id = p.credit_id
WHERE c.utilisateur_id = 1
GROUP BY c.id, c.type_credit, c.montant_total, c.montant_restant
ORDER BY c.date_approbation DESC;