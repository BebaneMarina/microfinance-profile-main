// dto/credit-long.dto.ts
import { 
  IsString, 
  IsNumber, 
  IsEmail, 
  IsBoolean, 
  IsOptional, 
  IsArray, 
  ValidateNested, 
  Min, 
  Max,
  IsEnum,
  IsNotEmpty
} from 'class-validator';
import { Type } from 'class-transformer';

// === ENUMS ===

export enum CreditLongStatus {
  DRAFT = 'draft',
  SUBMITTED = 'submitted',
  UNDER_REVIEW = 'under_review',
  APPROVED = 'approved',
  REJECTED = 'rejected',
  REQUIRES_INFO = 'requires_info'
}

export enum ContractType {
  CDI = 'CDI',
  CDD = 'CDD',
  FREELANCE = 'Freelance',
  FONCTIONNAIRE = 'Fonctionnaire'
}

export enum RepaymentFrequency {
  MENSUEL = 'mensuel',
  TRIMESTRIEL = 'trimestriel', 
  SEMESTRIEL = 'semestriel'
}

// === SUB-DTOs ===

export class PersonalInfoDto {
  @IsString()
  @IsNotEmpty()
  fullName: string;

  @IsEmail()
  email: string;

  @IsString()
  @IsNotEmpty()
  phone: string;

  @IsString()
  @IsNotEmpty()
  address: string;

  @IsString()
  @IsNotEmpty()
  profession: string;

  @IsString()
  @IsNotEmpty()
  company: string;

  @IsString()
  @IsOptional()
  maritalStatus?: string;

  @IsNumber()
  @IsOptional()
  @Min(0)
  dependents?: number;
}

export class CreditDetailsDto {
  @IsNumber()
  @Min(100000)
  @Max(100000000)
  requestedAmount: number;

  @IsNumber()
  @Min(3)
  @Max(120)
  duration: number;

  @IsString()
  @IsNotEmpty()
  purpose: string;

  @IsEnum(RepaymentFrequency)
  repaymentFrequency: RepaymentFrequency;

  @IsNumber()
  @IsOptional()
  preferredRate?: number;

  @IsString()
  @IsOptional()
  collateral?: string;

  @IsArray()
  @IsOptional()
  @ValidateNested({ each: true })
  @Type(() => GuarantorDto)
  guarantors?: GuarantorDto[];
}

export class GuarantorDto {
  @IsString()
  @IsNotEmpty()
  name: string;

  @IsString()
  @IsNotEmpty()
  phone: string;

  @IsString()
  @IsNotEmpty()
  profession: string;

  @IsString()
  @IsNotEmpty()
  relationship: string;
}

export class OtherIncomeDto {
  @IsString()
  @IsNotEmpty()
  source: string;

  @IsNumber()
  @Min(0)
  amount: number;

  @IsString()
  @IsNotEmpty()
  frequency: string;
}

export class ExistingLoanDto {
  @IsString()
  @IsNotEmpty()
  lender: string;

  @IsNumber()
  @Min(0)
  amount: number;

  @IsNumber()
  @Min(0)
  monthlyPayment: number;

  @IsNumber()
  @Min(0)
  remainingMonths: number;
}

export class AssetDto {
  @IsString()
  @IsNotEmpty()
  type: string;

  @IsString()
  @IsNotEmpty()
  description: string;

  @IsNumber()
  @Min(0)
  estimatedValue: number;
}

export class EmploymentDetailsDto {
  @IsString()
  @IsNotEmpty()
  employer: string;

  @IsString()
  @IsNotEmpty()
  position: string;

  @IsNumber()
  @Min(0)
  seniority: number;

  @IsEnum(ContractType)
  contractType: ContractType;

  @IsNumber()
  @Min(0)
  netSalary: number;

  @IsNumber()
  @Min(0)
  grossSalary: number;
}

export class FinancialDetailsDto {
  @IsNumber()
  @Min(100000)
  monthlyIncome: number;

