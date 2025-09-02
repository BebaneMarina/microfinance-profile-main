import { Component, OnInit, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ReactiveFormsModule, FormsModule, FormBuilder, FormGroup, Validators } from '@angular/forms';
import { RouterModule, Router, ActivatedRoute } from '@angular/router';
import { Subject } from 'rxjs';
import { takeUntil, debounceTime, distinctUntilChanged } from 'rxjs/operators';
import { EnhancedCreditSimulatorService } from '../../services/credit-simulator.service';
import { NotificationService } from '../../services/notification.service';
import { AnalyticsService } from '../../services/analytics.service';

interface QuickSimulationResult {
  estimatedCapacity: number;
  monthlyPayment: number;
  totalInterest: number;
  effectiveRate: number;
  recommendations: string[];
}

interface DailyRates {
  consommation: number;
  auto: number;
  immobilier: number;
  travaux: number;
  professionnel: number;
}

interface StatisticsData {
  satisfiedClients: number;
  financedCredits: string;
  clientRating: number;
  averageResponse: string;
}

interface AdvantageItem {
  icon: string;
  title: string;
  description: string;
  color: string;
}

interface SimulatorOption {
  id: string;
  title: string;
  description: string;
  icon: string;
  color: string;
  features: string[];
  route: string;
}

@Component({
  selector: 'app-simulator-home',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule, FormsModule, RouterModule],
  templateUrl: './simulator-home.component.html',
  styleUrls: ['./simulator-home.component.scss']
})
export class SimulatorHomeComponent implements OnInit, OnDestroy {
  quickSimForm!: FormGroup;
  quickResult: QuickSimulationResult | null = null;
  isQuickCalculating = false;
  showQuickSimulator = false;
  activeSimulator = '';

  // Données de l'interface
  dailyRates: DailyRates = {
    consommation: 8.5,
    auto: 6.9,
    immobilier: 5.2,
    travaux: 7.1,
    professionnel: 9.2
  };

  statistics: StatisticsData = {
    satisfiedClients: 50000,
    financedCredits: '2.5M€',
    clientRating: 4.8,
    averageResponse: '24h'
  };

  simulatorOptions: SimulatorOption[] = [
    {
      id: 'capacity',
      title: 'Capacité d\'emprunt',
      description: 'Découvrez combien vous pouvez emprunter selon vos revenus',
      icon: 'trending-up',
      color: 'from-blue-500 to-blue-600',
      features: [
        'Calcul instantané',
        'Graphique d\'évolution',
        'Recommandations personnalisées'
      ],
      route: '/borrowing-capacity' // corrigé
    },
    {
      id: 'payment',
      title: 'Calcul de mensualités',
      description: 'Estimez vos mensualités selon le montant et la durée',
      icon: 'calculator',
      color: 'from-green-500 to-green-600',
      features: [
        'Tableau d\'amortissement',
        'Visualisation graphique',
        'Optimisation durée'
      ],
      route: '/payment-calculator' // corrigé
    },
    {
      id: 'rate',
      title: 'Taux personnalisé',
      description: 'Obtenez un taux adapté à votre profil',
      icon: 'dollar-sign',
      color: 'from-purple-500 to-purple-600',
      features: [
        'Analyse du profil',
        'Taux en temps réel',
        'Comparaison banques'
      ],
      route: '/simulators/rate-simulator'
    },
    {
      id: 'comparator',
      title: 'Comparateur multi-banques',
      description: 'Comparez les offres de plusieurs établissements',
      icon: 'bar-chart',
      color: 'from-orange-500 to-orange-600',
      features: [
        'Comparaison instantanée',
        'Offres personnalisées',
        'Suivi des demandes'
      ],
      route: '/comparateur' // corrigé
    }
  ];

  advantages: AdvantageItem[] = [
    {
      icon: 'shield',
      title: 'Sécurisé et confidentiel',
      description: 'Vos données sont protégées et ne sont jamais partagées',
      color: 'blue'
    },
    {
      icon: 'clock',
      title: 'Réponse en 24h',
      description: 'Obtenez une réponse rapide de nos partenaires bancaires',
      color: 'green'
    },
    {
      icon: 'check-circle',
      title: 'Sans engagement',
      description: 'Simulez gratuitement sans obligation d\'achat',
      color: 'purple'
    }
  ];

