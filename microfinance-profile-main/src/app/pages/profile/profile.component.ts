// profile.component.ts - VERSION CORRIGEE SANS EMOJIS

import { Component, OnInit, OnDestroy, Input, Output, EventEmitter } from '@angular/core';
import { Router } from '@angular/router';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { FormsModule } from '@angular/forms';
import { ClientProfil } from '../../models/client-profile.model';
import { ProfileService, ActiveCredit, ProfileStats } from '../../services/profile.service';
import { ApiProxyService } from '../../services/proxy.service';
import { StorageService } from '../../services/storage.service';
import { ScoringService } from '../../services/scoring.service';
import { AuthService, User } from '../../services/auth.service';
import { CreditManagementService } from '../../services/credit-management.service';
import { CreditRequestsService } from '../../services/credit-requests.service';
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
  [x: string]: any;
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
  
  isPaid?: boolean;
  totalPaid?: number;
  percentagePaid?: number;
  paymentsCount?: number;
  lastPaymentDate?: string;
  lastPaymentAmount?: number;
  requestId?: number;
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

interface RecentCreditRequest {
  id: number;
  requestNumber: string;
  type: string;
  amount: number;
  status: string;
  submissionDate: string;
  approvedAmount?: number;
  isPaid?: boolean;
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
      name: 'Credit Consommation',
      icon: 'shopping_cart',
      color: '#4CAF50',
      description: 'Pour vos besoins personnels (max 2M FCFA)',
      maxAmount: 2000000,
      duration: '1 mois (1 a 3 remboursements)',
      available: true
    },
    {
      id: 'avance_salaire',
      name: 'Avance sur Salaire',
      icon: 'account_balance_wallet',
      color: '#2196F3',
      description: 'Jusqu\'a 70% de votre salaire net',
      maxAmount: 2000000,
      duration: '1 mois (fin du mois)',
      available: true
    },
    {
      id: 'depannage',
      name: 'Credit Depannage',
      icon: 'medical_services',
      color: '#FF5722',
      description: 'Solution urgente pour liquidites',
      maxAmount: 2000000,
      duration: '1 mois (remboursement unique)',
      available: true
    }
  ];

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

  activeCreditsFromService: RegisteredCredit[] = [];
  creditRestrictions: CreditRestrictions = {
    canApplyForCredit: true,
    maxCreditsAllowed: 2,
    activeCreditCount: 0,
    totalActiveDebt: 0,
    debtRatio: 0
  };
  showActiveCreditsModal!: boolean;
  animateScoreChange: any;
  
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
  showSuccessModal = false;
  successMessage = '';

  isSubmitting = false;
  quickCredit = {
    type: 'consommation_generale',
    amount: 0,
    duration: 1,
    frequency: 'mensuel'
  };

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

  realTimeScore: RealTimeScoreUpdate | null = null;
  isScoreUpdating = false;
  scoreChangeAnimation = false;
  previousScore = 0;
  showScoreHistory = false;
  scoreHistory: ScoreHistoryEntry[] = [];
  realTimeSubscription?: Subscription;
  paymentAnalysis: any = null;
  recentCreditRequests: RecentCreditRequest[] = [];
  
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
    private creditRequestsService: CreditRequestsService,
    private http: HttpClient,
    public creditManagementService: CreditManagementService,
    private apiProxy: ApiProxyService
  ) {}

  ngOnInit(): void {
    this.isLoading = true;
    
    this.authSubscription = this.authService.currentUser$.subscribe((user: any) => {
      if (user) {
        this.currentUser = user;
        this.loadUserProfile(user);
        
        // Initialisation securisee
        this.loadInitialScore(user);
        this.loadAccountBalance();
        this.loadCompleteStats(user.id);
        this.loadCreditsWithPaymentStatus(user.id);
        this.loadCreditRestrictions();
        
        this.startRealTimeScoreMonitoring(user.id);
      } else {
        this.router.navigate(['/login']);
      }
    });
  }
  // Remplacer ces methodes dans profile.component.ts

private handleRealTimeScoreUpdate(scoreUpdate: RealTimeScoreUpdate): void {
  const previousScore = Number(this.realTimeScore?.score) || Number(this.globalStats.creditScore) || 0;
  const newScore = Number(scoreUpdate.score) || 0;
  
  console.log('Mise a jour score temps reel:', {
    previous: previousScore,
    new: newScore,
    change: newScore - previousScore,
    analysis: scoreUpdate.payment_analysis
  });

  if (scoreUpdate.payment_analysis) {
    this.paymentAnalysis = scoreUpdate.payment_analysis;
  }

  // Mise a jour directe sans animation pour eviter les erreurs
  this.realTimeScore = scoreUpdate;
  this.globalStats.creditScore = newScore;
  this.globalStats.riskLevel = scoreUpdate.risk_level;
  
  // Mise a jour du montant eligible depuis la reponse Flask
  if (scoreUpdate['eligible_amount']) {
    this.globalStats.eligibleAmount = Number(scoreUpdate['eligible_amount']) || 0;
  }
  
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
  
  // Afficher notification uniquement si changement significatif
  if (Math.abs(newScore - previousScore) >= 0.1 && previousScore > 0) {
    this.showScoreChangeNotification(previousScore, newScore, scoreUpdate);
  }
}