  @IsArray()
  @IsOptional()
  @ValidateNested({ each: true })
  @Type(() => OtherIncomeDto)
  otherIncomes?: OtherIncomeDto[];

  @IsNumber()
  @Min(0)
  monthlyExpenses: number;

  @IsArray()
  @IsOptional()
  @ValidateNested({ each: true })
  @Type(() => ExistingLoanDto)
  existingLoans?: ExistingLoanDto[];

  @IsArray()
  @IsOptional()
  @ValidateNested({ each: true })
  @Type(() => AssetDto)
  assets?: AssetDto[];

  @ValidateNested()
  @Type(() => EmploymentDetailsDto)
  employmentDetails: EmploymentDetailsDto;
}

export class DocumentsDto {
  @IsBoolean()
  identityProof: boolean;

  @IsBoolean()
  incomeProof: boolean;

  @IsBoolean()
  bankStatements: boolean;

  @IsBoolean()
  employmentCertificate: boolean;

  @IsBoolean()
  @IsOptional()
  businessPlan?: boolean;

  @IsBoolean()
  @IsOptional()
  propertyDeeds?: boolean;

  @IsBoolean()
  @IsOptional()
  guarantorDocuments?: boolean;
}

export class ReviewHistoryEntryDto {
  @IsString()
  date: string;

  @IsString()
  @IsNotEmpty()
  action: string;

  @IsString()
  @IsNotEmpty()
  agent: string;

  @IsString()
  @IsOptional()
  comment?: string;

  @IsArray()
  @IsOptional()
  documents?: string[];
}

export class DecisionDto {
  @IsEnum(['approved', 'rejected', 'conditional'])
  status: 'approved' | 'rejected' | 'conditional';

  @IsNumber()
  @IsOptional()
  @Min(0)
  approvedAmount?: number;

  @IsNumber()
  @IsOptional()
  @Min(0)
  approvedRate?: number;

  @IsNumber()
  @IsOptional()
  @Min(1)
  approvedDuration?: number;

  @IsArray()
  @IsOptional()
  conditions?: string[];

  @IsString()
  @IsOptional()
  rejectionReason?: string;

  @IsString()
  @IsNotEmpty()
  decidedBy: string;

  @IsString()
  decisionDate: string;
}

// === MAIN DTOs ===

export class SimulateCreditDto {
  @IsNumber()
  @Min(100000)
  @Max(100000000)
  requestedAmount: number;

  @IsNumber()
  @Min(3)
  @Max(120)
  duration: number;

  @ValidateNested()
  @Type(() => Object)
  clientProfile: {
    userId?: number;
    username?: string;
    monthlyIncome?: number;
    creditScore?: number;
    riskLevel?: string;
  };

  @ValidateNested()
  @Type(() => FinancialDetailsDto)
  @IsOptional()
  financialDetails?: FinancialDetailsDto;

  @IsString()
  @IsOptional()
  purpose?: string;
}

export class CreateCreditLongRequestDto {
  @IsNumber()
  @IsOptional()
  userId?: number;

  @IsString()
  @IsOptional()
  username?: string;

  @ValidateNested()
  @Type(() => PersonalInfoDto)
  personalInfo: PersonalInfoDto;

  @ValidateNested()
  @Type(() => CreditDetailsDto)
  creditDetails: CreditDetailsDto;

  @ValidateNested()
  @Type(() => FinancialDetailsDto)
  financialDetails: FinancialDetailsDto;

  @ValidateNested()
  @Type(() => DocumentsDto)
  documents: DocumentsDto;

  @IsEnum(CreditLongStatus)
  @IsOptional()
  status?: CreditLongStatus;

  @IsString()
  @IsOptional()
  submissionDate?: string;

  @IsArray()
  @IsOptional()
  @ValidateNested({ each: true })
  @Type(() => ReviewHistoryEntryDto)
  reviewHistory?: ReviewHistoryEntryDto[];

