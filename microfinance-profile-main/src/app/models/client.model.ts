export interface Client {
  name: string;
  role: string;
  initials: string;
  accountNumber: string;
  bank: string;
  branch: string;
  accountType: string;
}

export interface ClientProfile {
  fullName: string;
  birthDate: string;
  birthPlace: string;
  gender: string;
  maritalStatus: string;
  children: number;
  phone1: string;
  phone2: string;
  email: string;
  city: string;
  district: string;
  address: string;
  profession: string;
  employer: string;
  monthlyIncome: number;
  workExperience: number;
  idType: string;
  idNumber: string;
  idIssueDate: string;
  idExpiryDate: string;
}

export interface Client {
  name: string;
  role: string;
  initials: string;
  accountNumber: string;
  bank: string;
  branch: string;
  accountType: string;
}

// src/app/models/client.model.ts
export interface ProfilClient {
  profileImage?: string;
  name?: string;
  initiales?: string; // ou initiales si vous préférez en français
  accountNumber?: string;
  fullName: string;
  birthDate: string;
  birthPlace: string;
  gender: string;
  maritalStatus: string;
  children: number;
  phone1: string;
  phone2: string;
  email: string;
  city: string;
  district: string;
  address: string;
  // ... autres propriétés
  idExpiryDate: string;
}