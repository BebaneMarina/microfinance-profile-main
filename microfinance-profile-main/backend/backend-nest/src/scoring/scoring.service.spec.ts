// src/scoring/scoring.service.ts
import { Injectable } from '@nestjs/common';
import { CalculateScoreDto } from './dto/calculate-score.dto';
import { ScoreResultDto } from './dto/score-result.dto';

@Injectable()
export class ScoringService {
  async calculateScore(input: CalculateScoreDto): Promise<ScoreResultDto> {
    // Adaptation de votre logique Flask existante
    const score = this.calculateBaseScore(input);
    const riskLevel = this.determineRiskLevel(score);
    
    return {
      score,
      riskLevel,
      explanation: this.generateExplanation(score, input),
      approved: this.isApproved(score, input),
    };
  }

  private calculateBaseScore(input: CalculateScoreDto): number {
    // Implémentation des règles de scoring comme dans votre modèle Flask
    let score = 0;
    
    // Exemple de règles (à adapter selon votre modèle existant)
    if (input.monthlyIncome > 300000) score += 100;
    if (input.monthlyExpenses < 150000) score += 80;
    if (input.employmentStatus === 'CDI' && input.employmentDuration > 2) score += 100;
    if (input.bankingHistory === 'positive') score += 120;
    if (!input.activeLoans) score += 100;
    
    return Math.min(score, 500); // Score max 500 comme dans l'exemple
  }

  private determineRiskLevel(score: number): string {
    if (score > 450) return 'low';
    if (score > 300) return 'medium';
    return 'high';
  }

  private isApproved(score: number, input: CalculateScoreDto): boolean {
    // Exemple de règles d'approbation
    const debtRatio = input.monthlyExpenses / input.monthlyIncome;
    return score > 450 && debtRatio < 0.33;
  }

  private generateExplanation(score: number, input: CalculateScoreDto): string {
    // Logique pour générer une explication compréhensible
    return `Votre score de ${score} est basé sur...`;
  }
}