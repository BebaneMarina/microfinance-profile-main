import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { CreditScoring } from './entities/credit-scoring.entity';
import axios from 'axios';

@Injectable()
export class ScoringService {
  private readonly logger = new Logger(ScoringService.name);

  constructor(
    @InjectRepository(CreditScoring)
    private readonly creditScoringRepository: Repository<CreditScoring>,
  ) {}

  async calculateScore(data: any): Promise<any> {
    try {
      this.logger.log('Calcul du score en cours...');
      
      // Calcul du taux d'endettement
      const totalIncome = data.monthly_income;
      const debtRatio = (data.monthly_charges + data.existing_debts) / Math.max(totalIncome, 1);

      // Calcul du score sur 10
      let score = 0;
      
      // 1. Score basé sur le revenu (0-4 points)
      if (totalIncome >= 1000000) score += 4;
      else if (totalIncome >= 500000) score += 3;
      else if (totalIncome >= 300000) score += 2;
      else if (totalIncome >= 150000) score += 1;
      
      // 2. Score basé sur la quotité cessible (0-3 points)
      const disposableIncome = totalIncome - (data.monthly_charges + data.existing_debts);
      const disposableRatio = disposableIncome / totalIncome;
      
      if (disposableRatio >= 0.5) score += 3;
      else if (disposableRatio >= 0.3) score += 2;
      else if (disposableRatio >= 0.1) score += 1;
      
      // 3. Score basé sur les dettes existantes (0-3 points)
      if (data.existing_debts === 0) score += 3;
      else if (data.existing_debts <= totalIncome * 0.3) score += 2;
      else if (data.existing_debts <= totalIncome * 0.5) score += 1;
      
      // Limiter le score entre 1 et 10
      score = Math.max(1, Math.min(10, score));

      // Déterminer le niveau de risque
      let riskLevel = 'medium';
      if (score >= 8) riskLevel = 'low';
      else if (score >= 5) riskLevel = 'medium';
      else if (score >= 3) riskLevel = 'high';
      else riskLevel = 'very_high';

      // Sauvegarder le scoring si user_id est fourni
      if (data.user_id) {
        const scoring = this.creditScoringRepository.create({
          user_id: data.user_id,
          credit_request_id: data.credit_request_id || null,
          total_score: score * 100, // Stocker comme pourcentage pour compatibilité
          risk_level: riskLevel,
          probability: score / 10,
          decision: score >= 6 ? 'approved' : score >= 4 ? 'pending' : 'rejected',
          income_score: this.calculateIncomeScore(data.monthly_income),
          debt_ratio_score: this.calculateDebtRatioScore(debtRatio),
          factors: [
            {name: 'monthly_income', value: data.monthly_income, impact: 40},
            {name: 'disposable_income', value: disposableIncome, impact: 30},
            {name: 'debt_ratio', value: debtRatio, impact: 30}
          ],
          recommendations: this.getRecommendations(score, debtRatio, disposableIncome),
          model_version: 'v3.0',
          processing_time: 0.5 // Temps de traitement en secondes
        });

        await this.creditScoringRepository.save(scoring);
      }

      return {
        score: score,
        risk_level: riskLevel,
        probability: score / 10,
        decision: score >= 6 ? 'approved' : score >= 4 ? 'pending' : 'rejected',
        factors: [
          {name: 'monthly_income', value: data.monthly_income, impact: 40},
          {name: 'disposable_income', value: disposableIncome, impact: 30},
          {name: 'debt_ratio', value: debtRatio, impact: 30}
        ],
        recommendations: this.getRecommendations(score, debtRatio, disposableIncome),
        model_version: 'v3.0'
      };
    } catch (error) {
      this.logger.error(`Erreur lors du calcul du score: ${error.message}`);
      return {
        score: 5,
        risk_level: 'medium',
        probability: 0.5,
        decision: 'pending',
        factors: [],
        recommendations: ['Service temporairement indisponible'],
        model_version: 'v3.0'
      };
    }
  }