  // Configuration des types de crédit
  creditTypes = [
    { id: 'immobilier', name: 'Crédit Immobilier', avgRate: 5.2 },
    { id: 'consommation', name: 'Crédit Consommation', avgRate: 8.5 },
    { id: 'auto', name: 'Crédit Auto', avgRate: 6.9 },
    { id: 'travaux', name: 'Crédit Travaux', avgRate: 7.1 },
    { id: 'professionnel', name: 'Crédit Pro', avgRate: 9.2 }
  ];

  // Montants prédéfinis
  amountPresets = [
    { amount: 1000000, label: '1M FCFA' },
    { amount: 5000000, label: '5M FCFA' },
    { amount: 10000000, label: '10M FCFA' },
    { amount: 25000000, label: '25M FCFA' },
    { amount: 50000000, label: '50M FCFA' }
  ];

  private destroy$ = new Subject<void>();

  constructor(
    private fb: FormBuilder,
    private router: Router,
    private route: ActivatedRoute,
    private simulatorService: EnhancedCreditSimulatorService,
    private notificationService: NotificationService,
    private analyticsService: AnalyticsService
  ) {}

  ngOnInit(): void {
    this.initializeQuickForm();
    this.setupFormListeners();
    this.trackPageView();
    this.loadDailyRates();
    this.handleUrlParameters();
  }

  ngOnDestroy(): void {
    this.destroy$.next();
    this.destroy$.complete();
  }

  private initializeQuickForm(): void {
    this.quickSimForm = this.fb.group({
      creditType: ['immobilier', Validators.required],
      amount: [10000000, [Validators.required, Validators.min(100000)]],
      duration: [240, [Validators.required, Validators.min(12), Validators.max(360)]],
      monthlyIncome: [750000, [Validators.required, Validators.min(200000)]],
      currentDebts: [0, [Validators.min(0)]]
    });
  }

  private setupFormListeners(): void {
    // Calcul automatique lors des changements
    this.quickSimForm.valueChanges
      .pipe(
        debounceTime(500),
        distinctUntilChanged(),
        takeUntil(this.destroy$)
      )
      .subscribe(() => {
        if (this.quickSimForm.valid && this.showQuickSimulator) {
          this.performQuickCalculation();
        }
      });

    // Mise à jour du taux selon le type de crédit
    this.quickSimForm.get('creditType')?.valueChanges
      .pipe(takeUntil(this.destroy$))
      .subscribe(creditType => {
        this.updateRateForCreditType(creditType);
      });
  }

  private handleUrlParameters(): void {
    this.route.queryParams
      .pipe(takeUntil(this.destroy$))
      .subscribe(params => {
        if (params['simulator']) {
          this.scrollToSimulators();
        }
        if (params['quicksim'] === 'true') {
          this.showQuickSimulator = true;
        }
      });
  }

  private loadDailyRates(): void {
    // Simulation du chargement des taux du jour
    // En production, ceci ferait appel à un service API
    this.simulatorService.getDailyRates()
      .pipe(takeUntil(this.destroy$))
      .subscribe({
        next: (rates: DailyRates) => {
          this.dailyRates = rates;
        },
        error: (error: any) => {
          console.warn('Impossible de charger les taux du jour:', error);
        }
      });
  }

  // Méthodes de navigation
  scrollToSimulators(): void {
    const element = document.getElementById('simulateurs');
    if (element) {
      element.scrollIntoView({ 
        behavior: 'smooth',
        block: 'start'
      });
    }
  }

  // Navigation vers les simulateurs - LIENS CORRIGÉS
  navigateToCapacitySimulator(): void {
    this.trackSimulatorNavigation('borrowing-capacity');
    this.router.navigate(['/borrowing-capacity']);
  }

