// dto/credit-scoring-request.dto.ts
import { IsString, IsNumber, IsOptional, IsArray, IsEmail, IsEnum, Min, Max } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class CreditScoringRequestDto {
  @ApiProperty({ description: 'ID du client' })
  @IsString()
  clientId: string;

  @ApiProperty({ description: 'Nom complet' })
  @IsString()
  fullName: string;

  @ApiProperty({ description: 'Date de naissance' })
  @IsString()
  birthDate: string;

  @ApiProperty({ description: 'Genre', required: false })
  @IsOptional()
  @IsString()
  gender?: string;

  @ApiProperty({ description: 'Statut marital', required: false })
  @IsOptional()
  @IsString()
  maritalStatus?: string;

  @ApiProperty({ description: 'Revenu mensuel' })
  @IsNumber()
  @Min(0)
  monthlyIncome: number;

  @ApiProperty({ description: 'Autres revenus', required: false })
  @IsOptional()
  @IsNumber()
  @Min(0)
  otherIncome?: number;

  @ApiProperty({ description: 'Dettes existantes', required: false })
  @IsOptional()
  @IsNumber()
  @Min(0)
  existingDebts?: number;

  @ApiProperty({ description: 'Ancienneté dans l\'emploi' })
  @IsString()
  jobSeniority: string;

  @ApiProperty({ description: 'Type de contrat' })
  @IsString()
  contractType: string;

  @ApiProperty({ description: 'Montant demandé' })
  @IsNumber()
  @Min(1)
  requestedAmount: number;

  @ApiProperty({ description: 'Durée demandée (en mois)' })
  @IsNumber()
  @Min(1)
  @Max(60)
  requestedDuration: number;

  @ApiProperty({ description: 'Type de crédit' })
  @IsString()
  creditType: string;

  @ApiProperty({ description: 'Âge du compte bancaire (en mois)', required: false })
  @IsOptional()
  @IsNumber()
  @Min(0)
  bankAccountAge?: number;

  @ApiProperty({ description: 'Solde moyen du compte', required: false })
  @IsOptional()
  @IsNumber()
  averageBalance?: number;

  @ApiProperty({ description: 'Nombre de prêts précédents', required: false })
  @IsOptional()
  @IsNumber()
  @Min(0)
  previousLoans?: number;

  @ApiProperty({ description: 'Historique de paiement', required: false })
  @IsOptional()
  @IsString()
  paymentHistory?: string;

  @ApiProperty({ description: 'Garanties', required: false })
  @IsOptional()
  @IsArray()
  guarantees?: string[];

  @ApiProperty({ description: 'Valeur des garanties', required: false })
  @IsOptional()
  @IsNumber()
  @Min(0)
  collateral?: number;

  @ApiProperty({ description: 'Email' })
  @IsEmail()
  email: string;

  @ApiProperty({ description: 'Téléphone' })
  @IsString()
  phone: string;

  @ApiProperty({ description: 'Adresse' })
  @IsString()
  address: string;
}
