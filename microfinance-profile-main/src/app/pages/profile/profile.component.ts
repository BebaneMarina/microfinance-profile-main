import { Component, OnInit, OnDestroy, Input, Output, EventEmitter } from '@angular/core';
import { Router } from '@angular/router';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { FormsModule } from '@angular/forms';
import { ClientProfil } from '../../models/client-profile.model';
import { ProfileService, ActiveCredit, ProfileStats } from '../../services/profile.service';
import { StorageService } from '../../services/storage.service';
import { ScoringService } from '../../services/scoring.service';
import { AuthService, User } from '../../services/auth.service';
import { CreditManagementService } from '../../services/credit-management.service'; // Service pour la gestion des dettes
import { Subscription, interval } from 'rxjs';
import { switchMap, catchError } from 'rxjs/operators';
import { HttpClient } from '@angular/common/http';
import { environment } from '../../environments/environment';

interface CreditType {
  id: string;
  name: string;
  icon: string;
  color: string;
  description: string;
  maxAmount: number;
  duration: string;
  available: boolean;
}

interface SavedScore {
  score: number;
  eligibleAmount: number;
  riskLevel: string;
  recommendations: string[];
  scoreDetails?: any;
  lastUpdate: string;
  factors?: any[];
  scoreHistory?: ScoreHistoryEntry[];
}

interface ScoreHistoryEntry {
  score: number;
  date: string;
  change: number;
  reason: string;
}

interface RealTimeScoreUpdate {
  user_id: number;
  score: number;
  previous_score?: number;
  risk_level: string;
  factors: Array<{
    name: string;
    value: number;
    impact: number;
    description: string;
  }>;
  recommendations: string[];
  last_updated: string;
  is_real_time: boolean;
  score_change?: number;
  payment_analysis?: any;
}

// NOUVELLES INTERFACES pour la gestion des dettes et restrictions
interface RegisteredCredit {
  id: string;
  type: string;
  amount: number;
  totalAmount: number;
  remainingAmount: number;
  interestRate: number;
  status: 'active' | 'paid' | 'overdue';
  approvedDate: string;
  dueDate: string;
  nextPaymentDate?: string;
  nextPaymentAmount?: number;
  paymentsHistory: PaymentRecord[];
}

interface PaymentRecord {
  id: string;
  amount: number;
  date: string;
  type: 'partial' | 'full';
  late: boolean;
  daysLate: number;
}

interface CreditRestrictions {
  canApplyForCredit: boolean;
  maxCreditsAllowed: number;
  activeCreditCount: number;
  totalActiveDebt: number;
  debtRatio: number;
  nextEligibleDate?: string;
  lastApplicationDate?: string;
  blockingReason?: string;
  daysUntilNextApplication?: number;
}

interface AccountBalance {
  totalCredited: number;
  totalUsed: number;
  currentBalance: number;
  lastTransaction: string;
  transactions: AccountTransaction[];
}

interface AccountTransaction {
  id: string;
  type: 'credit' | 'debit';
  amount: number;
  description: string;
  date: string;
  balance: number;
}

@Component({
  selector: 'app-profile',
  standalone: true,
  imports: [CommonModule, RouterLink, FormsModule],
  templateUrl: './profile.component.html',
  styleUrls: ['./profile.component.scss']
})
export class ProfileComponent implements OnInit, OnDestroy {
  @Input() client: ClientProfil = {
    name: '',
    fullName: '',
    email: '',
    phone: '',
    address: '',
    profession: '',
    company: '',
    ProfileImage: '',
    monthlyIncome: 0,
    clientId: '',
    profileImage: '',
    clientType: 'particulier',
    username: '',
    employmentStatus: 'cdi',
    jobSeniority: 0,
    id: undefined,
    existingDebts: 0,
    monthlyCharges: 0,
    birthDate: ''
  };
  
  @Output() profileImageChange = new EventEmitter<string>();
  @Output() creditFormOpen = new EventEmitter<void>();

  creditTypes: CreditType[] = [
    {
      id: 'consommation_generale',
      name: 'Crédit Consommation',
      icon: 'shopping_cart',
      color: '#4CAF50',
      description: 'Pour vos besoins personnels (max 2M FCFA)',
      maxAmount: 2000000,
      duration: '1 mois (1 à 3 remboursements)',
      available: true
    },
    {
      id: 'avance_salaire',
      name: 'Avance sur Salaire',
      icon: 'account_balance_wallet',
      color: '#2196F3',
      description: 'Jusqu\'à 70% de votre salaire net',
      maxAmount: 2000000,
      duration: '1 mois (fin du mois)',
      available: true
    },
    {
      id: 'depannage',
      name: 'Crédit Dépannage',
      icon: 'medical_services',
      color: '#FF5722',
      description: 'Solution urgente pour liquidités',
      maxAmount: 2000000,
      duration: '1 mois (remboursement unique)',
      available: true
    },
    {
      id: 'investissement',
      name: 'Crédit Investissement',
      icon: 'trending_up',
      color: '#9C27B0',
      description: 'Pour les entreprises uniquement',
      maxAmount: 100000000,
      duration: 'Jusqu\'à 36 mois',
      available: false
    },
    {
      id: 'tontine',
      name: 'Crédit Tontine',
      icon: 'groups',
      color: '#FF9800',
      description: 'Réservé aux membres cotisants',
      maxAmount: 5000000,
      duration: 'Variable',
      available: false
    },
    {
      id: 'retraite',
      name: 'Crédit Retraite',
      icon: 'elderly',
      color: '#607D8B',
      description: 'Pour les retraités CNSS/CPPF',
      maxAmount: 2000000,
      duration: '12 mois max',
      available: false
    }
  ];

  // DONNÉES EXISTANTES
  activeCredits: ActiveCredit[] = [];
  globalStats: ProfileStats = {
    totalBorrowed: 0,
    totalReimbursed: 0,
    activeCredits: 0,
    creditScore: 0,
    eligibleAmount: 0,
    totalApplications: 0,
    approvedApplications: 0,
    riskLevel: 'medium'
  };

  // NOUVELLES DONNÉES pour la gestion des dettes
  activeCreditsFromService: RegisteredCredit[] = [];
  creditRestrictions: CreditRestrictions = {
    canApplyForCredit: true,
    maxCreditsAllowed: 2,
    activeCreditCount: 0,
    totalActiveDebt: 0,
    debtRatio: 0
  };
  showActiveCreditsModal!: boolean;
  
  // PROPRIÉTÉS CALCULÉES
  get canApplyForCredit(): boolean {
    return this.creditRestrictions?.canApplyForCredit ?? true;
  }
  
  get creditBlockReason(): string {
    return this.creditRestrictions?.blockingReason || 'Restrictions actives';
  }

  isLoading = false;
  hasError = false;
  errorMessage = '';

  showQuickCreditModal = false;

  isSubmitting = false;
  quickCredit = {
    type: 'consommation_generale',
    amount: 0,
    duration: 1,
    frequency: 'mensuel'
  };

  // GESTION DU SOLDE
  accountBalance: AccountBalance = {
    totalCredited: 0,
    totalUsed: 0,
    currentBalance: 0,
    lastTransaction: '',
    transactions: []
  };

  showAccountDetails = false;
  showCustomAmountModal = false;
  customAmount: number = 0;
  customDescription: string = '';

  Math = Math;
  currentDate: string = new Date().toISOString();
  currentUser: User | null = null;
  savedScore: SavedScore | null = null;

  // SCORING TEMPS RÉEL
  realTimeScore: RealTimeScoreUpdate | null = null;
  isScoreUpdating = false;
  scoreChangeAnimation = false;
  previousScore = 0;
  showScoreHistory = false;
  scoreHistory: ScoreHistoryEntry[] = [];
  realTimeSubscription?: Subscription;
  paymentAnalysis: any = null;
  
  private apiUrl = environment.apiUrl || 'http://localhost:5000';
  private creditsSubscription?: Subscription;
  private statsSubscription?: Subscription;
  private storageSubscription?: Subscription;
  private authSubscription?: Subscription;

  constructor(
    private router: Router,
    private profileService: ProfileService,
    private storageService: StorageService,
    private scoringService: ScoringService,
    private authService: AuthService,
    private http: HttpClient,
    public creditManagementService: CreditManagementService // Service injecté
  ) {}

  ngOnInit(): void {
    this.isLoading = true;
    
    this.authSubscription = this.authService.currentUser$.subscribe((user: any) => {
      if (user) {
        this.currentUser = user;
        this.loadUserProfile(user);
        this.loadUserScore(user);
        this.loadAccountBalance();
        
        // NOUVEAU : Charger les crédits enregistrés et restrictions
        this.loadRegisteredCredits();
        this.loadCreditRestrictions();
        
        this.startRealTimeScoreMonitoring(user.id);
      } else {
        this.router.navigate(['/login']);
      }
    });

    // Abonnements existants conservés
    this.creditsSubscription = this.profileService.activeCredits$.subscribe(
      credits => {
        this.activeCredits = credits;
        this.isLoading = false;
      },
      error => {
        this.handleError('Erreur lors du chargement des crédits actifs', error);
      }
    );

    this.statsSubscription = this.profileService.profileStats$.subscribe(
      stats => {
        if (this.currentUser) {
          this.globalStats = {
            ...stats,
            creditScore: this.realTimeScore?.score || this.currentUser.creditScore || stats.creditScore || 0,
            eligibleAmount: this.currentUser.eligibleAmount || stats.eligibleAmount || 0,
            riskLevel: this.realTimeScore?.risk_level || this.currentUser.riskLevel || stats.riskLevel || 'medium'
          };
        } else {
          this.globalStats = stats;
        }
        
        if (this.client?.clientType !== 'entreprise') {
          this.globalStats.eligibleAmount = Math.min(this.globalStats.eligibleAmount, 2000000);
        }
      },
      error => {
        this.handleError('Erreur lors du chargement des statistiques', error);
      }
    );

    this.storageSubscription = this.storageService.applications$.subscribe(() => {
      this.profileService.refreshData();
    });

    this.checkEligibility();
  }

