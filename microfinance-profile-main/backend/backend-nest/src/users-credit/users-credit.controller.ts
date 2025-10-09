// user-credits.controller.ts (MISE À JOUR)
import { Controller, Get, Post, Body, Param } from '@nestjs/common';
import { Pool } from 'pg';

@Controller('user-credits')
export class UserCreditsController {
  private pool: Pool;

  constructor() {
    this.pool = new Pool({
      host: process.env.DB_HOST || 'localhost',
      database: process.env.DB_NAME || 'credit_scoring',
      user: process.env.DB_USER || 'postgres',
      password: process.env.DB_PASSWORD || 'admin',
      port: parseInt(process.env.DB_PORT || '5432')
    });
  }

  @Get(':username')
  async getUserCredits(@Param('username') username: string) {
    const client = await this.pool.connect();
    
    try {
      const result = await client.query(`
        SELECT 
          c.id,
          c.type_credit as type,
          c.montant_principal as amount,
          c.montant_total as "totalAmount",
          c.montant_restant as "remainingAmount",
          c.taux_interet as "interestRate",
          c.statut as status,
          c.date_approbation as "approvedDate",
          c.date_echeance as "dueDate",
          c.date_prochain_paiement as "nextPaymentDate",
          c.montant_prochain_paiement as "nextPaymentAmount"
        FROM credits_enregistres c
        JOIN utilisateurs u ON c.utilisateur_id = u.id
        WHERE u.email = $1 OR u.telephone = $1
        ORDER BY c.date_approbation DESC
      `, [username]);

      return result.rows.map(credit => ({
        ...credit,
        paymentsHistory: [] // À charger séparément si nécessaire
      }));

    } finally {
      client.release();
    }
  }

  @Post('register')
  async registerCredit(@Body() creditData: any) {
    const client = await this.pool.connect();
    
    try {
      await client.query('BEGIN');

      // 1. Récupérer l'ID utilisateur
      const userResult = await client.query(
        'SELECT id FROM utilisateurs WHERE email = $1 OR telephone = $1',
        [creditData.username]
      );

      if (userResult.rows.length === 0) {
        throw new Error('Utilisateur introuvable');
      }

      const userId = userResult.rows[0].id;

      // 2. Calculer la date d'échéance
      const dueDate = new Date();
      dueDate.setDate(dueDate.getDate() + 45); // 45 jours par défaut

      // 3. Insérer le crédit
      const creditResult = await client.query(`
        INSERT INTO credits_enregistres (
          utilisateur_id,
          type_credit,
          montant_principal,
          montant_total,
          montant_restant,
          taux_interet,
          duree_mois,
          statut,
          date_echeance
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
        RETURNING *
      `, [
        userId,
        creditData.type,
        creditData.amount,
        creditData.totalAmount,
        creditData.totalAmount,
        creditData.interestRate || 0.015,
        1,
        'actif',
        dueDate
      ]);

      // 4. Mettre à jour les restrictions
      await client.query(`
        UPDATE restrictions_credit
        SET 
          credits_actifs_count = credits_actifs_count + 1,
          dette_totale_active = dette_totale_active + $1,
          ratio_endettement = (dette_totale_active + $1) / (SELECT revenu_mensuel FROM utilisateurs WHERE id = $2) * 100,
          date_derniere_demande = NOW(),
          date_prochaine_eligibilite = NOW() + INTERVAL '30 days',
          jours_avant_prochaine_demande = 30,
          peut_emprunter = CASE 
            WHEN credits_actifs_count + 1 >= 2 THEN FALSE
            WHEN (dette_totale_active + $1) / (SELECT revenu_mensuel FROM utilisateurs WHERE id = $2) > 0.7 THEN FALSE
            ELSE TRUE
          END,
          raison_blocage = CASE 
            WHEN credits_actifs_count + 1 >= 2 THEN 'Maximum 2 crédits actifs atteint'
            WHEN (dette_totale_active + $1) / (SELECT revenu_mensuel FROM utilisateurs WHERE id = $2) > 0.7 THEN 'Ratio endettement > 70%'
            ELSE NULL
          END
        WHERE utilisateur_id = $2
      `, [creditData.totalAmount, userId]);

      // 5. Recalculer le score (appel à Flask)
      // À faire via HTTP dans un service séparé

      await client.query('COMMIT');

      return creditResult.rows[0];

    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }
}