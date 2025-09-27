// credit-long-request.component.ts - Version corrigée
import { Component, OnInit, OnDestroy, HostListener } from '@angular/core';
import { FormBuilder, FormGroup, Validators, FormArray, FormControl } from '@angular/forms';
import { Router, ActivatedRoute } from '@angular/router';
import { CommonModule } from '@angular/common';
import { ReactiveFormsModule, FormsModule } from '@angular/forms';
import { Subscription } from 'rxjs';
import { CreditRequestsService, LongCreditRequest } from '../../services/credit-requests.service';
import { CreditLongService, CreditLongRequest, CreditSimulation } from '../../services/credit-long.service';
import { AuthService } from '../../services/auth.service';

export interface CreateCreditResponse {
  id: string;
  success: boolean;
  message: string;
  request?: any;
  status?: string;
  submissionDate?: string;
}

interface CompatibleDraft extends Omit<LongCreditRequest, 'personalInfo' | 'creditDetails'> {
  personalInfo?: {
    fullName: string;
    email: string;
    phone: string;
    address: string;
    profession: string;
    company: string;
    maritalStatus?: string;
    dependents?: number;
  };
  creditDetails?: {
    requestedAmount: number;
    duration: number;
    purpose: string;
    repaymentFrequency: string;
    preferredRate?: number;  // Optionnel
    guarantors?: any[];      // Optionnel
  };
}


@Component({
  selector: 'app-credit-long-request',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule, FormsModule],
  templateUrl: './credit-long-request.component.html',
  styleUrls: ['./credit-long-request.component.scss']
})
export class CreditLongRequestComponent implements OnInit, OnDestroy {
  
  // Étapes du processus
  currentStep = 1;
  totalSteps = 5;
  stepTitles = [
    'Simulation',
    'Informations personnelles', 
    'Détails financiers',
    'Documents',
    'Confirmation'
  ];

  // Formulaires
  simulationForm!: FormGroup;
  personalForm!: FormGroup;
  financialForm!: FormGroup;
  documentsForm!: FormGroup;

  // État
  isLoading = false;
  isSubmitting = false;
  showSimulation = false;
  showResultModal = false;
  
  // Données
  currentUser: any = null;
  currentRequest: CreditLongRequest | null = null;
  simulation: CreditSimulation | null = null;
  uploadedFiles: { [key: string]: File } = {};
  submissionResult: any = null;
  
  // Abonnements
  private subscriptions: Subscription[] = [];

  // Validation
  validationErrors: string[] = [];
  warnings: string[] = [];

  // Variables pour les déclarations (étape confirmation)
  declarationsAccepted: boolean = false;
  termsAccepted: boolean = false;
  dataProcessingAccepted: boolean = false;

  constructor(
    private formBuilder: FormBuilder,
    private creditLongService: CreditLongService,
    private authService: AuthService,
    private router: Router,
    private route: ActivatedRoute,
    private creditRequestsService: CreditRequestsService 
  ) {}

  ngOnInit(): void {
    this.initializeForms();
    this.loadCurrentUser();
    this.loadExistingDraft();
    this.setupAutoSave();
    
    // Surveiller les changements de simulation
    this.subscriptions.push(
      this.simulationForm.valueChanges.subscribe(() => {
        if (this.simulationForm.valid && this.showSimulation) {
          this.updateSimulation();
        }
      })
    );
  }

 ngOnDestroy(): void {
    // Sauvegarder avant de quitter
    if (this.hasUnsavedChanges()) {
      this.saveDraft();
    }
    
    if (this.autoSaveTimeout) {
      clearTimeout(this.autoSaveTimeout);
    }
    
    this.subscriptions.forEach(sub => sub.unsubscribe());
  }

  private async uploadDocuments(requestId: string): Promise<void> {
  try {
    const uploadPromises = Object.entries(this.uploadedFiles).map(([documentType, file]) => 
      this.creditRequestsService.uploadLongRequestDocument(requestId, documentType, file)
    );

    await Promise.all(uploadPromises);
    console.log('Tous les documents ont été téléchargés avec succès');
    
  } catch (error) {
    console.error('Erreur lors du téléchargement des documents:', error);
    this.showNotification('Erreur lors du téléchargement de certains documents', 'warning');
  }
}

private showSuccessModal(response: LongCreditRequest): void {
  // Adapter le response au format attendu
  this.submissionResult = {
    applicationId: response.id || 'CR' + Date.now(),
    amount: this.simulationForm.get('requestedAmount')?.value,
    duration: this.simulationForm.get('duration')?.value,
    status: response.status,
    message: 'Demande soumise avec succès',
    submissionDate: response.submissionDate || new Date().toISOString()
  };
  this.showResultModal = true;
}


  // === MÉTHODE POUR FERMER LE MODAL ===
  closeResultModal(): void {
    this.showResultModal = false;
    this.submissionResult = null;
    this.router.navigate(['/profile']);
  }

  // === INITIALISATION ===