  ngOnDestroy(): void {
    this.creditsSubscription?.unsubscribe();
    this.statsSubscription?.unsubscribe();
    this.storageSubscription?.unsubscribe();
    this.authSubscription?.unsubscribe();
    this.realTimeSubscription?.unsubscribe();
  }

  // ========================================
  // NOUVELLES MÉTHODES - GESTION DES DETTES ET RESTRICTIONS
  // ========================================

  private loadRegisteredCredits(): void {
    if (!this.currentUser?.username) return;
    
    this.http.get<RegisteredCredit[]>(`${this.apiUrl}/user-credits/${this.currentUser.username}`)
      .subscribe({
        next: (credits) => {
          this.activeCreditsFromService = credits;
          this.updateDebtCalculations();
          console.log('✅ Crédits enregistrés chargés:', credits.length);
        },
        error: (error) => {
          console.error('❌ Erreur chargement crédits:', error);
          // Charger depuis le localStorage en fallback
          this.loadCreditsFromStorage();
        }
      });
  }

  private loadCreditsFromStorage(): void {
    try {
      const storageKey = `user_credits_${this.currentUser?.username}`;
      const savedCredits = localStorage.getItem(storageKey);
      
      if (savedCredits) {
        this.activeCreditsFromService = JSON.parse(savedCredits);
        this.updateDebtCalculations();
        console.log('📁 Crédits chargés depuis localStorage:', this.activeCreditsFromService.length);
      }
    } catch (error) {
      console.error('❌ Erreur chargement localStorage:', error);
      this.activeCreditsFromService = [];
    }
  }

  private saveCreditsToStorage(): void {
    try {
      const storageKey = `user_credits_${this.currentUser?.username}`;
      localStorage.setItem(storageKey, JSON.stringify(this.activeCreditsFromService));
      console.log('💾 Crédits sauvegardés en local');
    } catch (error) {
      console.error('❌ Erreur sauvegarde localStorage:', error);
    }
  }

  private loadCreditRestrictions(): void {
    if (!this.currentUser?.username) return;
    
    this.http.get<CreditRestrictions>(`${this.apiUrl}/credit-restrictions/${this.currentUser.username}`)
      .subscribe({
        next: (restrictions) => {
          this.creditRestrictions = restrictions;
          console.log('🔒 Restrictions chargées:', restrictions);
        },
        error: (error) => {
          console.error('❌ Erreur chargement restrictions:', error);
          this.calculateLocalRestrictions();
        }
      });
  }

  private calculateLocalRestrictions(): void {
    const activeCredits = this.activeCreditsFromService.filter(c => c.status === 'active');
    const totalDebt = activeCredits.reduce((sum, credit) => sum + credit.remainingAmount, 0);
    const monthlyIncome = this.currentUser?.monthlyIncome || 1;
    const debtRatio = totalDebt / monthlyIncome;
    
    // Vérifier la dernière demande
    const lastApplicationKey = `last_application_${this.currentUser?.username}`;
    const lastApplicationDate = localStorage.getItem(lastApplicationKey);
    const daysSinceLastApplication = lastApplicationDate ? 
      Math.floor((Date.now() - new Date(lastApplicationDate).getTime()) / (1000 * 60 * 60 * 24)) : 30;
    
    let canApply = true;
    let blockingReason = '';
    let nextEligibleDate = undefined;
    
    // Règle 1: Maximum 2 crédits actifs
    if (activeCredits.length >= 2) {
      canApply = false;
      blockingReason = 'Maximum 2 crédits actifs atteint';
    }
    
    // Règle 2: Ratio d'endettement maximum 70%
    else if (debtRatio > 0.7) {
      canApply = false;
      blockingReason = `Ratio d'endettement trop élevé (${(debtRatio * 100).toFixed(1)}%)`;
    }
    
    // Règle 3: Délai minimum de 30 jours entre demandes
    else if (daysSinceLastApplication < 30) {
      canApply = false;
      const remainingDays = 30 - daysSinceLastApplication;
      blockingReason = `Délai d'attente: ${remainingDays} jour(s) restant(s)`;
      
      const nextDate = new Date();
      nextDate.setDate(nextDate.getDate() + remainingDays);
      nextEligibleDate = nextDate.toISOString();
    }
    
    this.creditRestrictions = {
      canApplyForCredit: canApply,
      maxCreditsAllowed: 2,
      activeCreditCount: activeCredits.length,
      totalActiveDebt: totalDebt,
      debtRatio: debtRatio,
      nextEligibleDate: nextEligibleDate,
      lastApplicationDate: lastApplicationDate || undefined,
      blockingReason: blockingReason,
      daysUntilNextApplication: canApply ? 0 : (30 - daysSinceLastApplication)
    };
    
    console.log('🔒 Restrictions calculées localement:', this.creditRestrictions);
  }

  private updateDebtCalculations(): void {
    // Mettre à jour les dettes du client
    const totalActiveDebt = this.activeCreditsFromService
      .filter(c => c.status === 'active')
      .reduce((sum, credit) => sum + credit.remainingAmount, 0);
    
    if (this.client) {
      this.client.existingDebts = totalActiveDebt;
      this.saveClientData();
    }
    
    // Recalculer les restrictions
    this.calculateLocalRestrictions();
    
    // Mettre à jour le score si nécessaire
    if (totalActiveDebt !== this.creditRestrictions.totalActiveDebt) {
      this.refreshCreditScore();
    }
  }

  // ========================================
  // MÉTHODES PRINCIPALES DU HTML
  // ========================================

  /**
   * Ouvre le modal des crédits actifs
   */
  openActiveCreditsModal(): void {
  this.showActiveCreditsModal = true;
}

  /**
   * Ferme le modal des crédits actifs
   */
  closeActiveCreditsModal(): void {
    this.showActiveCreditsModal = false;
  }

  /**
   * Obtient le nom du type de crédit
   */
  getCreditTypeName(creditTypeId: string): string {
    const creditType = this.creditTypes.find(type => type.id === creditTypeId);
    return creditType ? creditType.name : 'Crédit';
  }

  /**
   * Obtient le texte du statut de crédit
   */
  getCreditStatusText(status: string): string {
    const statusMap: Record<string, string> = {
      'active': 'Actif',
      'paid': 'Remboursé',
      'overdue': 'En retard'
    };
    return statusMap[status] || status;
  }

  /**
   * Effectue un paiement sur un crédit
   */
  makePayment(creditId: string): void {
    const credit = this.activeCreditsFromService.find(c => c.id === creditId);
    if (!credit || credit.status !== 'active') {
      this.showNotification('Crédit non trouvé ou déjà remboursé', 'error');
      return;
    }

    const paymentAmount = Math.min(50000, credit.remainingAmount); // Paiement partiel de 50k ou le solde restant
    
    if (confirm(`Confirmer le paiement de ${this.formatCurrency(paymentAmount)} pour le crédit ${this.getCreditTypeName(credit.type)} ?`)) {
      this.processPayment(creditId, paymentAmount);
    }
  }

  /**
   * Simule l'impact d'un paiement
   */
  simulatePayment(creditId: string): void {
    // Simulation simple d'impact de paiement
    const credit = this.activeCreditsFromService.find(c => c.id === creditId);
    if (!credit) return;
    
    const currentScore = this.getCurrentScore();
    const estimatedImprovement = credit.remainingAmount > 100000 ? 0.2 : 0.1;
    const estimatedNewScore = Math.min(10, currentScore + estimatedImprovement);
    
    this.showNotification(
      `💡 Simulation: Rembourser ce crédit améliorerait votre score de ${currentScore.toFixed(1)} à ${estimatedNewScore.toFixed(1)} (+${estimatedImprovement.toFixed(1)})`,
      'info'
    );
  }

  /**
   * Traite un paiement
   */
  private processPayment(creditId: string, amount: number): void {
    const creditIndex = this.activeCreditsFromService.findIndex(c => c.id === creditId);
    if (creditIndex === -1) return;

    const credit = this.activeCreditsFromService[creditIndex];
    const isFullPayment = amount >= credit.remainingAmount;
    
    // Créer l'enregistrement de paiement
    const payment: PaymentRecord = {
      id: this.generatePaymentId(),
      amount: amount,
      date: new Date().toISOString(),
      type: isFullPayment ? 'full' : 'partial',
      late: false, // Simplification: on considère tous les paiements à temps
      daysLate: 0
    };
    
    // Mettre à jour le crédit
    credit.remainingAmount = Math.max(0, credit.remainingAmount - amount);
    credit.paymentsHistory.push(payment);
    
    if (credit.remainingAmount === 0) {
      credit.status = 'paid';
    }
    
    this.activeCreditsFromService[creditIndex] = credit;
    this.saveCreditsToStorage();
    
    // Envoyer au serveur
    const paymentData = {
      username: this.currentUser?.username,
      credit_id: creditId,
      payment: payment,
      remaining_amount: credit.remainingAmount,
      credit_status: credit.status
    };
    
    this.http.post(`${this.apiUrl}/process-payment`, paymentData)
      .subscribe({
        next: (response: any) => {
          console.log('✅ Paiement traité:', response);
          
          if (response.score_impact) {
            this.showScoreChangeNotification(
              response.score_impact.previous_score,
              response.score_impact.new_score,
              {
                recommendations: ['Paiement effectué avec succès'],
                user_id: 0,
                score: response.score_impact.new_score,
                risk_level: response.score_impact.risk_level || 'moyen',
                factors: [],
                last_updated: new Date().toISOString(),
                is_real_time: true
              }
            );
          }
        },
        error: (error) => {
          console.error('❌ Erreur traitement paiement serveur:', error);
        }
      });
    
    // Mettre à jour localement
    this.updateDebtCalculations();
    
    // Notification
    if (isFullPayment) {
      this.showNotification(`✅ Crédit intégralement remboursé ! Votre score va s'améliorer.`, 'success');
    } else {
      this.showNotification(`✅ Paiement de ${this.formatCurrency(amount)} effectué. Restant: ${this.formatCurrency(credit.remainingAmount)}`, 'success');
    }
  }

