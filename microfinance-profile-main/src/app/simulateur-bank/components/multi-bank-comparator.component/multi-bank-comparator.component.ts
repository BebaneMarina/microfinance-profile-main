import { Component, OnInit, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ReactiveFormsModule, FormBuilder, FormGroup, Validators } from '@angular/forms';
import { RouterModule, Router } from '@angular/router';
import { from, Subject } from 'rxjs';
import { takeUntil } from 'rxjs/operators';
import { MultiBankService } from '../../services/multi-bank.service';
import { NotificationService } from '../../services/notification.service';
import { AnalyticsService } from '../../services/analytics.service';
import { 
  MultiBankSimulationInput, 
  MultiBankComparisonResult, 
  BankOffer
} from '../models/multi-bank.model';
import { Bank } from '../models/bank.model';

@Component({
  selector: 'comparateur',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule, RouterModule],
  templateUrl: './multi-bank-comparator.component.html',
  styleUrls: ['./multi-bank-comparator.component.scss']
})
export class MultiBankComparatorComponent implements OnInit, OnDestroy {
  simulationForm!: FormGroup;
  comparisonResults: MultiBankComparisonResult | null = null;
  isLoading = false;
  hasFormError = false;
  errorMessage = '';
  
  availableBanks: Bank[] = [];
  selectedBanks: string[] = [];
  expandedOffers: Set<string> = new Set();
  sortBy: 'rate' | 'payment' | 'time' | 'approval' = 'rate';
  
  creditTypes = [
    { id: 'consommation', name: 'Crédit Consommation', description: 'Pour vos achats personnels' },
    { id: 'auto', name: 'Crédit Auto', description: 'Financement véhicule' },
    { id: 'immobilier', name: 'Crédit Immobilier', description: 'Achat ou construction' },
    { id: 'investissement', name: 'Crédit Investissement', description: 'Projets d\'entreprise' },
    { id: 'equipement', name: 'Crédit Équipement', description: 'Matériel professionnel' },
    { id: 'tresorerie', name: 'Crédit Trésorerie', description: 'Besoins de fonds de roulement' }
  ];

  durations = [
    { value: 6, label: '6 mois' },
    { value: 12, label: '12 mois' },
    { value: 18, label: '18 mois' },
    { value: 24, label: '2 ans' },
    { value: 36, label: '3 ans' },
    { value: 48, label: '4 ans' },
    { value: 60, label: '5 ans' }
  ];

  private destroy$ = new Subject<void>();

  constructor(
    private fb: FormBuilder,
    private multiBankService: MultiBankService,
    private notificationService: NotificationService,
    private analyticsService: AnalyticsService,
    private router: Router
  ) {}

  ngOnInit(): void {
    this.initializeForm();
    this.loadAvailableBanks();
    this.trackPageView();
  }

  ngOnDestroy(): void {
    this.destroy$.next();
    this.destroy$.complete();
  }

  private initializeForm(): void {
    this.simulationForm = this.fb.group({
      clientType: ['particulier', Validators.required],
      fullName: ['', [Validators.required, Validators.minLength(3)]],
      phoneNumber: ['', [Validators.required, Validators.pattern(/^(\+241|241)?[0-9]{8}$/)]],
      email: ['', [Validators.email]],
      monthlyIncome: [750000, [Validators.required, Validators.min(200000)]],
      profession: [''],
      creditType: ['consommation', Validators.required],
      requestedAmount: [2000000, [Validators.required, Validators.min(100000), Validators.max(100000000)]],
      duration: [24, [Validators.required, Validators.min(6), Validators.max(60)]],
      purpose: ['', Validators.required]
    });

    this.simulationForm.get('clientType')?.valueChanges
      .pipe(takeUntil(this.destroy$))
      .subscribe(clientType => {
        this.updateValidationRules(clientType);
      });
  }

  private updateValidationRules(clientType: string): void {
    const monthlyIncomeControl = this.simulationForm.get('monthlyIncome');
    const professionControl = this.simulationForm.get('profession');

    if (clientType === 'entreprise') {
      monthlyIncomeControl?.setValidators([
        Validators.required, 
        Validators.min(500000)
      ]);
      professionControl?.setValidators([Validators.required]);
    } else {
      monthlyIncomeControl?.setValidators([
        Validators.required, 
        Validators.min(200000)
      ]);
      professionControl?.clearValidators();
    }

    monthlyIncomeControl?.updateValueAndValidity();
    professionControl?.updateValueAndValidity();
  }

  private loadAvailableBanks(): void {
    this.multiBankService.getAvailableBanks()
      .pipe(takeUntil(this.destroy$))
      .subscribe({
        next: (banks) => {
          this.availableBanks = banks;
          this.selectedBanks = banks
            .filter(bank => ['bgfi', 'ugb', 'bicig'].includes(bank.id))
            .map(bank => bank.id);
        },
        error: (error) => {
          console.error('Erreur chargement banques:', error);
          this.notificationService.showError('Impossible de charger les banques disponibles');
        }
      });
  }

  hasError(controlName: string): boolean {
    const control = this.simulationForm.get(controlName);
    return !!(control?.errors && control?.touched);
  }