  private initializeForms(): void {
    // Formulaire de simulation
    this.simulationForm = this.formBuilder.group({
      requestedAmount: [2000000, [Validators.required, Validators.min(100000), Validators.max(100000000)]],
      duration: [12, [Validators.required, Validators.min(3), Validators.max(120)]],
      purpose: ['', [Validators.required, Validators.minLength(10)]],
      repaymentFrequency: ['mensuel', Validators.required]
    });

    // Formulaire informations personnelles
    this.personalForm = this.formBuilder.group({
      fullName: ['', [Validators.required, Validators.minLength(2)]],
      email: ['', [Validators.required, Validators.email]],
      phone: ['', [Validators.required, Validators.pattern(/^[0-9]{8,}$/)]],
      address: ['', [Validators.required, Validators.minLength(10)]],
      profession: ['', Validators.required],
      company: ['', Validators.required],
      maritalStatus: [''],
      dependents: [0, [Validators.min(0)]]
    });

    // Formulaire informations financières
    this.financialForm = this.formBuilder.group({
      monthlyIncome: [0, [Validators.required, Validators.min(100000)]],
      otherIncomes: this.formBuilder.array([]),
      monthlyExpenses: [0, [Validators.required, Validators.min(0)]],
      existingLoans: this.formBuilder.array([]),
      assets: this.formBuilder.array([]),
      employmentDetails: this.formBuilder.group({
        employer: ['', Validators.required],
        position: ['', Validators.required],
        seniority: [0, [Validators.required, Validators.min(0)]],
        contractType: ['CDI', Validators.required],
        netSalary: [0, [Validators.required, Validators.min(0)]],
        grossSalary: [0, [Validators.required, Validators.min(0)]]
      })
    });

    // Formulaire documents
    this.documentsForm = this.formBuilder.group({
      identityProof: [false, Validators.requiredTrue],
      incomeProof: [false, Validators.requiredTrue],
      bankStatements: [false, Validators.requiredTrue],
      employmentCertificate: [false, Validators.requiredTrue],
      businessPlan: [false],
      propertyDeeds: [false],
      guarantorDocuments: [false]
    });
  }

  private loadCurrentUser(): void {
    this.subscriptions.push(
      this.authService.currentUser$.subscribe(user => {
        this.currentUser = user;
        if (user) {
          this.prefillUserData(user);
        }
      })
    );
  }

  private prefillUserData(user: any): void {
    if (this.personalForm && user) {
      this.personalForm.patchValue({
        fullName: user.fullName || user.name,
        email: user.email,
        phone: user.phone,
        address: user.address,
        profession: user.profession,
        company: user.company
      });
    }

    if (this.financialForm && user) {
      this.financialForm.patchValue({
        monthlyIncome: user.monthlyIncome || 0
      });

      if (user.monthlyIncome) {
        this.financialForm.get('employmentDetails')?.patchValue({
          netSalary: user.monthlyIncome,
          grossSalary: user.monthlyIncome * 1.3
        });
      }
    }
  }
 private setupAutoSave(): void {
    // Sauvegarder automatiquement toutes les 30 secondes
    setInterval(async () => {
      if (this.hasUnsavedChanges()) {
        await this.saveDraft();
      }
    }, 30000);

    // Sauvegarder à chaque changement important
    [this.personalForm, this.financialForm, this.simulationForm].forEach(form => {
      form.valueChanges.subscribe(() => {
        // Débounce la sauvegarde
        clearTimeout(this.autoSaveTimeout);
        this.autoSaveTimeout = setTimeout(() => {
          this.saveDraft();
        }, 2000);
      });
    });
  }

  private autoSaveTimeout: any;

  private hasUnsavedChanges(): boolean {
    return this.personalForm.dirty || 
           this.financialForm.dirty || 
           this.simulationForm.dirty ||
           this.documentsForm.dirty;
  }

 private loadDraftData(draft: CompatibleDraft): void {
  if (draft.creditDetails) {
    // Extraire seulement les propriétés du formulaire de simulation
    const simulationData = {
      requestedAmount: draft.creditDetails.requestedAmount,
      duration: draft.creditDetails.duration,
      purpose: draft.creditDetails.purpose,
      repaymentFrequency: draft.creditDetails.repaymentFrequency
    };
    this.simulationForm.patchValue(simulationData);
  }
  
  if (draft.personalInfo) {
    this.personalForm.patchValue(draft.personalInfo);
  }
  
  if (draft.financialDetails) {
    this.financialForm.patchValue(draft.financialDetails);
    
    if (draft.financialDetails.otherIncomes) {
      this.loadOtherIncomes(draft.financialDetails.otherIncomes);
    }
    if (draft.financialDetails.existingLoans) {
      this.loadExistingLoans(draft.financialDetails.existingLoans);
    }
    if (draft.financialDetails.assets) {
      this.loadAssets(draft.financialDetails.assets);
    }
  }
}

  // === SIMULATION ===

  runSimulation(): void {
    if (!this.simulationForm.valid) {
      this.markFormGroupTouched(this.simulationForm);
      return;
    }

    this.isLoading = true;
    
    const simulationData = {
      requestedAmount: this.simulationForm.value.requestedAmount,
      duration: this.simulationForm.value.duration,
      clientProfile: {
        username: this.currentUser?.username,
        monthlyIncome: this.currentUser?.monthlyIncome || 0,
        creditScore: this.currentUser?.creditScore || 6
      },
      financialDetails: this.financialForm.value
    };

    this.creditLongService.simulateCredit(simulationData).subscribe({
      next: (simulation) => {
        this.simulation = simulation;
        this.showSimulation = true;
        this.isLoading = false;
        
        if (simulation.results.warnings.length > 0) {
          this.warnings = simulation.results.warnings;
        }
      },
      error: (error: any) => {
        console.error('Erreur simulation:', error);
        this.isLoading = false;
        this.showNotification('Erreur lors de la simulation', 'error');
      }
    });
  }