private showScoreChangeNotification(oldScore: number, newScore: number, scoreUpdate: RealTimeScoreUpdate): void {
  const oldScoreNum = Number(oldScore) || 0;
  const newScoreNum = Number(newScore) || 0;
  const change = newScoreNum - oldScoreNum;
  const isPositive = change > 0;
  const trend = scoreUpdate.payment_analysis?.trend || 'stable';
  
  let trendIcon = 'trending_flat';
  let trendText = 'Stable';
  
  if (trend === 'improving') {
    trendIcon = 'trending_up';
    trendText = 'En amelioration';
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
          <h4 style="margin: 0; font-size: 16px;">Score Mis a Jour</h4>
          <p style="margin: 5px 0 0 0; font-size: 14px;">
            ${oldScoreNum.toFixed(1)} -> ${newScoreNum.toFixed(1)} 
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

getCurrentScore(): number {
  return Number(this.realTimeScore?.score) || Number(this.globalStats.creditScore) || 0;
}

getScoreChange(): number {
  if (!this.realTimeScore?.score_change) return 0;
  return Number(this.realTimeScore.score_change) || 0;
}

isScoreRealTime(): boolean {
  return this.realTimeScore?.is_real_time || false;
}

getLastScoreUpdate(): string {
  if (!this.realTimeScore?.last_updated) return '';
  return this.getTimeAgo(this.realTimeScore.last_updated);
}




  ngOnDestroy(): void {
    this.creditsSubscription?.unsubscribe();
    this.statsSubscription?.unsubscribe();
    this.storageSubscription?.unsubscribe();
    this.authSubscription?.unsubscribe();
    this.realTimeSubscription?.unsubscribe();
  }

  private loadCompleteStats(userId: number): void {
    console.log('Chargement statistiques completes pour user:', userId);
    
    this.apiProxy.getUserStats(userId).subscribe({
      next: (response: { success: any; data: any; }) => {
        if (response.success) {
          const stats = response.data;
          console.log('Stats recues:', stats);
          
          this.globalStats = {
            totalBorrowed: stats.totalBorrowed || 0,
            totalReimbursed: stats.totalReimbursed || 0,
            activeCredits: stats.activeCredits || 0,
            creditScore: stats.creditScore || 0,
            eligibleAmount: stats.eligibleAmount || 0,
            totalApplications: stats.totalApplications || 0,
            approvedApplications: stats.approvedApplications || 0,
            riskLevel: stats.riskLevel || 'medium'
          };
          
          this.recentCreditRequests = (stats.recentRequests || []).map((req: any) => ({
            id: req.id,
            requestNumber: req.requestNumber,
            type: req.type,
            amount: req.amount,
            status: req.status,
            submissionDate: req.submissionDate,
            approvedAmount: req.approvedAmount,
            isPaid: req.isPaid || false
          }));
          
          console.log('Stats mises a jour:', this.globalStats);
          console.log('Dernieres demandes:', this.recentCreditRequests.length);
        }
      },
      error: (error: any) => {
        console.error('Erreur chargement stats:', error);
        this.recentCreditRequests = [];
      }
    });
  }

  private loadInitialScore(user: User): void {
    if (!user.id) return;
    
    this.apiProxy.getUserScoring(user.id, false).subscribe({
      next: (scoreUpdate: RealTimeScoreUpdate) => {
        if (scoreUpdate && scoreUpdate.user_id) {
          this.handleRealTimeScoreUpdate(scoreUpdate);
        }
      },
      error: (error) => {
        console.error('Erreur chargement score initial:', error);
        if (user.creditScore !== undefined) {
          this.globalStats.creditScore = user.creditScore;
          this.globalStats.eligibleAmount = user.eligibleAmount || 0;
          this.globalStats.riskLevel = user.riskLevel || 'medium';
        }
      }
    });
  }



  async submitQuickCredit(): Promise<void> {
    if (this.quickCredit.amount < 10000) {
      this.showNotification('Montant minimum: 10 000 FCFA', 'error');
      return;
    }

    this.isSubmitting = true;
    
    try {
      const creditData = {
        username: this.currentUser?.username,
        user_id: this.currentUser?.id,
        type: this.quickCredit.type,
        amount: this.quickCredit.amount,
        totalAmount: this.quickCredit.amount * 1.015,
        interestRate: 0.015
      };

      // Enregistrer dans PostgreSQL via NestJS
      const newCredit = await this.apiProxy.registerCredit(creditData).toPromise();
      
      console.log('Credit enregistre:', newCredit);
      
      // Recharger les donnees
      this.loadRegisteredCredits();
      this.loadCreditRestrictions();
      
      // Recalculer le score
      this.refreshCreditScore();
      
      // Afficher le message de succes
      this.showQuickCreditModal = false;
      this.showSuccessMessage(creditData.amount);
      
    } catch (error) {
      console.error('Erreur creation credit:', error);
      this.showNotification('Erreur lors de la creation', 'error');
    } finally {
      this.isSubmitting = false;
    }
  }

  private showSuccessMessage(amount: number): void {
    this.successMessage = `Votre demande de credit de ${this.formatCurrency(amount)} a ete enregistree avec succes. Vous serez decaisse dans quelques jours. Vous recevrez une notification par SMS et email.`;
    this.showSuccessModal = true;
  }

  closeSuccessModal(): void {
    this.showSuccessModal = false;
  }

  getCreditScoreStatus(): string {
    const score = this.getCurrentScore();
    if (score >= 9) return 'Excellent';
    if (score >= 7) return 'Tres bon';
    if (score >= 5) return 'Bon';
    if (score >= 3) return 'Moyen';
    return 'A ameliorer';
  }

  getCreditScoreColor(): string {
    const score = this.getCurrentScore();
    if (score >= 9) return '#4CAF50';
    if (score >= 7) return '#8BC34A';
    if (score >= 5) return '#FFC107';
    if (score >= 3) return '#FF9800';
    return '#F44336';
  }

  private loadCreditRestrictions(): void {
    if (!this.currentUser?.username) return;
    
    this.apiProxy.getUserRestrictions(this.currentUser.username).subscribe({
      next: (restrictions) => {
        this.creditRestrictions = restrictions;
        console.log('Restrictions chargees:', restrictions);
      },
      error: (error) => {
        console.error('Erreur chargement restrictions:', error);
      }
    });
  }

  getRiskLevelText(): string {
    const riskLevel = this.realTimeScore?.risk_level || this.globalStats?.riskLevel || this.savedScore?.riskLevel || 'medium';
    switch (riskLevel) {
      case 'tres_bas':
      case 'very_low': 
        return 'Risque Tres Faible';
      case 'bas':
      case 'low': 
        return 'Risque Faible';
      case 'moyen':
      case 'medium': 
        return 'Risque Moyen';
      case 'eleve':
      case 'high': 
        return 'Risque Eleve';
      case 'tres_eleve':
      case 'very_high': 
        return 'Risque Tres Eleve';
      default: 
        return 'Non evalue';
    }
  }

  formatCurrency(amount: number | undefined): string {
    return new Intl.NumberFormat('fr-FR', {
      style: 'currency',
      currency: 'XAF',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0
    }).format(amount || 0);
  }

  private loadUserProfile(user: User): void {
    console.log('Chargement du profil utilisateur:', user.name);
    
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
      console.error('Erreur lors de la sauvegarde des donnees client:', error);
    }
  }

  private loadRegisteredCredits(): void {
    if (!this.currentUser?.username) return;
    
    this.apiProxy.getUserCredits(this.currentUser.username).subscribe({
      next: (credits) => {
        this.activeCreditsFromService = credits;
        this.updateDebtCalculations();
        console.log('Credits charges depuis PostgreSQL:', credits.length);
      },
      error: (error) => {
        console.error('Erreur chargement credits:', error);
      }
    });
  }

  private updateDebtCalculations(): void {
    const totalActiveDebt = this.activeCreditsFromService
      .filter(c => c.status === 'active')
      .reduce((sum, credit) => sum + credit.remainingAmount, 0);
    
    if (this.client) {
      this.client.existingDebts = totalActiveDebt;
      this.saveClientData();
    }
    
    this.calculateLocalRestrictions();
    
    if (totalActiveDebt !== this.creditRestrictions.totalActiveDebt) {
      this.refreshCreditScore();
    }
  }

  private calculateLocalRestrictions(): void {
    const activeCredits = this.activeCreditsFromService.filter(c => c.status === 'active');
    const totalDebt = activeCredits.reduce((sum, credit) => sum + credit.remainingAmount, 0);
    const monthlyIncome = this.currentUser?.monthlyIncome || 1;
    const debtRatio = totalDebt / monthlyIncome;
    
    const lastApplicationKey = `last_application_${this.currentUser?.username}`;
    const lastApplicationDate = localStorage.getItem(lastApplicationKey);
    const daysSinceLastApplication = lastApplicationDate ? 
      Math.floor((Date.now() - new Date(lastApplicationDate).getTime()) / (1000 * 60 * 60 * 24)) : 30;
    
    let canApply = true;
    let blockingReason = '';
    let nextEligibleDate = undefined;
    
    if (activeCredits.length >= 2) {
      canApply = false;
      blockingReason = 'Maximum 2 credits actifs atteint';
    } else if (debtRatio > 0.7) {
      canApply = false;
      blockingReason = `Ratio d'endettement trop eleve (${(debtRatio * 100).toFixed(1)}%)`;
    } else if (daysSinceLastApplication < 30) {
      canApply = false;
      const remainingDays = 30 - daysSinceLastApplication;
      blockingReason = `Delai d'attente: ${remainingDays} jour(s) restant(s)`;
      
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
    
    console.log('Restrictions calculees localement:', this.creditRestrictions);
  }

  openActiveCreditsModal(): void {
    this.showActiveCreditsModal = true;
  }

  closeActiveCreditsModal(): void {
    this.showActiveCreditsModal = false;
  }

  getCreditTypeName(creditTypeId: string): string {
    const creditType = this.creditTypes.find(type => type.id === creditTypeId);
    return creditType ? creditType.name : 'Credit';
  }

  getCreditStatusText(status: string): string {
    const statusMap: Record<string, string> = {
      'active': 'Actif',
      'paid': 'Rembourse',
      'overdue': 'En retard'
    };
    return statusMap[status] || status;
  }

  makePayment(creditId: string): void {
    const credit = this.activeCreditsFromService.find(c => c.id === creditId);
    if (!credit || credit.status !== 'active') {
      this.showNotification('Credit non trouve ou deja rembourse', 'error');
      return;
    }

    const paymentAmount = Math.min(50000, credit.remainingAmount);
    
    if (confirm(`Confirmer le paiement de ${this.formatCurrency(paymentAmount)} pour le credit ${this.getCreditTypeName(credit.type)} ?`)) {
      this.processPayment(creditId, paymentAmount);
    }
  }

  simulatePayment(creditId: string): void {
    const credit = this.activeCreditsFromService.find(c => c.id === creditId);
    if (!credit) return;
    
    const currentScore = this.getCurrentScore();
    const estimatedImprovement = credit.remainingAmount > 100000 ? 0.2 : 0.1;
    const estimatedNewScore = Math.min(10, currentScore + estimatedImprovement);
    
    this.showNotification(
      `Simulation: Rembourser ce credit ameliorerait votre score de ${currentScore.toFixed(1)} a ${estimatedNewScore.toFixed(1)} (+${estimatedImprovement.toFixed(1)})`,
      'info'
    );
  }

  private processPayment(creditId: string, amount: number): void {
    const creditIndex = this.activeCreditsFromService.findIndex(c => c.id === creditId);
    if (creditIndex === -1) return;

    const credit = this.activeCreditsFromService[creditIndex];
    const isFullPayment = amount >= credit.remainingAmount;
    
    const payment: PaymentRecord = {
      id: this.generatePaymentId(),
      amount: amount,
      date: new Date().toISOString(),
      type: isFullPayment ? 'full' : 'partial',
      late: false,
      daysLate: 0
    };
    
    credit.remainingAmount = Math.max(0, credit.remainingAmount - amount);
    credit.paymentsHistory.push(payment);
    
    if (credit.remainingAmount === 0) {
      credit.status = 'paid';
    }
    
    this.activeCreditsFromService[creditIndex] = credit;
    
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
          console.log('Paiement traite:', response);
          
          if (response.score_impact) {
            this.showScoreChangeNotification(
              response.score_impact.previous_score,
              response.score_impact.new_score,
              {
                recommendations: ['Paiement effectue avec succes'],
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
          console.error('Erreur traitement paiement serveur:', error);
        }
      });
    
    this.updateDebtCalculations();
    
    if (isFullPayment) {
      this.showNotification(`Credit integralement rembourse ! Votre score va s'ameliorer.`, 'success');
    } else {
      this.showNotification(`Paiement de ${this.formatCurrency(amount)} effectue. Restant: ${this.formatCurrency(credit.remainingAmount)}`, 'success');
    }
  }

  private generatePaymentId(): string {
    return `PAY_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
  }

  getCreditByRequestId(requestId: number): RegisteredCredit | undefined {
    return this.activeCreditsFromService.find(c => c.requestId === requestId);
  }

  isRequestFullyPaid(requestId: number): boolean {
    const credit = this.getCreditByRequestId(requestId);
    return credit ? (credit.isPaid === true) : false;
  }

  getRequestPaymentPercentage(requestId: number): number {
    const credit = this.getCreditByRequestId(requestId);
    return credit ? (credit.percentagePaid || 0) : 0;
  }

  private loadCreditsWithPaymentStatus(userId: number): void {
    console.log('Chargement credits avec statut paiement pour user:', userId);
    
    this.apiProxy.getUserCreditsDetailed(userId).subscribe({
      next: (response: { success: any; data: any[]; }) => {
        if (response.success) {
          console.log('Credits detailles recus:', response.data);
          
          this.activeCreditsFromService = response.data.map((credit: any): RegisteredCredit => ({
            id: credit.id?.toString() || '',
            type: credit.type || '',
            amount: credit.amount || 0,
            totalAmount: credit.totalAmount || 0,
            remainingAmount: credit.remainingAmount || 0,
            interestRate: credit.interestRate || 0.015,
            status: credit.isPaid ? 'paid' : (credit.status || 'active'),
            approvedDate: credit.approvedDate || '',
            dueDate: credit.dueDate || '',
            paymentsHistory: credit.paymentsHistory || [],
            
            isPaid: credit.isPaid || false,
            totalPaid: credit.totalPaid || 0,
            percentagePaid: credit.percentagePaid || 0,
            paymentsCount: credit.paymentsCount || 0,
            lastPaymentDate: credit.lastPaymentDate || undefined,
            lastPaymentAmount: credit.lastPaymentAmount || 0,
            nextPaymentDate: credit.nextPaymentDate || undefined,
            nextPaymentAmount: credit.nextPaymentAmount || 0,
            requestId: credit.requestId || undefined
          }));
          
          console.log('Credits convertis:', this.activeCreditsFromService.length);
          this.updateDebtCalculations();
        }
      },
      error: (error: any) => {
        console.error('Erreur chargement credits detailles:', error);
        this.loadRegisteredCredits();
      }
    });
  }

  getRequestStatusText(status: string): string {
    const statusMap: Record<string, string> = {
      'SUBMITTED': 'Soumise',
      'IN_REVIEW': 'En cours',
      'APPROVED': 'Approuvee',
      'REJECTED': 'Rejetee',
      'CANCELLED': 'Annulee'
    };
    return statusMap[status] || status;
  }

  setQuickCreditAmount(percentage: number): void {
    this.quickCredit.amount = Math.round(this.globalStats.eligibleAmount * percentage);
  }

  getAvailableCreditTypes(): CreditType[] {
    return this.creditTypes.filter(type => type.available);
  }

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

  private saveAccountBalance(): void {
    localStorage.setItem(`accountBalance_${this.currentUser?.username}`, JSON.stringify(this.accountBalance));
  }

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

  toggleAccountDetails(): void {
    this.showAccountDetails = !this.showAccountDetails;
  }

  useCredit(amount: number, description: string = 'Utilisation du credit'): void {
    if (amount > this.accountBalance.currentBalance) {
      this.showNotification(`Solde insuffisant. Solde actuel: ${this.formatCurrency(this.accountBalance.currentBalance)}`, 'error');
      return;
    }

    if (amount <= 0) {
      this.showNotification('Le montant doit etre superieur a 0', 'error');
      return;
    }

    this.addTransaction('debit', amount, description);
    this.showNotification(`${this.formatCurrency(amount)} debite de votre compte. Solde restant: ${this.formatCurrency(this.accountBalance.currentBalance)}`, 'success');
  }

  openCustomAmountModal(): void {
    this.customAmount = 0;
    this.customDescription = '';
    this.showCustomAmountModal = true;
  }

  closeCustomAmountModal(): void {
    this.showCustomAmountModal = false;
    this.customAmount = 0;
    this.customDescription = '';
  }

  useCustomAmount(): void {
    if (!this.customAmount || this.customAmount <= 0) {
      this.showNotification('Veuillez saisir un montant valide', 'error');
      return;
    }

    if (this.customAmount > this.accountBalance.currentBalance) {
      this.showNotification(`Solde insuffisant. Solde actuel: ${this.formatCurrency(this.accountBalance.currentBalance)}`, 'error');
      return;
    }

    const description = this.customDescription || `Utilisation personnalisee de ${this.formatCurrency(this.customAmount)}`;
    
    this.useCredit(this.customAmount, description);
    this.closeCustomAmountModal();
  }

  filterTransactions(transactions: AccountTransaction[], type: string): AccountTransaction[] {
    if (!transactions) return [];
    return transactions.filter(transaction => transaction.type === type);
  }

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

  getTransactionIcon(type: 'credit' | 'debit'): string {
    return type === 'credit' ? 'add_circle' : 'remove_circle';
  }

  getTransactionColor(type: 'credit' | 'debit'): string {
    return type === 'credit' ? '#4CAF50' : '#F44336';
  }

  getTimeAgo(dateString: string): string {
    const date = new Date(dateString);
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffMinutes = Math.floor(diffMs / (1000 * 60));
    
    if (diffMinutes < 1) return 'a l\'instant';
    if (diffMinutes < 60) return `il y a ${diffMinutes} min`;
    
    const diffHours = Math.floor(diffMinutes / 60);
    if (diffHours < 24) return `il y a ${diffHours}h`;
    
    const diffDays = Math.floor(diffHours / 24);
    return `il y a ${diffDays} jour${diffDays > 1 ? 's' : ''}`;
  }

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

  checkEligibility(): void {
    if (!this.client) return;

    const isEnterprise = this.client.clientType === 'entreprise';
    
    if (!isEnterprise) {
      const avanceSalaireType = this.creditTypes.find(c => c.id === 'avance_salaire');
      if (avanceSalaireType && this.client.monthlyIncome) {
        avanceSalaireType.maxAmount = Math.min(2000000, Math.floor(this.client.monthlyIncome * 0.7));
        avanceSalaireType.description = `Jusqu'a 70% de votre salaire (max ${this.formatCurrency(avanceSalaireType.maxAmount)})`;
      }
      
      const consoType = this.creditTypes.find(c => c.id === 'consommation_generale');
      if (consoType && this.client.monthlyIncome) {
        consoType.maxAmount = Math.min(this.globalStats.eligibleAmount, 2000000);
        consoType.description = `Pour vos besoins personnels (max ${this.formatCurrency(consoType.maxAmount)})`;
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

  openQuickCreditModal(): void {
    this.quickCredit.amount = Math.floor((this.globalStats?.eligibleAmount || 0) * 0.5);
    const availableTypes = this.getAvailableCreditTypes();
    if (availableTypes.length > 0) {
      this.quickCredit.type = availableTypes[0].id;
    }
    this.showQuickCreditModal = true;
  }

  closeQuickCreditModal(): void {
    this.showQuickCreditModal = false;
  }

  private loadScoreHistory(): void {
    if (!this.currentUser?.username) return;
    
    this.apiProxy.getScoreTrend(this.currentUser.username).subscribe({
      next: (response) => {
        this.scoreHistory = response.recent_transactions?.map((t: any) => ({
          score: t.score || 6.5,
          date: t.date,
          change: t.change || 0.1,
          reason: t.event || t.description || 'Activite automatique'
        })) || [];
        console.log('Historique des scores charge:', this.scoreHistory.length, 'entrees');
      },
      error: (error) => {
        console.warn('Historique non disponible:', error);
        this.scoreHistory = [];
      }
    });
  }

  private startRealTimeScoreMonitoring(userId: number): void {
    console.log('Demarrage monitoring score temps reel pour:', userId);
    
    this.realTimeSubscription = interval(30000).pipe(
      switchMap(() => this.apiProxy.getUserScoring(userId, false)),
      catchError(error => {
        console.error('Erreur monitoring temps reel:', error);
        return [];
      })
    ).subscribe((scoreUpdate: any) => {
      if (scoreUpdate && scoreUpdate.user_id) {
        this.handleRealTimeScoreUpdate(scoreUpdate);
      }
    });

    this.apiProxy.getUserScoring(userId, false).subscribe({
      next: (scoreUpdate: any) => {
        if (scoreUpdate && scoreUpdate.user_id) {
          this.handleRealTimeScoreUpdate(scoreUpdate);
        }
      },
      error: (error) => {
        console.error('Erreur chargement score initial:', error);
      }
    });
  }

  refreshCreditScore(): void {
    if (!this.currentUser?.id) {
      this.showNotification('Utilisateur non connecte', 'error');
      return;
    }

    this.isScoreUpdating = true;
    
    this.apiProxy.recalculateUserScore(this.currentUser.id).subscribe({
      next: (result) => {
        console.log('Score recalcule:', result);
        
        this.globalStats.creditScore = result.score;
        this.globalStats.eligibleAmount = result.eligible_amount;
        this.globalStats.riskLevel = result.risk_level;
        
        this.showNotification('Score mis a jour !', 'success');
        this.isScoreUpdating = false;
      },
      error: (error) => {
        console.error('Erreur recalcul score:', error);
        this.showNotification('Erreur mise a jour score', 'error');
        this.isScoreUpdating = false;
      }
    });
  }

  hasCreditPayments(credit: RegisteredCredit): boolean {
    return (credit.paymentsCount || 0) > 0;
  }

  getPaymentStatusText(credit: RegisteredCredit): string {
    if (credit.isPaid) {
      return 'Entierement paye';
    }
    
    const percentage = credit.percentagePaid || 0;
    if (percentage === 0) {
      return 'Aucun paiement';
    } else if (percentage < 50) {
      return 'En cours de remboursement';
    } else {
      return 'Bientot termine';
    }
  }

  getPaymentStatusColor(credit: RegisteredCredit): string {
    if (credit.isPaid) {
      return '#4CAF50';
    }
    
    const percentage = credit.percentagePaid || 0;
    if (percentage === 0) {
      return '#F44336';
    } else if (percentage < 50) {
      return '#FF9800';
    } else {
      return '#8BC34A';
    }
  }

  triggerFileInput(): void {
    const fileInput = document.querySelector('input[type="file"]') as HTMLInputElement;
    fileInput?.click();
  }

  onFileSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    if (!input || !input.files || input.files.length === 0) return;
    
    const file = input.files[0];
    
    if (!file.type.startsWith('image/')) {
      this.showNotification('Veuillez selectionner un fichier image valide.', 'error');
      return;
    }
    
    if (file.size > 5 * 1024 * 1024) {
      this.showNotification('L\'image depasse la taille maximale de 5 Mo.', 'error');
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
        this.showNotification('Photo de profil mise a jour !', 'success');
      }
    };
    reader.readAsDataURL(file);
  }

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

  private getNotificationIcon(type: string): string {
    switch (type) {
      case 'success': return 'check_circle';
      case 'warning': return 'warning';
      case 'error': return 'error';
      default: return 'info';
    }
  }

  isCreditFullyPaid(credit: RegisteredCredit): boolean {
    return credit.isPaid === true || credit.remainingAmount === 0;
  }

  getCreditStatusColor(credit: RegisteredCredit): string {
    if (this.isCreditFullyPaid(credit)) {
      return '#4CAF50';
    }
    
    const percentage = credit.percentagePaid || 0;
    if (percentage === 0) {
      return '#F44336';
    } else if (percentage < 30) {
      return '#FF5722';
    } else if (percentage < 70) {
      return '#FF9800';
    } else {
      return '#8BC34A';
    }
  }

  getCreditStatusBadge(credit: RegisteredCredit): string {
    if (this.isCreditFullyPaid(credit)) {
      return 'Paye';
    }
    
    const percentage = credit.percentagePaid || 0;
    if (percentage === 0) {
      return 'Non commence';
    } else if (percentage < 30) {
      return 'Debut';
    } else if (percentage < 70) {
      return 'En cours';
    } else {
      return 'Presque termine';
    }
  }

  getCreditProgressInfo(credit: RegisteredCredit): string {
    const paid = credit.totalPaid || 0;
    const total = credit.totalAmount || 0;
    const remaining = credit.remainingAmount || 0;
    
    return `${this.formatCurrency(paid)} paye sur ${this.formatCurrency(total)} (reste: ${this.formatCurrency(remaining)})`;
  }

  getPaymentCount(credit: RegisteredCredit): string {
    const count = credit.paymentsCount || 0;
    return `${count} paiement${count > 1 ? 's' : ''} effectue${count > 1 ? 's' : ''}`;
  }

  getLastPaymentInfo(credit: RegisteredCredit): string {
    if (!credit.lastPaymentDate) {
      return 'Aucun paiement';
    }
    
    const date = new Date(credit.lastPaymentDate);
    const amount = credit.lastPaymentAmount || 0;
    
    return `${this.formatDate(date.toISOString())} - ${this.formatCurrency(amount)}`;
  }

  getDaysUntilDue(credit: RegisteredCredit): number {
    if (!credit.dueDate) return 0;
    
    const now = new Date();
    const due = new Date(credit.dueDate);
    const diffTime = due.getTime() - now.getTime();
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
    
    return diffDays;
  }

  getDaysUntilDueText(credit: RegisteredCredit): string {
    const days = this.getDaysUntilDue(credit);
    
    if (days < 0) {
      return `En retard de ${Math.abs(days)} jour${Math.abs(days) > 1 ? 's' : ''}`;
    } else if (days === 0) {
      return 'Echeance aujourd\'hui';
    } else if (days <= 7) {
      return `${days} jour${days > 1 ? 's' : ''} restant${days > 1 ? 's' : ''}`;
    } else {
      return `${days} jour${days > 1 ? 's' : ''} restant${days > 1 ? 's' : ''}`;
    }
  }

  isCreditOverdue(credit: RegisteredCredit): boolean {
    return this.getDaysUntilDue(credit) < 0 && !this.isCreditFullyPaid(credit);
  }

  private determinePaymentTrend(onTimeRatio: number): string {
    if (onTimeRatio >= 95) return 'excellent';
    if (onTimeRatio >= 85) return 'improving';
    if (onTimeRatio >= 70) return 'stable';
    return 'declining';
  }

  refreshScoreML(): void {
    if (!this.currentUser?.id) return;
    
    this.isScoreUpdating = true;
    
    this.apiProxy.recalculateUserScore(this.currentUser.id).subscribe({
      next: (result) => {
        console.log('Score ML recalcule:', result);
        
        this.globalStats.creditScore = result.score;
        this.globalStats.eligibleAmount = result.eligible_amount;
        this.globalStats.riskLevel = result.risk_level;
        
        this.showNotification(
          `Score mis a jour: ${result.score}/10 (${result.model_used})`,
          'success'
        );
        
        this.isScoreUpdating = false;
      },
      error: (error) => {
        console.error('Erreur recalcul ML:', error);
        this.showNotification('Erreur mise a jour score', 'error');
        this.isScoreUpdating = false;
      }
    });
  }

  getTotalActiveDebt(): number {
    return this.activeCreditsFromService
      .filter(c => c.status === 'active')
      .reduce((sum, c) => sum + c.remainingAmount, 0);
  }

  getActiveCreditCount(): number {
    return this.activeCreditsFromService.filter(c => c.status === 'active').length;
  }

  getNewTotalDebtWithQuickCredit(): number {
    const currentDebt = this.getTotalActiveDebt();
    const newCreditTotal = this.quickCredit.amount + (this.quickCredit.amount * 0.015);
    return currentDebt + newCreditTotal;
  }

  getNewDebtRatioWithQuickCredit(): number {
    const newTotalDebt = this.getNewTotalDebtWithQuickCredit();
    const monthlyIncome = this.currentUser?.monthlyIncome || 1;
    return (newTotalDebt / monthlyIncome) * 100;
  }

  isNewDebtRatioHigh(): boolean {
    return this.getNewDebtRatioWithQuickCredit() > 70;
  }

  isNewDebtRatioCritical(): boolean {
    return this.getNewDebtRatioWithQuickCredit() > 50;
  }

  getDebtRatioClasses(): any {
    return {
      'warning': this.isNewDebtRatioCritical(),
      'danger': this.isNewDebtRatioHigh()
    };
  }

  shouldShowHighDebtWarning(): boolean {
    return this.quickCredit.amount > 0 && this.isNewDebtRatioHigh();
  }

  shouldShowMultipleCreditInfo(): boolean {
    return this.creditRestrictions && this.creditRestrictions.activeCreditCount >= 1;
  }

  formatDate(dateString: string): string {
    if (!dateString) return '';
    const date = new Date(dateString);
    return date.toLocaleDateString('fr-FR', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric'
    });
  }

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

  getCreditReimbursementPercentage(credit: RegisteredCredit): number {
    if (!credit || credit.totalAmount === 0) return 0;
    return ((credit.totalAmount - credit.remainingAmount) / credit.totalAmount) * 100;
  }

  isActiveCreditCountHigh(): boolean {
    return this.getActiveCreditCount() >= 2;
  }

  getActiveCreditCountClasses(): any {
    return {
      'warning': this.isActiveCreditCountHigh()
    };
  }

  getCurrentDebtRatioClasses(): any {
    const currentRatio = this.creditRestrictions?.debtRatio || 0;
    return {
      'warning': currentRatio > 0.5,
      'danger': currentRatio > 0.7
    };
  }

  getCurrentDebtRatioPercentage(): number {
    const currentRatio = this.creditRestrictions?.debtRatio || 0;
    return currentRatio * 100;
  }

  formatInterestRate(rate: number): string {
    return (rate * 100).toFixed(1);
  }

  shouldShowScoreDebtWarning(): boolean {
    return this.currentUser ? this.creditManagementService.calculateDebtRatio(this.currentUser) > 0.5 : false;
  }

  getFormattedDebtRatioFromService(): string {
    if (!this.currentUser) return '0.0';
    return (this.creditManagementService.calculateDebtRatio(this.currentUser) * 100).toFixed(1);
  }

  isCreditActive(credit: RegisteredCredit): boolean {
    return credit.status === 'active';
  }

  getAdditionalCreditsCount(): number {
    return Math.max(0, this.activeCreditsFromService.length - 3);
  }

  hasAdditionalCredits(): boolean {
    return this.activeCreditsFromService.length > 3;
  }

  getDisplayedCredits(): RegisteredCredit[] {
    return this.activeCreditsFromService.slice(0, 3);
  }

  getNewCreditCountAfterApplication(): number {
    return (this.creditRestrictions?.activeCreditCount || 0) + 1;
  }

  isRestrictedByMaxCredits(): boolean {
    return this.getActiveCreditCount() >= 2;
  }

  isRestrictedByDebtRatio(): boolean {
    return (this.creditRestrictions?.totalActiveDebt || 0) / (this.currentUser?.monthlyIncome || 1) > 0.7;
  }

  isScoreBelowThreshold(): boolean {
    return this.getCurrentScore() < 7;
  }


  toggleScoreHistory(): void {
    this.showScoreHistory = !this.showScoreHistory;
    if (this.showScoreHistory && this.scoreHistory.length === 0) {
      this.loadScoreHistory();
    }
  }

  formatScoreHistoryDate(dateString: string): string {
    const date = new Date(dateString);
    return date.toLocaleDateString('fr-FR', {
      day: '2-digit',
      month: '2-digit',
      hour: '2-digit',
      minute: '2-digit'
    });
  }


  applyForCredit(creditType: CreditType): void {
    if (creditType.available) {
      this.router.navigate(['/credit-request'], { 
        queryParams: { type: creditType.id } 
      });
    } else {
      this.showIneligibilityMessage(creditType);
    }
  }

  private showIneligibilityMessage(creditType: CreditType): void {
    let message = `Vous n'etes pas eligible pour le ${creditType.name}.`;
    
    if (creditType.id === 'investissement') {
      message += '\nCe credit est reserve aux entreprises.';
    } else if (creditType.id === 'tontine') {
      message += '\nVous devez etre membre actif d\'une tontine.';
    } else if (creditType.id === 'retraite') {
      message += '\nCe credit est reserve aux retraites CNSS/CPPF.';
    }
    
    this.showNotification(message, 'warning');
  }

  getNextPaymentDate(): Date | null {
    const activeCreditsSorted = [...this.activeCredits]
      .filter(c => c.status === 'active')
      .sort((a, b) => a.nextPayment.getTime() - b.nextPayment.getTime());
    return activeCreditsSorted.length > 0 ? activeCreditsSorted[0].nextPayment : null;
  }

  getTotalMonthlyPayment(): number {
    return this.activeCredits
      .filter(c => c.status === 'active')
      .reduce((sum, credit) => sum + credit.nextPaymentAmount, 0);
  }

  viewCreditDetails(credit: ActiveCredit): void {
    if (!credit) return;

    const modal = document.createElement('div');
    modal.className = 'credit-details-modal';
    modal.innerHTML = `
      <div class="modal-backdrop" onclick="this.parentElement.remove()"></div>
      <div class="modal-content">
        <div class="modal-header">
          <h3>Details du credit</h3>
          <button class="close-btn" onclick="this.parentElement.parentElement.parentElement.remove()">
            <i class="material-icons">close</i>
          </button>
        </div>
        <div class="modal-body">
          <div class="detail-row">
            <span class="label">Type de credit:</span>
            <span class="value">${credit.type}</span>
          </div>
          <div class="detail-row">
            <span class="label">Montant emprunte:</span>
            <span class="value">${this.formatCurrency(credit.amount)}</span>
          </div>
          <div class="detail-row">
            <span class="label">Montant restant:</span>
            <span class="value">${this.formatCurrency(credit.remainingAmount)}</span>
          </div>
          <div class="detail-row">
            <span class="label">Prochaine echeance:</span>
            <span class="value">${credit.nextPayment.toLocaleDateString('fr-FR')}</span>
          </div>
          <div class="detail-row">
            <span class="label">Montant a payer:</span>
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

  // Ajouter ces methodes dans profile.component.ts

getModelType(): string {
  if (!this.realTimeScore) {
    return 'Regles metier';
  }
  
  const modelType = this.realTimeScore['model_type'] || this.realTimeScore['model_used'];
  
  if (modelType === 'random_forest') {
    return 'Random Forest ML';
  }
  
  return 'Regles metier';
}

getModelConfidence(): number {
  if (!this.realTimeScore) {
    return 0;
  }
  
  const confidence = this.realTimeScore['model_confidence'] || 0;
  return Math.round(Number(confidence) * 100);
}

hasRecommendations(): boolean {
  return !!(
    this.realTimeScore && 
    this.realTimeScore.recommendations && 
    Array.isArray(this.realTimeScore.recommendations) &&
    this.realTimeScore.recommendations.length > 0
  );
}

getRecommendations(): string[] {
  if (!this.realTimeScore || !this.realTimeScore.recommendations) {
    return [];
  }
  return this.realTimeScore.recommendations;
}

hasPaymentHistory(): boolean {
  return !!(
    this.paymentAnalysis && 
    this.paymentAnalysis.total_payments && 
    this.paymentAnalysis.total_payments > 0
  );
}

getPaymentAnalysisValue(key: string): any {
  if (!this.paymentAnalysis) {
    return key === 'reliability' ? 'N/A' : 0;
  }
  
  const value = this.paymentAnalysis[key];
  
  if (value === null || value === undefined) {
    return key === 'reliability' ? 'N/A' : 0;
  }
  
  return value;
}

getEligibleAmount(): number {
  // Priorite 1: depuis realTimeScore
  if (this.realTimeScore && this.realTimeScore['eligible_amount']) {
    return Number(this.realTimeScore['eligible_amount']) || 0;
  }
  
  // Priorite 2: depuis globalStats
  if (this.globalStats && this.globalStats.eligibleAmount) {
    return Number(this.globalStats.eligibleAmount) || 0;
  }
  
  return 0;
}

getDisplayRecommendations(): string[] {
  if (this.hasRecommendations()) {
    return this.getRecommendations();
  }
  
  // Recommendations par defaut
  return [
    'Effectuez vos paiements a temps pour ameliorer votre score',
    'Commencez par des petits montants pour construire votre historique',
    'Evitez d\'avoir plusieurs credits actifs simultanement',
    'Maintenez un ratio d\'endettement inferieur a 70%'
  ];
}

getScoreProgressPercentage(): number {
  const score = this.getCurrentScore();
  return (score / 10) * 100;
}

hasRealTimeScore(): boolean {
  return this.realTimeScore !== null && this.realTimeScore !== undefined;
}

getPaymentTrend(): string {
  const trend = this.getPaymentAnalysis()?.trend || 'stable';
  switch (trend) {
    case 'improving': return 'En amelioration';
    case 'declining': return 'En baisse';
    default: return 'Stable';
  }
}

getPaymentTrendIcon(): string {
  const trend = this.getPaymentAnalysis()?.trend || 'stable';
  switch (trend) {
    case 'improving': return 'trending_up';
    case 'declining': return 'trending_down';
    default: return 'trending_flat';
  }
}

getOnTimePaymentRatio(): number {
  const analysis = this.getPaymentAnalysis();
  if (!analysis) return 0;
  
  const ratio = analysis.on_time_ratio || 
                (analysis.on_time_payments / Math.max(analysis.total_payments, 1)) || 0;
  
  return Number(ratio) * 100;
}

getPaymentAnalysis(): any {
  return this.realTimeScore?.payment_analysis || this.paymentAnalysis;
}

getScoreFactors(): any[] {
  return this.realTimeScore?.factors || [];
}
}