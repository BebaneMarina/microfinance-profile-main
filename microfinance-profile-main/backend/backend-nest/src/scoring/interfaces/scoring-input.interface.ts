// src/scoring/interfaces/scoring-input.interface.ts
export interface ScoringInput {
  creditType: 'consommation' | 'investissement' | 'avance_facture' | 'avance_commande' | 'tontine' | 'retraite' | 'spot';
  personalInfo: {
    age: number;
    identityType: string;
    nationality: string;
  };
  financialInfo: {
    monthlySalary: number;
    otherIncome: number;
    jobSeniority: number; // en années
    contractType: 'CDI' | 'CDD' | 'Fonctionnaire' | 'Autre';
    existingDebts: number;
    turnover?: number; // Pour crédit investissement
    netProfit?: number; // Pour crédit investissement
    pensionAmount?: number; // Pour crédit retraite
    contributionAmount?: number; // Pour crédit tontine
    invoiceAmount?: number; // Pour avance facture
    totalOrderAmount?: number; // Pour avance commande
  };
  creditDetails: {
    requestedAmount: number;
    duration: number; // en mois
    repaymentMode: string;
  };
  documents: {
    identityDocument: boolean;
    paySlips: boolean;
    employmentCertificate: boolean;
    bankStatements: boolean;
    additionalDocuments: Record<string, boolean>; // Documents spécifiques
  };
}