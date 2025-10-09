// credit-restrictions.controller.ts (NOUVEAU)
import { Controller, Get, Param } from '@nestjs/common';
import { Pool } from 'pg';

@Controller('credit-restrictions')
export class CreditRestrictionsController {
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
  async getUserRestrictions(@Param('username') username: string) {
    const client = await this.pool.connect();
    
    try {
      // Récupérer l'ID utilisateur
      const userResult = await client.query(
        'SELECT id FROM utilisateurs WHERE email = $1 OR telephone = $1',
        [username]
      );

      if (userResult.rows.length === 0) {
        return {
          canApplyForCredit: false,
          blockingReason: 'Utilisateur introuvable'
        };
      }

      const userId = userResult.rows[0].id;

      // Récupérer les restrictions
      const restrictionsResult = await client.query(`
        SELECT 
          r.*,
          u.score_credit,
          u.niveau_risque
        FROM restrictions_credit r
        JOIN utilisateurs u ON r.utilisateur_id = u.id
        WHERE r.utilisateur_id = $1
      `, [userId]);

      if (restrictionsResult.rows.length === 0) {
        // Créer des restrictions par défaut
        await client.query(`
          INSERT INTO restrictions_credit (utilisateur_id)
          VALUES ($1)
        `, [userId]);
        
        return {
          canApplyForCredit: true,
          maxCreditsAllowed: 2,
          activeCreditCount: 0,
          totalActiveDebt: 0,
          debtRatio: 0
        };
      }

      const restrictions = restrictionsResult.rows[0];

      return {
        canApplyForCredit: restrictions.peut_emprunter,
        maxCreditsAllowed: restrictions.credits_max_autorises,
        activeCreditCount: restrictions.credits_actifs_count,
        totalActiveDebt: restrictions.dette_totale_active,
        debtRatio: restrictions.ratio_endettement,
        nextEligibleDate: restrictions.date_prochaine_eligibilite,
        lastApplicationDate: restrictions.date_derniere_demande,
        blockingReason: restrictions.raison_blocage,
        daysUntilNextApplication: restrictions.jours_avant_prochaine_demande
      };

    } finally {
      client.release();
    }
  }
}