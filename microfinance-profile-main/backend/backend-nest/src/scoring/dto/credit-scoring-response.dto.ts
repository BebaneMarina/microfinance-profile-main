// dto/credit-scoring-response.dto.ts
import { ApiProperty } from '@nestjs/swagger';

export class CreditScoringResponseDto {
  @ApiProperty({ description: 'ID du scoring' })
  scoringId: string;

  @ApiProperty({ description: 'ID du client' })
  clientId: string;

  @ApiProperty({ description: 'Score calculé (0-1000)' })
  score: number;

  @ApiProperty({ description: 'Probabilité de défaut' })
  probability: number;

  @ApiProperty({ description: 'Décision' })
  decision: string;

  @ApiProperty({ description: 'Raison de la décision' })
  decisionReason: string;

  @ApiProperty({ description: 'Montant recommandé' })
  recommendedAmount: number;

  @ApiProperty({ description: 'Durée recommandée' })
  recommendedDuration: number;

  @ApiProperty({ description: 'Niveau de risque' })
  riskLevel: string;

  @ApiProperty({ description: 'Facteurs d\'influence' })
  factors: any[];

  @ApiProperty({ description: 'Timestamp' })
  timestamp: Date;
}