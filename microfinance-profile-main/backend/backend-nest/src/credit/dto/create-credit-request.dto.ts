import { IsNotEmpty, IsString, IsOptional, IsNumber, ValidateNested, IsEmail, IsPhoneNumber, IsIn, Min, Max } from 'class-validator';
import { Type } from 'class-transformer';

// DTO pour les informations personnelles
export class PersonalInfoDto {
  @IsNotEmpty()
  @IsString()
  fullName: string;

  @IsNotEmpty()
  @IsEmail()
  email: string;

  @IsNotEmpty()
  @IsString()
  phoneNumber: string;

  @IsOptional()
  @IsString()
  address?: string;

  @IsOptional()
  @IsString()
  birthDate?: string;

  @IsOptional()
  @IsString()
  identityNumber?: string;

  @IsOptional()
  @IsString()
  profession?: string;
}

// DTO pour les informations financières
export class FinancialInfoDto {
  @IsNotEmpty()
  @IsString()
  monthlySalary: string;

  @IsOptional()
  @IsString()
  otherIncome?: string;

  @IsNotEmpty()
  @IsString()
  employerName: string;

  @IsNotEmpty()
  @IsIn(['cdi', 'cdd', 'interim', 'independant', 'autre'])
  contractType: string;

  @IsOptional()
  @IsString()
  jobSeniority?: string;

  @IsOptional()
  @IsString()
  monthlyCharges?: string;

  @IsOptional()
  @IsString()
  existingDebts?: string;

  @IsOptional()
  salaryDomiciliation?: boolean;
}

// DTO pour les détails du crédit
export class CreditDetailsDto {
  @IsNotEmpty()
  @IsString()
  requestedAmount: string;

  @IsNotEmpty()
  @IsString()
  duration: string;

  @IsOptional()
  @IsString()
  repaymentMode?: string;

  @IsOptional()
  @IsString()
  repaymentFrequency?: string;

  @IsNotEmpty()
  @IsString()
  creditPurpose: string;

  @IsOptional()
  @IsString()
  urgencyJustification?: string;
}

// DTO principal pour créer une demande de crédit
export class CreateCreditRequestDto {
  @IsNotEmpty()
  @IsIn([
    'consommation_generale',
    'avance_salaire',
    'depannage',
    'investissement',
    'avance_facture',
    'avance_commande',
    'tontine',
    'retraite',
    'spot'
  ])
  creditType: string;

  @ValidateNested()
  @Type(() => PersonalInfoDto)
  personalInfo: PersonalInfoDto;

  @ValidateNested()
  @Type(() => FinancialInfoDto)
  financialInfo: FinancialInfoDto;

  @ValidateNested()
  @Type(() => CreditDetailsDto)
  creditDetails: CreditDetailsDto;

  // Champs optionnels pour le scoring
  @IsOptional()
  @IsNumber()
  creditScore?: number;

  @IsOptional()
  @IsNumber()
  probability?: number;

  @IsOptional()
  @IsString()
  riskLevel?: string;

  @IsOptional()
  @IsString()
  decision?: string;

  @IsOptional()
  scoringFactors?: any[];

  @IsOptional()
  recommendations?: string[];

  @IsOptional()
  @IsString()
  submissionDate?: string;

  @IsOptional()
  @IsString()
  status?: string;
}