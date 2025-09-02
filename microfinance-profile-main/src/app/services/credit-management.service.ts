// credit-management.service.ts
import { Injectable } from '@angular/core';
import { BehaviorSubject, Observable } from 'rxjs';
import { HttpClient } from '@angular/common/http';
import { AuthService, User } from './auth.service';

export interface CreditRecord {
  id: string;
  userId: string;
  username: string;
  type: string;
  amount: number;
  approvedDate: string;
  dueDate: string;
  remainingAmount: number;
  status: 'active' | 'paid' | 'overdue';
  interestRate: number;
  monthlyPayment: number;
  totalAmount: number; // montant total à rembourser
  description: string;
}

export interface CreditRestriction {
  userId: string;
  lastCreditDate: string;
  nextEligibleDate: string;
  activeCreditCount: number;
  totalActiveDebt: number;
  canApplyForCredit: boolean;
  reasonIfBlocked: string;
}

@Injectable({
  providedIn: 'root'
})
export class CreditManagementService {
  private apiUrl = 'http://localhost:5000';
  
  private activeCreditsSubject = new BehaviorSubject<CreditRecord[]>([]);
  public activeCredits$ = this.activeCreditsSubject.asObservable();
  
  private creditRestrictionsSubject = new BehaviorSubject<CreditRestriction | null>(null);
  public creditRestrictions$ = this.creditRestrictionsSubject.asObservable();

  // Configuration des restrictions
  private readonly CREDIT_RESTRICTIONS = {
    MIN_DAYS_BETWEEN_CREDITS: 30, // 30 jours minimum entre deux crédits
    MAX_ACTIVE_CREDITS: 2, // Maximum 2 crédits actifs
    MAX_DEBT_RATIO: 0.7, // Maximum 70% du revenu en dettes
    QUICK_CREDIT_COOLDOWN: 15 // 15 jours pour les crédits rapides
  };

  constructor(
    private http: HttpClient,
    private authService: AuthService
  ) {
    this.authService.currentUser$.subscribe(user => {
      if (user) {
        this.loadActiveCredits(user);
        this.checkCreditRestrictions(user);
      }
    });
  }

  /**
   * Charge les crédits actifs de l'utilisateur
   */
  private loadActiveCredits(user: User): void {
    const storageKey = `activeCredits_${user.username}`;
    const savedCredits = localStorage.getItem(storageKey);
    
    if (savedCredits) {
      try {
        const credits: CreditRecord[] = JSON.parse(savedCredits);
        // Mettre à jour le statut des crédits
        const updatedCredits = credits.map(credit => this.updateCreditStatus(credit));
        this.activeCreditsSubject.next(updatedCredits);
      } catch (error) {
        console.error('Erreur chargement crédits:', error);
        this.activeCreditsSubject.next([]);
      }
    } else {
      this.activeCreditsSubject.next([]);
    }
  }