  private updateSimulation(): void {
    if (this.showSimulation) {
      this.runSimulation();
    }
  }

  acceptSimulation(): void {
    if (this.simulation) {
      this.nextStep();
    }
  }

  // === NAVIGATION ===

  nextStep(): void {
    if (!this.canProceedToNextStep()) {
      return;
    }

    this.saveDraft();
    this.currentStep++;
    
    if (this.currentStep === this.totalSteps && !this.simulation) {
      this.runSimulation();
    }
  }

  previousStep(): void {
    if (this.currentStep > 1) {
      this.currentStep--;
    }
  }

  canProceedToNextStep(): boolean {
    switch (this.currentStep) {
      case 1:
        return this.simulationForm.valid && this.showSimulation;
      case 2:
        return this.personalForm.valid;
      case 3:
        return this.financialForm.valid;
      case 4:
        return this.documentsForm.valid;
      case 5:
        return true;
      default:
        return false;
    }
  }

  // === GESTION DES TABLEAUX DYNAMIQUES ===

  get otherIncomes(): FormArray {
    return this.financialForm.get('otherIncomes') as FormArray;
  }

  addOtherIncome(): void {
    const incomeGroup = this.formBuilder.group({
      source: ['', Validators.required],
      amount: [0, [Validators.required, Validators.min(0)]],
      frequency: ['mensuel', Validators.required]
    });
    this.otherIncomes.push(incomeGroup);
  }

  removeOtherIncome(index: number): void {
    this.otherIncomes.removeAt(index);
  }

  private loadOtherIncomes(incomes: any[]): void {
    const incomeArray = this.formBuilder.array([]) as FormArray;
    incomes.forEach(income => {
      incomeArray.push(this.formBuilder.group(income) as unknown as FormControl);
    });
    this.financialForm.setControl('otherIncomes', incomeArray);
  }

  // Prêts existants
  get existingLoans(): FormArray {
    return this.financialForm.get('existingLoans') as FormArray;
  }

  addExistingLoan(): void {
    const loanGroup = this.formBuilder.group({
      lender: ['', Validators.required],
      amount: [0, [Validators.required, Validators.min(0)]],
      monthlyPayment: [0, [Validators.required, Validators.min(0)]],
      remainingMonths: [0, [Validators.required, Validators.min(0)]]
    });
    this.existingLoans.push(loanGroup as unknown as FormControl);
  }

  removeExistingLoan(index: number): void {
    this.existingLoans.removeAt(index);
  }

  private loadExistingLoans(loans: any[]): void {
    const loanArray = this.formBuilder.array([]) as FormArray;
    loans.forEach(loan => {
      loanArray.push(this.formBuilder.group(loan) as unknown as FormControl);
    });
    this.financialForm.setControl('existingLoans', loanArray);
  }

  // Biens/Actifs
  get assets(): FormArray {
    return this.financialForm.get('assets') as FormArray;
  }

  addAsset(): void {
    const assetGroup = this.formBuilder.group({
      type: ['', Validators.required],
      description: ['', Validators.required],
      estimatedValue: [0, [Validators.required, Validators.min(0)]]
    });
    this.assets.push(assetGroup as unknown as FormControl);
  }

  removeAsset(index: number): void {
    this.assets.removeAt(index);
  }

  private loadAssets(assets: any[]): void {
    const assetArray = this.formBuilder.array([]) as FormArray;
    assets.forEach(asset => {
      assetArray.push(this.formBuilder.group(asset) as unknown as FormControl);
    });
    this.financialForm.setControl('assets', assetArray);
  }

  // === GESTION DES DOCUMENTS ===

  triggerFileInput(documentType: string): void {
    const fileInput = document.getElementById(documentType) as HTMLInputElement;
    fileInput?.click();
  }

  onFileSelected(event: Event, documentType: string): void {
    const input = event.target as HTMLInputElement;
    if (input.files && input.files.length > 0) {
      const file = input.files[0];
      
      if (!this.isValidFile(file)) {
        this.showNotification('Format de fichier non autorisé. Utilisez PDF, JPG, PNG ou DOC.', 'error');
        return;
      }

      if (file.size > 10 * 1024 * 1024) {
        this.showNotification('Le fichier est trop volumineux (max 10MB).', 'error');
        return;
      }

      this.uploadedFiles[documentType] = file;
      
      this.documentsForm.patchValue({
        [documentType]: true
      });

      this.showNotification(`Document ${this.getDocumentLabel(documentType)} téléchargé avec succès.`, 'success');
    }
  }

  private isValidFile(file: File): boolean {
    const allowedTypes = [
      'application/pdf',
      'image/jpeg',
      'image/jpg', 
      'image/png',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
    ];
    return allowedTypes.includes(file.type);
  }

  getDocumentLabel(documentType: string): string {
    const labels: { [key: string]: string } = {
      'identityProof': 'Pièce d\'identité',
      'incomeProof': 'Justificatif de revenus',
      'bankStatements': 'Relevés bancaires',
      'employmentCertificate': 'Attestation de travail',
      'businessPlan': 'Plan d\'affaires',
      'propertyDeeds': 'Titre de propriété',
      'guarantorDocuments': 'Documents du garant'
    };
    return labels[documentType] || documentType;
  }

  isDocumentUploaded(documentType: string): boolean {
    return !!this.uploadedFiles[documentType];
  }