  @ValidateNested()
  @Type(() => Object)
  @IsOptional()
  simulation?: any;

  @ValidateNested()
  @Type(() => DecisionDto)
  @IsOptional()
  decision?: DecisionDto;
}

export class UpdateCreditLongRequestDto {
  @ValidateNested()
  @Type(() => PersonalInfoDto)
  @IsOptional()
  personalInfo?: PersonalInfoDto;

  @ValidateNested()
  @Type(() => CreditDetailsDto)
  @IsOptional()
  creditDetails?: CreditDetailsDto;

  @ValidateNested()
  @Type(() => FinancialDetailsDto)
  @IsOptional()
  financialDetails?: FinancialDetailsDto;

  @ValidateNested()
  @Type(() => DocumentsDto)
  @IsOptional()
  documents?: DocumentsDto;

  @IsEnum(CreditLongStatus)
  @IsOptional()
  status?: CreditLongStatus;

  @IsArray()
  @IsOptional()
  @ValidateNested({ each: true })
  @Type(() => ReviewHistoryEntryDto)
  reviewHistory?: ReviewHistoryEntryDto[];

  @ValidateNested()
  @Type(() => Object)
  @IsOptional()
  simulation?: any;

  @ValidateNested()
  @Type(() => DecisionDto)
  @IsOptional()
  decision?: DecisionDto;
}

// === RESPONSE DTOs ===

export class CreditSimulationResult {
  requestedAmount: number;
  duration: number;
  clientProfile: any;
  results: {
    score: number;
    riskLevel: string;
    recommendedAmount: number;
    maxAmount: number;
    suggestedRate: number;
    monthlyPayment: number;
    totalAmount: number;
    totalInterest: number;
    debtToIncomeRatio: number;
    approvalProbability: number;
    keyFactors: Array<{
      factor: string;
      impact: 'positive' | 'negative' | 'neutral';
      description: string;
    }>;
    recommendations: string[];
    warnings: string[];
  };
}

// === ENTITY ===

// Partie à modifier dans credit-long.dto.ts - Section Entity

import { Entity, Column, PrimaryGeneratedColumn, CreateDateColumn, UpdateDateColumn } from 'typeorm';

@Entity('credit_long_requests')
export class CreditLongRequestEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  userId: number;

  @Column()
  username: string;

  @Column('json')
  personalInfo: PersonalInfoDto;

  @Column('json')
  creditDetails: CreditDetailsDto;

  @Column('json')
  financialDetails: FinancialDetailsDto;

  @Column('json')
  documents: DocumentsDto;

  @Column({
    type: 'enum',
    enum: CreditLongStatus,
    default: CreditLongStatus.DRAFT
  })
  status: CreditLongStatus;

  @Column({ nullable: true, type: 'varchar' })
  submissionDate: string | null;  // Changement ici : permettre null explicitement

  @Column('json')
  reviewHistory: ReviewHistoryEntryDto[];

  @Column('json', { nullable: true })
  simulation: any;

  @Column('json', { nullable: true })
  decision: DecisionDto | null;  // Changement ici : permettre null explicitement

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}

// === INTERFACES POUR BACK-OFFICE ===

export interface BackOfficeNotification {
  id: string;
  type: 'new_request' | 'document_uploaded' | 'client_comment';
  requestId: string;
  clientUsername: string;
  title: string;
  message: string;
  priority: 'low' | 'medium' | 'high';
  createdAt: string;
  isRead: boolean;
}

export interface AgentAction {
  requestId: string;
  agentId: string;
  agentName: string;
  action: 'review_started' | 'document_requested' | 'approved' | 'rejected' | 'info_requested';
  comment?: string;
  documents?: string[];
  decision?: DecisionDto;
}

export interface RequestStatistics {
  totalRequests: number;
  pendingRequests: number;
  approvedRequests: number;
  rejectedRequests: number;
  averageProcessingTime: number;
  monthlyVolume: { [month: string]: number };
  approvalRate: number;
  averageAmount: number;
  riskDistribution: { [level: string]: number };
}

