import { Component, OnInit, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ReactiveFormsModule, FormBuilder, FormGroup, Validators } from '@angular/forms';
import { RouterModule, Router } from '@angular/router';
import { Subject } from 'rxjs';
import { takeUntil, debounceTime, distinctUntilChanged } from 'rxjs/operators';
import { EnhancedCreditSimulatorService } from '../../services/credit-simulator.service';
import { NotificationService } from '../../services/notification.service';
import { AnalyticsService } from '../../services/analytics.service';

interface BorrowingCapacityResult {
  borrowingCapacity: number;
  maxMonthlyPayment: number;
  totalProjectCapacity: number;
  debtRatio: number;
  riskLevel: 'low' | 'medium' | 'high';
  recommendations: string[];
  monthlyInsurance: number;
  totalInterest: number;
  effectiveRate: number;
  amortizationData: AmortizationPoint[];
  evolutionData: EvolutionPoint[];
  comparisonData: ComparisonPoint[];
  budgetBreakdown: BudgetBreakdown;
}

interface AmortizationPoint {
  year: number;
  remainingDebt: number;
  paidPrincipal: number;
  cumulativeInterest: number;
  monthlyPayment: number;
}

interface EvolutionPoint {
  duration: number;
  capacity: number;
  monthlyPayment: number;
  totalCost: number;
}

interface ComparisonPoint {
  rate: number;
  capacity: number;
  difference: number;
  monthlyPayment: number;
}

interface BudgetBreakdown {
  totalIncome: number;
  maxDebtPayment: number;
  currentDebts: number;
  availableForCredit: number;
  remainingIncome: number;
}

@Component({
  selector: 'borrowing-capacity',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule, RouterModule],
  templateUrl: './boworring-capacity.component.html',
  styleUrls: ['./boworring-capacity.component.scss']
})
export class BorrowingCapacityComponent implements OnInit, OnDestroy {
  capacityForm!: FormGroup;
  results: BorrowingCapacityResult | null = null;
  isCalculating = false;
  activeTab = 'simulation';
  showAdvancedOptions = false;
  
  // Configuration des graphiques
  chartConfig = {
    amortization: { width: 100, height: 400 },
    evolution: { width: 100, height: 300 },
    comparison: { width: 100, height: 300 }
  };

  // Options de durée
  durationOptions = [
    { value: 120, label: '10 ans' },
    { value: 180, label: '15 ans' },
    { value: 240, label: '20 ans' },
    { value: 300, label: '25 ans' },
    { value: 360, label: '30 ans' }
  ];