  isBankSelected(bankId: string): boolean {
    return this.selectedBanks.includes(bankId);
  }

  toggleBankSelection(bankId: string): void {
    const index = this.selectedBanks.indexOf(bankId);
    if (index > -1) {
      if (this.selectedBanks.length > 1) {
        this.selectedBanks.splice(index, 1);
      } else {
        this.notificationService.showWarning('Vous devez sélectionner au moins une banque');
      }
    } else {
      this.selectedBanks.push(bankId);
    }
  }

  toggleSelectAll(): void {
    if (this.allBanksSelected) {
      this.selectedBanks = ['bgfi'];
    } else {
      this.selectedBanks = this.availableBanks.map(bank => bank.id);
    }
  }

  get allBanksSelected(): boolean {
    return this.selectedBanks.length === this.availableBanks.length;
  }

  onSubmit(): void {
    if (this.simulationForm.invalid || this.selectedBanks.length === 0) {
      this.markFormGroupTouched(this.simulationForm);
      this.notificationService.showError('Veuillez corriger les erreurs du formulaire');
      return;
    }

    this.isLoading = true;
    this.hasFormError = false;
    this.comparisonResults = null;

    const input: MultiBankSimulationInput = {
      ...this.simulationForm.value,
      selectedBanks: this.selectedBanks
    };

    this.analyticsService.trackEvent('multi_bank_simulation_started', {
      banks_selected: this.selectedBanks.length,
      credit_type: input.creditType,
      requested_amount: input.requestedAmount,
      client_type: input.clientType
    });

    this.multiBankService.simulateMultiBank(input)
      .pipe(takeUntil(this.destroy$))
      .subscribe({
        next: (result) => {
          this.comparisonResults = result;
          this.isLoading = false;
          
          this.analyticsService.trackEvent('multi_bank_simulation_completed', {
            offers_received: result.bankOffers.length,
            best_rate: result.bestOffer?.interestRate,
            best_bank: result.bestOffer?.bankId
          });

          setTimeout(() => {
            this.scrollToResults();
          }, 100);

          this.notificationService.showSuccess('Comparaison terminée avec succès !');
        },
        error: (error) => {
          console.error('Erreur simulation:', error);
          this.isLoading = false;
          this.hasFormError = true;
          this.errorMessage = error.message || 'Une erreur est survenue lors de la comparaison';
          this.notificationService.showError(this.errorMessage);
        }
      });
  }

  setSortBy(sortType: 'rate' | 'payment' | 'time' | 'approval'): void {
    this.sortBy = sortType;
  }

  getSortedOffers(): BankOffer[] {
    if (!this.comparisonResults) return [];
    
    const offers = [...this.comparisonResults.bankOffers];
    
    switch (this.sortBy) {
      case 'rate':
        return offers.sort((a, b) => a.interestRate - b.interestRate);
      case 'payment':
        return offers.sort((a, b) => a.monthlyPayment - b.monthlyPayment);
      case 'time':
        return offers.sort((a, b) => a.processingTime - b.processingTime);
      case 'approval':
        return offers.sort((a, b) => b.approvalChance - a.approvalChance);
      default:
        return offers;
    }
  }

  toggleOfferDetails(bankId: string): void {
    if (this.expandedOffers.has(bankId)) {
      this.expandedOffers.delete(bankId);
    } else {
      this.expandedOffers.add(bankId);
    }
  }

  isOfferExpanded(bankId: string): boolean {
    return this.expandedOffers.has(bankId);
  }

  applyToOffer(offer: BankOffer): void {
    this.analyticsService.trackEvent('bank_offer_application_started', {
      bank_id: offer.bankId,
      bank_name: offer.bankName,
      interest_rate: offer.interestRate,
      monthly_payment: offer.monthlyPayment
    });

    if (offer.bankId === 'bamboo') {
      this.router.navigate(['/credit-application'], {
        queryParams: { 
          bank: offer.bankId,
          amount: offer.approvedAmount,
          rate: offer.interestRate,
          duration: offer.duration,
          from: 'comparator'
        }
      });
    } else {
      this.submitExternalApplication(offer);
    }
  }

  private submitExternalApplication(offer: BankOffer): void {
    const applicationData = {
      bankId: offer.bankId,
      userProfile: this.simulationForm.value,
      selectedOffer: offer,
      timestamp: new Date().toISOString(),
      source: 'multi_bank_comparator'
    };

    this.multiBankService.submitExternalApplication(applicationData)
      .pipe(takeUntil(this.destroy$))
      .subscribe({
        next: (response: any) => {
          this.notificationService.showSuccess(
            `Votre demande a été transmise à ${offer.bankName}. Numéro de suivi: ${response.trackingNumber}`
          );
          
          this.router.navigate(['/suivi', response.trackingNumber]);
        },
        error: (error: any) => {
          console.error('Erreur soumission externe:', error);
          this.notificationService.showError('Erreur lors de la transmission de votre demande');
        }
      });
  }

