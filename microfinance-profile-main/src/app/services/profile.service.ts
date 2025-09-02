import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { BehaviorSubject, Observable, of, forkJoin } from 'rxjs';
import { catchError, tap, map, switchMap } from 'rxjs/operators';
import { ScoringService } from './scoring.service';
import { StorageService } from './storage.service';
import { ClientProfil } from '../models/client-profile.model';
import { environment } from '../environments/environment';

export interface ActiveCredit {
  id: string;
  type: string;
  amount: number;
  remainingAmount: number;
  progress: number;
  nextPayment: Date;
  nextPaymentAmount: number;
  status: 'active' | 'late';
}

export interface ProfileStats {
  riskLevel: string | undefined;
  totalBorrowed: number;
  totalReimbursed: number;
  activeCredits: number;
  creditScore: number;
  eligibleAmount: number;
  totalApplications: number;
  approvedApplications: number;
}

@Injectable({
  providedIn: 'root'
})
export class ProfileService {
  private apiUrl = environment.apiUrl || 'http://localhost:5000';
  
  private activeCreditsSubject = new BehaviorSubject<ActiveCredit[]>([]);
  private profileStatsSubject = new BehaviorSubject<ProfileStats>({
    riskLevel: 'medium', // Valeur par défaut pour éviter undefined
    totalBorrowed: 0,
    totalReimbursed: 0,
    activeCredits: 0,
    creditScore: 6.5, // Score par défaut sur 10
    eligibleAmount: 0,
    totalApplications: 0,
    approvedApplications: 0
  });

  activeCredits$ = this.activeCreditsSubject.asObservable();
  profileStats$ = this.profileStatsSubject.asObservable();

  constructor(
    private http: HttpClient,
    private scoringService: ScoringService,
    private storageService: StorageService
  ) {
    this.refreshData();
  }

  /**
   * Rafraîchit toutes les données du profil y compris le score de crédit
   */
  refreshData(): void {
    // Charger d'abord les données de base
    this.loadActiveCredits();
    this.loadApplicationStats();

    // Ensuite calculer le score et l'éligibilité
    this.calculateCreditScore();
  }

  /**
   * Charge les crédits actifs de l'utilisateur
   */
  private loadActiveCredits(): void {
    const applications = this.storageService.getApplications() || [];
    const activeCredits: ActiveCredit[] = applications
      .filter(app => app.status === 'en-cours' && app.decision === 'approuvé')
      .map(app => {
        const amount = parseFloat(app.creditDetails?.requestedAmount || '0');
        const remainingAmount = amount; // Pour cet exemple
        return {
          id: app.id.toString(),
          type: this.getCreditTypeName(app.creditType),
          amount: amount,
          remainingAmount: remainingAmount,
          progress: 0, // À calculer
          nextPayment: this.calculateNextPaymentDate(app.submissionDate),
          nextPaymentAmount: amount, // Pour cet exemple, montant total à rembourser
          status: 'active' as const
        };
      });

    this.activeCreditsSubject.next(activeCredits);
    
    // Mise à jour des statistiques
    const currentStats = this.profileStatsSubject.value;
    this.profileStatsSubject.next({
      ...currentStats,
      activeCredits: activeCredits.length,
      totalBorrowed: activeCredits.reduce((sum, credit) => sum + credit.amount, 0)
    });
  }

  /**
   * Charge les statistiques des demandes
   */
  private loadApplicationStats(): void {
    const applications = this.storageService.getApplications() || [];
    const totalApplications = applications.length;
    const approvedApplications = applications.filter(app => app.decision === 'approuvé').length;
    const totalBorrowed = applications.reduce((sum, app) => {
      return sum + parseFloat(app.creditDetails?.requestedAmount || '0');
    }, 0);
    const totalReimbursed = 0; // À calculer avec les données réelles

    const currentStats = this.profileStatsSubject.value;
    this.profileStatsSubject.next({
      ...currentStats,
      totalBorrowed,
      totalReimbursed,
      totalApplications,
      approvedApplications
    });
  }