  // Types de revenus
  incomeTypes = [
    { id: 'salary', name: 'Salaire', icon: 'briefcase' },
    { id: 'business', name: 'Revenus d\'entreprise', icon: 'building' },
    { id: 'rental', name: 'Revenus locatifs', icon: 'home' },
    { id: 'pension', name: 'Pension/Retraite', icon: 'user-check' }
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

  private initializeForm(): void {
    this.capacityForm = this.fb.group({
      // Revenus
      monthlyIncome: [750000, [Validators.required, Validators.min(200000)]],
      additionalIncome: [0, [Validators.min(0)]],
      incomeType: ['salary', Validators.required],
      incomeStability: ['stable', Validators.required],
      
      // Charges actuelles
      currentDebts: [0, [Validators.min(0)]],
      rentOrMortgage: [0, [Validators.min(0)]],
      livingExpenses: [200000, [Validators.min(0)]],
      
      // Paramètres du crédit
      duration: [240, [Validators.required, Validators.min(60), Validators.max(360)]],
      interestRate: [6.5, [Validators.required, Validators.min(3), Validators.max(15)]],
      downPayment: [0, [Validators.min(0)]],
      
      // Assurance
      hasInsurance: [true],
      insuranceRate: [0.36, [Validators.min(0), Validators.max(2)]],
      
      // Options avancées
      includePropertyTax: [false],
      propertyTaxRate: [1.2, [Validators.min(0), Validators.max(5)]],
      includeMaintenanceCosts: [false],
      maintenanceRate: [1.0, [Validators.min(0), Validators.max(3)]],
      
      // Profil emprunteur
      age: [35, [Validators.required, Validators.min(18), Validators.max(70)]],
      profession: ['employee', Validators.required],
      workExperience: [5, [Validators.min(0), Validators.max(50)]]
    });
  }

  private setupFormListeners(): void {
    this.capacityForm.valueChanges
      .pipe(
        debounceTime(300),
        distinctUntilChanged(),
        takeUntil(this.destroy$)
      )
      .subscribe(() => {
        if (this.capacityForm.valid) {
          this.calculateCapacity();
        }
      });
  }

  calculateCapacity(): void {
    if (this.isCalculating || this.capacityForm.invalid) return;

    this.isCalculating = true;
    
    const formData = this.capacityForm.value;
    
    try {
      // Calcul de la capacité d'emprunt
      const totalIncome = formData.monthlyIncome + formData.additionalIncome;
      const totalCharges = formData.currentDebts + formData.rentOrMortgage + formData.livingExpenses;
      
      // Taux d'endettement maximum (33% en général, ajusté selon le profil)
      const maxDebtRatio = this.getMaxDebtRatio(formData);
      const maxMonthlyPayment = (totalIncome * maxDebtRatio / 100) - formData.currentDebts;

      if (maxMonthlyPayment <= 0) {
        this.results = this.createErrorResult('Capacité d\'emprunt insuffisante avec vos revenus actuels');
        this.isCalculating = false;
        return;
      }

      // Calcul de la capacité d'emprunt avec assurance
      let effectiveMonthlyPayment = maxMonthlyPayment;
      
      if (formData.hasInsurance) {
        effectiveMonthlyPayment = maxMonthlyPayment / (1 + (formData.insuranceRate / 100 / 12));
      }

      // Calcul du capital empruntable
      const monthlyRate = formData.interestRate / 100 / 12;
      const borrowingCapacity = this.calculateLoanAmount(effectiveMonthlyPayment, monthlyRate, formData.duration);
      
      // Capacité totale du projet
      const totalProjectCapacity = borrowingCapacity + formData.downPayment;

      // Calcul du taux d'endettement réel
      const realDebtRatio = ((maxMonthlyPayment + formData.currentDebts) / totalIncome) * 100;

      // Génération des données pour les graphiques
      const amortizationData = this.generateAmortizationData(borrowingCapacity, formData.interestRate, formData.duration);
      const evolutionData = this.generateEvolutionData(formData);
      const comparisonData = this.generateComparisonData(formData);

      // Calculs additionnels
      const monthlyInsurance = formData.hasInsurance ? (borrowingCapacity * formData.insuranceRate / 100 / 12) : 0;
      const totalInterest = (maxMonthlyPayment * formData.duration) - borrowingCapacity;
      const effectiveRate = this.calculateEffectiveRate(borrowingCapacity, maxMonthlyPayment, formData.duration);

      // Budget breakdown
      const budgetBreakdown: BudgetBreakdown = {
        totalIncome,
        maxDebtPayment: maxMonthlyPayment + formData.currentDebts,
        currentDebts: formData.currentDebts,
        availableForCredit: maxMonthlyPayment,
        remainingIncome: totalIncome - (maxMonthlyPayment + formData.currentDebts + formData.livingExpenses)
      };

      // Niveau de risque
      const riskLevel = this.calculateRiskLevel(realDebtRatio, formData);

      // Recommandations
      const recommendations = this.generateRecommendations(realDebtRatio, borrowingCapacity, formData);

      this.results = {
        borrowingCapacity: Math.round(borrowingCapacity),
        maxMonthlyPayment: Math.round(maxMonthlyPayment),
        totalProjectCapacity: Math.round(totalProjectCapacity),
        debtRatio: Math.round(realDebtRatio * 10) / 10,
        riskLevel,
        recommendations,
        monthlyInsurance: Math.round(monthlyInsurance),
        totalInterest: Math.round(totalInterest),
        effectiveRate: Math.round(effectiveRate * 100) / 100,
        amortizationData,
        evolutionData,
        comparisonData,
        budgetBreakdown
      };

      this.trackCalculationCompleted();
      
    } catch (error) {
      console.error('Erreur calcul capacité:', error);
      this.notificationService.showError('Erreur lors du calcul de la capacité d\'emprunt');
      this.results = this.createErrorResult('Erreur de calcul');
    } finally {
      this.isCalculating = false;
    }
  }

  private getMaxDebtRatio(formData: any): number {
    let baseRatio = 33;
    
    // Ajustements selon le profil
    if (formData.incomeStability === 'very_stable') baseRatio += 2;
    if (formData.incomeStability === 'unstable') baseRatio -= 3;
    
    if (formData.monthlyIncome > 1500000) baseRatio += 2;
    if (formData.workExperience > 10) baseRatio += 1;
    
    if (formData.age > 50) baseRatio -= 2;
    if (formData.profession === 'entrepreneur') baseRatio -= 2;
    
    return Math.max(25, Math.min(baseRatio, 35));
  }

  private calculateLoanAmount(monthlyPayment: number, monthlyRate: number, duration: number): number {
    if (monthlyRate === 0) {
      return monthlyPayment * duration;
    }
    
    const factor = Math.pow(1 + monthlyRate, duration);
    return monthlyPayment * (factor - 1) / (monthlyRate * factor);
  }

  private calculateEffectiveRate(capital: number, monthlyPayment: number, duration: number): number {
    const totalPaid = monthlyPayment * duration;
    const totalInterest = totalPaid - capital;
    return ((totalInterest / capital) / (duration / 12)) * 100;
  }

  private generateAmortizationData(capital: number, rate: number, duration: number): AmortizationPoint[] {
    const monthlyRate = rate / 100 / 12;
    const monthlyPayment = capital * (monthlyRate * Math.pow(1 + monthlyRate, duration)) / (Math.pow(1 + monthlyRate, duration) - 1);
    
    let remainingCapital = capital;
    let cumulativeInterest = 0;
    const data: AmortizationPoint[] = [];
    
    for (let month = 1; month <= Math.min(duration, 360); month++) {
      const interestPayment = remainingCapital * monthlyRate;
      const principalPayment = monthlyPayment - interestPayment;
      remainingCapital -= principalPayment;
      cumulativeInterest += interestPayment;
      
      if (month % 12 === 0 || month <= 12) {
        data.push({
          year: Math.ceil(month / 12),
          remainingDebt: Math.round(Math.max(0, remainingCapital)),
          paidPrincipal: Math.round(capital - remainingCapital),
          cumulativeInterest: Math.round(cumulativeInterest),
          monthlyPayment: Math.round(monthlyPayment)
        });
      }
    }
    
    return data;
  }

  private generateEvolutionData(formData: any): EvolutionPoint[] {
    const durations = [120, 180, 240, 300, 360];
    const totalIncome = formData.monthlyIncome + formData.additionalIncome;
    const maxDebtRatio = this.getMaxDebtRatio(formData);
    const maxMonthlyPayment = (totalIncome * maxDebtRatio / 100) - formData.currentDebts;
    
    return durations.map(duration => {
      const monthlyRate = formData.interestRate / 100 / 12;
      const capacity = this.calculateLoanAmount(maxMonthlyPayment, monthlyRate, duration);
      
      return {
        duration: duration / 12,
        capacity: Math.round(capacity),
        monthlyPayment: Math.round(maxMonthlyPayment),
        totalCost: Math.round(maxMonthlyPayment * duration)
      };
    });
  }

  private generateComparisonData(formData: any): ComparisonPoint[] {
    const rates = [5.0, 5.5, 6.0, 6.5, 7.0, 7.5, 8.0];
    const totalIncome = formData.monthlyIncome + formData.additionalIncome;
    const maxDebtRatio = this.getMaxDebtRatio(formData);
    const maxMonthlyPayment = (totalIncome * maxDebtRatio / 100) - formData.currentDebts;
    const currentRate = formData.interestRate;
    
    return rates.map(rate => {
      const monthlyRate = rate / 100 / 12;
      const capacity = this.calculateLoanAmount(maxMonthlyPayment, monthlyRate, formData.duration);
      const currentCapacity = this.calculateLoanAmount(maxMonthlyPayment, currentRate / 100 / 12, formData.duration);
      
      return {
        rate,
        capacity: Math.round(capacity),
        difference: Math.round(capacity - currentCapacity),
        monthlyPayment: Math.round(maxMonthlyPayment)
      };
    });
  }

  private calculateRiskLevel(debtRatio: number, formData: any): 'low' | 'medium' | 'high' {
    let riskScore = 0;
    
    if (debtRatio > 30) riskScore += 3;
    else if (debtRatio > 25) riskScore += 1;
    
    if (formData.incomeStability === 'unstable') riskScore += 2;
    if (formData.profession === 'entrepreneur') riskScore += 1;
    if (formData.age > 55) riskScore += 1;
    if (formData.workExperience < 2) riskScore += 1;
    
    if (riskScore >= 4) return 'high';
    if (riskScore >= 2) return 'medium';
    return 'low';
  }

  private generateRecommendations(debtRatio: number, capacity: number, formData: any): string[] {
    const recommendations: string[] = [];
    
    if (debtRatio > 30) {
      recommendations.push('Votre taux d\'endettement est élevé. Considérez réduire vos charges actuelles.');
    }
    
    if (formData.downPayment < capacity * 0.1) {
      recommendations.push('Un apport personnel de 10-20% améliorerait vos conditions de financement.');
    }
    
    if (formData.duration > 300) {
      recommendations.push('Une durée plus courte réduirait le coût total de votre crédit.');
    }
    
    if (formData.interestRate > 7) {
      recommendations.push('Négociez votre taux ou comparez avec d\'autres établissements.');
    }
    
    if (!formData.hasInsurance && capacity > 5000000) {
      recommendations.push('Souscrivez une assurance emprunteur pour sécuriser votre financement.');
    }
    
    if (formData.incomeStability === 'unstable') {
      recommendations.push('Stabilisez vos revenus avant de faire votre demande.');
    }
    
    if (recommendations.length === 0) {
      recommendations.push('Votre profil est excellent pour un emprunt immobilier !');
      recommendations.push('Vous pouvez négocier des conditions préférentielles.');
    }
    
    return recommendations;
  }

  private createErrorResult(message: string): BorrowingCapacityResult {
    return {
      borrowingCapacity: 0,
      maxMonthlyPayment: 0,
      totalProjectCapacity: 0,
      debtRatio: 0,
      riskLevel: 'high',
      recommendations: [message],
      monthlyInsurance: 0,
      totalInterest: 0,
      effectiveRate: 0,
      amortizationData: [],
      evolutionData: [],
      comparisonData: [],
      budgetBreakdown: {
        totalIncome: 0,
        maxDebtPayment: 0,
        currentDebts: 0,
        availableForCredit: 0,
        remainingIncome: 0
      }
    };
  }

  // Méthodes d'interface utilisateur
  setActiveTab(tab: string): void {
    this.activeTab = tab;
  }

  toggleAdvancedOptions(): void {
    this.showAdvancedOptions = !this.showAdvancedOptions;
  }

  resetForm(): void {
    this.capacityForm.reset({
      monthlyIncome: 750000,
      additionalIncome: 0,
      incomeType: 'salary',
      incomeStability: 'stable',
      currentDebts: 0,
      rentOrMortgage: 0,
      livingExpenses: 200000,
      duration: 240,
      interestRate: 6.5,
      downPayment: 0,
      hasInsurance: true,
      insuranceRate: 0.36,
      includePropertyTax: false,
      propertyTaxRate: 1.2,
      includeMaintenanceCosts: false,
      maintenanceRate: 1.0,
      age: 35,
      profession: 'employee',
      workExperience: 5
    });
    this.results = null;
  }

  goToComparator(): void {
    if (!this.results) return;

    const queryParams = {
      creditType: 'immobilier',
      requestedAmount: this.results.borrowingCapacity,
      duration: this.capacityForm.get('duration')?.value,
      monthlyIncome: this.capacityForm.get('monthlyIncome')?.value,
      from: 'capacity_simulator'
    };

    this.router.navigate(['/multi-bank-comparator'], { queryParams });
  }

  exportResults(): void {
    if (!this.results) return;

    const exportData = {
      type: 'borrowing_capacity',
      inputs: this.capacityForm.value,
      results: this.results,
      timestamp: new Date().toISOString()
    };

    this.simulatorService.exportSimulation(exportData)
      .pipe(takeUntil(this.destroy$))
      .subscribe({
        next: (blob: Blob | MediaSource) => {
          const url = window.URL.createObjectURL(blob);
          const link = document.createElement('a');
          link.href = url;
          link.download = `capacite-emprunt-${Date.now()}.pdf`;
          link.click();
          window.URL.revokeObjectURL(url);
        },
        error: () => {
          this.notificationService.showError('Erreur lors de l\'export');
        }
      });
  }

  shareResults(): void {
    if (!this.results) return;

    const shareText = `Ma capacité d'emprunt: ${this.formatCurrency(this.results.borrowingCapacity)} - Projet total possible: ${this.formatCurrency(this.results.totalProjectCapacity)}`;
    
    if (navigator.share) {
      navigator.share({
        title: 'Ma capacité d\'emprunt - Bamboo',
        text: shareText,
        url: window.location.href
      });
    } else {
      navigator.clipboard.writeText(shareText).then(() => {
        this.notificationService.showSuccess('Résultats copiés dans le presse-papier');
      });
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
    return `${value.toFixed(1)}%`;
  }

  getRiskColor(level: string): string {
    switch (level) {
      case 'low': return 'text-green-600 bg-green-100';
      case 'medium': return 'text-yellow-600 bg-yellow-100';
      case 'high': return 'text-red-600 bg-red-100';
      default: return 'text-gray-600 bg-gray-100';
    }
  }

  getRiskLabel(level: string): string {
    switch (level) {
      case 'low': return 'Risque faible';
      case 'medium': return 'Risque modéré';
      case 'high': return 'Risque élevé';
      default: return 'Non évalué';
    }
  }

  hasError(controlName: string): boolean {
    const control = this.capacityForm.get(controlName);
    return !!(control?.errors && control?.touched);
  }

  getErrorMessage(controlName: string): string {
    const control = this.capacityForm.get(controlName);
    if (!control?.errors) return '';

    const errors = control.errors;
    
    if (errors['required']) return 'Ce champ est requis';
    if (errors['min']) return `Valeur minimum: ${errors['min'].min}`;
    if (errors['max']) return `Valeur maximum: ${errors['max'].max}`;
    
    return 'Valeur invalide';
  }

  private trackPageView(): void {
    this.analyticsService.trackPageView('borrowing_capacity_simulator', {
      page_title: 'Simulateur Capacité d\'Emprunt'
    });
  }

  private trackCalculationCompleted(): void {
    if (!this.results) return;

    this.analyticsService.trackEvent('capacity_calculation_completed', {
      borrowing_capacity: this.results.borrowingCapacity,
      debt_ratio: this.results.debtRatio,
      risk_level: this.results.riskLevel,
      monthly_income: this.capacityForm.get('monthlyIncome')?.value
    });
  }

  // Getters pour le template
  get isFormValid(): boolean {
    return this.capacityForm.valid;
  }

  get canExport(): boolean {
    return !!this.results && this.results.borrowingCapacity > 0;
  }

  get canShare(): boolean {
    return !!this.results && this.results.borrowingCapacity > 0;
  }

  get maxLoanToValueRatio(): number {
    if (!this.results || this.results.totalProjectCapacity === 0) return 0;
    return (this.results.borrowingCapacity / this.results.totalProjectCapacity) * 100;
  }

  get monthlyBudgetAfterLoan(): number {
    if (!this.results) return 0;
    return this.results.budgetBreakdown.remainingIncome;
  }

  get totalMonthlyCosts(): number {
    if (!this.results) return 0;
    const formData = this.capacityForm.value;
    let total = this.results.maxMonthlyPayment;
    
    if (formData.includePropertyTax && this.results.totalProjectCapacity > 0) {
      total += (this.results.totalProjectCapacity * formData.propertyTaxRate / 100 / 12);
    }
    
    if (formData.includeMaintenanceCosts && this.results.totalProjectCapacity > 0) {
      total += (this.results.totalProjectCapacity * formData.maintenanceRate / 100 / 12);
    }
    
    return total;
  }
}