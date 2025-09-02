import { ApiProperty } from '@nestjs/swagger';

export class ScoringHistoryDto {
  @ApiProperty({ description: 'ID de l\'historique' })
  id: string;

  @ApiProperty({ description: 'ID du client' })
  clientId: string;

  @ApiProperty({ description: 'Score' })
  score: number;

  @ApiProperty({ description: 'Décision' })
  decision: string;

  @ApiProperty({ description: 'Timestamp' })
  timestamp: Date;
}