  /**
   * Calcule le score de crédit et le montant éligible
   */
  private calculateCreditScore(): void {
    // Vérifier d'abord si des données d'éligibilité existent déjà
    const savedEligibility = localStorage.getItem('clientEligibility');
    
    if (savedEligibility) {
      try {
        const eligibilityData = JSON.parse(savedEligibility);
        const lastUpdated = new Date(eligibilityData.lastUpdated);
        const now = new Date();
        
        // Si les données ont moins de 24 heures, les utiliser
        if ((now.getTime() - lastUpdated.getTime()) < 24 * 60 * 60 * 1000) {
          const currentStats = this.profileStatsSubject.value;
          this.profileStatsSubject.next({
            ...currentStats,
            creditScore: eligibilityData.creditScore,
            eligibleAmount: eligibilityData.eligibleAmount,
            riskLevel: eligibilityData.riskLevel || 'medium'
          });
          return;
        }
      } catch (e) {
        console.error('Erreur lors de la lecture des données d\'éligibilité', e);
      }
    }
    
    // Si pas de données récentes, calculer avec l'API
    const clientData = this.getCurrentClientData();
    if (!clientData) return;

    // Préparer les données pour l'API de scoring
    const scoringData = {
      age: this.calculateAge(clientData.birthDate || '1990-01-01'),
      monthly_income: clientData.monthlyIncome || 0,
      other_income: 0,
      monthly_charges: clientData.monthlyCharges || 0,
      existing_debts: clientData.existingDebts || 0,
      job_seniority: clientData.jobSeniority || 12,
      employment_status: clientData.employmentStatus || 'cdi',
      loan_amount: 0,
      loan_duration: 1,
      username: clientData.username || 'theobawana' // Utiliser l'identifiant du client connecté
    };

    // Appeler l'API pour calculer le montant éligible et le score
    this.scoringService.calculateEligibleAmount(scoringData).subscribe({
      next: (result) => {
        // Mettre à jour les stats avec le score sur 10
        const currentStats = this.profileStatsSubject.value;
        this.profileStatsSubject.next({
          ...currentStats,
          creditScore: result.score, // Déjà sur 10 grâce au service
          eligibleAmount: result.eligible_amount,
          riskLevel: result.risk_level || 'medium'
        });
        
        // Sauvegarder les données pour les prochaines sessions
        localStorage.setItem('clientEligibility', JSON.stringify({
          creditScore: result.score,
          eligibleAmount: result.eligible_amount,
          riskLevel: result.risk_level,
          lastUpdated: new Date().toISOString()
        }));
      },
      error: (error) => {
        console.error('Erreur lors du calcul du score de crédit:', error);
        // Utiliser un calcul offline simple en cas d'erreur
        const offlineResult = this.calculateSimpleOfflineScore(clientData);
        const currentStats = this.profileStatsSubject.value;
        this.profileStatsSubject.next({
          ...currentStats,
          creditScore: offlineResult.score,
          eligibleAmount: offlineResult.eligibleAmount,
          riskLevel: offlineResult.riskLevel || 'medium'
        });
      }
    });
  }

  /**
   * Calcul offline simple du score de crédit
   */
  private calculateSimpleOfflineScore(clientData: ClientProfil): { score: number; eligibleAmount: number; riskLevel: string } {
    let score = 5; // Score de base
    let eligibleAmount = 0;
    let riskLevel = 'medium';
    
    const monthlyIncome = clientData.monthlyIncome || 0;
    const monthlyCharges = clientData.monthlyCharges || 0;
    const existingDebts = clientData.existingDebts || 0;
    const jobSeniority = clientData.jobSeniority || 0;
    
    // Calcul basé sur le revenu
    if (monthlyIncome > 0) {
      const netIncome = monthlyIncome - monthlyCharges - existingDebts;
      const incomeRatio = netIncome / monthlyIncome;
      
      if (incomeRatio > 0.7) {
        score += 2;
        eligibleAmount = netIncome * 0.3333; // 3x le revenu net
      } else if (incomeRatio > 0.5) {
        score += 1;
        eligibleAmount = netIncome * 0.3333;
      } else if (incomeRatio > 0.3) {
        eligibleAmount = netIncome * 0.3333;
      } else {
        score -= 1;
        eligibleAmount = netIncome;
      }
    }
    
    // Ajustement selon l'ancienneté
    if (jobSeniority >= 24) {
      score += 1;
    } else if (jobSeniority >= 12) {
      score += 0.5;
    }
    
    // Limitation du montant éligible
    eligibleAmount = Math.min(eligibleAmount, 2000000); // Maximum 2M FCFA
    eligibleAmount = Math.max(eligibleAmount, 0);
    
    // Calcul du niveau de risque
    if (score >= 8) {
      riskLevel = 'low';
    } else if (score >= 6) {
      riskLevel = 'medium';
    } else if (score >= 4) {
      riskLevel = 'high';
    } else {
      riskLevel = 'very_high';
    }
    
    // S'assurer que le score est entre 0 et 10
    score = Math.max(0, Math.min(10, score));
    
    return { score, eligibleAmount, riskLevel };
  }

