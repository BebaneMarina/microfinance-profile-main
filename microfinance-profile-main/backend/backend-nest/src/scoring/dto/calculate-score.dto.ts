// src/scoring/dto/calculate-score.dto.ts
import { ApiProperty } from '@nestjs/swagger';
import { IsNumber, IsString, IsBoolean, IsOptional, IsEnum, Min } from 'class-validator';

export enum EmploymentStatusEnum {
  CDI = 'CDI',
  CDD = 'CDD',
  Entrepreneur = 'Entrepreneur',
  Autre = 'Autre',
}

export enum BankingHistoryEnum {
  positive = 'positive',
  neutral = 'neutral',
  negative = 'negative',
}

export class CalculateScoreDto {
  @ApiProperty({ description: 'Revenu mensuel en FCFA', example: 350000, minimum: 0 })
  @IsNumber()
  @Min(0)
  monthlyIncome: number;

  @ApiProperty({ description: 'Charges mensuelles en FCFA', example: 120000, minimum: 0 })
  @IsNumber()
  @Min(0)
  monthlyExpenses: number;

  @ApiProperty({ description: 'Statut d\'emploi', example: 'CDI', enum: EmploymentStatusEnum })
  @IsEnum(EmploymentStatusEnum)
  employmentStatus: EmploymentStatusEnum;

  @ApiProperty({ description: 'Durée d\'emploi en années', example: 3, minimum: 0 })
  @IsNumber()
  @Min(0)
  employmentDuration: number;

  @ApiProperty({ description: 'Historique bancaire', example: 'positive', enum: BankingHistoryEnum })
  @IsEnum(BankingHistoryEnum)
  bankingHistory: BankingHistoryEnum;

  @ApiProperty({ description: 'Présence de prêts actifs', example: false })
  @IsBoolean()
  activeLoans: boolean;

  @ApiProperty({ description: 'Données additionnelles optionnelles', required: false, type: Object })
  @IsOptional()
  additionalData?: Record<string, any>;
}
