export interface MultiBankSimulationInput {
  clientType: string;
  fullName: string;
  phoneNumber: string;
  email?: string;
  monthlyIncome: number;
  profession?: string;
  creditType: string;
  requestedAmount: number;
  duration: number;
  purpose: string;
  selectedBanks: string[];
}

export interface BankOffer {
  bankId: string;
  bankName: string;
  bankLogo: string;
  bankColor: string;
  creditType: string; 
  interestRate: number;
  monthlyPayment: number;
  totalCost: number;
  approvedAmount: number;
  duration: number;
  processingTime: number;
  approvalChance: number;
   competitiveAdvantages?: string[];
  eligibilityStatus: 'eligible' | 'conditional' | 'not_eligible';
  fees: {
    applicationFee: number;
    processingFee: number;
    insuranceFee: number;
    totalFees: number;
  };
  requiredDocuments: string[];
  specialConditions: string[];
  contactInfo: {
    phone: string;
    email: string;
    website: string;
    address: string;
  };
  validUntil: Date;
  terms: string;
}

export interface MarketAnalysis {
  bestRate: number;
  averageRate: number;
  averageProcessingTime: number;
  approvalRate: number;
}

export interface MultiBankComparisonResult {
  requestId: string;
  bankOffers: BankOffer[];
  bestOffer: BankOffer;
  summary: {
    totalOffers: number;
    averageRate: number;
    bestRate: number;
    worstRate: number;
    totalSavings: number;
    fastestProcessing: number;
    highestApprovalChance: number;
  };
  comparisonMetrics: {
    rateSpread: number;
    paymentDifference: number;
    processingTimeRange: number;
  };
  marketAnalysis: MarketAnalysis;
  recommendations: string[];
  createdAt: Date;
  expiresAt: Date;
}

export interface BankSimulationRequest {
  bankId: string;
  simulationData: MultiBankSimulationInput;
}

export interface BankSimulationResponse {
  success: boolean;
  data?: BankOffer;
  error?: string;
}

export interface CreditApplication {
  bankId: string;
  offerId: string;
  userData: {
    fullName: string;
    phoneNumber: string;
    email?: string;
  };
  applicationDate: Date;
  status: 'pending' | 'approved' | 'rejected';
  trackingNumber: string;
}