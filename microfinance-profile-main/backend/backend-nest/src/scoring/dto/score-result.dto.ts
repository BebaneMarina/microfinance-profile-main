// src/scoring/dto/score-result.dto.ts
import { ApiProperty } from '@nestjs/swagger';

export class ScoreResultDto {
  @ApiProperty({
    description: 'Score de crédit calculé',
    example: 450,
    minimum: 0,
    maximum: 500,
  })
  score: number;

  @ApiProperty({
    description: "Niveau de risque ('low', 'medium', 'high')",
    example: 'medium',
    enum: ['low', 'medium', 'high'],
  })
  riskLevel: string;

  @ApiProperty({
    description: 'Explication détaillée du score',
    example: 'Votre score de 450 est basé sur...',
  })
  explanation: string;

  @ApiProperty({
    description: 'Si le crédit est pré-approuvé automatiquement',
    example: true,
  })
  approved: boolean;

  @ApiProperty({
    description: 'Recommandations pour améliorer le score',
    example: ['Réduire vos charges mensuelles', 'Stabiliser votre emploi'],
    type: [String],
    required: false,
  })
  recommendations?: string[];
}