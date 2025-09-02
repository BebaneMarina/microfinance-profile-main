export interface CreditDataInterface {
  // Données personnelles
  age: number;
  gender: string;
  maritalStatus: string;
  
  // Données financières
  monthlyIncome: number;
  otherIncome: number;
  totalIncome: number;
  existingDebts: number;
  debtToIncomeRatio: number;
  repaymentCapacity: number;
  
  // Données emploi
  jobSeniority: number;
  contractType: string;
  employmentStability: number;
  
  // Données crédit
  requestedAmount: number;
  requestedDuration: number;
  creditType: string;
  requestedAmountRatio: number;
  
  // Données bancaires
  bankAccountAge: number;
  averageBalance: number;
  
  // Historique
  previousLoans: number;
  paymentHistory: string;
  
  // Garanties
  guarantees: string[];
  collateral: number;
}