  private calculateIncomeScore(income: number): number {
    if (income >= 1000000) return 100;
    if (income >= 500000) return 75;
    if (income >= 300000) return 50;
    if (income >= 150000) return 25;
    return 10;
  }

  private calculateDebtRatioScore(debtRatio: number): number {
    if (debtRatio <= 0.3) return 100;
    if (debtRatio <= 0.5) return 75;
    if (debtRatio <= 0.7) return 50;
    return 25;
  }

  private getRecommendations(score: number, debtRatio: number, disposableIncome: number): string[] {
    const recommendations: string[] = [];
    
    if (score < 5) {
      if (debtRatio > 0.5) {
        recommendations.push("Réduisez vos dettes existantes pour améliorer votre score");
      }
      if (disposableIncome < 100000) {
        recommendations.push("Augmentez vos revenus pour améliorer votre capacité de remboursement");
      }
    }
    
    if (recommendations.length === 0) {
      if (score >= 8) {
        recommendations.push("Excellent profil ! Vous êtes éligible aux meilleures conditions");
      } else {
        recommendations.push("Profil correct. Vous pouvez améliorer votre score en réduisant vos dettes");
      }
    }
    
    return recommendations;
  }

  async calculateEligibleAmount(monthlyIncome: number, creditScore: number, risk_level: any): Promise<number> {
    // Calcul basé sur le revenu et le score
    let baseAmount = monthlyIncome * 0.3333; // 70% du revenu mensuel
    
    // Ajustement selon le score
    if (creditScore >= 8) baseAmount *= 0.3333;
    else if (creditScore >= 6) baseAmount *= 0.3333;
    else if (creditScore >= 4) baseAmount *= 0.3333;
    else baseAmount *= 0.5;
    
    // Plafonner à 2M pour les particuliers
    return Math.min(Math.round(baseAmount), 2000000);
  }

  async saveUserScore(userId: number, scoringResult: any): Promise<void> {
    try {
      const scoring = this.creditScoringRepository.create({
        user_id: userId,
        total_score: scoringResult.score * 100,
        risk_level: scoringResult.risk_level,
        probability: scoringResult.probability,
        decision: scoringResult.decision,
        factors: scoringResult.factors,
        recommendations: scoringResult.recommendations,
        model_version: 'v3.0',
        processing_time: 0.5
      });
      await this.creditScoringRepository.save(scoring);
    } catch (error) {
      this.logger.error(`Erreur lors de la sauvegarde du score: ${error.message}`);
    }
  }

  async getUserActiveLoans(userId: number): Promise<any[]> {
    // Implémentez cette méthode pour récupérer les crédits actifs
    return [];
  }

  async getUserOverduePayments(userId: number): Promise<any[]> {
    // Implémentez cette méthode pour récupérer les paiements en retard
    return [];
  }

  async findAll(): Promise<CreditScoring[]> {
    return this.creditScoringRepository.find({
      order: { created_at: 'DESC' },
      take: 100,
      relations: ['user', 'creditRequest']
    });
  }

  async findOne(id: number): Promise<CreditScoring> {
    const scoring = await this.creditScoringRepository.findOne({
      where: { id },
      relations: ['user', 'creditRequest']
    });

    if (!scoring) {
      throw new NotFoundException(`Score #${id} non trouvé`);
    }

    return scoring;
  }

  async findByUserId(userId: number): Promise<CreditScoring[]> {
    return this.creditScoringRepository.find({
      where: { user_id: userId },
      order: { created_at: 'DESC' },
      relations: ['user', 'creditRequest']
    });
  }

  async findByCreditRequestId(creditRequestId: number): Promise<CreditScoring | null> {
    return this.creditScoringRepository.findOne({
      where: { credit_request_id: creditRequestId },
      relations: ['user', 'creditRequest']
    });
  }
}