  /**
   * Vérifie les restrictions de crédit pour l'utilisateur
   */
  private checkCreditRestrictions(user: User): void {
    const activeCredits = this.activeCreditsSubject.value;
    const now = new Date();
    
    // Calculer la dernière date de crédit
    const lastCreditDate = activeCredits.length > 0 
      ? new Date(Math.max(...activeCredits.map(c => new Date(c.approvedDate).getTime())))
      : null;
    
    // Calculer la prochaine date éligible
    const nextEligibleDate = lastCreditDate 
      ? new Date(lastCreditDate.getTime() + (this.CREDIT_RESTRICTIONS.MIN_DAYS_BETWEEN_CREDITS * 24 * 60 * 60 * 1000))
      : now;
    
    // Calculer le total des dettes actives
    const totalActiveDebt = activeCredits
      .filter(c => c.status === 'active')
      .reduce((sum, credit) => sum + credit.remainingAmount, 0);
    
    // Vérifier si peut demander un crédit
    const activeCreditCount = activeCredits.filter(c => c.status === 'active').length;
    const daysSinceLastCredit = lastCreditDate 
      ? Math.floor((now.getTime() - lastCreditDate.getTime()) / (1000 * 60 * 60 * 24))
      : Infinity;
    
    let canApplyForCredit = true;
    let reasonIfBlocked = '';
    
    // Vérifications des restrictions
    if (activeCreditCount >= this.CREDIT_RESTRICTIONS.MAX_ACTIVE_CREDITS) {
      canApplyForCredit = false;
      reasonIfBlocked = `Vous avez déjà ${activeCreditCount} crédit(s) actif(s). Maximum autorisé: ${this.CREDIT_RESTRICTIONS.MAX_ACTIVE_CREDITS}`;
    } else if (daysSinceLastCredit < this.CREDIT_RESTRICTIONS.MIN_DAYS_BETWEEN_CREDITS) {
      canApplyForCredit = false;
      const remainingDays = this.CREDIT_RESTRICTIONS.MIN_DAYS_BETWEEN_CREDITS - daysSinceLastCredit;
      reasonIfBlocked = `Vous devez attendre ${remainingDays} jour(s) avant votre prochaine demande`;
    } else if (user.monthlyIncome && totalActiveDebt > (user.monthlyIncome * this.CREDIT_RESTRICTIONS.MAX_DEBT_RATIO)) {
      canApplyForCredit = false;
      reasonIfBlocked = `Votre ratio d'endettement dépasse ${(this.CREDIT_RESTRICTIONS.MAX_DEBT_RATIO * 100)}% de vos revenus`;
    }
    
    const restrictions: CreditRestriction = {
      userId: user.id?.toString() || '',
      lastCreditDate: lastCreditDate?.toISOString() || '',
      nextEligibleDate: nextEligibleDate.toISOString(),
      activeCreditCount,
      totalActiveDebt,
      canApplyForCredit,
      reasonIfBlocked
    };
    
    this.creditRestrictionsSubject.next(restrictions);
  }

  /**
   * Met à jour le statut d'un crédit
   */
  private updateCreditStatus(credit: CreditRecord): CreditRecord {
    const now = new Date();
    const dueDate = new Date(credit.dueDate);
    
    if (credit.remainingAmount <= 0) {
      credit.status = 'paid';
    } else if (now > dueDate) {
      credit.status = 'overdue';
    } else {
      credit.status = 'active';
    }
    
    return credit;
  }

  /**
   * Enregistre un nouveau crédit rapide
   */
  async approveQuickCredit(creditData: {
    type: string;
    amount: number;
    duration: number;
    frequency: string;
    user: User;
  }): Promise<{ success: boolean; credit?: CreditRecord; error?: string }> {
    try {
      // Vérifier les restrictions
      const restrictions = this.creditRestrictionsSubject.value;
      if (restrictions && !restrictions.canApplyForCredit) {
        return {
          success: false,
          error: restrictions.reasonIfBlocked
        };
      }

      const now = new Date();
      const dueDate = new Date();
      
      // Calculer la date d'échéance selon la fréquence
      if (creditData.frequency === 'fin_du_mois') {
        dueDate.setMonth(dueDate.getMonth() + 1);
        dueDate.setDate(0); // Dernier jour du mois
      } else {
        dueDate.setMonth(dueDate.getMonth() + creditData.duration);
      }

      // Calculer les intérêts et montant total
      const interestRate = this.getInterestRateByType(creditData.type);
      const totalInterest = creditData.amount * interestRate;
      const totalAmount = creditData.amount + totalInterest;
      const monthlyPayment = totalAmount / creditData.duration;

      // Créer l'enregistrement du crédit
      const newCredit: CreditRecord = {
        id: this.generateCreditId(),
        userId: creditData.user.id?.toString() || '',
        username: creditData.user.username || '',
        type: creditData.type,
        amount: creditData.amount,
        approvedDate: now.toISOString(),
        dueDate: dueDate.toISOString(),
        remainingAmount: totalAmount,
        status: 'active',
        interestRate,
        monthlyPayment,
        totalAmount,
        description: this.getCreditTypeDescription(creditData.type)
      };

      // Sauvegarder le crédit
      await this.saveCreditRecord(newCredit, creditData.user);
      
      // Mettre à jour les dettes de l'utilisateur
      await this.updateUserDebts(creditData.user, totalAmount);
      
      // Recalculer le score avec les nouvelles dettes
      await this.updateCreditScore(creditData.user);
      
      // Mettre à jour les restrictions
      this.checkCreditRestrictions(creditData.user);

      return { success: true, credit: newCredit };

    } catch (error) {
      console.error('Erreur approbation crédit:', error);
      return {
        success: false,
        error: 'Erreur lors du traitement de votre demande'
      };
    }
  }

