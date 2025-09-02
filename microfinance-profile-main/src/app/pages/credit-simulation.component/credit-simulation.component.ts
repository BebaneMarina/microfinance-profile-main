import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule, ReactiveFormsModule, FormBuilder, FormGroup, Validators } from '@angular/forms';
import { RouterModule } from '@angular/router';
import { CreditSimulationService, SimulationInput, SimulationResult } from '../../services/credit-simulation.service';

@Component({
  selector: 'credit-simulation',
  standalone: true,
  imports: [CommonModule, FormsModule, ReactiveFormsModule, RouterModule],
  templateUrl: './credit-simulation.component.html',
  styleUrls: ['./credit-simulation.component.scss']
})
export class CreditSimulateurComponent implements OnInit {
  simulationForm!: FormGroup;
  simulationResult: SimulationResult | null = null;
  isLoading = false;
  showAmortizationTable = false;
  
  // Types de clients
  clientTypes = [
    { id: 'particulier', name: 'Particulier', icon: 'person' },
    { id: 'entreprise', name: 'Entreprise', icon: 'business' }
  ];
  
  // Types de crédits avec leurs contraintes
  creditTypes = [
    { id: 'consommation', name: 'Crédit Consommation', maxDuration: 48, maxAmount: null, clientTypes: ['particulier'] },
    { id: 'investissement', name: 'Crédit Investissement', maxDuration: 36, maxAmount: 100000000, clientTypes: ['entreprise'] },
    { id: 'avance_facture', name: 'Avance sur Facture', maxDuration: null, maxAmount: 100000000, clientTypes: ['particulier'] },
    { id: 'avance_commande', name: 'Avance sur Bon de Commande', maxDuration: null, maxAmount: 100000000, clientTypes: ['particulier'] },
    { id: 'tontine', name: 'Crédit Tontine', maxDuration: null, maxAmount: 5000000, clientTypes: ['particulier'] },
    { id: 'retraite', name: 'Crédit Retraite', maxDuration: 12, maxAmount: 2000000, clientTypes: ['particulier'] },
    { id: 'spot', name: 'Crédit Spot', maxDuration: 3, maxAmount: 100000000, clientTypes: ['particulier'] }
  ];
  
  constructor(
    private fb: FormBuilder,
    private simulationService: CreditSimulationService
  ) {}

  ngOnInit(): void {
    this.initializeForm();
    
    // Charger les données du profil si l'utilisateur est connecté
    const savedProfile = localStorage.getItem('currentClient');
    if (savedProfile) {
      const profile = JSON.parse(savedProfile);
      this.simulationForm.patchValue({
        fullName: profile.fullName || profile.name || 'BEBANE MOUKOUMBI Marina',
        monthlyIncome: profile.monthlyIncome || 750000,
        clientType: profile.clientType || 'particulier'
      });
    } else {
      // Valeurs par défaut 
      this.simulationForm.patchValue({
        fullName: 'BEBANE MOUKOUMBI Marina',
        monthlyIncome: 750000,
        clientType: 'particulier'
      });
    }
  }

  initializeForm(): void {
    this.simulationForm = this.fb.group({
      clientType: ['particulier', Validators.required],
      fullName: ['', [Validators.required, Validators.minLength(3)]],
      monthlyIncome: [750000, [Validators.required, Validators.min(100000)]],
      creditType: ['consommation', Validators.required],
      requestedAmount: [1000000, [Validators.required, Validators.min(50000)]],
      duration: [12, [Validators.required, Validators.min(1), Validators.max(48)]],
      amortizationType: ['constant', Validators.required]
    });

    // Écouter les changements de type de client
    this.simulationForm.get('clientType')?.valueChanges.subscribe(clientType => {
      this.updateAvailableCreditTypes(clientType);
    });

    // Écouter les changements pour mettre à jour la durée max
    this.simulationForm.get('creditType')?.valueChanges.subscribe(type => {
      this.updateDurationConstraints(type);
    });
  }

  updateAvailableCreditTypes(clientType: string): void {
    const currentCreditType = this.simulationForm.get('creditType')?.value;
    const availableTypes = this.creditTypes.filter(type => 
      type.clientTypes.includes(clientType)
    );
    
    // Si le type de crédit actuel n'est pas disponible pour ce type de client
    if (!availableTypes.find(t => t.id === currentCreditType)) {
      // Pour entreprise, sélectionner automatiquement crédit investissement
      // Pour particulier, sélectionner crédit consommation
      const defaultType = clientType === 'entreprise' ? 'investissement' : 'consommation';
      this.simulationForm.patchValue({ creditType: defaultType });
    }
  }