  /**
   * Récupère les données du client actuel
   */
  private getCurrentClientData(): ClientProfil | null {
    try {
      const savedClient = localStorage.getItem('currentClient');
      if (savedClient) {
        return JSON.parse(savedClient);
      }
      return null;
    } catch (e) {
      console.error('Erreur lors de la récupération des données client', e);
      return null;
    }
  }

  /**
   * Enregistre le profil utilisateur
   */
  saveUserProfile(userData: Partial<ClientProfil>): void {
    const currentData = this.getCurrentClientData();
    if (currentData) {
      const updatedData = { ...currentData, ...userData };
      localStorage.setItem('currentClient', JSON.stringify(updatedData));
      
      // Recalculer le score après mise à jour
      this.calculateCreditScore();
    }
  }

  /**
   * Simule un paiement
   */
  makePayment(creditId: string, amount: number): void {
    const activeCredits = this.activeCreditsSubject.value;
    const creditIndex = activeCredits.findIndex(c => c.id === creditId);
    
    if (creditIndex >= 0) {
      const updatedCredits = [...activeCredits];
      const credit = { ...updatedCredits[creditIndex] };
      
      // Simuler le paiement
      credit.remainingAmount = Math.max(0, credit.remainingAmount - amount);
      credit.progress = ((credit.amount - credit.remainingAmount) / credit.amount) * 100;
      
      // Si remboursé intégralement
      if (credit.remainingAmount <= 0) {
        updatedCredits.splice(creditIndex, 1);
      } else {
        updatedCredits[creditIndex] = credit;
      }
      
      this.activeCreditsSubject.next(updatedCredits);
      
      // Mettre à jour les stats
      const currentStats = this.profileStatsSubject.value;
      this.profileStatsSubject.next({
        ...currentStats,
        totalReimbursed: currentStats.totalReimbursed + amount,
        activeCredits: updatedCredits.length
      });
    }
  }

  /**
   * Calcule la date du prochain paiement
   */
  private calculateNextPaymentDate(submissionDate?: string): Date {
    const today = new Date();
    const baseDate = submissionDate ? new Date(submissionDate) : today;
    
    // Pour un crédit de 1 mois, la date d'échéance est 30 jours après
    const nextPayment = new Date(baseDate);
    nextPayment.setDate(nextPayment.getDate() + 30);
    
    return nextPayment;
  }

  /**
   * Obtient le nom lisible d'un type de crédit
   */
  private getCreditTypeName(typeId: string): string {
    const types: {[key: string]: string} = {
      'consommation_generale': 'Crédit Consommation',
      'avance_salaire': 'Avance sur Salaire',
      'depannage': 'Crédit Dépannage',
      'investissement': 'Crédit Investissement',
      'tontine': 'Crédit Tontine',
      'retraite': 'Crédit Retraite',
      'spot': 'Crédit Spot',
      'facture': 'Crédit Facture',
      'bonCommande': 'Crédit Bon de Commande'
    };
    
    return types[typeId] || typeId;
  }

  /**
   * Calcule l'âge à partir d'une date de naissance
   */
  private calculateAge(birthDateStr: string): number {
    const birthDate = new Date(birthDateStr);
    const today = new Date();
    let age = today.getFullYear() - birthDate.getFullYear();
    const monthDiff = today.getMonth() - birthDate.getMonth();
    
    if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birthDate.getDate())) {
      age--;
    }
    
    return age;
  }

  /**
   * Obtient les statistiques du profil actuel
   */
  getProfileStats(): ProfileStats {
    return this.profileStatsSubject.value;
  }

  /**
   * Obtient les crédits actifs
   */
  getActiveCredits(): ActiveCredit[] {
    return this.activeCreditsSubject.value;
  }

  /**
   * Met à jour le niveau de risque
   */
  updateRiskLevel(riskLevel: string): void {
    const currentStats = this.profileStatsSubject.value;
    this.profileStatsSubject.next({
      ...currentStats,
      riskLevel
    });
  }

  /**
   * Récupère l'historique des crédits depuis l'API
   */
  getCreditHistory(): Observable<any[]> {
    const user = this.storageService.getCurrentUser();
    if (!user || !user.id) {
      return of([]);
    }

    return this.http.get<any[]>(`${this.apiUrl}/api/credits/history/${user.id}`).pipe(
      catchError(error => {
        console.error('Erreur lors de la récupération de l\'historique:', error);
        return of([]);
      })
    );
  }

  /**
   * Vérifie l'éligibilité pour un montant donné
   */
  checkEligibility(amount: number): Observable<boolean> {
    const stats = this.getProfileStats();
    return of(amount <= stats.eligibleAmount);
  }
}