import { IsOptional, IsEnum, IsString, IsNumber } from 'class-validator';
import { RequestStatus, CreditType, RiskLevel } from '../entities/credit-request.entity';

export class UpdateCreditRequestDto {
  @IsOptional()
  @IsEnum(RequestStatus)
  status?: RequestStatus;

  @IsOptional()
  @IsEnum(CreditType)
  creditType?: CreditType;

  @IsOptional()
  @IsNumber()
  approvedAmount?: number;

  @IsOptional()
  @IsString()
  decisionNotes?: string;

  @IsOptional()
  @IsEnum(RiskLevel)
  riskLevel?: RiskLevel;

  @IsOptional()
  @IsNumber()
  interestRate?: number;
}