  removeDocument(documentType: string): void {
    delete this.uploadedFiles[documentType];
    this.documentsForm.patchValue({
      [documentType]: false
    });
  }

  // === SAUVEGARDE ET SOUMISSION ===

 async saveDraft(): Promise<void> {
  try {
    const draftData: Partial<any> = {
      userId: this.currentUser?.id,
      username: this.currentUser?.email,
      status: 'draft',
      personalInfo: this.personalForm.value,
      creditDetails: {
        ...this.simulationForm.value,
        preferredRate: this.simulation?.results?.suggestedRate // ✅ Ajout de ?. pour éviter l'erreur
      },
      financialDetails: this.financialForm.value,
      documents: this.documentsForm.value,
      simulation: this.simulation?.results ? { // ✅ Vérifier que results existe
        calculatedScore: this.simulation.results.score,
        riskLevel: this.simulation.results.riskLevel,
        recommendedAmount: this.simulation.results.recommendedAmount,
        suggestedRate: this.simulation.results.suggestedRate,
        monthlyPayment: this.simulation.results.monthlyPayment,
        totalInterest: this.simulation.results.totalInterest,
        debtToIncomeRatio: this.simulation.results.debtToIncomeRatio,
        approvalProbability: this.simulation.results.approvalProbability
      } : null, // ✅ Retourner null si pas de simulation
      reviewHistory: [{
        date: new Date().toISOString(),
        action: 'Brouillon créé',
        agent: 'Client',
        comment: 'Brouillon sauvegardé automatiquement'
      }]
    };

    await this.creditRequestsService.saveLongRequestDraft(draftData);
    
    console.log('Brouillon sauvegardé en base de données');

  } catch (error) {
    console.error('Erreur sauvegarde brouillon:', error);
    // Continuer même si la sauvegarde échoue
  }
}

private validateFinalRequest(): string[] {
  const errors: string[] = [];

  if (!this.simulation) {
    errors.push('Une simulation est requise avant la soumission.');
  }

  if (!this.personalForm.valid) {
    errors.push('Les informations personnelles sont incomplètes.');
  }

  if (!this.financialForm.valid) {
    errors.push('Les informations financières sont incomplètes.');
  }

  if (!this.documentsForm.valid) {
    errors.push('Tous les documents obligatoires doivent être fournis.');
  }

  const monthlyIncome = this.financialForm.value.monthlyIncome;
  const requestedAmount = this.simulationForm.value.requestedAmount;
  
  if (requestedAmount > monthlyIncome * 60) {
    errors.push('Le montant demandé est trop élevé par rapport aux revenus.');
  }

  const totalExistingPayments = this.calculateTotalExistingPayments();
  const newPayment = this.simulation?.results?.monthlyPayment || 0; // ✅ Ajout de ?. 
  const debtRatio = ((totalExistingPayments + newPayment) / monthlyIncome) * 100;
  
  if (debtRatio > 50) {
    errors.push('Le taux d\'endettement total dépasse 50%.');
  }

  return errors;
}

