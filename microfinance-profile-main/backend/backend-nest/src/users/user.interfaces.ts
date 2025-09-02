// Interface pour l'utilisateur avec les propriétés de scoring
export interface User {
  id?: number;
  uuid?: string;
  email: string;
  username?: string;
  first_name?: string;
  last_name?: string;
  name?: string;
  role: string;
  phone_number?: string;
  address?: string;
  profession?: string;
  employer_name?: string;
  company?: string;
  birth_date?: string;
  employment_status?: string;
  work_experience?: number;
  jobSeniority?: number;
  monthly_income?: number;
  monthlyIncome?: number;
  profile_image?: string;
  profileImage?: string;
  client_type?: string;
  clientType?: string;
  
  // Propriétés de scoring
  creditScore?: number;
  eligibleAmount?: number;
  riskLevel?: string;
  recommendations?: string[];
  scoreDetails?: {
    factors?: any[];
    model_version?: string;
    probability?: number;
    decision?: string;
  };
}

// Interface pour la réponse de connexion
export interface LoginResponse {
  success: boolean;
  message?: string;
  user?: User;
  token?: string;
}