  getAvailableCreditTypes(): any[] {
    const clientType = this.simulationForm.get('clientType')?.value;
    return this.creditTypes.filter(type => type.clientTypes.includes(clientType));
  }

  updateDurationConstraints(creditType: string): void {
    const selectedType = this.creditTypes.find(t => t.id === creditType);
    if (selectedType && selectedType.maxDuration) {
      const durationControl = this.simulationForm.get('duration');
      
      if (durationControl) {
        durationControl.setValidators([
          Validators.required,
          Validators.min(1),
          Validators.max(selectedType.maxDuration)
        ]);
        
        const currentDuration = durationControl.value;
        if (currentDuration && currentDuration > selectedType.maxDuration) {
          durationControl.setValue(selectedType.maxDuration);
        }
        
        durationControl.updateValueAndValidity();
      }
    }
  }

  onSubmit(): void {
    if (this.simulationForm.valid) {
      this.isLoading = true;
      const simulationInput: SimulationInput = {
        ...this.simulationForm.value,
        interestRate: this.simulationForm.get('clientType')?.value === 'entreprise' ? 24 : 18
      };
      
      this.simulationService.simulateCredit(simulationInput).subscribe({
        next: (result) => {
          this.simulationResult = result;
          this.isLoading = false;
          
          // Analyser avec ML
          this.analyzeWithML(simulationInput, result);
        },
        error: (error) => {
          console.error('Erreur lors de la simulation:', error);
          this.isLoading = false;
          this.showErrorNotification('Une erreur est survenue lors de la simulation');
        }
      });
    } else {
      this.markFormGroupTouched(this.simulationForm);
    }
  }

  analyzeWithML(input: SimulationInput, result: SimulationResult): void {
    const mlData = {
      ...input,
      ...result,
      debtRatio: result.debtRatio
    };
    
    this.simulationService.analyzeWithML(mlData).subscribe({
      next: (mlResult) => {
        if (this.simulationResult) {
          this.simulationResult.recommendations = [
            ...this.simulationResult.recommendations,
            ...mlResult.recommendations
          ];
        }
      },
      error: (error) => {
        console.error('Erreur ML:', error);
      }
    });
  }

  resetForm(): void {
    const currentName = this.simulationForm.get('fullName')?.value || 'BEBANE MOUKOUMBI Marina';
    const currentIncome = this.simulationForm.get('monthlyIncome')?.value || 750000;
    const currentClientType = this.simulationForm.get('clientType')?.value || 'particulier';
    
    this.simulationForm.reset({
      clientType: currentClientType,
      fullName: currentName,
      monthlyIncome: currentIncome,
      creditType: currentClientType === 'entreprise' ? 'investissement' : 'consommation',
      requestedAmount: 1000000,
      duration: 12,
      amortizationType: 'constant'
    });
    this.simulationResult = null;
    this.showAmortizationTable = false;
  }

  toggleAmortizationTable(): void {
    this.showAmortizationTable = !this.showAmortizationTable;
  }

  exportToPDF(): void {
    if (!this.simulationResult) return;
    
    const htmlContent = this.simulationService.exportToPDF(
      this.simulationResult,
      this.simulationForm.value
    );
    
    const printWindow = window.open('', '_blank');
    if (printWindow) {
      printWindow.document.write(htmlContent);
      printWindow.document.close();
      printWindow.print();
    }
  }

  saveSimulation(): void {
    if (this.simulationResult) {
      this.simulationService.saveSimulation({
        input: this.simulationForm.value,
        result: this.simulationResult
      }).subscribe({
        next: () => {
          this.showSuccessNotification('Simulation sauvegardée avec succès !');
        },
        error: () => {
          this.showErrorNotification('Erreur lors de la sauvegarde');
        }
      });
    }
  }

  // Méthodes utilitaires
  formatCurrency(amount: number): string {
    return this.simulationService.formatCurrency(amount);
  }

