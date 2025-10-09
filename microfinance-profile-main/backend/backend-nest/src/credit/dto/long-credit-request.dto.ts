import { LongCreditStatus } from "../entities/long-credit-request.entity";

// dto/long-credit-request.dto.ts
export interface CreateLongCreditRequestDto {
  username: string;
  userId?: number;
  status?: LongCreditStatus;
  personalInfo: {
    fullName: string;
    email: string;
    phone: string;
    address: string;
    profession: string;
    company: string;
    maritalStatus?: string;
    dependents?: number;
  };
  creditDetails: {
    type?: string;  // Type de crédit (consommation_generale, immobilier, etc.)
    requestedAmount: number;
    duration: number;
    purpose: string;
    repaymentFrequency: string;
    preferredRate?: number;
    guarantors?: any[];
  };
  financialDetails: {
    monthlyIncome: number;
    otherIncomes?: any[];
    monthlyExpenses: number;
    existingLoans?: any[];
    assets?: any[];
    employmentDetails?: any;
  };
  documents?: any;
  simulation?: any;
  reviewHistory?: ReviewHistoryEntryDto[];
}

// dto/long-credit-request.dto.ts
export class UpdateLongCreditRequestDto {
  status?: string;
  personalInfo?: any;
  creditDetails?: any;
  financialDetails?: any;
  documents?: any;
  simulationResults?: any;
  submissionDate?: string | Date;
  decisionDate?: string | Date;
  decisionBy?: number;
  decision?: string;  // ✅ Rendre OPTIONNEL
  decisionNotes?: string;
  approvedAmount?: number;
  approvedRate?: number;
  approvedDuration?: number;
  specialConditions?: string;
  assignedTo?: number;
}

export interface SimulateCreditDto {
  requestedAmount: number;
  duration: number;
  clientProfile?: {
    username: string;
    monthlyIncome: number;
    creditScore: number;
  };
  financialDetails?: any;
}

export interface ReviewHistoryEntryDto {
  date: string;
  action: string;
  agent: string;
  comment?: string;
}

export { LongCreditStatus };