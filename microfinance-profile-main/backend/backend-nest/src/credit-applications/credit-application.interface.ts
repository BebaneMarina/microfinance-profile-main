export interface CreditApplication {
  id: string;
  requestNumber: string;
  submissionDate: string;
  creditType: string;
  status: string;
  personalInfo: {
    fullName: string;
    email: string;
    phoneNumber: string;
    profession: string;
  };
  financialInfo: {
    monthlySalary: string;
    employerName: string;
    contractType: string;
    jobSeniority: string;
  };
  creditDetails: {
    requestedAmount: string;
    duration: string;
    creditPurpose: string;
  };
  documents: {
    identityCard?: boolean;
    salarySlip?: boolean;
    employmentCertificate?: boolean;
  };
  creditScore?: number;
  decision?: string;
  localId?: string;
  metadata?: {
    createdAt?: string;
    updatedAt?: string;
    version?: number;
  };
}