  async submitRequest(): Promise<void> {
  // Validation finale
  this.validationErrors = this.validateFinalRequest();
  
  if (this.validationErrors.length > 0) {
    this.showNotification('Veuillez corriger les erreurs avant de soumettre.', 'error');
    return;
  }

  if (this.isSubmitting) {
    return;
  }

  this.isSubmitting = true;

  try {
    // Construire la demande finale
    const requestData = {
      userId: this.currentUser?.id,
      username: this.currentUser?.email,
      status: 'submitted',
      submissionDate: new Date().toISOString(),
      
      personalInfo: this.personalForm.value,
      
      creditDetails: {
        ...this.simulationForm.value,
        preferredRate: this.simulation?.results?.suggestedRate, // ✅
        guarantors: []
      },
      
      financialDetails: this.financialForm.value,
      
      documents: this.documentsForm.value,
      
      simulation: this.simulation?.results ? { // ✅ Vérification
        calculatedScore: this.simulation.results.score,
        riskLevel: this.simulation.results.riskLevel,
        recommendedAmount: this.simulation.results.recommendedAmount,
        suggestedRate: this.simulation.results.suggestedRate,
        monthlyPayment: this.simulation.results.monthlyPayment,
        totalInterest: this.simulation.results.totalInterest,
        debtToIncomeRatio: this.simulation.results.debtToIncomeRatio,
        approvalProbability: this.simulation.results.approvalProbability
      } : null, // ✅
      
      reviewHistory: [{
        date: new Date().toISOString(),
        action: 'Demande soumise',
        agent: 'Client',
        comment: 'Demande initiale soumise par le client'
      }]
    };

    const createdRequest = await this.creditRequestsService.createLongRequest(requestData);
    
    this.submissionResult = {
      applicationId: createdRequest.id,
      status: createdRequest.status,
      submissionDate: createdRequest.submissionDate,
      message: 'Demande soumise avec succès'
    };
    
    // Upload des documents si nécessaire
    if (Object.keys(this.uploadedFiles).length > 0) {
      await this.uploadDocuments(createdRequest.id);
    }

    this.showSuccessModal(createdRequest);
    this.clearDraft();

  } catch (error) {
    console.error('Erreur soumission:', error);
    this.showNotification('Erreur lors de la soumission de la demande.', 'error');
  } finally {
    this.isSubmitting = false;
  }
}
 private loadExistingDraft(): Promise<void> {
  return new Promise(async (resolve) => {
    if (!this.currentUser?.email) { 
      resolve();
      return;
    }
    
    try {
      //  CORRIGÉ : passe l'email au lieu du username
      const draft = await this.creditRequestsService.getLongRequestDraft(this.currentUser.email);
      
      if (draft) {
        this.loadDraftDataDirectly(draft);
        console.log('Brouillon chargé depuis la base de données');
      }
      resolve();
    } catch (error) {
      console.error('Erreur chargement brouillon:', error);
      resolve();
    }
  });
}

private loadDraftDataDirectly(draft: any): void {
  // Charger les données de simulation
  if (draft.creditDetails) {
    this.simulationForm.patchValue({
      requestedAmount: draft.creditDetails.requestedAmount || 2000000,
      duration: draft.creditDetails.duration || 12,
      purpose: draft.creditDetails.purpose || '',
      repaymentFrequency: draft.creditDetails.repaymentFrequency || 'mensuel'
    });
  }
  
  // Charger les informations personnelles
  if (draft.personalInfo) {
    this.personalForm.patchValue({
      fullName: draft.personalInfo.fullName || '',
      email: draft.personalInfo.email || '',
      phone: draft.personalInfo.phone || '',
      address: draft.personalInfo.address || '',
      profession: draft.personalInfo.profession || '',
      company: draft.personalInfo.company || '',
      maritalStatus: draft.personalInfo.maritalStatus || '',
      dependents: draft.personalInfo.dependents || 0
    });
  }
  
  // Charger les informations financières
  if (draft.financialDetails) {
    this.financialForm.patchValue({
      monthlyIncome: draft.financialDetails.monthlyIncome || 0,
      monthlyExpenses: draft.financialDetails.monthlyExpenses || 0
    });
    
    // Charger les détails d'emploi si présents
    if (draft.financialDetails.employmentDetails) {
      this.financialForm.get('employmentDetails')?.patchValue(draft.financialDetails.employmentDetails);
    }
    
    // Charger les tableaux dynamiques
    if (draft.financialDetails.otherIncomes) {
      this.loadOtherIncomes(draft.financialDetails.otherIncomes);
    }
    if (draft.financialDetails.existingLoans) {
      this.loadExistingLoans(draft.financialDetails.existingLoans);
    }
    if (draft.financialDetails.assets) {
      this.loadAssets(draft.financialDetails.assets);
    }
  }
  
  // Charger la simulation si présente
  if (draft.simulation) {
    this.simulation = draft.simulation;
    this.showSimulation = true;
  }
}

private mapStatusToComponent(serviceStatus: string): 'draft' | 'submitted' | 'approved' | 'rejected' | 'under_review' | 'cancelled' {
  const statusMapping: Record<string, any> = {
    'in_review': 'under_review',
    'requires_info': 'under_review'
  };
  
  return statusMapping[serviceStatus] || serviceStatus as any;
}


  private calculateTotalExistingPayments(): number {
    return this.existingLoans.value.reduce((total: number, loan: any) => {
      return total + (loan.monthlyPayment || 0);
    }, 0);
  }

  private clearDraft(): void {
    if (this.currentUser?.username) {
      // Supprimer le brouillon côté serveur
      // (à implémenter selon votre API)
    }
  }

  // === CALCULS ET UTILITAIRES ===

  calculateTotalMonthlyIncome(): number {
    const baseIncome = this.financialForm.value.monthlyIncome || 0;
    const otherIncomes = this.otherIncomes.value.reduce((total: number, income: any) => {
      const monthlyAmount = this.convertToMonthly(income.amount, income.frequency);
      return total + monthlyAmount;
    }, 0);
    
    return baseIncome + otherIncomes;
  }

  calculateNetDisposableIncome(): number {
    const totalIncome = this.calculateTotalMonthlyIncome();
    const expenses = this.financialForm.value.monthlyExpenses || 0;
    const existingPayments = this.calculateTotalExistingPayments();
    
    return Math.max(0, totalIncome - expenses - existingPayments);
  }

  calculateCurrentDebtRatio(): number {
    const totalIncome = this.calculateTotalMonthlyIncome();
    const totalPayments = this.calculateTotalExistingPayments();
    
    return totalIncome > 0 ? (totalPayments / totalIncome) * 100 : 0;
  }

  calculateProjectedDebtRatio(): number {
    const totalIncome = this.calculateTotalMonthlyIncome();
    const totalExistingPayments = this.calculateTotalExistingPayments();
    const newPayment = this.simulation?.results.monthlyPayment || 0;
    
    return totalIncome > 0 ? ((totalExistingPayments + newPayment) / totalIncome) * 100 : 0;
  }

  private convertToMonthly(amount: number, frequency: string): number {
    switch (frequency) {
      case 'hebdomadaire': return amount * 4.33;
      case 'bimensuel': return amount * 2;
      case 'mensuel': return amount;
      case 'trimestriel': return amount / 3;
      case 'semestriel': return amount / 6;
      case 'annuel': return amount / 12;
      default: return amount;
    }
  }

  // === INTERFACE UTILISATEUR ===

  getStepClass(stepNumber: number): string {
    if (this.currentStep > stepNumber) {
      return 'step completed';
    } else if (this.currentStep === stepNumber) {
      return 'step active';
    } else {
      return 'step inactive';
    }
  }

