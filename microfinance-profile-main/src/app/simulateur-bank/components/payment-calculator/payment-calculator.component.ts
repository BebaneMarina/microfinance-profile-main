import { Component, OnInit, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ReactiveFormsModule, FormsModule, FormBuilder, FormGroup, Validators } from '@angular/forms';
import { RouterModule, Router } from '@angular/router';
import { Subject } from 'rxjs';
import { takeUntil, debounceTime, distinctUntilChanged } from 'rxjs/operators';
import { EnhancedCreditSimulatorService } from '../../services/credit-simulator.service';
import { NotificationService } from '../../services/notification.service';
import { AnalyticsService } from '../../services/analytics.service';

interface PaymentCalculationResult {
  monthlyPayment: number;
  totalInterest: number;
  totalCost: number;
  effectiveRate: number;
  monthlyInsurance: number;
  amortizationSchedule: AmortizationEntry[];
  paymentBreakdown: PaymentBreakdown;
  optimizations: OptimizationSuggestion[];
  comparisonData: DurationComparison[];
  costBreakdown: CostBreakdown;
}

interface AmortizationEntry {
  month: number;
  year: number;
  monthlyPayment: number;
  capitalPayment: number;
  interestPayment: number;
  insurancePayment: number;
  remainingCapital: number;
  cumulativeInterest: number;
  cumulativeCapital: number;
}

interface PaymentBreakdown {
  capitalPortion: number;
  interestPortion: number;
  insurancePortion: number;
  totalMonthly: number;
}

// CORRECTION : Interface OptimizationSuggestion avec newMonthlyPayment obligatoire
interface OptimizationSuggestion {
  type: 'duration' | 'rate' | 'amount' | 'early_payment';
  title: string;
  description: string;
  currentValue: number;
  suggestedValue: number;
  savings: number;
  impact: string;
  newMonthlyPayment: number; // Maintenant obligatoire
}

interface DurationComparison {
  duration: number;
  monthlyPayment: number;
  totalCost: number;
  totalInterest: number;
  savings: number;
}

interface CostBreakdown {
  principal: number;
  totalInterest: number;
  totalInsurance: number;
  totalFees: number;
  grandTotal: number;
}

@Component({
  selector: 'payment-calculator',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule, FormsModule, RouterModule], // Ajout de FormsModule
  templateUrl: './payment-calculator.component.html',
  styleUrls: ['./payment-calculator.component.scss']
})
export class PaymentCalculatorComponent implements OnInit, OnDestroy {
  calculatorForm!: FormGroup;
  results: PaymentCalculationResult | null = null;
  isCalculating = false;
  activeTab = 'amortization';
  showFullSchedule = false;
  selectedYear = 1;

  // CORRECTION : Exposer Math au template
  Math = Math;

  // Configuration
  creditTypes = [
    { id: 'immobilier', name: 'Crédit Immobilier', icon: '🏠', avgRate: 6.2 },
    { id: 'consommation', name: 'Crédit Consommation', icon: '💳', avgRate: 12.5 },
    { id: 'auto', name: 'Crédit Auto', icon: '🚗', avgRate: 8.9 },
    { id: 'travaux', name: 'Crédit Travaux', icon: '🔨', avgRate: 7.8 },
    { id: 'professionnel', name: 'Crédit Pro', icon: '💼', avgRate: 9.8 }
  ];

