// src/simulation/dto/simulate-credit.dto.ts
import { ApiProperty } from '@nestjs/swagger';
import { IsNumber, IsString, IsOptional } from 'class-validator';

export class SimulateCreditDto {
  @ApiProperty({
    description: 'Score de crédit du client',
    example: 450,
  })
  @IsNumber()
  creditScore: number;

  @ApiProperty({
    description: 'Montant souhaité en FCFA',
    example: 5000000,
  })
  @IsNumber()
  amount: number;

  @ApiProperty({
    description: 'Durée souhaitée en mois',
    example: 24,
  })
  @IsNumber()
  duration: number;

  @ApiProperty({
    description: "Type de crédit ('personnel', 'immobilier', 'professionnel')",
    example: 'personnel',
    enum: ['personnel', 'immobilier', 'professionnel'],
  })
  @IsString()
  creditType: string;

  @ApiProperty({
    description: 'Revenu mensuel en FCFA',
    example: 350000,
    required: false,
  })
  @IsOptional()
  @IsNumber()
  monthlyIncome?: number;
}