  getProgressPercentage(): number {
    return ((this.currentStep - 1) / (this.totalSteps - 1)) * 100;
  }

  formatAmount(amount: number): string {
    return this.creditLongService.formatAmount(amount);
  }

  formatDuration(months: number): string {
    if (months < 12) {
      return `${months} mois`;
    }
    
    const years = Math.floor(months / 12);
    const remainingMonths = months % 12;
    
    if (remainingMonths === 0) {
      return `${years} an${years > 1 ? 's' : ''}`;
    }
    
    return `${years} an${years > 1 ? 's' : ''} et ${remainingMonths} mois`;
  }

  getRiskLevelColor(riskLevel: string): string {
    const colors: { [key: string]: string } = {
      'Très faible': '#28a745',
      'Faible': '#6bcf7f',
      'Moyen': '#ffc107',
      'Élevé': '#fd7e14',
      'Très élevé': '#dc3545'
    };
    return colors[riskLevel] || '#6c757d';
  }

  private markFormGroupTouched(formGroup: FormGroup): void {
    Object.keys(formGroup.controls).forEach(key => {
      const control = formGroup.get(key);
      control?.markAsTouched();
      
      if (control instanceof FormGroup) {
        this.markFormGroupTouched(control);
      }
    });
  }

  private showNotification(message: string, type: 'success' | 'error' | 'warning' | 'info' = 'info'): void {
    console.log(`${type.toUpperCase()}: ${message}`);
    
    const notification = document.createElement('div');
    notification.className = `notification notification-${type}`;
    notification.textContent = message;
    notification.style.cssText = `
      position: fixed;
      top: 20px;
      right: 20px;
      padding: 12px 24px;
      border-radius: 6px;
      color: white;
      z-index: 10000;
      max-width: 400px;
    `;
    
    switch (type) {
      case 'success': notification.style.backgroundColor = '#28a745'; break;
      case 'error': notification.style.backgroundColor = '#dc3545'; break;
      case 'warning': notification.style.backgroundColor = '#ffc107'; break;
      default: notification.style.backgroundColor = '#17a2b8'; break;
    }
    
    document.body.appendChild(notification);
    
    setTimeout(() => {
      notification.remove();
    }, 5000);
  }


  // === GETTERS POUR LE TEMPLATE ===

  get isSimulationStep(): boolean { return this.currentStep === 1; }
  get isPersonalStep(): boolean { return this.currentStep === 2; }
  get isFinancialStep(): boolean { return this.currentStep === 3; }
  get isDocumentsStep(): boolean { return this.currentStep === 4; }
  get isConfirmationStep(): boolean { return this.currentStep === 5; }

  get canGoNext(): boolean { return this.canProceedToNextStep(); }
  get canGoPrevious(): boolean { return this.currentStep > 1; }
  get canSubmit(): boolean { 
    return this.currentStep === this.totalSteps && 
           this.validationErrors.length === 0 && 
           this.declarationsAccepted && 
           this.termsAccepted && 
           this.dataProcessingAccepted; 
  }

  // Calculés pour l'affichage
  get totalMonthlyIncome(): number { return this.calculateTotalMonthlyIncome(); }
  get netDisposableIncome(): number { return this.calculateNetDisposableIncome(); }
  get currentDebtRatio(): number { return this.calculateCurrentDebtRatio(); }
  get projectedDebtRatio(): number { return this.calculateProjectedDebtRatio(); }

  // === MÉTHODES COMPLÉMENTAIRES ===

  calculateEstimatedPayment(): number {
    if (!this.simulation?.results) {
      const amount = this.simulationForm.get('requestedAmount')?.value || 0;
      const duration = this.simulationForm.get('duration')?.value || 12;
      const defaultRate = 12;

      if (amount > 0 && duration > 0) {
        return this.creditLongService.calculateMonthlyPayment(amount, defaultRate, duration);
      }
    }
    
    return this.simulation?.results.monthlyPayment || 0;
  }

  isAmountValid(): boolean {
    const amount = this.simulationForm.get('requestedAmount')?.value || 0;
    const income = this.calculateTotalMonthlyIncome();
    const maxAmount = Math.min(income * 40, 100000000);
    
    return amount >= 100000 && amount <= maxAmount;
  }

  getTotalCreditCost(): number {
    const monthlyPayment = this.calculateEstimatedPayment();
    const duration = this.simulationForm.get('duration')?.value || 12;
    const requestedAmount = this.simulationForm.get('requestedAmount')?.value || 0;
    
    return (monthlyPayment * duration) - requestedAmount;
  }

  isDocumentRequired(documentType: string): boolean {
    const requiredDocs = ['identityProof', 'incomeProof', 'bankStatements', 'employmentCertificate'];
    return requiredDocs.includes(documentType);
  }

  getDocumentStatusClass(documentType: string): string {
    const isUploaded = this.isDocumentUploaded(documentType);
    const isRequired = this.isDocumentRequired(documentType);
    
    if (isUploaded) return 'uploaded';
    if (isRequired) return 'required-missing';
    return 'optional';
  }