  /**
   * Génère un ID de paiement unique
   */
  private generatePaymentId(): string {
    return `PAY_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
  }

  // ========================================
  // MÉTHODE PRINCIPALE - CRÉDIT RAPIDE AMÉLIORÉ
  // ========================================

  /**
   * Soumet une demande de crédit rapide
   */
  submitQuickCredit(): void {
    if (this.isSubmitting) return;
    
    // Vérifications préliminaires
    if (!this.canApplyForCredit) {
      this.showNotification(this.creditBlockReason, 'error');
      return;
    }
    
    if (this.quickCredit.amount > this.globalStats.eligibleAmount) {
      this.showNotification(`Le montant demandé (${this.formatCurrency(this.quickCredit.amount)}) dépasse votre montant éligible (${this.formatCurrency(this.globalStats.eligibleAmount)})`, 'error');
      return;
    }
    
    if (this.quickCredit.amount < 10000) {
      this.showNotification('Le montant minimum est de 10 000 FCFA', 'error');
      return;
    }

    this.isSubmitting = true;
    
    // Calculer les détails du crédit
    const interestRate = this.getCreditInterestRate(this.quickCredit.type);
    const processingFee = Math.round(this.quickCredit.amount * 0.015);
    const totalAmount = this.quickCredit.amount + processingFee;
    
    // Créer l'objet crédit
    const newCredit: RegisteredCredit = {
      id: this.generateCreditId(),
      type: this.quickCredit.type,
      amount: this.quickCredit.amount,
      totalAmount: totalAmount,
      remainingAmount: totalAmount,
      interestRate: interestRate,
      status: 'active',
      approvedDate: new Date().toISOString(),
      dueDate: this.calculateDueDate(this.quickCredit.type),
      paymentsHistory: []
    };
    
    // Préparer les données pour l'API
    const creditData = {
      username: this.currentUser?.username,
      credit: newCredit,
      client_data: {
        name: this.client?.name || '',
        email: this.client?.email || '',
        phone: this.client?.phone || '',
        monthly_income: this.client?.monthlyIncome || 0,
        existing_debts: this.client?.existingDebts || 0
      }
    };

    // Envoyer au serveur
    this.http.post<any>(`${this.apiUrl}/register-credit`, creditData)
      .subscribe({
        next: (response) => {
          console.log('✅ Crédit enregistré sur le serveur:', response);
          
          // Traitement local immédiat
          this.processLocalCredit(newCredit);
          
          this.isSubmitting = false;
          this.showQuickCreditModal = false;
          
          // Notification de succès
          this.showCreditNotification(
            this.quickCredit.amount, 
            processingFee, 
            totalAmount,
            response.updated_score
          );
        },
        error: (error) => {
          console.error('❌ Erreur serveur, traitement local:', error);
          
          // Fallback: traitement local
          this.processLocalCredit(newCredit);
          
          this.isSubmitting = false;
          this.showQuickCreditModal = false;
          
          this.showCreditNotification(
            this.quickCredit.amount, 
            processingFee, 
            totalAmount
          );
        }
      });
  }

  /**
   * Traite un crédit localement
   */
  private processLocalCredit(newCredit: RegisteredCredit): void {
    // 1. Ajouter le crédit à la liste
    this.activeCreditsFromService.push(newCredit);
    this.saveCreditsToStorage();
    
    // 2. Créditer le compte
    this.addTransaction('credit', newCredit.amount, `Crédit ${this.getCreditTypeName(newCredit.type)} approuvé`);
    
    // 3. Enregistrer la date de demande
    const applicationKey = `last_application_${this.currentUser?.username}`;
    localStorage.setItem(applicationKey, new Date().toISOString());
    
    // 4. Mettre à jour les calculs de dettes
    this.updateDebtCalculations();
    
    // 5. Actualiser les données du profil
    this.profileService.refreshData();
    
    console.log('✅ Crédit traité localement:', newCredit);
  }

  /**
   * Génère un ID de crédit unique
   */
  private generateCreditId(): string {
    const timestamp = Date.now();
    const random = Math.floor(Math.random() * 1000);
    return `CREDIT_${timestamp}_${random}`;
  }

  /**
   * Obtient le taux d'intérêt pour un type de crédit
   */
  private getCreditInterestRate(creditType: string): number {
    const rates: Record<string, number> = {
      'consommation_generale': 0.05,
      'avance_salaire': 0.03,
      'depannage': 0.04,
      'investissement': 0.08,
      'tontine': 0.06,
      'retraite': 0.04
    };
    return rates[creditType] || 0.05;
  }

  /**
   * Calcule la date d'échéance d'un crédit
   */
  private calculateDueDate(creditType: string): string {
    const dueDate = new Date();
    
    switch (creditType) {
      case 'avance_salaire':
        // Fin du mois suivant
        dueDate.setMonth(dueDate.getMonth() + 1);
        dueDate.setDate(new Date(dueDate.getFullYear(), dueDate.getMonth() + 1, 0).getDate());
        break;
      case 'depannage':
        // 30 jours
        dueDate.setDate(dueDate.getDate() + 30);
        break;
      case 'consommation_generale':
        // 45 jours
        dueDate.setDate(dueDate.getDate() + 45);
        break;
      default:
        // 30 jours par défaut
        dueDate.setDate(dueDate.getDate() + 30);
    }
    
    return dueDate.toISOString();
  }

  /**
   * Définit le montant du crédit rapide en pourcentage
   */
  setQuickCreditAmount(percentage: number): void {
    this.quickCredit.amount = Math.round(this.globalStats.eligibleAmount * percentage);
  }


  /**
   * Obtient les types de crédit disponibles
   */
  getAvailableCreditTypes(): CreditType[] {
    return this.creditTypes.filter(type => type.available);
  }

  // ========================================
  // MÉTHODES DE GESTION DU SOLDE EXISTANTES CONSERVÉES
  // ========================================

  /**
   * Charge le solde du compte depuis le localStorage
   */
  private loadAccountBalance(): void {
    const savedBalance = localStorage.getItem(`accountBalance_${this.currentUser?.username}`);
    if (savedBalance) {
      this.accountBalance = JSON.parse(savedBalance);
    } else {
      this.accountBalance = {
        totalCredited: 0,
        totalUsed: 0,
        currentBalance: 0,
        lastTransaction: '',
        transactions: []
      };
      this.saveAccountBalance();
    }
  }

  /**
   * Sauvegarde le solde du compte
   */
  private saveAccountBalance(): void {
    localStorage.setItem(`accountBalance_${this.currentUser?.username}`, JSON.stringify(this.accountBalance));
  }

  /**
   * Ajoute une transaction au compte
   */
  private addTransaction(type: 'credit' | 'debit', amount: number, description: string): void {
    const transaction: AccountTransaction = {
      id: Date.now().toString(),
      type: type,
      amount: amount,
      description: description,
      date: new Date().toISOString(),
      balance: type === 'credit' ? this.accountBalance.currentBalance + amount : this.accountBalance.currentBalance - amount
    };

    if (type === 'credit') {
      this.accountBalance.totalCredited += amount;
      this.accountBalance.currentBalance += amount;
    } else {
      this.accountBalance.totalUsed += amount;
      this.accountBalance.currentBalance -= amount;
    }

    this.accountBalance.lastTransaction = transaction.date;
    this.accountBalance.transactions.unshift(transaction);

    if (this.accountBalance.transactions.length > 50) {
      this.accountBalance.transactions = this.accountBalance.transactions.slice(0, 50);
    }

    this.saveAccountBalance();
  }

  /**
   * Active/désactive l'affichage des détails du compte
   */
  toggleAccountDetails(): void {
    this.showAccountDetails = !this.showAccountDetails;
  }

  /**
   * Utilise du crédit du compte
   */
  useCredit(amount: number, description: string = 'Utilisation du crédit'): void {
    if (amount > this.accountBalance.currentBalance) {
      this.showNotification(`Solde insuffisant. Solde actuel: ${this.formatCurrency(this.accountBalance.currentBalance)}`, 'error');
      return;
    }

    if (amount <= 0) {
      this.showNotification('Le montant doit être supérieur à 0', 'error');
      return;
    }

    this.addTransaction('debit', amount, description);
    this.showNotification(`${this.formatCurrency(amount)} débité de votre compte. Solde restant: ${this.formatCurrency(this.accountBalance.currentBalance)}`, 'success');
  }

  /**
   * Ouvre le modal pour montant personnalisé
   */
  openCustomAmountModal(): void {
    this.customAmount = 0;
    this.customDescription = '';
    this.showCustomAmountModal = true;
  }

  /**
   * Ferme le modal pour montant personnalisé
   */
  closeCustomAmountModal(): void {
    this.showCustomAmountModal = false;
    this.customAmount = 0;
    this.customDescription = '';
  }

  /**
   * Utilise un montant personnalisé
   */
  useCustomAmount(): void {
    if (!this.customAmount || this.customAmount <= 0) {
      this.showNotification('Veuillez saisir un montant valide', 'error');
      return;
    }

    if (this.customAmount > this.accountBalance.currentBalance) {
      this.showNotification(`Solde insuffisant. Solde actuel: ${this.formatCurrency(this.accountBalance.currentBalance)}`, 'error');
      return;
    }

    const description = this.customDescription || `Utilisation personnalisée de ${this.formatCurrency(this.customAmount)}`;
    
    this.useCredit(this.customAmount, description);
    this.closeCustomAmountModal();
  }

  /**
   * Filtre les transactions par type
   */
  filterTransactions(transactions: AccountTransaction[], type: string): AccountTransaction[] {
    if (!transactions) return [];
    return transactions.filter(transaction => transaction.type === type);
  }

  /**
   * Formate la date d'une transaction
   */
  formatTransactionDate(dateString: string): string {
    const date = new Date(dateString);
    return date.toLocaleDateString('fr-FR', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  }

  /**
   * Obtient l'icône d'une transaction
   */
  getTransactionIcon(type: 'credit' | 'debit'): string {
    return type === 'credit' ? 'add_circle' : 'remove_circle';
  }

  /**
   * Obtient la couleur d'une transaction
   */
  getTransactionColor(type: 'credit' | 'debit'): string {
    return type === 'credit' ? '#4CAF50' : '#F44336';
  }

  /**
   * Calcule le temps écoulé depuis une date
   */
  getTimeAgo(dateString: string): string {
    const date = new Date(dateString);
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffMinutes = Math.floor(diffMs / (1000 * 60));
    
    if (diffMinutes < 1) return 'à l\'instant';
    if (diffMinutes < 60) return `il y a ${diffMinutes} min`;
    
    const diffHours = Math.floor(diffMinutes / 60);
    if (diffHours < 24) return `il y a ${diffHours}h`;
    
    const diffDays = Math.floor(diffHours / 24);
    return `il y a ${diffDays} jour${diffDays > 1 ? 's' : ''}`;
  }

  // ========================================
  // MÉTHODES DE SCORING TEMPS RÉEL
  // ========================================

  /**
   * Démarre le monitoring du score en temps réel
   */
  private startRealTimeScoreMonitoring(userId: number): void {
    console.log('🔄 Démarrage monitoring score temps réel pour:', userId);
    
    this.realTimeSubscription = interval(30000).pipe(
      switchMap(() => this.getRealTimeScore(userId)),
      catchError(error => {
        console.error('❌ Erreur monitoring temps réel:', error);
        return [];
      })
    ).subscribe((scoreUpdate: RealTimeScoreUpdate) => {
      if (scoreUpdate) {
        this.handleRealTimeScoreUpdate(scoreUpdate);
      }
    });

    this.getRealTimeScore(userId).subscribe((scoreUpdate: RealTimeScoreUpdate) => {
      if (scoreUpdate) {
        this.handleRealTimeScoreUpdate(scoreUpdate);
      }
    });
  }

  /**
   * Obtient le score en temps réel
   */
  private getRealTimeScore(userId: number) {
    const userData = {
      username: this.currentUser?.username || 'user_' + userId,
      monthly_income: this.client?.monthlyIncome || 0,
      employment_status: this.client?.employmentStatus || 'cdi',
      job_seniority: this.client?.jobSeniority || 24,
      existing_debts: this.client?.existingDebts || 0,
      monthly_charges: this.client?.monthlyCharges || 0,
      age: this.calculateAge() || 35,
      profession: this.client?.profession || '',
      company: this.client?.company || '',
      // NOUVEAU: Inclure les crédits actifs dans le calcul
      active_credits: this.activeCreditsFromService.filter(c => c.status === 'active').map(credit => ({
        amount: credit.amount,
        remaining: credit.remainingAmount,
        type: credit.type,
        approved_date: credit.approvedDate
      }))
    };
    
    return this.http.post<RealTimeScoreUpdate>(`${this.apiUrl}/realtime-scoring`, userData);
  }

  /**
   * Calcule l'âge du client
   */
  private calculateAge(): number {
    if (!this.client?.birthDate) return 35;
    
    const birthDate = new Date(this.client.birthDate);
    const today = new Date();
    let age = today.getFullYear() - birthDate.getFullYear();
    const monthDiff = today.getMonth() - birthDate.getMonth();
    
    if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birthDate.getDate())) {
      age--;
    }
    
    return age;
  }

  /**
   * Gère la mise à jour du score en temps réel
   */
  private handleRealTimeScoreUpdate(scoreUpdate: RealTimeScoreUpdate): void {
    const previousScore = this.realTimeScore?.score || this.globalStats.creditScore || 0;
    const newScore = scoreUpdate.score;
    
    console.log('📊 Mise à jour score temps réel:', {
      previous: previousScore,
      new: newScore,
      change: newScore - previousScore,
      analysis: scoreUpdate.payment_analysis
    });

    if (scoreUpdate.payment_analysis) {
      this.paymentAnalysis = scoreUpdate.payment_analysis;
    }

    if (Math.abs(newScore - previousScore) >= 0.1) {
      this.animateScoreChange(previousScore, newScore);
      this.showScoreChangeNotification(previousScore, newScore, scoreUpdate);
    }

    this.realTimeScore = scoreUpdate;
    this.globalStats.creditScore = newScore;
    this.globalStats.riskLevel = scoreUpdate.risk_level;
    
    this.savedScore = {
      score: newScore,
      eligibleAmount: this.globalStats.eligibleAmount,
      riskLevel: scoreUpdate.risk_level,
      recommendations: scoreUpdate.recommendations,
      lastUpdate: scoreUpdate.last_updated,
      factors: scoreUpdate.factors,
      scoreHistory: this.scoreHistory
    };

    this.checkEligibility();
    this.loadScoreHistory();
  }

  /**
   * Anime le changement de score
   */
  private animateScoreChange(oldScore: number, newScore: number): void {
    this.scoreChangeAnimation = true;
    this.previousScore = oldScore;
    
    const scoreElement = document.querySelector('.score-number');
    if (scoreElement) {
      scoreElement.classList.add('score-updating');
      
      setTimeout(() => {
        scoreElement.classList.remove('score-updating');
        this.scoreChangeAnimation = false;
      }, 1000);
    }
  }

  /**
   * Affiche une notification de changement de score
   */
  private showScoreChangeNotification(oldScore: number, newScore: number, scoreUpdate: RealTimeScoreUpdate): void {
    const change = newScore - oldScore;
    const isPositive = change > 0;
    const trend = scoreUpdate.payment_analysis?.trend || 'stable';
    
    let trendIcon = 'trending_flat';
    let trendText = 'Stable';
    
    if (trend === 'improving') {
      trendIcon = 'trending_up';
      trendText = 'En amélioration';
    } else if (trend === 'declining') {
      trendIcon = 'trending_down';
      trendText = 'En baisse';
    }
    
    const notification = document.createElement('div');
    notification.className = `score-change-notification ${isPositive ? 'positive' : 'negative'}`;
    notification.innerHTML = `
      <div style="position: fixed; top: 100px; right: 20px; max-width: 350px; 
                  background: ${isPositive ? '#4CAF50' : '#f44336'}; color: white; 
                  border-radius: 8px; padding: 16px; z-index: 1001; 
                  box-shadow: 0 4px 12px rgba(0,0,0,0.2);
                  animation: slideInRight 0.3s ease-out;">
        <div style="display: flex; align-items: center; gap: 12px;">
          <i class="material-icons" style="font-size: 24px;">
            ${isPositive ? 'trending_up' : 'trending_down'}
          </i>
          <div>
            <h4 style="margin: 0; font-size: 16px;">Score Mis à Jour</h4>
            <p style="margin: 5px 0 0 0; font-size: 14px;">
              ${oldScore.toFixed(1)} → ${newScore.toFixed(1)} 
              (${isPositive ? '+' : ''}${change.toFixed(1)})
            </p>
            <p style="margin: 5px 0 0 0; font-size: 12px; display: flex; align-items: center; gap: 4px;">
              <i class="material-icons" style="font-size: 16px;">${trendIcon}</i>
              ${trendText}
            </p>
            ${scoreUpdate.recommendations && scoreUpdate.recommendations.length > 0 ? 
              `<p style="margin: 5px 0 0 0; font-size: 12px; opacity: 0.9;">
                ${scoreUpdate.recommendations[0]}
              </p>` : ''
            }
          </div>
          <button onclick="this.parentElement.parentElement.remove()" 
                  style="background: none; border: none; color: white; 
                         font-size: 18px; cursor: pointer; opacity: 0.8;">×</button>
        </div>
      </div>
    `;
    
    document.body.appendChild(notification);
    
    setTimeout(() => {
      if (notification.parentNode) {
        notification.style.animation = 'slideOutRight 0.3s ease-in';
        setTimeout(() => notification.remove(), 300);
      }
    }, 5000);
  }

  /**
   * Charge l'historique des scores
   */
  private loadScoreHistory(): void {
    if (!this.currentUser?.username) return;
    this.http.get<any>(`${this.apiUrl}/score-trend/${this.currentUser.username}`)
      .subscribe({
        next: (response) => {
          this.scoreHistory = response.recent_transactions?.map((t: any) => ({
            score: 6.5,
            date: t.date,
            change: 0.1,
            reason: t.description || 'Activité automatique'
          })) || [];
          console.log('📈 Historique des scores chargé:', this.scoreHistory.length, 'entrées');
        },
        error: (error) => {
          console.error('❌ Erreur chargement historique:', error);
        }
      });
  }

  /**
   * Obtient le score actuel
   */
  getCurrentScore(): number {
    return this.realTimeScore?.score || this.globalStats.creditScore || 0;
  }

  /**
   * Obtient le changement de score
   */
  getScoreChange(): number {
    if (!this.realTimeScore?.score_change) return 0;
    return this.realTimeScore.score_change;
  }

  /**
   * Vérifie si le score est en temps réel
   */
  isScoreRealTime(): boolean {
    return this.realTimeScore?.is_real_time || false;
  }

  /**
   * Obtient la dernière mise à jour du score
   */
  getLastScoreUpdate(): string {
    if (!this.realTimeScore?.last_updated) return '';
    return this.getTimeAgo(this.realTimeScore.last_updated);
  }

  /**
   * Actualise le score de crédit
   */
  refreshCreditScore(): void {
    if (!this.currentUser || this.currentUser.username === undefined) {
        this.showNotification('Utilisateur non connecté ou username manquant', 'error');
        return;
    }

    this.isScoreUpdating = true;
    
    const refreshBtn = document.querySelector('.refresh-btn i');
    if (refreshBtn) {
        refreshBtn.classList.add('rotating');
    }
    
    console.log('🔄 Actualisation du score pour:', this.currentUser.name);
    
    const userData = {
      username: this.currentUser.username,
      name: this.currentUser.name || this.currentUser.fullName,
      email: this.currentUser.email,
      phone: this.currentUser.phone,
      monthly_income: this.client?.monthlyIncome || 0,
      employment_status: this.client?.employmentStatus || 'cdi',
      job_seniority: this.client?.jobSeniority || 24,
      profession: this.client?.profession || '',
      company: this.client?.company || '',
      existing_debts: this.client?.existingDebts || 0,
      monthly_charges: this.client?.monthlyCharges || 0,
      use_realtime: true,
      // NOUVEAU: Inclure les crédits actifs
      active_credits: this.activeCreditsFromService.filter(c => c.status === 'active').map(credit => ({
        amount: credit.amount,
        remaining: credit.remainingAmount,
        type: credit.type,
        approved_date: credit.approvedDate
      }))
    };
    
    this.http.post<any>(`${this.apiUrl}/client-scoring`, userData).subscribe({
        next: (result: any) => {
            console.log('✅ Score actualisé:', result);
            
            const adaptedResult: RealTimeScoreUpdate = {
              user_id: this.currentUser?.id || 0,
              score: result.score,
              previous_score: result.previous_score,
              risk_level: result.risk_level,
              factors: result.factors || [],
              recommendations: result.recommendations || [],
              last_updated: result.calculation_date || new Date().toISOString(),
              is_real_time: result.is_realtime || false,
              score_change: result.score_change || 0,
              payment_analysis: result.payment_analysis
            };
            
            this.handleRealTimeScoreUpdate(adaptedResult);
            this.checkEligibility();
            
            this.showNotification('Score de crédit actualisé !', 'success');
            
            if (refreshBtn) {
                refreshBtn.classList.remove('rotating');
            }
            this.isScoreUpdating = false;
        },
        error: (error: any) => {
            console.error('❌ Erreur lors du rafraîchissement du score:', error);
            this.showNotification('Erreur lors de la mise à jour du score', 'error');
            
            if (refreshBtn) {
                refreshBtn.classList.remove('rotating');
            }
            this.isScoreUpdating = false;
        }
    });
  }

  // ========================================
  // MÉTHODES D'INFORMATION ET STATUT
  // ========================================

  /**
   * Obtient le statut du score de crédit
   */
  getCreditScoreStatus(): string {
    const score = this.getCurrentScore();
    if (score >= 9) return 'Excellent';
    if (score >= 7) return 'Très bon';
    if (score >= 5) return 'Bon';
    if (score >= 3) return 'Moyen';
    return 'À améliorer';
  }

  /**
   * Obtient la couleur du score de crédit
   */
  getCreditScoreColor(): string {
    const score = this.getCurrentScore();
    if (score >= 9) return '#4CAF50';
    if (score >= 7) return '#8BC34A';
    if (score >= 5) return '#FFC107';
    if (score >= 3) return '#FF9800';
    return '#F44336';
  }

  /**
   * Obtient le texte du niveau de risque
   */
  getRiskLevelText(): string {
    const riskLevel = this.realTimeScore?.risk_level || this.globalStats?.riskLevel || this.savedScore?.riskLevel || 'medium';
    switch (riskLevel) {
      case 'très_bas':
      case 'very_low': 
        return 'Risque Très Faible';
      case 'bas':
      case 'low': 
        return 'Risque Faible';
      case 'moyen':
      case 'medium': 
        return 'Risque Moyen';
      case 'élevé':
      case 'high': 
        return 'Risque Élevé';
      case 'très_élevé':
      case 'very_high': 
        return 'Risque Très Élevé';
      default: 
        return 'Non évalué';
    }
  }

  /**
   * Formate une valeur monétaire
   */
  formatCurrency(amount: number | undefined): string {
    return new Intl.NumberFormat('fr-FR', {
      style: 'currency',
      currency: 'XAF',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0
    }).format(amount || 0);
  }

  // ========================================
  // MÉTHODES DE GESTION DU PROFIL
  // ========================================

  /**
   * Charge le profil utilisateur
   */
  private loadUserProfile(user: User): void {
    console.log('📋 Chargement du profil utilisateur:', user.name);
    
    this.client = {
      name: user.fullName || user.name || '',
      fullName: user.fullName || user.name || '',
      email: user.email || '',
      phone: user.phone || '',
      address: user.address || '',
      profession: user.profession || '',
      company: user.company || '',
      ProfileImage: user.profileImage || '',
      monthlyIncome: user.monthlyIncome || 0,
      clientId: user.id?.toString() || '',
      profileImage: user.profileImage || '',
      clientType: user.clientType || 'particulier',
      username: user.username || '',
      employmentStatus: user.employmentStatus || 'cdi',
      jobSeniority: user.jobSeniority || 0,
      id: user.id,
      existingDebts: user.existingDebts || 0,
      monthlyCharges: user.monthlyCharges || 0,
      birthDate: user.birthDate || ''
    };

    const savedImage = localStorage.getItem('profileImage');
    if (savedImage) {
      this.client.ProfileImage = savedImage;
      this.client.profileImage = savedImage;
    }

    this.saveClientData();
  }

  /**
   * Charge le score utilisateur
   */
  private loadUserScore(user: User): void {
    if (user.creditScore !== undefined) {
      console.log('📊 Score utilisateur disponible:', user.creditScore);
      
      this.savedScore = {
        score: user.creditScore,
        eligibleAmount: user.eligibleAmount || 0,
        riskLevel: user.riskLevel || 'moyen',
        recommendations: user.recommendations || [],
        scoreDetails: user.scoreDetails,
        lastUpdate: new Date().toISOString()
      };

      this.globalStats.creditScore = user.creditScore;
      this.globalStats.eligibleAmount = user.eligibleAmount || 0;
      this.globalStats.riskLevel = user.riskLevel || 'medium';

      this.showScoreNotification(this.savedScore);
      this.displayRecommendations();
    } else {
      console.log('⚠️ Aucun score disponible, rechargement...');
      this.refreshCreditScore();
    }
  }

  /**
   * Sauvegarde les données client
   */
  saveClientData(): void {
    try {
      if (!this.client) return;

      const clientData = {
        ...this.client,
        clientType: this.client.clientType || 'particulier',
        username: this.currentUser?.username || this.client.username,
        monthlyIncome: this.client.monthlyIncome || 0,
        employmentStatus: this.client.employmentStatus || 'cdi',
        jobSeniority: this.client.jobSeniority || 0,
        monthlyCharges: this.client.monthlyCharges || 0,
        existingDebts: this.client.existingDebts || 0
      };
      
      localStorage.setItem('currentClient', JSON.stringify(clientData));
      
      this.profileService.saveUserProfile({
        ...clientData,
        email: this.client.email || '',
        monthlyIncome: this.client.monthlyIncome || 0
      });
    } catch (error) {
      console.error('Erreur lors de la sauvegarde des données client:', error);
    }
  }

  /**
   * Vérifie l'éligibilité pour les crédits
   */
  checkEligibility(): void {
    if (!this.client) return;

    const isEnterprise = this.client.clientType === 'entreprise';
    
    if (isEnterprise) {
      this.creditTypes.forEach(type => {
        type.available = type.id === 'investissement';
      });
    } else {
      const avanceSalaireType = this.creditTypes.find(c => c.id === 'avance_salaire');
      if (avanceSalaireType && this.client.monthlyIncome) {
        avanceSalaireType.maxAmount = Math.min(2000000, Math.floor(this.client.monthlyIncome * 0.3333));
        avanceSalaireType.description = `Jusqu'à 70% de votre salaire (max ${this.formatCurrency(avanceSalaireType.maxAmount)})`;
      }
      
