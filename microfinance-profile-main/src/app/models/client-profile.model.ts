export interface ClientProfil {
  existingDebts: number;
  monthlyCharges: number;
  birthDate: string;
  id?: number | undefined;
  uuid?: string;
  username: string;
  clientId: string;
  clientType: string;
  initiales?: string;
  name: string;
  fullName: string;
  email: string;
  phone: string;
  address: string;
  profession: string;
  company: string;
  role?: string;
  accountNumber?: string;
  profileImage: string;
  ProfileImage?: string;
  monthlyIncome: number;
  employmentStatus: string;
  jobSeniority: number;
  
  // Propriétés optionnelles de scoring
  creditScore?: number;
  eligibleAmount?: number;
  riskLevel?: string;
  recommendations?: string[];
  scoreDetails?: any;
}