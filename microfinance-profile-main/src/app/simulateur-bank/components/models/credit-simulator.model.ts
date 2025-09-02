// models/credit-simulator.model.ts

export interface SimulatorCreditType {
  id: string;
  name: string;
  description: string;
  minAmount: number;
  maxAmount: number;
  minDuration: number;
  maxDuration: number;
  averageRate: number;
  features: string[];
}

export interface SimulationInput {
  creditType: string;
  simulationMode: 'amount' | 'payment' | 'budget';
  requestedAmount?: number;
  duration: number;
  monthlyPayment?: number;
  monthlyIncome?: number;
  currentDebts?: number;
  downPayment?: number;
  interestRate: number;
  insuranceRate?: number;
  processingFees?: number;
  includeInsurance?: boolean;
  includeProcessingFees?: boolean;
  optimizeForPayment?: boolean;
}

export interface AmortizationPayment {
  month: number;
  monthlyPayment: number;
  capitalPayment: number;
  interestPayment: number;
  insurancePayment?: number;
  remainingCapital: number;
  cumulativeInterest: number;
  cumulativeCapital: number;
}

export interface SimulationResult {
  // Montants principaux
  requestedAmount: number;
  approvedAmount?: number;
  calculatedAmount?: number; // Pour mode "payment"
  totalAmount: number;
  downPayment?: number;

  // Mensualités
  monthlyPayment: number;
  monthlyCapital: number;
  monthlyInterest: number;
  monthlyInsurance?: number;

  // Coûts totaux
  totalCost: number;
  totalInterest: number;
  totalInsurance?: number;
  processingFees?: number;

  // Taux
  nominalRate: number;
  effectiveRate: number; // TEG
  insuranceRate?: number;

  // Durée
  duration: number;
  firstPaymentDate?: Date;
  lastPaymentDate?: Date;

  // Capacité financière
  debtRatio?: number;
  remainingIncome?: number;
  affordabilityScore?: number;

  // Tableau d'amortissement
  amortizationSchedule: AmortizationPayment[];

  // Métadonnées
  calculatedAt: Date;
  simulationId: string;
  warnings?: string[];
  recommendations?: string[];
}

export interface SimulationScenario {
  id: string;
  name: string;
  input: SimulationInput;
  result: SimulationResult;
  createdAt: Date;
  notes?: string;
}

export interface SimulationComparison {
  scenarios: SimulationScenario[];
  bestScenario: SimulationScenario;
  worstScenario: SimulationScenario;
  averageMonthlyPayment: number;
  averageTotalCost: number;
  maxSavings: number;
  recommendedScenario?: SimulationScenario;
}

export interface SimulationExport {
  input: SimulationInput;
  result: SimulationResult;
  scenarios?: SimulationScenario[];
  comparison?: SimulationComparison;
  exportDate: Date;
  format: 'pdf' | 'excel' | 'json';
}

// Types pour les calculs internes
export interface CalculationParams {
  principal: number;
  rate: number;
  duration: number;
  insuranceRate?: number;
  processingFees?: number;
  downPayment?: number;
}

export interface CalculationResult {
  monthlyPayment: number;
  totalInterest: number;
  totalCost: number;
  effectiveRate: number;
  amortizationSchedule: AmortizationPayment[];
}

// Enums pour les types
export enum CreditTypeEnum {
  CONSOMMATION = 'consommation',
  AUTO = 'auto',
  IMMOBILIER = 'immobilier',
  PROFESSIONNEL = 'professionnel'
}

export enum SimulationModeEnum {
  AMOUNT = 'amount',
  PAYMENT = 'payment', 
  BUDGET = 'budget'
}

export enum AffordabilityLevel {
  EXCELLENT = 'excellent',
  GOOD = 'good',
  ACCEPTABLE = 'acceptable',
  RISKY = 'risky',
  CRITICAL = 'critical'
}

// Constantes de validation - déclarées une seule fois
export const SIMULATOR_VALIDATION_CONSTANTS = {
  MIN_AMOUNT: 100000,
  MAX_AMOUNT: 1000000000,
  MIN_DURATION: 6,
  MAX_DURATION: 360,
  MIN_RATE: 0.1,
  MAX_RATE: 30,
  MIN_INCOME: 200000,
  MAX_DEBT_RATIO: 40,
  RECOMMENDED_DEBT_RATIO: 35
};

// Configuration des types de crédit - déclarée une seule fois
export const SIMULATOR_CREDIT_TYPE_CONFIGS: Record<string, Partial<SimulatorCreditType>> = {
  [CreditTypeEnum.CONSOMMATION]: {
    minAmount: 100000,
    maxAmount: 50000000,
    minDuration: 6,
    maxDuration: 84,
    averageRate: 12.5
  },
  [CreditTypeEnum.AUTO]: {
    minAmount: 500000,
    maxAmount: 75000000,
    minDuration: 12,
    maxDuration: 84,
    averageRate: 8.9
  },
  [CreditTypeEnum.IMMOBILIER]: {
    minAmount: 5000000,
    maxAmount: 500000000,
    minDuration: 60,
    maxDuration: 300,
    averageRate: 6.2
  },
  [CreditTypeEnum.PROFESSIONNEL]: {
    minAmount: 1000000,
    maxAmount: 200000000,
    minDuration: 12,
    maxDuration: 120,
    averageRate: 9.8
  }
};

// Interface pour les alertes et recommandations
export interface SimulationAlert {
  type: 'warning' | 'error' | 'info' | 'success';
  code: string;
  message: string;
  severity: 'low' | 'medium' | 'high';
  action?: string;
}

// Interface pour l'historique des simulations
export interface SimulationHistory {
  userId?: string;
  sessionId: string;
  simulations: SimulationResult[];
  createdAt: Date;
  lastModified: Date;
}

// Interface pour les préférences utilisateur
export interface UserSimulationPreferences {
  defaultCreditType: CreditTypeEnum;
  defaultSimulationMode: SimulationModeEnum;
  includeInsuranceByDefault: boolean;
  includeProcessingFeesByDefault: boolean;
  maxDebtRatio: number;
  favoriteScenarios: string[];
  notificationSettings: {
    rateChanges: boolean;
    newOffers: boolean;
    simulationReminders: boolean;
  };
}

// Interface pour les statistiques de simulation
export interface SimulationStats {
  totalSimulations: number;
  averageAmount: number;
  averageDuration: number;
  mostPopularCreditType: CreditTypeEnum;
  mostUsedSimulationMode: SimulationModeEnum;
  averageDebtRatio: number;
  conversionRate: number; // Taux de conversion simulation -> demande
}