  formatDate(date: Date): string {
    if (!date) return '';
    const d = new Date(date);
    return d.toLocaleDateString('fr-FR', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric'
    });
  }

  formatPercent(value: number): string {
    return value.toFixed(2) + '%';
  }

  getMonthName(monthNumber: number): string {
    const startDate = new Date();
    const targetDate = new Date(startDate.getFullYear(), startDate.getMonth() + monthNumber - 1, 1);
    const months = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    return `${months[targetDate.getMonth()]} ${targetDate.getFullYear()}`;
  }

  getInterestRateText(): string {
    const clientType = this.simulationForm.get('clientType')?.value;
    return clientType === 'entreprise' ? '24%' : '18%';
  }

  getProgressWidth(): number {
    if (!this.simulationResult) return 0;
    const requestedAmount = this.simulationForm.get('requestedAmount')?.value || 0;
    return Math.min(100, (requestedAmount / this.simulationResult.maxBorrowingCapacity) * 100);
  }

  getEligibilityClass(): string {
    if (!this.simulationResult) return '';
    return this.simulationResult.isEligible ? 'eligible' : 'not-eligible';
  }

  // Méthodes pour le résumé annuel
  getYearIndices(): number[] {
    const duration = this.simulationForm.get('duration')?.value || 0;
    const years = Math.ceil(duration / 12);
    return Array.from({ length: years }, (_, i) => i);
  }

  shouldShowYear(yearIndex: number): boolean {
    const duration = this.simulationForm.get('duration')?.value || 0;
    return yearIndex * 12 < duration;
  }

  getYearlyPayment(yearIndex: number): number {
    if (!this.simulationResult) return 0;
    const duration = this.simulationForm.get('duration')?.value || 0;
    const startMonth = yearIndex * 12;
    const endMonth = Math.min(startMonth + 12, duration);
    
    let total = 0;
    for (let i = startMonth; i < endMonth; i++) {
      if (this.simulationResult.amortizationTable[i]) {
        total += this.simulationResult.amortizationTable[i].monthlyPayment;
      }
    }
    return total;
  }

  getYearlyCapital(yearIndex: number): number {
    if (!this.simulationResult) return 0;
    const duration = this.simulationForm.get('duration')?.value || 0;
    const startMonth = yearIndex * 12;
    const endMonth = Math.min(startMonth + 12, duration);
    
    let total = 0;
    for (let i = startMonth; i < endMonth; i++) {
      if (this.simulationResult.amortizationTable[i]) {
        total += this.simulationResult.amortizationTable[i].principal;
      }
    }
    return total;
  }

  // Méthode pour marquer tous les champs comme touchés
  private markFormGroupTouched(formGroup: FormGroup): void {
    Object.keys(formGroup.controls).forEach(key => {
      const control = formGroup.get(key);
      control?.markAsTouched();

      if (control instanceof FormGroup) {
        this.markFormGroupTouched(control);
      }
    });
  }

  // Méthodes de notification
  private showSuccessNotification(message: string): void {
    this.showNotification(message, 'success');
  }

  private showErrorNotification(message: string): void {
    this.showNotification(message, 'error');
  }

  private showNotification(message: string, type: 'success' | 'error' | 'info' = 'info'): void {
    const notification = document.createElement('div');
    notification.className = `notification ${type}`;
    notification.innerHTML = `
      <i class="material-icons">${type === 'success' ? 'check_circle' : type === 'error' ? 'error' : 'info'}</i>
      <span>${message}</span>
    `;
    
    notification.style.cssText = `
      position: fixed;
      top: 20px;
      right: 20px;
      padding: 16px 24px;
      background: ${type === 'success' ? '#4CAF50' : type === 'error' ? '#f44336' : '#2196F3'};
      color: white;
      border-radius: 8px;
      box-shadow: 0 4px 12px rgba(0,0,0,0.15);
      display: flex;
      align-items: center;
      gap: 12px;
      z-index: 1000;
      animation: slideIn 0.3s ease-out;
    `;
    
    document.body.appendChild(notification);
    
    setTimeout(() => {
      notification.style.animation = 'slideOut 0.3s ease-in';
      setTimeout(() => notification.remove(), 300);
    }, 3000);
  }

  // Méthode pour la gestion de la durée
  setDuration(months: number): void {
    const durationControl = this.simulationForm.get('duration');
    if (durationControl) {
      durationControl.setValue(months);
    }
  }

  // Getters pour le template
  get fullNameControl() {
    return this.simulationForm.get('fullName');
  }

  get monthlyIncomeControl() {
    return this.simulationForm.get('monthlyIncome');
  }

  get requestedAmountControl() {
    return this.simulationForm.get('requestedAmount');
  }

  get durationControl() {
    return this.simulationForm.get('duration');
  }

  get creditTypeControl() {
    return this.simulationForm.get('creditType');
  }

  get clientTypeControl() {
    return this.simulationForm.get('clientType');
  }

  get amortizationTypeControl() {
    return this.simulationForm.get('amortizationType');
  }
}