  /**
   * Sauvegarde un enregistrement de crédit
   */
  private async saveCreditRecord(credit: CreditRecord, user: User): Promise<void> {
    const currentCredits = this.activeCreditsSubject.value;
    const updatedCredits = [...currentCredits, credit];
    
    // Sauvegarder localement
    const storageKey = `activeCredits_${user.username}`;
    localStorage.setItem(storageKey, JSON.stringify(updatedCredits));
    
    // Mettre à jour le BehaviorSubject
    this.activeCreditsSubject.next(updatedCredits);
    
    // Envoyer au backend pour enregistrement permanent
    try {
      await this.http.post(`${this.apiUrl}/save-credit-record`, {
        credit,
        username: user.username
      }).toPromise();
    } catch (error) {
      console.warn('Erreur sauvegarde backend crédit:', error);
    }
  }

  /**
   * Met à jour les dettes de l'utilisateur
   */
  private async updateUserDebts(user: User, additionalDebt: number): Promise<void> {
    try {
      const currentDebts = user.existingDebts || 0;
      const newTotalDebts = currentDebts + additionalDebt;
      
      // Mettre à jour localement
      user.existingDebts = newTotalDebts;
      localStorage.setItem('currentUser', JSON.stringify(user));
      
      // Mettre à jour via le service auth
      this.authService.updateUserDebts(newTotalDebts);
      
    } catch (error) {
      console.error('Erreur mise à jour dettes:', error);
    }
  }

  /**
   * Recalcule le score de crédit avec les nouvelles dettes
   */
  private async updateCreditScore(user: User): Promise<void> {
    try {
      const userData = {
        username: user.username,
        monthly_income: user.monthlyIncome || 0,
        employment_status: user.employmentStatus || 'cdi',
        job_seniority: user.jobSeniority || 24,
        existing_debts: user.existingDebts || 0,
        monthly_charges: user.monthlyCharges || 0,
        age: this.calculateAge(user.birthDate) || 35,
        profession: user.profession || '',
        company: user.company || '',
        use_realtime: true
      };
      
      const result = await this.http.post<any>(`${this.apiUrl}/client-scoring`, userData).toPromise();
      
      if (result) {
        // Mettre à jour le score de l'utilisateur
        user.creditScore = result.score;
        user.eligibleAmount = result.eligible_amount;
        user.riskLevel = result.risk_level;
        
        localStorage.setItem('currentUser', JSON.stringify(user));
        this.authService.updateUserScore(result.score, result.eligible_amount, result.risk_level);
      }
      
    } catch (error) {
      console.error('Erreur recalcul score:', error);
    }
  }

  /**
   * Effectue un paiement sur un crédit
   */
  async makePayment(creditId: string, amount: number): Promise<{ success: boolean; message: string }> {
    try {
      const currentCredits = this.activeCreditsSubject.value;
      const creditIndex = currentCredits.findIndex(c => c.id === creditId);
      
      if (creditIndex === -1) {
        return { success: false, message: 'Crédit non trouvé' };
      }
      
      const credit = { ...currentCredits[creditIndex] };
      
      if (amount > credit.remainingAmount) {
        return { success: false, message: 'Montant supérieur au solde restant' };
      }
      
      // Mettre à jour le crédit
      credit.remainingAmount -= amount;
      if (credit.remainingAmount <= 0) {
        credit.status = 'paid';
        credit.remainingAmount = 0;
      }
      
      const updatedCredits = [...currentCredits];
      updatedCredits[creditIndex] = credit;
      
      // Sauvegarder
      const user = this.authService.getCurrentUser();
      if (user) {
        const storageKey = `activeCredits_${user.username}`;
        localStorage.setItem(storageKey, JSON.stringify(updatedCredits));
        
        // Mettre à jour les dettes de l'utilisateur
        await this.updateUserDebts(user, -amount);
        
        // Recalculer le score
        await this.updateCreditScore(user);
        
        // Enregistrer la transaction de paiement
        await this.recordPaymentTransaction(user, credit, amount);
      }
      
      this.activeCreditsSubject.next(updatedCredits);
      this.checkCreditRestrictions(user!);
      
      return { 
        success: true, 
        message: credit.status === 'paid' 
          ? 'Crédit entièrement remboursé !' 
          : `Paiement de ${this.formatCurrency(amount)} effectué`
      };
      
    } catch (error) {
      console.error('Erreur paiement:', error);
      return { success: false, message: 'Erreur lors du paiement' };
    }
  }