  saveComparison(): void {
    if (!this.comparisonResults) return;

    const comparisonData = {
      input: this.simulationForm.value,
      results: this.comparisonResults,
      timestamp: new Date().toISOString()
    };

    this.multiBankService.saveComparison(comparisonData)
      .pipe(takeUntil(this.destroy$))
      .subscribe({
        next: () => {
          this.notificationService.showSuccess('Comparaison sauvegardée avec succès');
        },
        error: () => {
          this.notificationService.showError('Erreur lors de la sauvegarde');
        }
      });
  }

  exportToPDF(): void {
    if (!this.comparisonResults) return;

    this.multiBankService.exportComparisonToPDF(this.comparisonResults, this.simulationForm.value)
      .pipe(takeUntil(this.destroy$))
      .subscribe({
        next: (pdfBlob: any) => {
          const url = window.URL.createObjectURL(pdfBlob);
          const link = document.createElement('a');
          link.href = url;
          link.download = `comparaison-credit-${Date.now()}.pdf`;
          link.click();
          window.URL.revokeObjectURL(url);
        },
        error: () => {
          this.notificationService.showError('Erreur lors de l\'export PDF');
        }
      });
  }

  shareComparison(): void {
    if (!this.comparisonResults) return;

    if (navigator.share) {
      navigator.share({
        title: 'Comparaison de Crédits - Bamboo',
        text: `J'ai trouvé le meilleur taux: ${this.comparisonResults.bestOffer?.interestRate}% chez ${this.comparisonResults.bestOffer?.bankName}`,
        url: window.location.href
      });
    } else {
      const shareText = `Comparaison de crédits - Meilleur taux: ${this.comparisonResults.bestOffer?.interestRate}% chez ${this.comparisonResults.bestOffer?.bankName}`;
      navigator.clipboard.writeText(shareText).then(() => {
        this.notificationService.showSuccess('Lien copié dans le presse-papier');
      });
    }
  }

  resetForm(): void {
    this.simulationForm.reset({
      clientType: 'particulier',
      monthlyIncome: 750000,
      creditType: 'consommation',
      requestedAmount: 2000000,
      duration: 24
    });
    this.comparisonResults = null;
    this.hasFormError = false;
    this.selectedBanks = ['bgfi', 'ugb', 'bicig'];
  }

  getEligibilityClass(status: string): string {
    switch (status) {
      case 'eligible': return 'eligible';
      case 'conditional': return 'conditional';
      case 'not_eligible': return 'not-eligible';
      default: return '';
    }
  }

  getEligibilityText(status: string): string {
    switch (status) {
      case 'eligible': return 'Éligible';
      case 'conditional': return 'Sous conditions';
      case 'not_eligible': return 'Non éligible';
      default: return 'À étudier';
    }
  }

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

  getProcessingTimeText(hours: number): string {
    if (hours <= 24) return `${hours}h`;
    const days = Math.ceil(hours / 24);
    return `${days} jour${days > 1 ? 's' : ''}`;
  }

  hasValidationError(controlName: string, errorType: string = ''): boolean {
    const control = this.simulationForm.get(controlName);
    if (!control) return false;
    
    if (errorType) {
      return !!(control.errors?.[errorType] && control.touched);
    }
    return !!(control.errors && control.touched);
  }

  getErrorMessage(controlName: string): string {
    const control = this.simulationForm.get(controlName);
    if (!control?.errors) return '';

    const errors = control.errors;
    
    if (errors['required']) return 'Ce champ est requis';
    if (errors['email']) return 'Format d\'email invalide';
    if (errors['minlength']) return `Minimum ${errors['minlength'].requiredLength} caractères`;
    if (errors['min']) return `Valeur minimum: ${errors['min'].min}`;
    if (errors['max']) return `Valeur maximum: ${errors['max'].max}`;
    if (errors['pattern']) return 'Format invalide';
    
    return 'Valeur invalide';
  }

  private markFormGroupTouched(formGroup: FormGroup): void {
    Object.keys(formGroup.controls).forEach(key => {
      const control = formGroup.get(key);
      control?.markAsTouched();
    });
  }

  private scrollToResults(): void {
    const resultsElement = document.querySelector('.results-section');
    if (resultsElement) {
      resultsElement.scrollIntoView({ 
        behavior: 'smooth',
        block: 'start'
      });
    }
  }

  private trackPageView(): void {
    this.analyticsService.trackPageView('multi_bank_comparator', {
      page_title: 'Comparateur Multi-Banques',
      available_banks: this.availableBanks.length
    });
  }

  get isFormValid(): boolean {
    return this.simulationForm.valid && this.selectedBanks.length > 0;
  }

  get selectedBanksCount(): number {
    return this.selectedBanks.length;
  }

  get totalBanksCount(): number {
    return this.availableBanks.length;
  }

  get bestOfferSavings(): number {
    if (!this.comparisonResults || this.comparisonResults.bankOffers.length < 2) return 0;
    
    const offers = this.comparisonResults.bankOffers;
    const bestOffer = offers[0];
    const worstOffer = offers[offers.length - 1];
    
    return worstOffer.totalCost - bestOffer.totalCost;
  }
}