  getCompletionPercentage(): number {
    let totalPoints = 0;
    let completedPoints = 0;

    totalPoints += 20;
    if (this.simulation) completedPoints += 20;

    totalPoints += 20;
    if (this.personalForm.valid) completedPoints += 20;

    totalPoints += 20;
    if (this.financialForm.valid) completedPoints += 20;

    const requiredDocs = this.getRequiredDocuments();
    const uploadedDocs = requiredDocs.filter(doc => this.isDocumentUploaded(doc)).length;
    const docPercentage = (uploadedDocs / requiredDocs.length) * 30;
    totalPoints += 30;
    completedPoints += docPercentage;

    totalPoints += 10;
    if (this.declarationsAccepted && this.termsAccepted && this.dataProcessingAccepted) {
      completedPoints += 10;
    }

    return Math.round((completedPoints / totalPoints) * 100);
  }

  getRequiredDocuments(): string[] {
    const baseDocs = ['identityProof', 'incomeProof', 'bankStatements', 'employmentCertificate'];
    
    const purpose = this.simulationForm.get('purpose')?.value || '';
    const amount = this.simulationForm.get('requestedAmount')?.value || 0;
    
    if (purpose.toLowerCase().includes('investissement') || purpose.toLowerCase().includes('professionnel')) {
      baseDocs.push('businessPlan');
    }
    
    if (amount > 10000000) {
      baseDocs.push('propertyDeeds');
    }
    
    return baseDocs;
  }

  getEstimatedProcessingTime(): string {
    const amount = this.simulationForm.get('requestedAmount')?.value || 0;
    const score = this.currentUser?.creditScore || 6;
    const hasCompleteDocuments = this.getRequiredDocuments().every(doc => this.isDocumentUploaded(doc));
    
    let baseDays = 3;
    
    if (amount > 10000000) baseDays += 2;
    if (score < 5) baseDays += 2;
    if (!hasCompleteDocuments) baseDays += 1;
    
    return `${baseDays}-${baseDays + 2} jours ouvrés`;
  }

  isEligibleForPreferentialRates(): boolean {
    const score = this.currentUser?.creditScore || 6;
    const income = this.calculateTotalMonthlyIncome();
    const debtRatio = this.currentDebtRatio;
    const employmentType = this.financialForm.get('employmentDetails.contractType')?.value;
    
    return score >= 7 && 
           income >= 1000000 && 
           debtRatio <= 30 && 
           ['CDI', 'Fonctionnaire'].includes(employmentType);
  }

  getPreferentialRate(): number {
    if (!this.isEligibleForPreferentialRates()) {
      return this.simulation?.results.suggestedRate || 12;
    }
    
    const baseRate = this.simulation?.results.suggestedRate || 12;
    const reduction = 1.5;
    
    return Math.max(6, baseRate - reduction);
  }

  isCollateralRecommended(): boolean {
    const amount = this.simulationForm.get('requestedAmount')?.value || 0;
    const duration = this.simulationForm.get('duration')?.value || 12;
    const score = this.currentUser?.creditScore || 6;
    
    return amount > 5000000 || duration > 60 || score < 6;
  }

  getRecommendedCollateralValue(): number {
    const amount = this.simulationForm.get('requestedAmount')?.value || 0;
    return amount * 1.2;
  }

  isGuarantorRequired(): boolean {
    const score = this.currentUser?.creditScore || 6;
    const debtRatio = this.projectedDebtRatio;
    const amount = this.simulationForm.get('requestedAmount')?.value || 0;
    
    return score < 5 || debtRatio > 45 || amount > 20000000;
  }

  getPersonalizedAdvice(): string[] {
    const advice: string[] = [];
    const income = this.calculateTotalMonthlyIncome();
    const amount = this.simulationForm.get('requestedAmount')?.value || 0;
    const duration = this.simulationForm.get('duration')?.value || 12;
    const debtRatio = this.projectedDebtRatio;
    
    if (debtRatio > 40) {
      advice.push("💡 Considérez réduire la durée pour diminuer le coût total");
    }
    
    if (amount / income > 30) {
      advice.push("⚠️ Le montant représente plus de 30 mois de revenus, vérifiez votre capacité de remboursement");
    }
    
    if (duration > 60) {
      advice.push("📅 Une durée plus courte vous ferait économiser sur les intérêts");
    }
    
    if (this.assets.length === 0 && amount > 5000000) {
      advice.push("🏠 Apporter des garanties pourrait améliorer vos conditions");
    }
    
    if (this.isEligibleForPreferentialRates()) {
      advice.push("🎉 Votre profil vous permet de bénéficier de taux préférentiels !");
    }
    
    return advice;
  }

  exportToPDF(): void {
    const exportData = {
      clientInfo: {
        name: this.personalForm.get('fullName')?.value,
        email: this.personalForm.get('email')?.value,
        phone: this.personalForm.get('phone')?.value,
        profession: this.personalForm.get('profession')?.value
      },
      creditDetails: {
        amount: this.simulationForm.get('requestedAmount')?.value,
        duration: this.simulationForm.get('duration')?.value,
        purpose: this.simulationForm.get('purpose')?.value,
        monthlyPayment: this.calculateEstimatedPayment()
      },
      financialSituation: {
        monthlyIncome: this.calculateTotalMonthlyIncome(),
        monthlyExpenses: this.financialForm.get('monthlyExpenses')?.value,
        netDisposableIncome: this.netDisposableIncome,
        debtRatio: this.currentDebtRatio
      },
      simulation: this.simulation,
      completionDate: new Date().toLocaleDateString('fr-FR')
    };
    
    console.log('Export PDF:', exportData);
    this.showNotification('Fonctionnalité d\'export en cours de développement', 'info');
  }

