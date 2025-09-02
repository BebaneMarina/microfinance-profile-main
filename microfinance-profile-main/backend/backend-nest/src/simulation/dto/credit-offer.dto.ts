// src/simulation/dto/credit-offer.dto.ts
import { ApiProperty } from '@nestjs/swagger';

export class CreditOfferDto {
  @ApiProperty({
    description: 'Montant du prêt en FCFA',
    example: 5000000,
  })
  amount: number;

  @ApiProperty({
    description: 'Durée en mois',
    example: 24,
  })
  duration: number;

  @ApiProperty({
    description: 'Taux d intérêt annuel',
    example: 5.5,
  })
  interestRate: number;

  @ApiProperty({
    description: 'Mensualité en FCFA',
    example: 220000,
  })
  monthlyPayment: number;

  @ApiProperty({
    description: 'Frais de dossier en FCFA',
    example: 50000,
  })
  fees: number;

  @ApiProperty({
    description: 'Montant total à rembourser en FCFA',
    example: 5280000,
  })
  totalRepayment: number;

  @ApiProperty({
    description: 'Conditions spéciales le cas échéant',
    example: 'Assurance incluse',
    required: false,
  })
  specialConditions?: string;
}