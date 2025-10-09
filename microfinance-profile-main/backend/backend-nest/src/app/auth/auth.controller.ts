// auth.controller.ts - VERSION CORRIGÉE
import { Controller, Post, Body, HttpException, HttpStatus } from '@nestjs/common';
import { Pool } from 'pg';
import * as bcrypt from 'bcrypt';

interface LoginRequest {
  email: string;
  password: string;
  rememberMe?: boolean;
}

interface AuthResponse {
  success: boolean;
  message?: string;
  user?: any;
  token?: string;
}

@Controller('auth')
export class AuthController {
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

  @Post('login')
  async login(@Body() credentials: LoginRequest): Promise<AuthResponse> {
    const client = await this.pool.connect();
    
    try {
      // 1. Rechercher l'utilisateur par email ou téléphone
      const userQuery = `
        SELECT 
          u.id,
          u.uuid,
          u.nom,
          u.prenom,
          u.email,
          u.telephone,
          u.mot_de_passe_hash,
          u.ville,
          u.quartier,
          u.province,
          u.profession,
          u.employeur,
          u.statut_emploi,
          u.revenu_mensuel,
          u.anciennete_mois,
          u.charges_mensuelles,
          u.dettes_existantes,
          u.score_credit,
          u.score_850,
          u.niveau_risque,
          u.montant_eligible,
          u.statut,
          u.date_creation,
          u.derniere_connexion
        FROM utilisateurs u
        WHERE (u.email = $1 OR u.telephone = $1)
          AND u.statut = 'actif'
      `;

      const userResult = await client.query(userQuery, [credentials.email]);

      if (userResult.rows.length === 0) {
        throw new HttpException(
          'Email ou téléphone invalide',
          HttpStatus.UNAUTHORIZED
        );
      }

      const user = userResult.rows[0];

      // 2. CORRECTION : Vérifier le mot de passe avec bcrypt au lieu de verify_password()
      const isPasswordValid = await bcrypt.compare(
        credentials.password,
        user.mot_de_passe_hash
      );

      if (!isPasswordValid) {
        throw new HttpException(
          'Mot de passe incorrect',
          HttpStatus.UNAUTHORIZED
        );
      }

      // 3. Récupérer les restrictions de crédit
      const restrictionsQuery = `
        SELECT 
          peut_emprunter,
          credits_actifs_count,
          credits_max_autorises,
          dette_totale_active,
          ratio_endettement,
          raison_blocage,
          date_derniere_demande,
          date_prochaine_eligibilite
        FROM restrictions_credit
        WHERE utilisateur_id = $1
      `;

      const restrictionsResult = await client.query(restrictionsQuery, [user.id]);
      const restrictions = restrictionsResult.rows[0] || null;

      // 4. Compter les crédits actifs
      const creditsQuery = `
        SELECT 
          COUNT(*) FILTER (WHERE statut = 'actif') as actifs,
          COUNT(*) FILTER (WHERE statut = 'solde') as soldes,
          COUNT(*) FILTER (WHERE statut = 'en_retard') as en_retard,
          COALESCE(SUM(montant_restant) FILTER (WHERE statut = 'actif'), 0) as dette_totale
        FROM credits_enregistres
        WHERE utilisateur_id = $1
      `;

      const creditsResult = await client.query(creditsQuery, [user.id]);
      const creditsStats = creditsResult.rows[0];

      // 5. Mettre à jour la dernière connexion
      await client.query(
        'UPDATE utilisateurs SET derniere_connexion = NOW() WHERE id = $1',
        [user.id]
      );

      // 6. Préparer la réponse utilisateur
      const userResponse = {
        id: user.id,
        uuid: user.uuid,
        name: `${user.prenom} ${user.nom}`,
        fullName: `${user.prenom} ${user.nom}`,
        email: user.email,
        phone: user.telephone,
        username: user.email,
        
        // Informations géographiques
        address: `${user.quartier || ''}, ${user.ville}`,
        ville: user.ville,
        quartier: user.quartier,
        province: user.province,
        
        // Informations professionnelles
        profession: user.profession,
        company: user.employeur,
        employmentStatus: user.statut_emploi,
        jobSeniority: user.anciennete_mois,
        monthlyIncome: parseFloat(user.revenu_mensuel),
        monthlyCharges: parseFloat(user.charges_mensuelles),
        existingDebts: parseFloat(user.dettes_existantes),
        
        // Scoring
        creditScore: parseFloat(user.score_credit),
        score850: user.score_850,
        riskLevel: user.niveau_risque,
        eligibleAmount: parseFloat(user.montant_eligible),
        
        // Restrictions
        canApplyForCredit: restrictions?.peut_emprunter ?? true,
        activeCreditCount: creditsStats.actifs,
        maxCreditsAllowed: restrictions?.credits_max_autorises || 2,
        totalActiveDebt: parseFloat(creditsStats.dette_totale),
        debtRatio: restrictions?.ratio_endettement || 0,
        blockingReason: restrictions?.raison_blocage,
        
        // Stats
        totalCredits: parseInt(creditsStats.actifs) + parseInt(creditsStats.soldes),
        paidCredits: creditsStats.soldes,
        lateCredits: creditsStats.en_retard,
        
        // Méta
        clientType: 'particulier',
        profileImage: '',
        accountCreated: user.date_creation,
        lastLogin: user.derniere_connexion,
        
        recommendations: this.generateRecommendations(
          parseFloat(user.score_credit),
          user.niveau_risque,
          creditsStats.actifs
        ),
        
        scoreDetails: {
          factors: [
            {
              name: 'Revenus mensuels',
              value: parseFloat(user.revenu_mensuel),
              impact: this.calculateIncomeImpact(parseFloat(user.revenu_mensuel))
            },
            {
              name: 'Ancienneté emploi',
              value: user.anciennete_mois,
              impact: this.calculateSeniorityImpact(user.anciennete_mois)
            },
            {
              name: 'Ratio endettement',
              value: restrictions?.ratio_endettement || 0,
              impact: this.calculateDebtRatioImpact(restrictions?.ratio_endettement || 0)
            },
            {
              name: 'Crédits actifs',
              value: creditsStats.actifs,
              impact: this.calculateActiveCreditsImpact(creditsStats.actifs)
            }
          ],
          lastUpdate: new Date().toISOString()
        }
      };

      const token = this.generateSimpleToken(user.id, user.email);

      return {
        success: true,
        message: 'Connexion réussie',
        user: userResponse,
        token: token
      };

    } catch (error) {
      if (error instanceof HttpException) {
        throw error;
      }
      
      console.error('Erreur lors de la connexion:', error);
      throw new HttpException(
        'Erreur serveur lors de la connexion',
        HttpStatus.INTERNAL_SERVER_ERROR
      );
    } finally {
      client.release();
    }
  }

