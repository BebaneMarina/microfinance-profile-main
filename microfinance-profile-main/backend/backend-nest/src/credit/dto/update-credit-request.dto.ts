import { IsOptional, IsEnum, IsString, IsNumber } from 'class-validator';
import { RequestStatus, CreditType, RiskLevel } from '../entities/credit-request.entity';

export class UpdateCreditRequestDto {
  decision_notes(arg0: number, arg1: any, arg2: any, decision_notes: any) {
    throw new Error('Method not implemented.');
  }
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