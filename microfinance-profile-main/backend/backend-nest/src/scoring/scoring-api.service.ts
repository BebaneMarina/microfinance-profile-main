import { Injectable, Logger } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { ConfigService } from '@nestjs/config';
import { firstValueFrom } from 'rxjs';

@Injectable()
export class ScoringApiService {
  private readonly logger = new Logger(ScoringApiService.name);
  private readonly apiUrl: string;
  private readonly apiKey: string;

  constructor(
    private readonly httpService: HttpService,
    private readonly configService: ConfigService,
  ) {
    this.apiUrl = this.configService.get('SCORING_API_URL', 'http://localhost:3001');
    this.apiKey = this.configService.get('SCORING_API_KEY', '');
  }

  /**
   * Appel API externe pour calculer le score de crédit
   */
  async calculateExternalScore(data: any): Promise<any> {
    try {
      this.logger.log('Appel de l\'API externe de scoring...');
      
      const response = await firstValueFrom(
        this.httpService.post(`${this.apiUrl}/api/scoring/calculate`, data, {
          headers: {
            'Authorization': `Bearer ${this.apiKey}`,
            'Content-Type': 'application/json',
          },
          timeout: 10000, // 10 secondes de timeout
        })
      );

      return response.data;
    } catch (error) {
      this.logger.error(`Erreur lors de l'appel API externe: ${error.message}`);
      
      // Retourner un score par défaut en cas d'erreur
      return {
        score: 5,
        risk_level: 'medium',
        probability: 0.5,
        decision: 'pending',
        error: 'Service externe indisponible',
        source: 'fallback'
      };
    }
  }

  /**
   * Validation des données avant envoi à l'API
   */
  async validateScoringData(data: any): Promise<boolean> {
    const requiredFields = ['monthly_income', 'monthly_charges', 'existing_debts', 'user_id'];
    
    for (const field of requiredFields) {
      if (!data[field] && data[field] !== 0) {
        this.logger.warn(`Champ manquant: ${field}`);
        return false;
      }
    }

    return true;
  }

  /**
   * Enrichir les données avec des informations supplémentaires
   */
  async enrichScoringData(data: any): Promise<any> {
    try {
      // Ajouter des informations supplémentaires si disponibles
      const enrichedData = {
        ...data,
        timestamp: new Date().toISOString(),
        source: 'internal',
        version: '1.0'
      };

      return enrichedData;
    } catch (error) {
      this.logger.error(`Erreur lors de l'enrichissement des données: ${error.message}`);
      return data;
    }
  }

  /**
   * Comparer les scores de différentes sources
   */
  async compareScores(localScore: any, externalScore: any): Promise<any> {
    try {
      const comparison = {
        local_score: localScore.score,
        external_score: externalScore.score,
        difference: Math.abs(localScore.score - externalScore.score),
        recommended_score: (localScore.score + externalScore.score) / 2,
        source_reliability: externalScore.error ? 'local_only' : 'both'
      };

      this.logger.log(`Comparaison des scores: ${JSON.stringify(comparison)}`);
      return comparison;
    } catch (error) {
      this.logger.error(`Erreur lors de la comparaison: ${error.message}`);
      return {
        recommended_score: localScore.score,
        source_reliability: 'local_only'
      };
    }
  }

  /**
   * Obtenir l'historique des scores d'un utilisateur via API externe
   */
  async getUserScoreHistory(userId: number): Promise<any[]> {
    try {
      const response = await firstValueFrom(
        this.httpService.get(`${this.apiUrl}/api/scoring/history/${userId}`, {
          headers: {
            'Authorization': `Bearer ${this.apiKey}`,
          },
          timeout: 5000,
        })
      );

      return response.data || [];
    } catch (error) {
      this.logger.error(`Erreur lors de la récupération de l'historique: ${error.message}`);
      return [];
    }
  }
}