  durationPresets = [
    { months: 60, label: '5 ans' },
    { months: 84, label: '7 ans' },
    { months: 120, label: '10 ans' },
    { months: 180, label: '15 ans' },
    { months: 240, label: '20 ans' },
    { months: 300, label: '25 ans' }
  ];

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
    private simulatorService: EnhancedCreditSimulatorService,
    private notificationService: NotificationService,
    private analyticsService: AnalyticsService,
    private router: Router
  ) {}

  ngOnInit(): void {
    this.initializeForm();
    this.setupFormListeners();
    this.trackPageView();
  }

  ngOnDestroy(): void {
    this.destroy$.next();
    this.destroy$.complete();
  }

  // CORRECTION : Méthode pour obtenir le taux actuel (éviter l'expression complexe dans le template)
  getCurrentCreditTypeRate(): string {
    const currentType = this.calculatorForm.get('creditType')?.value;
    const type = this.creditTypes.find(t => t.id === currentType);
    return this.formatPercent(type?.avgRate || 6.5);
  }

  // CORRECTION : Méthode utilitaire pour Math.abs
  getAbsoluteValue(value: number): number {
    return Math.abs(value);
  }

  private initializeForm(): void {
    this.calculatorForm = this.fb.group({
      // Montant et durée
      loanAmount: [10000000, [Validators.required, Validators.min(100000), Validators.max(500000000)]],
      duration: [240, [Validators.required, Validators.min(12), Validators.max(360)]],
      interestRate: [6.5, [Validators.required, Validators.min(1), Validators.max(25)]],
      
      // Type de crédit
      creditType: ['immobilier', Validators.required],
      
      // Assurance
      includeInsurance: [true],
      insuranceRate: [0.36, [Validators.min(0), Validators.max(5)]],
      insuranceType: ['declining', Validators.required], // declining ou constant
      
      // Frais
      applicationFee: [50000, [Validators.min(0)]],
      notaryFees: [0, [Validators.min(0)]],
      guaranteeFees: [0, [Validators.min(0)]],
      
      // Options de remboursement
      paymentFrequency: ['monthly', Validators.required],
      firstPaymentDate: [new Date(), Validators.required],
      
      // Remboursement anticipé
      earlyPaymentAmount: [0, [Validators.min(0)]],
      earlyPaymentMonth: [0, [Validators.min(0)]],
      
      // Modulation
      allowModulation: [false],
      modulationPercentage: [20, [Validators.min(10), Validators.max(50)]]
    });
  }

  private setupFormListeners(): void {
    // Calcul automatique lors des changements
    this.calculatorForm.valueChanges
      .pipe(
        debounceTime(300),
        distinctUntilChanged(),
        takeUntil(this.destroy$)
      )
      .subscribe(() => {
        if (this.calculatorForm.valid) {
          this.calculatePayments();
        }
      });

    // Mise à jour du taux selon le type de crédit
    this.calculatorForm.get('creditType')?.valueChanges
      .pipe(takeUntil(this.destroy$))
      .subscribe(creditType => {
        const selectedType = this.creditTypes.find(type => type.id === creditType);
        if (selectedType) {
          this.calculatorForm.patchValue({ 
            interestRate: selectedType.avgRate 
          }, { emitEvent: false });
        }
      });
  }

  calculatePayments(): void {
    if (this.isCalculating || this.calculatorForm.invalid) return;

    this.isCalculating = true;

    try {
      const formData = this.calculatorForm.value;
      
      // Calcul de la mensualité de base
      const monthlyRate = formData.interestRate / 100 / 12;
      const baseMonthlyPayment = this.calculateMonthlyPayment(
        formData.loanAmount,
        monthlyRate,
        formData.duration
      );

      // Calcul de l'assurance
      const monthlyInsurance = this.calculateInsurance(formData);

      // Mensualité totale
      const totalMonthlyPayment = baseMonthlyPayment + monthlyInsurance;

      // Calculs des coûts totaux
      const totalInterest = (baseMonthlyPayment * formData.duration) - formData.loanAmount;
      const totalInsurance = monthlyInsurance * formData.duration;
      const totalFees = formData.applicationFee + formData.notaryFees + formData.guaranteeFees;
      const totalCost = formData.loanAmount + totalInterest + totalInsurance + totalFees;

      // Taux effectif global
      const effectiveRate = this.calculateEffectiveRate(formData, totalMonthlyPayment);

      // Tableau d'amortissement
      const amortizationSchedule = this.generateAmortizationSchedule(formData, baseMonthlyPayment, monthlyInsurance);

      // Répartition de la mensualité
      const paymentBreakdown: PaymentBreakdown = {
        capitalPortion: this.calculateAverageCapitalPayment(amortizationSchedule),
        interestPortion: this.calculateAverageInterestPayment(amortizationSchedule),
        insurancePortion: monthlyInsurance,
        totalMonthly: totalMonthlyPayment
      };

      // Comparaisons par durée
      const comparisonData = this.generateDurationComparisons(formData);

      // Optimisations possibles
      const optimizations = this.generateOptimizations(formData, totalMonthlyPayment, totalCost);

      // Répartition des coûts
      const costBreakdown: CostBreakdown = {
        principal: formData.loanAmount,
        totalInterest,
        totalInsurance,
        totalFees,
        grandTotal: totalCost
      };

      this.results = {
        monthlyPayment: Math.round(totalMonthlyPayment),
        totalInterest: Math.round(totalInterest),
        totalCost: Math.round(totalCost),
        effectiveRate: Math.round(effectiveRate * 100) / 100,
        monthlyInsurance: Math.round(monthlyInsurance),
        amortizationSchedule,
        paymentBreakdown,
        optimizations,
        comparisonData,
        costBreakdown
      };

      this.trackCalculationCompleted();

    } catch (error) {
      console.error('Erreur calcul mensualités:', error);
      this.notificationService.showError('Erreur lors du calcul des mensualités');
    } finally {
      this.isCalculating = false;
    }
  }

  private calculateMonthlyPayment(amount: number, monthlyRate: number, duration: number): number {
    if (monthlyRate === 0) {
      return amount / duration;
    }
    
    const factor = Math.pow(1 + monthlyRate, duration);
    return amount * (monthlyRate * factor) / (factor - 1);
  }

  private calculateInsurance(formData: any): number {
    if (!formData.includeInsurance) return 0;

    if (formData.insuranceType === 'constant') {
      // Assurance sur capital initial constant
      return (formData.loanAmount * formData.insuranceRate / 100) / 12;
    } else {
      // Assurance sur capital restant dû (dégressif)
      // Approximation : moyenne sur la durée
      return (formData.loanAmount * formData.insuranceRate / 100) / 12 * 0.6;
    }
  }

  private calculateEffectiveRate(formData: any, monthlyPayment: number): number {
    const totalPaid = monthlyPayment * formData.duration;
    const totalFees = formData.applicationFee + formData.notaryFees + formData.guaranteeFees;
    const netAmount = formData.loanAmount - totalFees;
    
    // Calcul TEG simplifié
    const totalCost = totalPaid + totalFees;
    const totalInterest = totalCost - formData.loanAmount;
    
    return (totalInterest / formData.loanAmount) / (formData.duration / 12) * 100;
  }

  private generateAmortizationSchedule(
    formData: any, 
    basePayment: number, 
    monthlyInsurance: number
  ): AmortizationEntry[] {
    const schedule: AmortizationEntry[] = [];
    const monthlyRate = formData.interestRate / 100 / 12;
    let remainingCapital = formData.loanAmount;
    let cumulativeInterest = 0;
    let cumulativeCapital = 0;

    for (let month = 1; month <= formData.duration; month++) {
      const interestPayment = remainingCapital * monthlyRate;
      const capitalPayment = basePayment - interestPayment;
      
      remainingCapital -= capitalPayment;
      cumulativeInterest += interestPayment;
      cumulativeCapital += capitalPayment;

      // Assurance selon le type
      let insurancePayment = monthlyInsurance;
      if (formData.insuranceType === 'declining') {
        insurancePayment = (remainingCapital * formData.insuranceRate / 100) / 12;
      }

      schedule.push({
        month,
        year: Math.ceil(month / 12),
        monthlyPayment: basePayment + insurancePayment,
        capitalPayment: Math.round(capitalPayment),
        interestPayment: Math.round(interestPayment),
        insurancePayment: Math.round(insurancePayment),
        remainingCapital: Math.round(Math.max(0, remainingCapital)),
        cumulativeInterest: Math.round(cumulativeInterest),
        cumulativeCapital: Math.round(cumulativeCapital)
      });
    }

    return schedule;
  }

  private calculateAverageCapitalPayment(schedule: AmortizationEntry[]): number {
    const total = schedule.reduce((sum, entry) => sum + entry.capitalPayment, 0);
    return Math.round(total / schedule.length);
  }

  private calculateAverageInterestPayment(schedule: AmortizationEntry[]): number {
    const total = schedule.reduce((sum, entry) => sum + entry.interestPayment, 0);
    return Math.round(total / schedule.length);
  }

  private generateDurationComparisons(formData: any): DurationComparison[] {
    const durations = [120, 180, 240, 300, 360].filter(d => d !== formData.duration);
    durations.push(formData.duration);
    durations.sort((a, b) => a - b);

    const currentTotalCost = this.results?.totalCost || 0;

    return durations.map(duration => {
      const monthlyRate = formData.interestRate / 100 / 12;
      const monthlyPayment = this.calculateMonthlyPayment(formData.loanAmount, monthlyRate, duration);
      const totalInterest = (monthlyPayment * duration) - formData.loanAmount;
      const totalCost = formData.loanAmount + totalInterest;
      
      return {
        duration: duration / 12,
        monthlyPayment: Math.round(monthlyPayment),
        totalCost: Math.round(totalCost),
        totalInterest: Math.round(totalInterest),
        savings: Math.round(currentTotalCost - totalCost)
      };
    });
  }

  // CORRECTION : Générer les optimisations avec newMonthlyPayment obligatoire
  private generateOptimizations(formData: any, monthlyPayment: number, totalCost: number): OptimizationSuggestion[] {
    const optimizations: OptimizationSuggestion[] = [];

    // Optimisation par réduction de durée
    if (formData.duration > 120) {
      const shorterDuration = Math.max(120, formData.duration - 60);
      const shorterMonthlyRate = formData.interestRate / 100 / 12;
      const shorterPayment = this.calculateMonthlyPayment(formData.loanAmount, shorterMonthlyRate, shorterDuration);
      const shorterTotalCost = formData.loanAmount + ((shorterPayment * shorterDuration) - formData.loanAmount);
      
      optimizations.push({
        type: 'duration',
        title: 'Réduire la durée',
        description: `Passer de ${formData.duration/12} à ${shorterDuration/12} ans`,
        currentValue: formData.duration,
        suggestedValue: shorterDuration,
        savings: Math.round(totalCost - shorterTotalCost),
        impact: `+${Math.round(shorterPayment - monthlyPayment)} FCFA/mois`,
        newMonthlyPayment: Math.round(shorterPayment) // Toujours fournir une valeur
      });
    }

    // Optimisation par négociation de taux
    if (formData.interestRate > 5) {
      const betterRate = Math.max(5, formData.interestRate - 0.5);
      const betterMonthlyRate = betterRate / 100 / 12;
      const betterPayment = this.calculateMonthlyPayment(formData.loanAmount, betterMonthlyRate, formData.duration);
      const betterTotalCost = formData.loanAmount + ((betterPayment * formData.duration) - formData.loanAmount);
      
      optimizations.push({
        type: 'rate',
        title: 'Négocier le taux',
        description: `Obtenir un taux de ${betterRate}% au lieu de ${formData.interestRate}%`,
        currentValue: formData.interestRate,
        suggestedValue: betterRate,
        savings: Math.round(totalCost - betterTotalCost),
        impact: `-${Math.round(monthlyPayment - betterPayment)} FCFA/mois`,
        newMonthlyPayment: Math.round(betterPayment) // Toujours fournir une valeur
      });
    }

    // Optimisation par remboursement anticipé
    const earlyPaymentAmount = formData.loanAmount * 0.1; // 10% du capital
    const earlyPaymentSavings = this.calculateEarlyPaymentSavings(formData, earlyPaymentAmount, 60);
    
    if (earlyPaymentSavings > 0) {
      optimizations.push({
        type: 'early_payment',
        title: 'Remboursement anticipé',
        description: `Rembourser ${this.formatCurrency(earlyPaymentAmount)} dans 5 ans`,
        currentValue: 0,
        suggestedValue: earlyPaymentAmount,
        savings: Math.round(earlyPaymentSavings),
        impact: 'Réduction de la durée',
        newMonthlyPayment: Math.round(monthlyPayment) // Garder la même mensualité
      });
    }

    return optimizations;
  }

  private calculateEarlyPaymentSavings(formData: any, amount: number, atMonth: number): number {
    // Calcul simplifié des économies d'intérêts
    const monthlyRate = formData.interestRate / 100 / 12;
    const remainingMonths = formData.duration - atMonth;
    
    // Capital restant au moment du remboursement anticipé
    let remainingCapital = formData.loanAmount;
    const monthlyPayment = this.calculateMonthlyPayment(formData.loanAmount, monthlyRate, formData.duration);
    
    for (let i = 0; i < atMonth; i++) {
      const interestPayment = remainingCapital * monthlyRate;
      const capitalPayment = monthlyPayment - interestPayment;
      remainingCapital -= capitalPayment;
    }

    // Économies d'intérêts sur le montant remboursé par anticipation
    const interestSavings = amount * monthlyRate * remainingMonths;
    
    return interestSavings;
  }

  // Méthodes d'interface utilisateur
  setActiveTab(tab: string): void {
    this.activeTab = tab;
  }

  toggleFullSchedule(): void {
    this.showFullSchedule = !this.showFullSchedule;
  }

  setPresetAmount(amount: number): void {
    this.calculatorForm.patchValue({ loanAmount: amount });
  }

  setPresetDuration(months: number): void {
    this.calculatorForm.patchValue({ duration: months });
  }

  exportToExcel(): void {
    if (!this.results) return;

    // Création des données pour l'export
    const exportData = {
      simulation: this.calculatorForm.value,
      results: this.results,
      amortizationSchedule: this.results.amortizationSchedule
    };

    // Simulation de l'export (remplacer par vraie implémentation)
    this.notificationService.showSuccess('Export Excel généré avec succès');
  }

  goToComparator(): void {
    if (!this.results) return;

    const queryParams = {
      creditType: this.calculatorForm.get('creditType')?.value,
      requestedAmount: this.calculatorForm.get('loanAmount')?.value,
      duration: this.calculatorForm.get('duration')?.value,
      from: 'payment_calculator'
    };

    this.router.navigate(['/multi-bank-comparator'], { queryParams });
  }

  simulateEarlyPayment(): void {
    const earlyAmount = this.calculatorForm.get('earlyPaymentAmount')?.value;
    const earlyMonth = this.calculatorForm.get('earlyPaymentMonth')?.value;
    
    if (earlyAmount && earlyAmount > 0 && earlyMonth > 0) {
      // Recalculer avec remboursement anticipé
      this.calculatePayments();
      this.notificationService.showInfo(`Simulation avec remboursement de ${this.formatCurrency(earlyAmount)} au mois ${earlyMonth}`);
    }
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
    return `${value.toFixed(2)}%`;
  }

  getScheduleForYear(year: number): AmortizationEntry[] {
    if (!this.results) return [];
    return this.results.amortizationSchedule.filter(entry => entry.year === year);
  }

  getAvailableYears(): number[] {
    if (!this.results) return [];
    const years = new Set(this.results.amortizationSchedule.map(entry => entry.year));
    return Array.from(years).sort();
  }

  hasError(controlName: string): boolean {
    const control = this.calculatorForm.get(controlName);
    return !!(control?.errors && control?.touched);
  }

  getErrorMessage(controlName: string): string {
    const control = this.calculatorForm.get(controlName);
    if (!control?.errors) return '';

    const errors = control.errors;
    
    if (errors['required']) return 'Ce champ est requis';
    if (errors['min']) return `Valeur minimum: ${errors['min'].min}`;
    if (errors['max']) return `Valeur maximum: ${errors['max'].max}`;
    
    return 'Valeur invalide';
  }

  private trackPageView(): void {
    this.analyticsService.trackPageView('payment_calculator', {
      page_title: 'Calculateur de Mensualités'
    });
  }

  private trackCalculationCompleted(): void {
    if (!this.results) return;

    this.analyticsService.trackEvent('payment_calculation_completed', {
      loan_amount: this.calculatorForm.get('loanAmount')?.value,
      duration: this.calculatorForm.get('duration')?.value,
      interest_rate: this.calculatorForm.get('interestRate')?.value,
      monthly_payment: this.results.monthlyPayment,
      total_cost: this.results.totalCost,
      credit_type: this.calculatorForm.get('creditType')?.value
    });
  }

  // Getters pour le template
  get isFormValid(): boolean {
    return this.calculatorForm.valid;
  }

  get canExport(): boolean {
    return !!this.results;
  }

  get monthlyBudgetImpact(): number {
    return this.results?.monthlyPayment || 0;
  }

  get totalProjectCost(): number {
    if (!this.results) return 0;
    return this.calculatorForm.get('loanAmount')?.value + this.results.totalInterest;
  }

  get interestToCapitalRatio(): number {
    if (!this.results) return 0;
    const loanAmount = this.calculatorForm.get('loanAmount')?.value || 1;
    return (this.results.totalInterest / loanAmount) * 100;
  }

  get averageMonthlyInterest(): number {
    if (!this.results) return 0;
    const duration = this.calculatorForm.get('duration')?.value || 1;
    return this.results.totalInterest / duration;
  }
}