  shareByEmail(): void {
    const email = this.personalForm.get('email')?.value;
    const summary = this.generateSummaryText();
    
    if (email && summary) {
      this.showNotification(`Récapitulatif envoyé à ${email}`, 'success');
    } else {
      this.showNotification('Email non valide', 'error');
    }
  }

  private generateSummaryText(): string {
    const amount = this.formatAmount(this.simulationForm.get('requestedAmount')?.value || 0);
    const duration = this.formatDuration(this.simulationForm.get('duration')?.value || 12);
    const monthlyPayment = this.formatAmount(this.calculateEstimatedPayment());
    
    return `
Demande de Crédit Personnel
==========================

Montant demandé: ${amount}
Durée: ${duration}
Mensualité estimée: ${monthlyPayment}

Demandeur: ${this.personalForm.get('fullName')?.value}
Email: ${this.personalForm.get('email')?.value}

Générée le ${new Date().toLocaleDateString('fr-FR')}
    `.trim();
  }

  resetForm(): void {
    this.simulationForm.reset();
    this.personalForm.reset();
    this.financialForm.reset();
    this.documentsForm.reset();
    
    while (this.otherIncomes.length) {
      this.otherIncomes.removeAt(0);
    }
    while (this.existingLoans.length) {
      this.existingLoans.removeAt(0);
    }
    while (this.assets.length) {
      this.assets.removeAt(0);
    }
    
    this.currentStep = 1;
    this.showSimulation = false;
    this.simulation = null;
    this.uploadedFiles = {};
    this.validationErrors = [];
    this.warnings = [];
    this.declarationsAccepted = false;
    this.termsAccepted = false;
    this.dataProcessingAccepted = false;
    
    if (this.currentUser) {
      this.prefillUserData(this.currentUser);
    }
    
    this.showNotification('Formulaire réinitialisé', 'info');
  }

  @HostListener('window:beforeunload', ['$event'])
  beforeUnloadHandler(event: Event): void {
    if (this.currentStep > 1 && !this.isSubmitting) {
      this.saveDraft();
    }
  }

  @HostListener('document:keydown', ['$event'])
  handleKeyboardEvent(event: KeyboardEvent): void {
    if (event.ctrlKey || event.metaKey) {
      switch (event.key) {
        case 's':
          event.preventDefault();
          this.saveDraft();
          this.showNotification('Brouillon sauvegardé', 'success');
          break;
        case 'Enter':
          if (this.canGoNext) {
            event.preventDefault();
            this.nextStep();
          }
          break;
      }
    }
    
    if (event.key === 'Escape') {
      if (this.showResultModal) {
        this.closeResultModal();
      }
    }
  }

  onFieldChange(formGroup: FormGroup, fieldName: string): void {
    const field = formGroup.get(fieldName);
    if (field && field.valid) {
      if (['requestedAmount', 'duration', 'monthlyIncome'].includes(fieldName)) {
        setTimeout(() => this.saveDraft(), 1000);
      }
      
      if (this.isSimulationStep && ['requestedAmount', 'duration'].includes(fieldName)) {
        setTimeout(() => {
          if (this.simulationForm.valid) {
            this.updateSimulation();
          }
        }, 500);
      }
    }
  }

  private performFinalValidation(): boolean {
    this.validationErrors = [];
    
    const amount = this.simulationForm.get('requestedAmount')?.value || 0;
    const income = this.calculateTotalMonthlyIncome();
    const maxAffordable = income * 40;
    
    if (amount > maxAffordable) {
      this.validationErrors.push(`Le montant demandé dépasse 40 fois vos revenus mensuels (max: ${this.formatAmount(maxAffordable)})`);
    }
    
    if (this.projectedDebtRatio > 50) {
      this.validationErrors.push('Le taux d\'endettement projeté dépasse 50%');
    }
    
    if (this.calculateEstimatedPayment() > this.netDisposableIncome) {
      this.validationErrors.push('La mensualité dépasse vos revenus disponibles');
    }
    
    const missingDocs = this.getRequiredDocuments().filter(doc => !this.isDocumentUploaded(doc));
    if (missingDocs.length > 0) {
      this.validationErrors.push(`Documents manquants: ${missingDocs.map(doc => this.getDocumentLabel(doc)).join(', ')}`);
    }
    
    return this.validationErrors.length === 0;
  }

  getContextualHelp(): string[] {
    const help: string[] = [];
    
    switch (this.currentStep) {
      case 1:
        help.push("💡 Utilisez le simulateur pour voir les conditions qui vous seraient proposées");
        help.push("🎯 Un montant adapté à vos revenus augmente vos chances d'approbation");
        break;
        
      case 2:
        help.push("📝 Assurez-vous que toutes les informations sont exactes et à jour");
        help.push("📧 L'email sera utilisé pour toutes les communications sur votre dossier");
        break;
        
      case 3:
        help.push("💰 Soyez précis sur vos revenus et charges pour un calcul optimal");
        help.push("📊 Plus votre profil financier est détaillé, meilleures seront vos conditions");
        break;
        
      case 4:
        help.push("📎 Des documents de qualité accélèrent le traitement de votre dossier");
        help.push("✅ Tous les documents obligatoires doivent être fournis");
        break;
        
      case 5:
        help.push("👀 Vérifiez attentivement tous les détails avant de soumettre");
        help.push("📋 Une fois soumise, votre demande sera examinée sous 24-48h");
        break;
    }
    
    return help;
  }
}