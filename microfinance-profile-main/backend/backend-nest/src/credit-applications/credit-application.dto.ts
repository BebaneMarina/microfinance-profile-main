import { IsNotEmpty, IsString, IsNumber, IsObject, IsArray, IsOptional } from 'class-validator';

export class CreateCreditApplicationDto {
  @IsNotEmpty()
  @IsString()
  creditType: string;

  @IsNotEmpty()
  @IsObject()
  personalInfo: {
    fullName: string;
    email: string;
    phoneNumber: string;
  };

  @IsNotEmpty()
  @IsObject()
  financialInfo: {
    monthlySalary: number;
    employerName: string;
  };

  @IsNotEmpty()
  @IsObject()
  creditDetails: {
    requestedAmount: number;
    duration: number;
    creditPurpose: string;
    repaymentMode: string;
  };

  @IsNotEmpty()
  @IsNumber()
  creditScore: number;

  @IsNotEmpty()
  @IsString()
  riskLevel: string;

  @IsNotEmpty()
  @IsNumber()
  creditProbability: number;

  @IsOptional()
  @IsString()
  status?: string;

  @IsOptional()
  @IsArray()
  scoringFactors?: any[];
}