// === VALIDATION HELPERS ===

export class ValidationResult {
  isValid: boolean;
  errors: string[];
  warnings?: string[];
}

export class FileValidation {
  isValid: boolean;
  errors: string[];
  fileInfo?: {
    name: string;
    size: number;
    type: string;
    path: string;
  };
}

// === NOTIFICATION DTOs ===

export class NotificationDto {
  @IsString()
  id: string;

  @IsString()
  @IsNotEmpty()
  userId: string;

  @IsString()
  @IsNotEmpty()
  title: string;

  @IsString()
  @IsNotEmpty()
  message: string;

  @IsString()
  @IsOptional()
  type?: string;

  @IsBoolean()
  @IsOptional()
  isRead?: boolean;

  @IsString()
  createdAt: string;

  @IsString()
  @IsOptional()
  requestId?: string;
}

// === SEARCH AND FILTER DTOs ===

export class RequestSearchDto {
  @IsString()
  @IsOptional()
  username?: string;

  @IsEnum(CreditLongStatus)
  @IsOptional()
  status?: CreditLongStatus;

  @IsNumber()
  @IsOptional()
  @Min(0)
  minAmount?: number;

  @IsNumber()
  @IsOptional()
  @Min(0)
  maxAmount?: number;

  @IsString()
  @IsOptional()
  dateFrom?: string;

  @IsString()
  @IsOptional()
  dateTo?: string;

  @IsNumber()
  @IsOptional()
  @Min(1)
  page?: number;

  @IsNumber()
  @IsOptional()
  @Min(1)
  @Max(100)
  limit?: number;

  @IsString()
  @IsOptional()
  sortBy?: string;

  @IsString()
  @IsOptional()
  sortOrder?: 'ASC' | 'DESC';
}

// === EMAIL TEMPLATES DATA ===

export interface EmailTemplateData {
  clientName: string;
  requestId: string;
  requestAmount: string;
  requestStatus: string;
  agentName?: string;
  comments?: string;
  nextSteps?: string[];
  documents?: string[];
  approvalDetails?: {
    approvedAmount: string;
    rate: string;
    duration: string;
    monthlyPayment: string;
  };
}

// === AUDIT TRAIL ===

export class AuditLogDto {
  @IsString()
  id: string;

  @IsString()
  requestId: string;

  @IsString()
  userId: string;

  @IsString()
  userRole: string;

  @IsString()
  action: string;

  @IsString()
  @IsOptional()
  oldValue?: string;

  @IsString()
  @IsOptional()
  newValue?: string;

  @IsString()
  @IsOptional()
  comment?: string;

  @IsString()
  ipAddress: string;

  @IsString()
  userAgent: string;

  @IsString()
  timestamp: string;
}

// === WORKFLOW STATES ===

export interface WorkflowStep {
  id: string;
  name: string;
  description: string;
  requiredRole: string[];
  requiredDocuments: string[];
  autoTransitions?: {
    condition: string;
    nextStep: string;
  }[];
  manualActions: string[];
  estimatedDuration: number; // in hours
}

