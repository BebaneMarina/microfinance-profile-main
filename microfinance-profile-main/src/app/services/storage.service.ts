import { Injectable } from '@angular/core';
import { BehaviorSubject, Observable } from 'rxjs';

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
    otherIncome: number;
    monthlyCharges: number;
    monthlySalary: number; // Changé de string à number
    employerName: string;
    contractType: string;
    jobSeniority: number; // Changé de string à number
  };
  creditDetails: {
    requestedAmount: string;
    duration: string;
    creditPurpose: string;
  };
  documents?: {
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

@Injectable({
  providedIn: 'root'
})
export class StorageService {
  private readonly STORAGE_KEYS = {
    APPLICATIONS: 'credit_applications',
    USER: 'currentUser',
    THEME: 'app_theme',
    LANGUAGE: 'app_language',
    NOTIFICATIONS: 'notifications',
    CREDIT_SCORE: 'userCreditScore',
    TOKEN: 'access_token'
  };

  private applicationsSubject = new BehaviorSubject<CreditApplication[]>([]);
  public applications$ = this.applicationsSubject.asObservable();

  private currentUserSubject = new BehaviorSubject<any>(null);
  public currentUser$ = this.currentUserSubject.asObservable();
  setSelectedBank: any;
  setDemoMode: any;

  constructor() {
    this.loadApplications();
    this.loadCurrentUser();
  }

  // Méthodes pour le token
  setToken(token: string): void {
    try {
      localStorage.setItem(this.STORAGE_KEYS.TOKEN, token);
    } catch (error) {
      console.error('Erreur lors de la sauvegarde du token:', error);
    }
  }

  getToken(): string | null {
    return localStorage.getItem(this.STORAGE_KEYS.TOKEN);
  }

  clearAuth(): void {
    try {
      localStorage.removeItem(this.STORAGE_KEYS.TOKEN);
      localStorage.removeItem(this.STORAGE_KEYS.USER);
      this.currentUserSubject.next(null);
    } catch (error) {
      console.error('Erreur lors de la suppression des données d\'authentification:', error);
    }
  }

  // Méthodes pour les applications
  private loadApplications(): void {
    try {
      const stored = localStorage.getItem(this.STORAGE_KEYS.APPLICATIONS);
      if (stored) {
        const applications = JSON.parse(stored);
        this.applicationsSubject.next(applications);
      }
    } catch (error) {
      console.error('Erreur lors du chargement des applications:', error);
      this.applicationsSubject.next([]);
    }
  }

  getApplications(): CreditApplication[] {
    return this.applicationsSubject.value;
  }

  saveApplication(application: CreditApplication): void {
    const applications = this.getApplications();
    const index = applications.findIndex(app => app.id === application.id);
    
    if (index >= 0) {
      applications[index] = application;
    } else {
      applications.push(application);
    }
    
    this.saveApplications(applications);
  }

  private saveApplications(applications: CreditApplication[]): void {
    try {
      localStorage.setItem(this.STORAGE_KEYS.APPLICATIONS, JSON.stringify(applications));
      this.applicationsSubject.next(applications);
    } catch (error) {
      console.error('Erreur lors de la sauvegarde des applications:', error);
    }
  }

  deleteApplication(id: string): void {
    const applications = this.getApplications().filter(app => app.id !== id);
    this.saveApplications(applications);
  }

  // Méthodes pour l'utilisateur
  private loadCurrentUser(): void {
    try {
      const stored = localStorage.getItem(this.STORAGE_KEYS.USER);
      if (stored) {
        const user = JSON.parse(stored);
        this.currentUserSubject.next(user);
      }
    } catch (error) {
      console.error('Erreur lors du chargement de l\'utilisateur:', error);
      this.currentUserSubject.next(null);
    }
  }

  getCurrentUser(): any {
    return this.currentUserSubject.value;
  }

  setCurrentUser(user: any): void {
    try {
      if (user) {
        localStorage.setItem(this.STORAGE_KEYS.USER, JSON.stringify(user));
        this.currentUserSubject.next(user);
      } else {
        localStorage.removeItem(this.STORAGE_KEYS.USER);
        this.currentUserSubject.next(null);
      }
    } catch (error) {
      console.error('Erreur lors de la sauvegarde de l\'utilisateur:', error);
    }
  }

  // Méthodes pour le thème
  getTheme(): string {
    return localStorage.getItem(this.STORAGE_KEYS.THEME) || 'light';
  }

  setTheme(theme: string): void {
    localStorage.setItem(this.STORAGE_KEYS.THEME, theme);
  }

  // Méthodes pour la langue
  getLanguage(): string {
    return localStorage.getItem(this.STORAGE_KEYS.LANGUAGE) || 'fr';
  }

  setLanguage(language: string): void {
    localStorage.setItem(this.STORAGE_KEYS.LANGUAGE, language);
  }

  // Méthode pour effacer toutes les données
  clearAll(): void {
    try {
      // Sauvegarder le thème et la langue
      const theme = this.getTheme();
      const language = this.getLanguage();
      
      // Effacer tout le localStorage
      localStorage.clear();
      
      // Restaurer le thème et la langue
      this.setTheme(theme);
      this.setLanguage(language);
      
      // Réinitialiser les subjects
      this.applicationsSubject.next([]);
      this.currentUserSubject.next(null);
      
      console.log('Toutes les données ont été effacées');
    } catch (error) {
      console.error('Erreur lors de l\'effacement des données:', error);
    }
  }

  // Méthode pour effacer uniquement les données utilisateur
  clearUserData(): void {
    try {
      localStorage.removeItem(this.STORAGE_KEYS.USER);
      localStorage.removeItem(this.STORAGE_KEYS.CREDIT_SCORE);
      localStorage.removeItem(this.STORAGE_KEYS.TOKEN);
      localStorage.removeItem('profileImage');
      
      this.currentUserSubject.next(null);
      
      console.log('Données utilisateur effacées');
    } catch (error) {
      console.error('Erreur lors de l\'effacement des données utilisateur:', error);
    }
  }

  // Méthode pour obtenir le score de crédit sauvegardé
  getCreditScore(): any {
    try {
      const stored = localStorage.getItem(this.STORAGE_KEYS.CREDIT_SCORE);
      return stored ? JSON.parse(stored) : null;
    } catch (error) {
      console.error('Erreur lors de la récupération du score de crédit:', error);
      return null;
    }
  }

  // Méthode pour sauvegarder le score de crédit
  setCreditScore(scoreData: any): void {
    try {
      if (scoreData) {
        localStorage.setItem(this.STORAGE_KEYS.CREDIT_SCORE, JSON.stringify(scoreData));
      } else {
        localStorage.removeItem(this.STORAGE_KEYS.CREDIT_SCORE);
      }
    } catch (error) {
      console.error('Erreur lors de la sauvegarde du score de crédit:', error);
    }
  }

  // Méthode pour vérifier si des données existent
  hasData(key: string): boolean {
    return localStorage.getItem(key) !== null;
  }

  // Méthode générique pour stocker des données
  setItem(key: string, value: any): void {
    try {
      localStorage.setItem(key, JSON.stringify(value));
    } catch (error) {
      console.error(`Erreur lors de la sauvegarde de ${key}:`, error);
    }
  }

  // Méthode générique pour récupérer des données
  getItem(key: string): any {
    try {
      const item = localStorage.getItem(key);
      return item ? JSON.parse(item) : null;
    } catch (error) {
      console.error(`Erreur lors de la récupération de ${key}:`, error);
      return null;
    }
  }

  // Méthode pour recharger les données
  reload(): void {
    this.loadApplications();
    this.loadCurrentUser();
  }

  // Méthode pour ajouter une application
  addApplication(application: CreditApplication): void {
    if (!application.metadata) {
      application.metadata = {
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        version: 1
      };
    }
    this.saveApplication(application);
  }

  // Conversion de données pour assurer la compatibilité
  convertApplicationData(data: any): CreditApplication {
    return {
      ...data,
      financialInfo: {
        ...data.financialInfo,
        monthlySalary: typeof data.financialInfo.monthlySalary === 'string' 
          ? parseFloat(data.financialInfo.monthlySalary) 
          : data.financialInfo.monthlySalary,
        jobSeniority: typeof data.financialInfo.jobSeniority === 'string'
          ? parseInt(data.financialInfo.jobSeniority)
          : data.financialInfo.jobSeniority
      }
    };
  }
}