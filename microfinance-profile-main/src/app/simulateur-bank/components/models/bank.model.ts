import { BankOffer } from "./multi-bank.model";

export interface Bank {
  id: string;
  name: string;
  logo: string;
  description: string;
  isActive: boolean;
  supportedCreditTypes: string[];
  minAmount: number;
  maxAmount: number;
  minDuration: number;
  maxDuration: number;
  baseInterestRate: number;
  processingTime: number;
  requiredDocuments: string[];
  eligibilityCriteria: {
    minIncome: number;
    minAge: number;
    maxAge: number;
    acceptedProfessions: string[];
    blacklistedProfessions: string[];
  };
  contactInfo: {
    phone: string;
    email: string;
    website: string;
    address: string;
  };
  ratings: {
    customerService: number;
    processSpeed: number;
    competitiveRates: number;
    overall: number;
  };
  fees: {
    applicationFee: number;
    processingFee: number;
    insuranceFee: number;
    penaltyRate: number;
  };
  specialOffers: any[];
  createdAt: Date;
  updatedAt: Date;
  color: string;
  shortName: string;
  marketShare: number;
}

export interface BankApiConfig {
  bankId: string;
  baseUrl: string;
  apiKey: string;
  endpoints: {
    simulation: string;
    application: string;
    status: string;
    documents: string;
  };
  authMethod: string;
  rateLimit: {
    requestsPerMinute: number;
    requestsPerDay: number;
  };
  timeout: number;
  retryAttempts: number;
}

export interface BankIntegrationStatus {
  bankId: string;
  isOnline: boolean;
  lastCheck: Date;
  averageResponseTime: number;
  successRate: number;
  healthScore: number;
  lastError?: string;
}

export interface BankResponse {
  bankId: string;
  success: boolean;
  data?: BankOffer;
  error?: {
    code: string;
    message: string;
    details?: any;
  };
  responseTime: number;
  timestamp: Date;
}