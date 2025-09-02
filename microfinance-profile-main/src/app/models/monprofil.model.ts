// src/app/models/client-profile.model.ts
export interface ClientProfil {
  // Informations de base
  profileImage?: string;
  ProfileImage?: string; // Pour la compatibilité
  name?: string;
  initiales?: string;
  accountNumber?: string;
  
  // Informations personnelles
  fullName: string;
  birthDate: string;
  birthPlace: string;
  gender: string;
  maritalStatus: string;
  children: number;
  
  // Contact
  phone1: string;
  phone2: string;
  email: string;
  
  // Adresse
  city: string;
  district: string;
  address: string;
  
  // Informations professionnelles
  profession?: string;
  employer?: string;
  monthlyIncome?: number;
  workExperience?: number;
  
  // Documents d'identité
  idType?: string;
  idNumber?: string;
  idIssueDate?: string;
  idExpiryDate: string;
  
  // Informations bancaires
  bank?: string;
  branch?: string;
  accountType?: string;
  
  // Métadonnées
  createdAt?: string;
  updatedAt?: string;
  isActive?: boolean;
  role?: string;
}