  navigateToPaymentSimulator(): void {
    this.trackSimulatorNavigation('payment-calculator');
    this.router.navigate(['/payment-calculator']);
  }

  navigateToRateSimulator(): void {
    this.trackSimulatorNavigation('rate');
    this.router.navigate(['/simulators/rate-simulator']);
  }

  navigateToComparator(): void {
    this.trackSimulatorNavigation('comparateur');
    this.router.navigate(['/comparateur']);
  }

  // Méthode générique pour naviguer vers n'importe quel simulateur
  navigateToSimulator(simulatorId: string): void {
    const simulator = this.simulatorOptions.find(sim => sim.id === simulatorId);
    if (simulator) {
      this.trackSimulatorNavigation(simulatorId);
      this.router.navigate([simulator.route]);
    }
  }

  // Simulation rapide
  toggleQuickSimulator(): void {
    this.showQuickSimulator = !this.showQuickSimulator;
    
    if (this.showQuickSimulator && this.quickSimForm.valid) {
      this.performQuickCalculation();
    }
    
    this.analyticsService.trackEvent('quick_simulator_toggled', {
      action: this.showQuickSimulator ? 'opened' : 'closed'
    });
  }

  performQuickCalculation(): void {
    if (this.isQuickCalculating || this.quickSimForm.invalid) return;

    this.isQuickCalculating = true;

    try {
      const formData = this.quickSimForm.value;
      const creditType = this.creditTypes.find(type => type.id === formData.creditType);
      const interestRate = creditType?.avgRate || 6.5;

      // Calcul de la capacité d'emprunt basique
      const totalIncome = formData.monthlyIncome;
      const maxDebtRatio = 33;
      const maxMonthlyPayment = (totalIncome * maxDebtRatio / 100) - formData.currentDebts;

      if (maxMonthlyPayment <= 0) {
        this.quickResult = null;
        this.notificationService.showWarning('Capacité d\'emprunt insuffisante avec vos revenus actuels');
        return;
      }

      // Calcul de la mensualité demandée
      const monthlyRate = interestRate / 100 / 12;
      const requestedMonthlyPayment = this.calculateMonthlyPayment(
        formData.amount,
        monthlyRate,
        formData.duration
      );

      // Calcul de la capacité maximale
      const maxCapacity = this.calculateLoanAmount(maxMonthlyPayment, monthlyRate, formData.duration);

      // Intérêts totaux
      const totalInterest = (requestedMonthlyPayment * formData.duration) - formData.amount;

      // Taux effectif simplifié
      const effectiveRate = ((totalInterest / formData.amount) / (formData.duration / 12)) * 100;

      // Recommandations
      const recommendations = this.generateQuickRecommendations(
        formData,
        requestedMonthlyPayment,
        maxMonthlyPayment,
        maxCapacity
      );

      this.quickResult = {
        estimatedCapacity: Math.round(maxCapacity),
        monthlyPayment: Math.round(requestedMonthlyPayment),
        totalInterest: Math.round(totalInterest),
        effectiveRate: Math.round(effectiveRate * 100) / 100,
        recommendations
      };

      this.trackQuickCalculation();

    } catch (error) {
      console.error('Erreur calcul rapide:', error);
      this.notificationService.showError('Erreur lors du calcul rapide');
    } finally {
      this.isQuickCalculating = false;
    }
  }

  private calculateMonthlyPayment(amount: number, monthlyRate: number, duration: number): number {
    if (monthlyRate === 0) {
      return amount / duration;
    }
    
    const factor = Math.pow(1 + monthlyRate, duration);
    return amount * (monthlyRate * factor) / (factor - 1);
  }

  private calculateLoanAmount(monthlyPayment: number, monthlyRate: number, duration: number): number {
    if (monthlyRate === 0) {
      return monthlyPayment * duration;
    }
    
    const factor = Math.pow(1 + monthlyRate, duration);
    return monthlyPayment * (factor - 1) / (monthlyRate * factor);
  }