      const consoType = this.creditTypes.find(c => c.id === 'consommation_generale');
      if (consoType && this.client.monthlyIncome) {
        consoType.maxAmount = Math.min(this.globalStats.eligibleAmount, 2000000);
        consoType.description = `Pour vos besoins personnels (max ${this.formatCurrency(consoType.maxAmount)})`;
      }
      
      const isTontineMember = localStorage.getItem('isTontineMember') === 'true';
      const tontineType = this.creditTypes.find(c => c.id === 'tontine');
      if (tontineType) {
        tontineType.available = isTontineMember;
      }
      
      const isRetired = this.client.profession?.toLowerCase().includes('retraité') ||
                       localStorage.getItem('isRetired') === 'true';
      const retraiteType = this.creditTypes.find(c => c.id === 'retraite');
      if (retraiteType) {
        retraiteType.available = isRetired;
      }
    }
    
    if (this.getCurrentScore() < 5) {
      this.creditTypes.forEach(type => {
        if (type.available) {
          type.maxAmount = Math.round(type.maxAmount * 0.5);
        }
      });
    }
  }

  // ========================================
  // MÉTHODES DE GESTION DES MODALS
  // ========================================

  /**
   * Ouvre le modal de crédit rapide
   */
  openQuickCreditModal(): void {
    this.quickCredit.amount = Math.floor((this.globalStats?.eligibleAmount || 0) * 0.3333);
    const availableTypes = this.getAvailableCreditTypes();
    if (availableTypes.length > 0) {
      this.quickCredit.type = availableTypes[0].id;
    }
    this.showQuickCreditModal = true;
  }

  /**
   * Ferme le modal de crédit rapide
   */
  closeQuickCreditModal(): void {
    this.showQuickCreditModal = false;
  }

  // ========================================
  // MÉTHODES DE GESTION DES FICHIERS
  // ========================================

  /**
   * Déclenche la sélection de fichier
   */
  triggerFileInput(): void {
    const fileInput = document.querySelector('input[type="file"]') as HTMLInputElement;
    fileInput?.click();
  }

  /**
   * Gère la sélection d'un fichier image
   */
  onFileSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    if (!input || !input.files || input.files.length === 0) return;
    
    const file = input.files[0];
    
    if (!file.type.startsWith('image/')) {
      this.showNotification('Veuillez sélectionner un fichier image valide.', 'error');
      return;
    }
    
    if (file.size > 5 * 1024 * 1024) {
      this.showNotification('L\'image dépasse la taille maximale de 5 Mo.', 'error');
      return;
    }

    const reader = new FileReader();
    reader.onload = () => {
      const result = reader.result as string;
      if (this.client) {
        this.client.ProfileImage = result;
        this.client.profileImage = result;
        localStorage.setItem('profileImage', result);
        this.saveClientData();
        this.profileImageChange.emit(result);
        this.showNotification('Photo de profil mise à jour !', 'success');
      }
    };
    reader.readAsDataURL(file);
  }

  // ========================================
  // MÉTHODES D'AFFICHAGE ET NOTIFICATIONS
  // ========================================

  /**
   * Affiche une notification de score
   */
  private showScoreNotification(scoreData: SavedScore): void {
    const scoreStatus = this.getCreditScoreStatus();
    const scoreColor = this.getCreditScoreColor();
    
    const notification = document.createElement('div');
    notification.className = 'score-notification';
    notification.innerHTML = `
      <div style="position: fixed; top: 80px; right: 20px; max-width: 400px; 
                  background: white; border-radius: 12px; box-shadow: 0 4px 20px rgba(0,0,0,0.1); 
                  z-index: 1000; padding: 20px; animation: slideIn 0.5s ease-out;">
        <div style="display: flex; align-items: center; gap: 15px;">
          <div style="width: 60px; height: 60px; border-radius: 50%; 
                      background: ${scoreColor}; display: flex; align-items: center; 
                      justify-content: center; color: white; font-size: 24px; font-weight: bold;">
            ${scoreData.score}/10
          </div>
          <div style="flex: 1;">
            <h5 style="margin: 0; color: #333;">Votre Score de Crédit</h5>
            <p style="margin: 5px 0 0 0; color: #666; font-size: 14px;">
              Statut: <strong style="color: ${scoreColor}">${scoreStatus}</strong>
            </p>
            <p style="margin: 5px 0 0 0; color: #666; font-size: 14px;">
              Montant éligible: <strong>${this.formatCurrency(scoreData.eligibleAmount)}</strong>
            </p>
            ${this.isScoreRealTime() ? 
              '<p style="margin: 5px 0 0 0; color: #4CAF50; font-size: 12px;"><i class="material-icons" style="font-size: 16px; vertical-align: middle;">access_time</i> Temps réel</p>' 
              : ''
            }
          </div>
          <button onclick="this.parentElement.parentElement.remove()" 
                  style="background: none; border: none; font-size: 20px; 
                         cursor: pointer; color: #999;">×</button>
        </div>
      </div>
    `;
    
    document.body.appendChild(notification);
    
    setTimeout(() => {
      if (notification.parentNode) {
        notification.style.animation = 'slideOut 0.3s ease-in';
        setTimeout(() => notification.remove(), 300);
      }
    }, 8000);
  }

  /**
   * Affiche les recommandations
   */
  private displayRecommendations(): void {
    const recommendations = this.realTimeScore?.recommendations || this.savedScore?.recommendations;
    
    if (recommendations && recommendations.length > 0) {
      setTimeout(() => {
        const existingRec = document.querySelector('.recommendations-banner');
        if (existingRec) return;

        const recommendationsDiv = document.createElement('div');
        recommendationsDiv.className = 'recommendations-banner';
        recommendationsDiv.innerHTML = `
          <div style="background: #f8f9fa; border-left: 4px solid ${this.getCreditScoreColor()}; 
                      padding: 15px; margin: 20px 0; border-radius: 4px;">
            <h6 style="margin: 0 0 10px 0; color: #333;">
              <i class="material-icons" style="vertical-align: middle; margin-right: 5px;">lightbulb</i>
              Recommandations pour améliorer votre profil
              ${this.isScoreRealTime() ? 
                '<span style="color: #4CAF50; font-size: 12px; margin-left: 10px;">(Mis à jour en temps réel)</span>' 
                : ''
              }
            </h6>
            ${recommendations.map(rec => `
              <p style="margin: 5px 0; color: #666; font-size: 14px;">
                • ${rec}
              </p>
            `).join('')}
          </div>
        `;
        
        const profileHeader = document.querySelector('.dashboard-header');
        if (profileHeader && profileHeader.parentNode) {
          profileHeader.parentNode.insertBefore(recommendationsDiv, profileHeader.nextSibling);
        }
      }, 1000);
    }
  }

  /**
   * Affiche une notification générale
   */
  private showNotification(message: string, type: 'success' | 'warning' | 'error' | 'info' = 'info'): void {
    const notification = document.createElement('div');
    notification.className = `custom-notification ${type}`;
    notification.innerHTML = `
      <div class="notification-content">
        <i class="material-icons">${this.getNotificationIcon(type)}</i>
        <p>${message}</p>
        <button onclick="this.parentElement.parentElement.remove()" class="close-btn">
          <i class="material-icons">close</i>
        </button>
      </div>
    `;
    
    notification.style.cssText = `
      position: fixed;
      top: 80px;
      right: 20px;
      max-width: 400px;
      background: white;
      border-radius: 8px;
      box-shadow: 0 4px 12px rgba(0,0,0,0.15);
      z-index: 1000;
      animation: slideIn 0.3s ease-out;
      padding: 16px;
    `;
    
    document.body.appendChild(notification);
    
    setTimeout(() => {
      if (notification.parentNode) {
        notification.style.animation = 'slideOut 0.3s ease-in';
        setTimeout(() => notification.remove(), 300);
      }
    }, 5000);
  }

  /**
   * Obtient l'icône pour une notification
   */
  private getNotificationIcon(type: string): string {
    switch (type) {
      case 'success': return 'check_circle';
      case 'warning': return 'warning';
      case 'error': return 'error';
      default: return 'info';
    }
  }

  /**
   * Gère les erreurs
   */
  private handleError(message: string, error: any): void {
    console.error(message, error);
    this.hasError = true;
    this.errorMessage = message;
    this.isLoading = false;
    this.showNotification(message, 'error');
  }

  // ========================================
  // NOTIFICATION CRÉDIT AMÉLIORÉE
  // ========================================

  /**
   * Affiche une notification de crédit approuvé
   */
  private showCreditNotification(creditAmount: number, processingFee: number, totalAmount: number, scoreImpact?: any): void {
    const notification = document.createElement('div');
    notification.className = 'credit-notification-modal';
    
    const style = document.createElement('style');
    style.textContent = `
      .credit-notification-modal {
        position: fixed;
        top: 0;
        left: 0;
        width: 100%;
        height: 100%;
        z-index: 1050;
        display: flex;
        align-items: center;
        justify-content: center;
        backdrop-filter: blur(4px);
      }
      
      .credit-notification-modal .modal-backdrop {
        position: absolute;
        top: 0;
        left: 0;
        width: 100%;
        height: 100%;
        background: rgba(0, 0, 0, 0.6);
        animation: fadeIn 0.3s ease-out;
      }
      
      .credit-modal-content {
        position: relative;
        width: 90%;
        max-width: 500px;
        background: white;
        border-radius: 16px;
        box-shadow: 0 15px 40px rgba(0, 0, 0, 0.3);
        z-index: 1051;
        overflow: hidden;
        animation: modalSlideInCredit 0.4s cubic-bezier(0.34, 1.56, 0.64, 1);
      }
      
      .credit-header {
        background: linear-gradient(135deg, #4CAF50, #45a049);
        color: white;
        padding: 20px;
        text-align: center;
        position: relative;
      }
      
      .success-icon {
        background: rgba(255, 255, 255, 0.2);
        width: 60px;
        height: 60px;
        border-radius: 50%;
        display: flex;
        align-items: center;
        justify-content: center;
        margin: 0 auto 15px;
        animation: successIconPulse 2s infinite ease-in-out;
      }
      
      .success-icon i {
        font-size: 32px;
        animation: iconBounce 0.6s ease-out 0.2s both;
      }
      
      .credit-header h3 {
        margin: 0;
        font-size: 1.3rem;
        font-weight: 600;
      }
      
      .credit-header .close-btn {
        position: absolute;
        top: 15px;
        right: 15px;
        background: rgba(255, 255, 255, 0.2);
        border: none;
        color: white;
        border-radius: 50%;
        width: 32px;
        height: 32px;
        display: flex;
        align-items: center;
        justify-content: center;
        cursor: pointer;
        transition: all 0.3s ease;
      }
      
      .credit-header .close-btn:hover {
        background: rgba(255, 255, 255, 0.3);
        transform: scale(1.1);
      }
      
      .credit-body {
        padding: 25px 20px;
        background: #fafafa;
      }
      
      .credit-summary h4 {
        margin: 0 0 20px 0;
        font-size: 1.1rem;
        color: #333;
        font-weight: 600;
        text-align: center;
      }
      
      .amount-breakdown {
        background: white;
        border-radius: 12px;
        padding: 20px;
        margin-bottom: 20px;
        box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
        border: 1px solid rgba(76, 175, 80, 0.1);
      }
      
      .breakdown-item {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding: 10px 0;
      }
      
      .breakdown-item:not(:last-child) {
        border-bottom: 1px solid #f0f0f0;
      }
      
      .breakdown-item.total {
        border-top: 2px solid #4CAF50;
        padding-top: 15px;
        margin-top: 10px;
        font-weight: 600;
        background: linear-gradient(135deg, #e8f5e9, transparent);
        padding: 15px 10px;
        border-radius: 8px;
      }
      
      .debt-notice {
        background: rgba(255, 152, 0, 0.1);
        border-left: 4px solid #FF9800;
        padding: 15px;
        margin: 15px 0;
        border-radius: 4px;
      }
      
      .debt-notice h5 {
        margin: 0 0 8px 0;
        color: #e65100;
        font-size: 0.9rem;
        display: flex;
        align-items: center;
        gap: 8px;
      }
      
      .debt-notice p {
        margin: 0;
        font-size: 0.85rem;
        color: #f57c00;
      }
      
      .score-impact {
        background: white;
        border-radius: 8px;
        padding: 15px;
        margin: 15px 0;
        border: 1px solid #e0e0e0;
      }
      
      .score-impact h5 {
        margin: 0 0 10px 0;
        color: #333;
        font-size: 0.9rem;
        display: flex;
        align-items: center;
        gap: 8px;
      }
      
      .score-change {
        display: flex;
        align-items: center;
        gap: 10px;
        font-size: 0.9rem;
      }
      
      .score-change.negative {
        color: #f44336;
      }
      
      .score-change.positive {
        color: #4CAF50;
      }
      
      @keyframes fadeIn {
        from { opacity: 0; }
        to { opacity: 1; }
      }
      
      @keyframes modalSlideInCredit {
        from {
          opacity: 0;
          transform: translateY(-50px) scale(0.9);
        }
        to {
          opacity: 1;
          transform: translateY(0) scale(1);
        }
      }
      
      @keyframes successIconPulse {
        0%, 100% {
          transform: scale(1);
        }
        50% {
          transform: scale(1.05);
        }
      }
      
      @keyframes iconBounce {
        0% {
          transform: scale(0) rotate(-180deg);
          opacity: 0;
        }
        50% {
          transform: scale(1.1) rotate(-90deg);
        }
        100% {
          transform: scale(1) rotate(0deg);
          opacity: 1;
        }
      }
    `;
    
    document.head.appendChild(style);
    
    notification.innerHTML = `
      <div class="modal-backdrop"></div>
      <div class="credit-modal-content">
        <div class="credit-header">
          <div class="success-icon">
            <i class="material-icons">account_balance_wallet</i>
          </div>
          <h3>Crédit Approuvé et Enregistré !</h3>
          <button class="close-btn">
            <i class="material-icons">close</i>
          </button>
        </div>
        
        <div class="credit-body">
          <div class="credit-summary">
            <h4>Votre crédit a été traité avec succès</h4>
            
            <div class="amount-breakdown">
              <div class="breakdown-item">
                <span class="label">Montant crédité :</span>
                <span class="value credit-amount">${this.formatCurrency(creditAmount)}</span>
              </div>
              <div class="breakdown-item">
                <span class="label">Frais de dossier :</span>
                <span class="value fee-amount">${this.formatCurrency(processingFee)}</span>
              </div>
              <div class="breakdown-item total">
                <span class="label">Total à rembourser :</span>
                <span class="value total-amount">${this.formatCurrency(totalAmount)}</span>
              </div>
            </div>

            <div class="debt-notice">
              <h5>
                <i class="material-icons">trending_up</i>
                Impact sur vos dettes
              </h5>
              <p>Ce montant a été automatiquement ajouté à vos dettes enregistrées et influencera votre score de crédit.</p>
            </div>

            ${scoreImpact ? `
              <div class="score-impact">
                <h5>
                  <i class="material-icons">analytics</i>
                  Impact sur votre score
                </h5>
                <div class="score-change ${scoreImpact.change < 0 ? 'negative' : 'positive'}">
                  <span>Score: ${scoreImpact.previous?.toFixed(1) || 'N/A'} → ${scoreImpact.new?.toFixed(1) || 'N/A'}</span>
                  <span>(${scoreImpact.change > 0 ? '+' : ''}${scoreImpact.change?.toFixed(1) || '0'})</span>
                </div>
              </div>
            ` : ''}

            <div style="background: white; border-radius: 8px; padding: 15px; margin-top: 15px;">
              <h5 style="margin: 0 0 10px 0; color: #333;">
                <i class="material-icons">info</i>
                Prochaines étapes
              </h5>
              <ul style="margin: 0; padding-left: 20px; font-size: 0.9rem; color: #666;">
                <li>Le montant est disponible immédiatement dans votre solde</li>
                <li>Vous pouvez l'utiliser pour vos achats</li>
                <li>Ce crédit est maintenant enregistré dans vos dettes</li>
                <li>Votre prochain crédit sera possible dans 30 jours minimum</li>
                <li>Maximum 2 crédits actifs simultanément</li>
              </ul>
            </div>
          </div>
        </div>
      </div>
    `;
    
    document.body.appendChild(notification);
    
    const closeButtons = notification.querySelectorAll('.close-btn, .modal-backdrop');
    closeButtons.forEach(button => {
      button.addEventListener('click', () => {
        if (document.head.contains(style)) {
          document.head.removeChild(style);
        }
        notification.remove();
      });
    });
    
    setTimeout(() => {
      if (notification.parentNode) {
        if (document.head.contains(style)) {
          document.head.removeChild(style);
        }
        notification.remove();
      }
    }, 15000);
  }

  // ========================================
  // MÉTHODES UTILITAIRES ET LEGACY
  // ========================================

  /**
   * Affiche un message d'inéligibilité
   */
  private showIneligibilityMessage(creditType: CreditType): void {
    let message = `Vous n'êtes pas éligible pour le ${creditType.name}.`;
    
    if (creditType.id === 'investissement') {
      message += '\nCe crédit est réservé aux entreprises.';
    } else if (creditType.id === 'tontine') {
      message += '\nVous devez être membre actif d\'une tontine.';
    } else if (creditType.id === 'retraite') {
      message += '\nCe crédit est réservé aux retraités CNSS/CPPF.';
    }
    
    this.showNotification(message, 'warning');
  }

  /**
   * Applique pour un crédit (méthode legacy)
   */
  applyForCredit(creditType: CreditType): void {
    if (creditType.available) {
      this.router.navigate(['/credit-request'], { 
        queryParams: { type: creditType.id } 
      });
    } else {
      this.showIneligibilityMessage(creditType);
    }
  }

  /**
   * Obtient la prochaine date de paiement
   */
  getNextPaymentDate(): Date | null {
    const activeCreditsSorted = [...this.activeCredits]
      .filter(c => c.status === 'active')
      .sort((a, b) => a.nextPayment.getTime() - b.nextPayment.getTime());
    return activeCreditsSorted.length > 0 ? activeCreditsSorted[0].nextPayment : null;
  }

  /**
   * Obtient le total des paiements mensuels
   */
  getTotalMonthlyPayment(): number {
    return this.activeCredits
      .filter(c => c.status === 'active')
      .reduce((sum, credit) => sum + credit.nextPaymentAmount, 0);
  }

  /**
   * Affiche les détails d'un crédit (méthode legacy)
   */
  viewCreditDetails(credit: ActiveCredit): void {
    if (!credit) return;

    const modal = document.createElement('div');
    modal.className = 'credit-details-modal';
    modal.innerHTML = `
      <div class="modal-backdrop" onclick="this.parentElement.remove()"></div>
      <div class="modal-content">
        <div class="modal-header">
          <h3>Détails du crédit</h3>
          <button class="close-btn" onclick="this.parentElement.parentElement.parentElement.remove()">
            <i class="material-icons">close</i>
          </button>
        </div>
        <div class="modal-body">
          <div class="detail-row">
            <span class="label">Type de crédit:</span>
            <span class="value">${credit.type}</span>
          </div>
          <div class="detail-row">
            <span class="label">Montant emprunté:</span>
            <span class="value">${this.formatCurrency(credit.amount)}</span>
          </div>
          <div class="detail-row">
            <span class="label">Montant restant:</span>
            <span class="value">${this.formatCurrency(credit.remainingAmount)}</span>
          </div>
          <div class="detail-row">
            <span class="label">Prochaine échéance:</span>
            <span class="value">${credit.nextPayment.toLocaleDateString('fr-FR')}</span>
          </div>
          <div class="detail-row">
            <span class="label">Montant à payer:</span>
            <span class="value">${this.formatCurrency(credit.nextPaymentAmount)}</span>
          </div>
        </div>
        <div class="modal-footer">
          <button class="btn-primary" onclick="this.parentElement.parentElement.parentElement.remove()">
            Fermer
          </button>
        </div>
      </div>
    `;
    
    document.body.appendChild(modal);
  }

  /**
   * Obtient le pourcentage de progression du score
   */
  getScoreProgressPercentage(): number {
    const score = this.getCurrentScore();
    return (score / 10) * 100;
  }

  // ========================================
  // MÉTHODES POUR LES CALCULS DU TEMPLATE
  // ========================================

  /**
   * Obtient le total des dettes actives
   */
  getTotalActiveDebt(): number {
    return this.activeCreditsFromService
      .filter(c => c.status === 'active')
      .reduce((sum, c) => sum + c.remainingAmount, 0);
  }

  /**
   * Obtient le nombre de crédits actifs
   */
  getActiveCreditCount(): number {
    return this.activeCreditsFromService.filter(c => c.status === 'active').length;
  }

  /**
   * Calcule le nouveau total de dettes avec le crédit rapide
   */
  getNewTotalDebtWithQuickCredit(): number {
    const currentDebt = this.getTotalActiveDebt();
    const newCreditTotal = this.quickCredit.amount + (this.quickCredit.amount * 0.015);
    return currentDebt + newCreditTotal;
  }

  /**
   * Calcule le nouveau ratio d'endettement avec le crédit rapide
   */
  getNewDebtRatioWithQuickCredit(): number {
    const newTotalDebt = this.getNewTotalDebtWithQuickCredit();
    const monthlyIncome = this.currentUser?.monthlyIncome || 1;
    return (newTotalDebt / monthlyIncome) * 100;
  }

  /**
   * Vérifie si le nouveau ratio d'endettement est élevé
   */
  isNewDebtRatioHigh(): boolean {
    return this.getNewDebtRatioWithQuickCredit() > 70;
  }

  /**
   * Vérifie si le nouveau ratio d'endettement est critique
   */
  isNewDebtRatioCritical(): boolean {
    return this.getNewDebtRatioWithQuickCredit() > 50;
  }

  /**
   * Obtient les classes CSS pour le ratio d'endettement
   */
  getDebtRatioClasses(): any {
    return {
      'warning': this.isNewDebtRatioCritical(),
      'danger': this.isNewDebtRatioHigh()
    };
  }

  /**
   * Vérifie si un avertissement doit être affiché pour le ratio élevé
   */
  shouldShowHighDebtWarning(): boolean {
    return this.quickCredit.amount > 0 && this.isNewDebtRatioHigh();
  }

  /**
   * Vérifie si l'info sur les crédits multiples doit être affichée
   */
  shouldShowMultipleCreditInfo(): boolean {
    return this.creditRestrictions && this.creditRestrictions.activeCreditCount >= 1;
  }

  /**
   * Formate une date pour l'affichage
   */
  formatDate(dateString: string): string {
    if (!dateString) return '';
    const date = new Date(dateString);
    return date.toLocaleDateString('fr-FR', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric'
    });
  }

  /**
   * Formate une date avec l'heure pour l'affichage détaillé
   */
  formatDateWithTime(dateString: string): string {
    if (!dateString) return '';
    const date = new Date(dateString);
    return date.toLocaleDateString('fr-FR', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  }

  /**
   * Calcule le pourcentage de remboursement d'un crédit
   */
  getCreditReimbursementPercentage(credit: RegisteredCredit): number {
    if (!credit || credit.totalAmount === 0) return 0;
    return ((credit.totalAmount - credit.remainingAmount) / credit.totalAmount) * 100;
  }

  /**
   * Vérifie si le compte de crédits actifs est élevé
   */
  isActiveCreditCountHigh(): boolean {
    return this.getActiveCreditCount() >= 2;
  }

  /**
   * Obtient les classes CSS pour le compte de crédits
   */
  getActiveCreditCountClasses(): any {
    return {
      'warning': this.isActiveCreditCountHigh()
    };
  }

  /**
   * Obtient les classes CSS pour le ratio d'endettement actuel
   */
  getCurrentDebtRatioClasses(): any {
    const currentRatio = this.creditRestrictions?.debtRatio || 0;
    return {
      'warning': currentRatio > 0.5,
      'danger': currentRatio > 0.7
    };
  }

  /**
   * Obtient le pourcentage du ratio d'endettement actuel
   */
  getCurrentDebtRatioPercentage(): number {
    const currentRatio = this.creditRestrictions?.debtRatio || 0;
    return currentRatio * 100;
  }

  /**
   * Formate le taux d'intérêt en pourcentage
   */
  formatInterestRate(rate: number): string {
    return (rate * 100).toFixed(1);
  }

  /**
   * Vérifie si le score doit déclencher un avertissement de ratio élevé
   */
  shouldShowScoreDebtWarning(): boolean {
    return this.currentUser ? this.creditManagementService.calculateDebtRatio(this.currentUser) > 0.5 : false;
  }

  /**
   * Obtient le ratio d'endettement formaté depuis le service
   */
  getFormattedDebtRatioFromService(): string {
    if (!this.currentUser) return '0.0';
    return (this.creditManagementService.calculateDebtRatio(this.currentUser) * 100).toFixed(1);
  }

  /**
   * Vérifie si un crédit est en cours (actif)
   */
  isCreditActive(credit: RegisteredCredit): boolean {
    return credit.status === 'active';
  }

  /**
   * Obtient le nombre de crédits supplémentaires non affichés
   */
  getAdditionalCreditsCount(): number {
    return Math.max(0, this.activeCreditsFromService.length - 3);
  }

  /**
   * Vérifie s'il y a des crédits supplémentaires à afficher
   */
  hasAdditionalCredits(): boolean {
    return this.activeCreditsFromService.length > 3;
  }

  /**
   * Obtient les 3 premiers crédits pour l'affichage
   */
  getDisplayedCredits(): RegisteredCredit[] {
    return this.activeCreditsFromService.slice(0, 3);
  }

  /**
   * Calcule le nouveau nombre de crédits après demande
   */
  getNewCreditCountAfterApplication(): number {
    return (this.creditRestrictions?.activeCreditCount || 0) + 1;
  }

  /**
   * Vérifie si les restrictions sont dues au nombre de crédits
   */
  isRestrictedByMaxCredits(): boolean {
    return this.getActiveCreditCount() >= 2;
  }

  /**
   * Vérifie si les restrictions sont dues au ratio d'endettement
   */
  isRestrictedByDebtRatio(): boolean {
    return (this.creditRestrictions?.totalActiveDebt || 0) / (this.currentUser?.monthlyIncome || 1) > 0.7;
  }

  /**
   * Vérifie si le score est en dessous du seuil recommandé
   */
  isScoreBelowThreshold(): boolean {
    return this.getCurrentScore() < 7;
  }

  /**
   * Obtient les facteurs du score
   */
  getScoreFactors(): any[] {
    return this.realTimeScore?.factors || [];
  }

  /**
   * Obtient l'analyse des paiements
   */
  getPaymentAnalysis(): any {
    return this.realTimeScore?.payment_analysis || this.paymentAnalysis;
  }

  /**
   * Obtient la tendance des paiements
   */
  getPaymentTrend(): string {
    const trend = this.getPaymentAnalysis()?.trend || 'stable';
    switch (trend) {
      case 'improving': return 'En amélioration';
      case 'declining': return 'En baisse';
      default: return 'Stable';
    }
  }

  /**
   * Obtient l'icône de tendance des paiements
   */
  getPaymentTrendIcon(): string {
    const trend = this.getPaymentAnalysis()?.trend || 'stable';
    switch (trend) {
      case 'improving': return 'trending_up';
      case 'declining': return 'trending_down';
      default: return 'trending_flat';
    }
  }

  /**
   * Obtient le ratio de paiements à temps
   */
  getOnTimePaymentRatio(): number {
    const analysis = this.getPaymentAnalysis();
    if (!analysis) return 0;
    return (analysis.on_time_ratio || analysis.on_time_payments / analysis.total_payments || 0) * 100;
  }

  /**
   * Active/désactive l'historique des scores
   */
  toggleScoreHistory(): void {
    this.showScoreHistory = !this.showScoreHistory;
    if (this.showScoreHistory && this.scoreHistory.length === 0) {
      this.loadScoreHistory();
    }
  }

  /**
   * Formate la date de l'historique des scores
   */
  formatScoreHistoryDate(dateString: string): string {
    const date = new Date(dateString);
    return date.toLocaleDateString('fr-FR', {
      day: '2-digit',
      month: '2-digit',
      hour: '2-digit',
      minute: '2-digit'
    });
  }
}