  @Post('register')
  async register(@Body() userData: any): Promise<AuthResponse> {
    const client = await this.pool.connect();
    
    try {
      await client.query('BEGIN');

      // 1. Vérifier si l'utilisateur existe déjà
      const existingUser = await client.query(
        'SELECT id FROM utilisateurs WHERE email = $1 OR telephone = $2',
        [userData.email, userData.telephone]
      );

      if (existingUser.rows.length > 0) {
        throw new HttpException(
          'Cet email ou téléphone est déjà utilisé',
          HttpStatus.CONFLICT
        );
      }

      // 2. CORRECTION : Hacher le mot de passe avec bcrypt au lieu de hash_password()
      const saltRounds = 10;
      const hashedPassword = await bcrypt.hash(userData.password, saltRounds);

      // 3. Insérer l'utilisateur
      const insertQuery = `
        INSERT INTO utilisateurs (
          nom, prenom, email, telephone, mot_de_passe_hash,
          ville, quartier, province,
          profession, employeur, statut_emploi,
          revenu_mensuel, anciennete_mois,
          charges_mensuelles, dettes_existantes
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
        RETURNING id, uuid, email
      `;

      const userResult = await client.query(insertQuery, [
        userData.nom,
        userData.prenom,
        userData.email,
        userData.telephone,
        hashedPassword,
        userData.ville || 'Libreville',
        userData.quartier || '',
        userData.province || 'Estuaire',
        userData.profession || '',
        userData.employeur || '',
        userData.statut_emploi || 'cdi',
        userData.revenu_mensuel || 0,
        userData.anciennete_mois || 0,
        userData.charges_mensuelles || 0,
        userData.dettes_existantes || 0
      ]);

      const newUser = userResult.rows[0];

      // 4. Créer les restrictions par défaut
      await client.query(`
        INSERT INTO restrictions_credit (utilisateur_id)
        VALUES ($1)
      `, [newUser.id]);

      await client.query('COMMIT');

      return {
        success: true,
        message: 'Inscription réussie',
        user: {
          id: newUser.id,
          email: newUser.email,
          uuid: newUser.uuid
        }
      };

    } catch (error) {
      await client.query('ROLLBACK');
      
      if (error instanceof HttpException) {
        throw error;
      }
      
      console.error('Erreur lors de l\'inscription:', error);
      throw new HttpException(
        'Erreur serveur lors de l\'inscription',
        HttpStatus.INTERNAL_SERVER_ERROR
      );
    } finally {
      client.release();
    }
  }

  // Méthodes utilitaires (inchangées)
  private generateSimpleToken(userId: number, email: string): string {
    const payload = `${userId}:${email}:${Date.now()}`;
    return Buffer.from(payload).toString('base64');
  }

  private generateRecommendations(score: number, riskLevel: string, activeCredits: number): string[] {
    const recommendations: string[] = [];

    if (score < 5) {
      recommendations.push('Remboursez vos dettes actuelles pour améliorer votre score');
      recommendations.push('Évitez de nouvelles demandes de crédit pendant 3 mois');
    } else if (score < 7) {
      recommendations.push('Maintenez vos paiements à temps pour améliorer votre score');
      recommendations.push('Limitez vos dettes à 50% de votre revenu mensuel');
    } else {
      recommendations.push('Excellent profil ! Vous êtes éligible aux meilleurs taux');
    }

    if (activeCredits >= 2) {
      recommendations.push('Vous avez atteint le maximum de crédits actifs (2)');
    }

    return recommendations;
  }

  private calculateIncomeImpact(income: number): string {
    if (income >= 1500000) return 'Très positif';
    if (income >= 1000000) return 'Positif';
    if (income >= 500000) return 'Neutre';
    return 'Négatif';
  }

  private calculateSeniorityImpact(months: number): string {
    if (months >= 60) return 'Très positif';
    if (months >= 24) return 'Positif';
    if (months >= 12) return 'Neutre';
    return 'Négatif';
  }

  private calculateDebtRatioImpact(ratio: number): string {
    if (ratio <= 30) return 'Très positif';
    if (ratio <= 50) return 'Positif';
    if (ratio <= 70) return 'Attention';
    return 'Critique';
  }

  private calculateActiveCreditsImpact(count: number): string {
    if (count === 0) return 'Neutre';
    if (count === 1) return 'Acceptable';
    return 'Maximum atteint';
  }
}