  private generateQuickRecommendations(
    formData: any,
    requestedPayment: number,
    maxPayment: number,
    maxCapacity: number
  ): string[] {
    const recommendations: string[] = [];

    if (requestedPayment > maxPayment) {
      recommendations.push('Le montant demandé dépasse votre capacité d\'emprunt');
      recommendations.push(`Montant maximum conseillé: ${this.formatCurrency(maxCapacity)}`);
    } else if (requestedPayment < maxPayment * 0.7) {
      recommendations.push('Vous pourriez emprunter davantage si nécessaire');
      recommendations.push('Votre profil permet des conditions favorables');
    }

    if (formData.duration > 240) {
      recommendations.push('Réduire la durée diminuerait le coût total');
    }

    if (formData.currentDebts > formData.monthlyIncome * 0.1) {
      recommendations.push('Réduire vos charges actuelles améliorerait votre capacité');
    }

    if (recommendations.length === 0) {
      recommendations.push('Votre projet semble parfaitement adapté à votre situation');
      recommendations.push('Vous pouvez procéder à une simulation détaillée');
    }

    return recommendations;
  }

  private updateRateForCreditType(creditType: string): void {
    const selectedType = this.creditTypes.find(type => type.id === creditType);
    if (selectedType) {
      // Mise à jour visuelle du taux dans l'interface
      this.dailyRates = { ...this.dailyRates };
    }
  }

  // Méthodes pour les presets
  setPresetAmount(amount: number): void {
    this.quickSimForm.patchValue({ amount });
    this.analyticsService.trackEvent('preset_amount_selected', { amount });
  }

  // Méthodes utilitaires
  formatCurrency(amount: number): string {
    return new Intl.NumberFormat('fr-FR', {
      style: 'currency',
      currency: 'XAF',
      minimumFractionDigits: 0
    }).format(amount);
  }

  formatPercent(value: number): string {
    return `${value.toFixed(1)}%`;
  }

  formatNumber(value: number): string {
    if (value >= 1000000) {
      return `${(value / 1000000).toFixed(1)}M`;
    } else if (value >= 1000) {
      return `${(value / 1000).toFixed(0)}K`;
    }
    return value.toString();
  }

  // Validation du formulaire
  hasError(controlName: string): boolean {
    const control = this.quickSimForm.get(controlName);
    return !!(control?.errors && control?.touched);
  }

  getErrorMessage(controlName: string): string {
    const control = this.quickSimForm.get(controlName);
    if (!control?.errors) return '';

    const errors = control.errors;
    
    if (errors['required']) return 'Ce champ est requis';
    if (errors['min']) return `Valeur minimum: ${this.formatCurrency(errors['min'].min)}`;
    if (errors['max']) return `Valeur maximum: ${this.formatCurrency(errors['max'].max)}`;
    
    return 'Valeur invalide';
  }

  // Méthodes pour les couleurs et styles
  getColorClass(color: string): string {
    const colors = {
      blue: 'text-blue-600 bg-blue-100',
      green: 'text-green-600 bg-green-100',
      purple: 'text-purple-600 bg-purple-100',
      yellow: 'text-yellow-600 bg-yellow-100',
      red: 'text-red-600 bg-red-100',
      orange: 'text-orange-600 bg-orange-100'
    };
    return colors[color as keyof typeof colors] || colors.blue;
  }

  getGradientClass(gradient: string): string {
    return `bg-gradient-to-br ${gradient}`;
  }

  // Méthodes d'animation et interaction
  onSimulatorCardHover(simulatorId: string): void {
    this.activeSimulator = simulatorId;
  }

  onSimulatorCardLeave(): void {
    this.activeSimulator = '';
  }

  // Actions sociales et partage
  shareResults(): void {
    if (!this.quickResult) return;

    const shareText = `Ma simulation rapide sur Bamboo: Capacité d'emprunt ${this.formatCurrency(this.quickResult.estimatedCapacity)}`;
    
    if (navigator.share) {
      navigator.share({
        title: 'Simulation Crédit - Bamboo',
        text: shareText,
        url: window.location.href
      });
    } else {
      navigator.clipboard.writeText(shareText).then(() => {
        this.notificationService.showSuccess('Résultats copiés dans le presse-papier');
      });
    }
  }

