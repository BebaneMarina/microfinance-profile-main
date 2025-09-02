export interface AuthUser {
  existingDebts: number;
  monthlyCharges: number;
  birthDate: string;
  jobSeniority: number;
  employmentStatus: string;
  address: string;
  company: string;
  profession: string;
  profileImage: string;
  id: number;
  email: string;
  firstName: string;
  lastName: string;
  role: string;
  phone?: string;
  phoneNumber?: string;
  monthlyIncome?: number;
  createdAt?: string;
  creditScore?: number;
  eligibleAmount?: number;
  riskLevel?: string;
  recommendations?: string[];
  scoreDetails?: any;
}

export interface AuthResponse {
  success: boolean;
  message?: string;
  user: AuthUser;
  token?: string;
}