export const CREDIT_LONG_WORKFLOW: WorkflowStep[] = [
  {
    id: 'draft',
    name: 'Brouillon',
    description: 'Demande en cours de préparation par le client',
    requiredRole: ['client'],
    requiredDocuments: [],
    manualActions: ['edit', 'submit'],
    estimatedDuration: 0
  },
  {
    id: 'submitted',
    name: 'Soumise',
    description: 'Demande soumise en attente d\'examen initial',
    requiredRole: ['agent', 'supervisor'],
    requiredDocuments: ['identityProof', 'incomeProof', 'employmentCertificate'],
    autoTransitions: [
      {
        condition: 'all_documents_valid',
        nextStep: 'under_review'
      }
    ],
    manualActions: ['start_review', 'request_documents', 'reject'],
    estimatedDuration: 24
  },
  {
    id: 'under_review',
    name: 'En cours d\'examen',
    description: 'Dossier en cours d\'analyse par les agents',
    requiredRole: ['agent', 'supervisor'],
    requiredDocuments: ['identityProof', 'incomeProof', 'employmentCertificate', 'bankStatements'],
    manualActions: ['approve', 'reject', 'request_info', 'escalate'],
    estimatedDuration: 48
  },
  {
    id: 'requires_info',
    name: 'Informations requises',
    description: 'En attente d\'informations complémentaires du client',
    requiredRole: ['client'],
    requiredDocuments: [],
    autoTransitions: [
      {
        condition: 'client_responds',
        nextStep: 'under_review'
      }
    ],
    manualActions: ['provide_info', 'upload_documents'],
    estimatedDuration: 72
  },
  {
    id: 'approved',
    name: 'Approuvée',
    description: 'Demande approuvée, en attente de signature du contrat',
    requiredRole: ['agent', 'client'],
    requiredDocuments: [],
    manualActions: ['generate_contract', 'sign_contract', 'disburse'],
    estimatedDuration: 24
  },
  {
    id: 'rejected',
    name: 'Rejetée',
    description: 'Demande rejetée définitivement',
    requiredRole: ['agent', 'supervisor'],
    requiredDocuments: [],
    manualActions: ['provide_feedback'],
    estimatedDuration: 0
  }
];

// === BUSINESS RULES ===

export interface BusinessRule {
  id: string;
  name: string;
  description: string;
  condition: string;
  action: string;
  priority: number;
  isActive: boolean;
}

export const CREDIT_LONG_BUSINESS_RULES: BusinessRule[] = [
  {
    id: 'max_amount_income_ratio',
    name: 'Ratio Montant/Revenus Maximum',
    description: 'Le montant demandé ne peut pas dépasser 40 fois le revenu mensuel',
    condition: 'requestedAmount > monthlyIncome * 40',
    action: 'reject_with_reason',
    priority: 1,
    isActive: true
  },
  {
    id: 'min_income_threshold',
    name: 'Revenu Minimum Requis',
    description: 'Le revenu mensuel doit être d\'au moins 150 000 FCFA',
    condition: 'monthlyIncome < 150000',
    action: 'reject_with_reason',
    priority: 1,
    isActive: true
  },
  {
    id: 'max_debt_ratio',
    name: 'Taux d\'Endettement Maximum',
    description: 'Le taux d\'endettement total ne peut pas dépasser 50%',
    condition: 'debtToIncomeRatio > 50',
    action: 'request_guarantor',
    priority: 2,
    isActive: true
  },
  {
    id: 'min_employment_duration',
    name: 'Ancienneté Minimum',
    description: 'L\'ancienneté dans l\'emploi actuel doit être d\'au moins 6 mois',
    condition: 'jobSeniority < 6',
    action: 'escalate_to_supervisor',
    priority: 3,
    isActive: true
  },
  {
    id: 'high_risk_score',
    name: 'Score de Risque Élevé',
    description: 'Les demandes avec un score inférieur à 4 nécessitent une approbation superviseur',
    condition: 'creditScore < 4',
    action: 'escalate_to_supervisor',
    priority: 2,
    isActive: true
  }
];

// === CONFIGURATION ===

export interface CreditLongConfig {
  maxAmount: number;
  minAmount: number;
  maxDuration: number;
  minDuration: number;
  maxActiveRequests: number;
  documentRetentionDays: number;
  autoApprovalThreshold: number;
  defaultInterestRates: {
    [riskLevel: string]: number;
  };
  notificationSettings: {
    emailNotifications: boolean;
    smsNotifications: boolean;
    pushNotifications: boolean;
  };
  fileUploadLimits: {
    maxFileSize: number;
    allowedTypes: string[];
    maxFilesPerDocument: number;
  };
}