  // Méthodes d'exportation
  startDetailedSimulation(): void {
    if (!this.quickResult) return;

    const formData = this.quickSimForm.value;
    const queryParams = {
      creditType: formData.creditType,
      amount: formData.amount,
      duration: formData.duration,
      monthlyIncome: formData.monthlyIncome,
      currentDebts: formData.currentDebts,
      from: 'quick_sim'
    };

    // Redirection vers le simulateur détaillé approprié
    if (formData.amount <= this.quickResult.estimatedCapacity) {
      this.router.navigate(['/payment-calculator'], { queryParams });
    } else {
      this.router.navigate(['/borrowing-capacity'], { queryParams });
    }
  }

  // Contact et support
  contactSupport(): void {
    this.analyticsService.trackEvent('contact_support_clicked', {
      source: 'home_page'
    });
    // Redirection vers la page de contact ou ouverture du chat
    this.router.navigate(['/contact']);
  }

  // Méthodes d'analyse et tracking
  private trackPageView(): void {
    this.analyticsService.trackPageView('simulator_home', {
      page_title: 'Accueil Simulateurs - Bamboo Credit'
    });
  }

  private trackSimulatorNavigation(simulatorType: string): void {
    this.analyticsService.trackEvent('simulator_navigation', {
      simulator_type: simulatorType,
      source: 'home_page'
    });
  }

  private trackQuickCalculation(): void {
    if (!this.quickResult) return;

    this.analyticsService.trackEvent('quick_calculation_completed', {
      credit_type: this.quickSimForm.get('creditType')?.value,
      requested_amount: this.quickSimForm.get('amount')?.value,
      estimated_capacity: this.quickResult.estimatedCapacity,
      monthly_payment: this.quickResult.monthlyPayment
    });
  }

  // Getters pour le template
  get isQuickFormValid(): boolean {
    return this.quickSimForm.valid;
  }

  get canStartDetailedSim(): boolean {
    return !!this.quickResult && this.quickResult.estimatedCapacity > 0;
  }

  get quickSimulationFeasible(): boolean {
    if (!this.quickResult) return false;
    const requestedAmount = this.quickSimForm.get('amount')?.value || 0;
    return requestedAmount <= this.quickResult.estimatedCapacity;
  }

  get dailyRatesList(): Array<{key: string, label: string, rate: number, color: string}> {
    return [
      { key: 'consommation', label: 'Crédit Conso', rate: this.dailyRates.consommation, color: 'blue' },
      { key: 'auto', label: 'Crédit Auto', rate: this.dailyRates.auto, color: 'green' },
      { key: 'immobilier', label: 'Crédit Immo', rate: this.dailyRates.immobilier, color: 'purple' }
    ];
  }

  get statisticsArray(): Array<{icon: string, value: string, label: string, color: string}> {
    return [
      { icon: 'users', value: `${this.formatNumber(this.statistics.satisfiedClients)}+`, label: 'Clients satisfaits', color: 'blue' },
      { icon: 'trending-up', value: this.statistics.financedCredits, label: 'Crédits financés', color: 'green' },
      { icon: 'star', value: `${this.statistics.clientRating}/5`, label: 'Note client', color: 'yellow' },
      { icon: 'clock', value: this.statistics.averageResponse, label: 'Réponse moyenne', color: 'purple' }
    ];
  }

  // Méthodes pour l'accessibilité
  getAriaLabel(simulator: SimulatorOption): string {
    return `Accéder au simulateur ${simulator.title}. ${simulator.description}`;
  }

  // Méthodes pour les animations
  onEnterViewport(element: HTMLElement): void {
    element.classList.add('fade-in');
  }

  // Méthodes pour les données dynamiques
  refreshRates(): void {
    this.loadDailyRates();
    this.notificationService.showInfo('Taux actualisés');
  }

  // Gestion des erreurs réseau
  private handleNetworkError(error: any): void {
    console.error('Erreur réseau:', error);
    this.notificationService.showWarning('Connexion limitée - certaines données peuvent ne pas être à jour');
  }
}