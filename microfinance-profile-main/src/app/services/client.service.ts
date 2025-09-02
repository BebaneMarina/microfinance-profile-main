import { Injectable } from '@angular/core';
import { Client, ClientProfile } from '../models/client.model';
import { Folder } from '../models/folders.model';

@Injectable({
  providedIn: 'root'
})
export class ClientService {
  private client: Client = {
    name: 'Marina MKB',
    role: 'Cliente Bamboo',
    initials: 'MN',
    accountNumber: 'ECO2024001234',
    bank: 'Bamboo EMF',
    branch: 'Libreville Centre',
    accountType: 'Microfinance'
  };

  private profile: ClientProfile = {
    fullName: 'BEBANE MOUKOUMBI Marina Brunelle',
    birthDate: '1985-03-15',
    birthPlace: 'Libreville',
    gender: 'F',
    maritalStatus: 'marrié',
    children: 2,
    phone1: '+241 06 12 34 56',
    phone2: '+241 07 65 43 21',
    email: 'marina@email.com',
    city: 'Libreville',
    district: 'Glass',
    address: 'BP 1234, Rue de la Paix, Quartier Glass',
    profession: 'Commerçante',
    employer: 'Commerce Indépendant',
    monthlyIncome: 350000,
    workExperience: 8,
    idType: 'cni',
    idNumber: 'CNI123456789',
    idIssueDate: '2020-01-15',
    idExpiryDate: '2030-01-15'
  };

  private folders: Folder[] = [
    { name: 'Crédit Personnel', status: 'approved', statusText: 'Approuvé' },
    { name: 'Micro-crédit Commerce', status: 'pending', statusText: 'En cours' },
    { name: 'Épargne Progressive', status: 'approved', statusText: 'Actif' },
    { name: 'Demande Crédit Auto', status: 'review', statusText: 'Étude' }
  ];

  getClient(): Client {
    return this.client;
  }

  getProfile(): ClientProfile {
    return this.profile;
  }

  updateProfile(updatedProfile: ClientProfile): void {
    this.profile = { ...this.profile, ...updatedProfile };
  }

  getFolders(): Folder[] {
    return this.folders;
  }

  openCreditForm(): void {
    if (confirm('Nouveau formulaire de crédit\n\nTypes disponibles:\n• Micro-crédit personnel\n• Crédit commerce\n• Crédit équipement\n• Crédit agriculture\n\nContinuer?')) {
      alert('Redirection vers le formulaire de crédit...');
    }
  }
}