  /**
   * Enregistre une transaction de paiement
   */
  private async recordPaymentTransaction(user: User, credit: CreditRecord, amount: number): Promise<void> {
    try {
      const paymentData = {
        username: user.username,
        type: 'payment',
        amount: amount,
        loan_contract_id: credit.id,
        description: `Paiement crédit ${credit.type}`,
        days_late: 0 // Calcul du retard si nécessaire
      };
      
      await this.http.post(`${this.apiUrl}/process-transaction`, paymentData).toPromise();
    } catch (error) {
      console.warn('Erreur enregistrement transaction:', error);
    }
  }

  /**
   * Vérifie si l'utilisateur peut faire une demande de crédit
   */
  canApplyForCredit(): Observable<{ canApply: boolean; reason?: string }> {
    return new Observable(observer => {
      this.creditRestrictions$.subscribe(restrictions => {
        if (!restrictions) {
          observer.next({ canApply: true });
        } else {
          observer.next({
            canApply: restrictions.canApplyForCredit,
            reason: restrictions.reasonIfBlocked
          });
        }
      });
    });
  }

  /**
   * Obtient les crédits actifs
   */
  getActiveCredits(): Observable<CreditRecord[]> {
    return this.activeCredits$;
  }

  /**
   * Obtient les restrictions de crédit
   */
  getCreditRestrictions(): Observable<CreditRestriction | null> {
    return this.creditRestrictions$;
  }

  /**
   * Calcule le ratio d'endettement
   */
  calculateDebtRatio(user: User): number {
    if (!user.monthlyIncome) return 0;
    
    const totalDebts = (user.existingDebts || 0) + (user.monthlyCharges || 0);
    return totalDebts / user.monthlyIncome;
  }

  // Méthodes utilitaires
  private generateCreditId(): string {
    return 'CREDIT-' + Date.now() + '-' + Math.random().toString(36).substr(2, 9);
  }

  private getInterestRateByType(creditType: string): number {
    const rates = {
      'consommation_generale': 0.05,
      'avance_salaire': 0.03,
      'depannage': 0.04,
      'investissement': 0.06,
      'tontine': 0.02,
      'retraite': 0.04
    };
    return rates[creditType as keyof typeof rates] || 0.05;
  }

  private getCreditTypeDescription(creditType: string): string {
    const descriptions = {
      'consommation_generale': 'Crédit Consommation Générale',
      'avance_salaire': 'Avance sur Salaire',
      'depannage': 'Crédit Dépannage',
      'investissement': 'Crédit Investissement',
      'tontine': 'Crédit Tontine',
      'retraite': 'Crédit Retraite'
    };
    return descriptions[creditType as keyof typeof descriptions] || 'Crédit';
  }

  private calculateAge(birthDate?: string): number {
    if (!birthDate) return 35;
    
    const birth = new Date(birthDate);
    const today = new Date();
    let age = today.getFullYear() - birth.getFullYear();
    const monthDiff = today.getMonth() - birth.getMonth();
    
    if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birth.getDate())) {
      age--;
    }
    
    return age;
  }

  private formatCurrency(amount: number): string {
    return new Intl.NumberFormat('fr-FR', {
      style: 'currency',
      currency: 'XAF',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0
    }).format(amount);
  }
}