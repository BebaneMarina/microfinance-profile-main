export interface EligibilityResult {
  valid: boolean;
  errors: string[];
  warnings: string[];
  maxAmount?: number;
  recommendations?: string[];
  debt_ratio?: number;
}

export interface ScoringResult {
  score: number;
  risk_level: string;
  probability: number;
  decision: string;
  factors: ScoringFactor[];
  recommendations: string[];
}

export interface ScoringFactor {
  name: string;
  value: number;
  impact: number;
}

export interface LoanDetails {
  monthlyPayment: number;
  totalInterest: number;
  totalAmount: number;
  teg: number;
}

export interface CreditStatistics {
  total: number;
  byStatus: StatusCount[];
  byType: TypeStatistics[];
  recentApplications: any[];
}

export interface StatusCount {
  status: string;
  count: number;
}

export interface TypeStatistics {
  type: string;
  count: number;
  avgAmount: number;
  avgScore: number;
}