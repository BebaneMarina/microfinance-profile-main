import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { UserCredit } from './entities/users-credit.entity';
import { CreditRestriction } from './entities/credit-restriction.entity';
import { RealtimeScore } from './entities/realtime-score.entity';

@Injectable()
export class UserCreditsService {
  constructor(
    @InjectRepository(UserCredit)
    private userCreditsRepo: Repository<UserCredit>,
    
    @InjectRepository(CreditRestriction)
    private restrictionsRepo: Repository<CreditRestriction>,
    
    @InjectRepository(RealtimeScore)
    private scoresRepo: Repository<RealtimeScore>,
  ) {}

  // ==================== USER CREDITS ====================
  
  async getUserCredits(username: string) {
    return this.userCreditsRepo.find({
      where: { username },
      order: { createdAt: 'DESC' }
    });
  }

  async createUserCredit(creditData: any) {
    const credit = this.userCreditsRepo.create({
      ...creditData,
      paymentsHistory: creditData.paymentsHistory || []
    });
    
    const saved = await this.userCreditsRepo.save(credit);
    
    // Mettre à jour les restrictions automatiquement
    await this.updateRestrictions(creditData.username);
    
    return saved;
  }

  async processPayment(paymentData: any) {
    const credit = await this.userCreditsRepo.findOne({
      where: { id: paymentData.credit_id, username: paymentData.username }
    });

    if (!credit) {
      throw new NotFoundException('Crédit non trouvé');
    }

    credit.remainingAmount = paymentData.remaining_amount;
    credit.status = paymentData.credit_status;
    credit.paymentsHistory.push(paymentData.payment);

    const updated = await this.userCreditsRepo.save(credit);
    await this.updateRestrictions(paymentData.username);

    return {
      success: true,
      credit: updated,
      score_impact: {
        previous_score: 6.0,
        new_score: 6.2,
        risk_level: 'moyen'
      }
    };
  }

  // ==================== RESTRICTIONS ====================
  
  async getCreditRestrictions(username: string) {
    let restrictions = await this.restrictionsRepo.findOne({
      where: { username }
    });

    if (!restrictions) {
      restrictions = await this.calculateAndSaveRestrictions(username);
    }

    return restrictions;
  }

  private async calculateAndSaveRestrictions(username: string) {
    const activeCredits = await this.userCreditsRepo.find({
      where: { username, status: 'active' }
    });

    const totalDebt = activeCredits.reduce((sum, c) => sum + Number(c.remainingAmount), 0);
    const activeCreditCount = activeCredits.length;
    
    // Récupérer le revenu depuis la table users
    const monthlyIncome = 500000; // TODO: Récupérer depuis la table users
    const debtRatio = monthlyIncome > 0 ? totalDebt / monthlyIncome : 0;

    let canApply = true;
    let blockingReason = '';

    if (activeCreditCount >= 2) {
      canApply = false;
      blockingReason = 'Maximum 2 crédits actifs atteint';
    } else if (debtRatio > 0.7) {
      canApply = false;
      blockingReason = `Ratio d'endettement trop élevé (${(debtRatio * 100).toFixed(1)}%)`;
    }

    const restrictions = this.restrictionsRepo.create({
      username,
      canApplyForCredit: canApply,
      maxCreditsAllowed: 2,
      activeCreditCount,
      totalActiveDebt: totalDebt,
      debtRatio,
      blockingReason,
      daysUntilNextApplication: canApply ? 0 : 30
    });

    return this.restrictionsRepo.save(restrictions);
  }

  private async updateRestrictions(username: string) {
    await this.restrictionsRepo.delete({ username });
    return this.calculateAndSaveRestrictions(username);
  }

  // ==================== REALTIME SCORING ====================
  
  async calculateRealtimeScore(userData: any) {
    const { username, monthly_income = 0, active_credits = [] } = userData;
    
    const totalDebt = active_credits.reduce((sum: number, c: any) => sum + (c.remaining || 0), 0);
    const debtRatio = monthly_income > 0 ? totalDebt / monthly_income : 0;

    let baseScore = 6.0;

    // Ajustements
    if (monthly_income >= 500000) baseScore += 1.5;
    else if (monthly_income >= 300000) baseScore += 0.8;

    if (debtRatio < 0.3) baseScore += 1.0;
    else if (debtRatio < 0.5) baseScore += 0.3;
    else if (debtRatio > 0.7) baseScore -= 1.5;

    if (userData.employment_status === 'cdi') baseScore += 0.5;

    const finalScore = Math.max(0, Math.min(10, baseScore));

    let riskLevel = 'moyen';
    if (finalScore >= 8) riskLevel = 'bas';
    else if (finalScore >= 6) riskLevel = 'moyen';
    else riskLevel = 'élevé';

    // Sauvegarder le score
    const existingScore = await this.scoresRepo.findOne({ where: { username } });
    const previousScore = existingScore?.score || finalScore;

    const scoreEntity = this.scoresRepo.create({
      username,
      score: parseFloat(finalScore.toFixed(1)),
      previousScore,
      riskLevel,
      factors: [
        { name: 'monthly_income', value: monthly_income, impact: 30, description: 'Revenus mensuels' },
        { name: 'debt_ratio', value: Math.round(debtRatio * 100), impact: 25, description: "Taux d'endettement" }
      ],
      recommendations: this.getRecommendations(finalScore, debtRatio),
      isRealTime: true,
      scoreChange: finalScore - previousScore,
      paymentAnalysis: { trend: 'stable', on_time_ratio: 0.8, total_payments: active_credits.length }
    });

    const saved = await this.scoresRepo.save(scoreEntity);

    return {
      user_id: userData.user_id || 0,
      username,
      score: saved.score,
      previous_score: saved.previousScore,
      risk_level: saved.riskLevel,
      factors: saved.factors,
      recommendations: saved.recommendations,
      last_updated: saved.lastUpdated.toISOString(),
      is_real_time: saved.isRealTime,
      score_change: saved.scoreChange,
      payment_analysis: saved.paymentAnalysis
    };
  }

  private getRecommendations(score: number, debtRatio: number): string[] {
    const recommendations: string[] = [];

    if (score < 6) {
      recommendations.push('Améliorez votre régularité de paiement');
    } else if (score >= 8) {
      recommendations.push('Excellent profil ! Maintenez vos bonnes habitudes');
    }

    if (debtRatio > 0.5) {
      recommendations.push('Réduisez votre endettement pour améliorer votre score');
    }

    return recommendations;
  }
}