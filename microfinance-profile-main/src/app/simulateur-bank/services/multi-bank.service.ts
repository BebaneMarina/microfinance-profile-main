import { Injectable } from '@angular/core';
import { HttpClient, HttpHeaders, HttpErrorResponse } from '@angular/common/http';
import { Observable, of, forkJoin, throwError, BehaviorSubject } from 'rxjs';
import { map, catchError, timeout, retry, mergeMap, delay, tap } from 'rxjs/operators';
import { 
  MultiBankSimulationInput, 
  MultiBankComparisonResult, 
  BankOffer,
  BankSimulationRequest,
  BankSimulationResponse,
  CreditApplication
} from '../components/models/multi-bank.model';
import { Bank, BankApiConfig, BankResponse, BankIntegrationStatus } from '../components/models/bank.model';
import { NotificationService } from './notification.service';
import { AnalyticsService } from './analytics.service';

@Injectable({
  providedIn: 'root'
})
export class MultiBankService {
  private readonly apiUrl = '/api/v1';
  private readonly timeout = 30000;
  private bankConfigs = new Map<string, BankApiConfig>();
  private bankStatuses$ = new BehaviorSubject<Map<string, BankIntegrationStatus>>(new Map());

  constructor(
    private http: HttpClient,
    private notificationService: NotificationService,
    private analyticsService: AnalyticsService
  ) {
    this.initializeBankConfigs();
    this.startHealthChecks();
  }

  simulateMultiBank(input: MultiBankSimulationInput): Observable<MultiBankComparisonResult> {
    const startTime = Date.now();
    
    this.analyticsService.trackEvent('multi_bank_simulation_start', {
      selected_banks: input.selectedBanks.length,
      credit_type: input.creditType,
      amount: input.requestedAmount
    });

    const bankRequests = input.selectedBanks.map(bankId => 
      this.simulateWithBank(bankId, input)
    );

    return forkJoin(bankRequests).pipe(
      map(responses => this.processBankResponses(responses, input)),
      tap(result => {
        const processingTime = Date.now() - startTime;
        this.analyticsService.trackEvent('multi_bank_simulation_complete', {
          processing_time: processingTime,
          offers_count: result.bankOffers.length,
          best_rate: result.bestOffer?.interestRate
        });
      }),
      catchError(error => {
        this.analyticsService.trackError(error, { context: 'multi_bank_simulation' });
        return throwError(() => new Error('Erreur lors de la simulation multi-banques'));
      })
    );
  }

  private simulateWithBank(bankId: string, input: MultiBankSimulationInput): Observable<BankResponse> {
    const startTime = Date.now();
    
    return this.getAvailableBanks().pipe(
      mergeMap(banks => {
        const bank = banks.find(b => b.id === bankId);
        if (!bank) {
          throw new Error(`Banque ${bankId} non trouvée`);
        }

        if (!this.checkBasicEligibility(bank, input)) {
          return of(this.createIneligibleResponse(bankId, bank.name, 'Critères d\'éligibilité non respectés'));
        }

        if (bankId === 'bamboo') {
          return this.simulateInternalBank(bank, input);
        } else {
          return this.simulateExternalBank(bank, input);
        }
      }),
      timeout(this.timeout),
      retry(2),
      map(response => ({
        ...response,
        responseTime: Date.now() - startTime
      })),
      catchError(error => {
        console.error(`Erreur simulation ${bankId}:`, error);
        return of(this.createErrorResponse(bankId, error));
      })
    );
  }

  submitExternalApplication(applicationData: any): Observable<{ trackingNumber: string }> {
    const trackingNumber = this.generateTrackingNumber();
    
    return this.http.post<{ trackingNumber: string }>(`${this.apiUrl}/external-applications`, {
      ...applicationData,
      trackingNumber,
      submittedAt: new Date().toISOString()
    }).pipe(
      tap(() => {
        this.analyticsService.trackEvent('external_application_submitted', {
          bank_id: applicationData.bankId,
          tracking_number: trackingNumber
        });
      }),
      catchError(error => {
        console.error('Erreur soumission externe:', error);
        return of({ trackingNumber });
      })
    );
  }

  saveComparison(comparisonData: any): Observable<{ id: string }> {
    const comparisonId = this.generateComparisonId();
    
    return this.http.post<{ id: string }>(`${this.apiUrl}/comparisons`, {
      ...comparisonData,
      id: comparisonId,
      savedAt: new Date().toISOString()
    }).pipe(
      catchError(() => {
        this.saveComparisonLocally(comparisonId, comparisonData);
        return of({ id: comparisonId });
      })
    );
  }

  exportComparisonToPDF(results: MultiBankComparisonResult, formData: any): Observable<Blob> {
    const exportData = {
      results,
      formData,
      timestamp: new Date().toISOString(),
      metadata: {
        generatedBy: 'Bamboo Multi-Bank Comparator',
        version: '1.0.0'
      }
    };
    
    return this.http.post(`${this.apiUrl}/export/pdf`, exportData, {
      responseType: 'blob',
      headers: new HttpHeaders({
        'Content-Type': 'application/json'
      })
    }).pipe(
      catchError(() => {
        return this.generatePDFClientSide(results, formData);
      })
    );
  }

  getAvailableBanks(): Observable<Bank[]> {
    const mockBanks: Bank[] = [
      {
        id: 'bgfi',
        name: 'BGFI Bank',
        shortName: 'BGFI',
        color: '#005baa',
        marketShare: 28,
        logo: '/assets/banks/bgfi-logo.png',
        description: 'Banque Gabonaise et Française Internationale',
        isActive: true,
        supportedCreditTypes: ['consommation', 'auto', 'immobilier'],
        minAmount: 100000,
        maxAmount: 50000000,
        minDuration: 6,
        maxDuration: 84,
        baseInterestRate: 8.5,
        processingTime: 72,
        requiredDocuments: ['carte_identite', 'justificatif_revenus', 'releve_bancaire'],
        eligibilityCriteria: {
          minIncome: 300000,
          minAge: 21,
          maxAge: 65,
          acceptedProfessions: ['salarie', 'fonctionnaire', 'entrepreneur'],
          blacklistedProfessions: []
        },
        contactInfo: {
          phone: '+241 01 44 63 63',
          email: 'contact@bgfibank.ga',
          website: 'https://www.bgfibank.ga',
          address: 'Boulevard Triomphal Omar Bongo, Libreville'
        },
        ratings: {
          customerService: 4.2,
          processSpeed: 3.8,
          competitiveRates: 4.0,
          overall: 4.0
        },
        fees: {
          applicationFee: 25000,
          processingFee: 50000,
          insuranceFee: 1.2,
          penaltyRate: 2.0
        },
        specialOffers: [],
        createdAt: new Date(),
        updatedAt: new Date()
      },
      {
        id: 'ugb',
        name: 'UGB (Union Gabonaise de Banque)',
        shortName: 'UGB',
        color: '#e30613',
        marketShare: 25,
        logo: '/assets/banks/ugb-logo.png',
        description: 'Union Gabonaise de Banque',
        isActive: true,
        supportedCreditTypes: ['consommation', 'auto', 'immobilier', 'investissement'],
        minAmount: 200000,
        maxAmount: 75000000,
        minDuration: 6,
        maxDuration: 96,
        baseInterestRate: 9.0,
        processingTime: 48,
        requiredDocuments: ['carte_identite', 'justificatif_revenus', 'releve_bancaire'],
        eligibilityCriteria: {
          minIncome: 250000,
          minAge: 18,
          maxAge: 70,
          acceptedProfessions: ['salarie', 'fonctionnaire', 'entrepreneur', 'liberal'],
          blacklistedProfessions: []
        },
        contactInfo: {
          phone: '+241 01 76 24 24',
          email: 'info@ugb.ga',
          website: 'https://www.ugb.ga',
          address: 'Avenue du Colonel Parant, Libreville'
        },
        ratings: {
          customerService: 4.1,
          processSpeed: 4.2,
          competitiveRates: 3.9,
          overall: 4.1
        },
        fees: {
          applicationFee: 30000,
          processingFee: 40000,
          insuranceFee: 1.5,
          penaltyRate: 2.5
        },
        specialOffers: [],
        createdAt: new Date(),
        updatedAt: new Date()
      },
      {
        id: 'bicig',
        name: 'BICIG',
        shortName: 'BICIG',
        color: '#ffcc00',
        marketShare: 22,
        logo: '/assets/banks/bicig-logo.png',
        description: 'Banque Internationale pour le Commerce et l\'Industrie du Gabon',
        isActive: true,
        supportedCreditTypes: ['consommation', 'auto', 'equipement', 'tresorerie'],
        minAmount: 150000,
        maxAmount: 60000000,
        minDuration: 6,
        maxDuration: 72,
        baseInterestRate: 8.8,
        processingTime: 96,
        requiredDocuments: ['carte_identite', 'justificatif_revenus', 'releve_bancaire'],
        eligibilityCriteria: {
          minIncome: 400000,
          minAge: 21,
          maxAge: 65,
          acceptedProfessions: ['salarie', 'fonctionnaire'],
          blacklistedProfessions: ['etudiant']
        },
        contactInfo: {
          phone: '+241 01 44 35 35',
          email: 'clientele@bicig.ga',
          website: 'https://www.bicig.ga',
          address: 'Boulevard de l\'Indépendance, Libreville'
        },
        ratings: {
          customerService: 3.9,
          processSpeed: 3.5,
          competitiveRates: 4.2,
          overall: 3.9
        },
        fees: {
          applicationFee: 20000,
          processingFee: 60000,
          insuranceFee: 1.0,
          penaltyRate: 1.8
        },
        specialOffers: [],
        createdAt: new Date(),
        updatedAt: new Date()
      },
      {
        id: 'bamboo',
        name: 'Bamboo',
        shortName: 'BMB',
        color: '#00a651',
        marketShare: 15,
        logo: '/assets/banks/bamboo-logo.png',
        description: 'Plateforme de financement digital',
        isActive: true,
        supportedCreditTypes: ['consommation', 'auto', 'investissement', 'equipement'],
        minAmount: 50000,
        maxAmount: 25000000,
        minDuration: 3,
        maxDuration: 60,
        baseInterestRate: 7.5,
        processingTime: 24,
        requiredDocuments: ['carte_identite', 'justificatif_revenus'],
        eligibilityCriteria: {
          minIncome: 200000,
          minAge: 18,
          maxAge: 65,
          acceptedProfessions: ['salarie', 'fonctionnaire', 'entrepreneur', 'liberal'],
          blacklistedProfessions: []
        },
        contactInfo: {
          phone: '+241 01 23 45 67',
          email: 'support@bamboo.ga',
          website: 'https://www.bamboo.ga',
          address: 'Quartier Batterie IV, Libreville'
        },
        ratings: {
          customerService: 4.5,
          processSpeed: 4.8,
          competitiveRates: 4.3,
          overall: 4.5
        },
        fees: {
          applicationFee: 0,
          processingFee: 25000,
          insuranceFee: 0.8,
          penaltyRate: 1.5
        },
        specialOffers: [
          {
            id: 'new-customer-2024',
            title: 'Offre Nouveaux Clients',
            description: 'Taux préférentiel pour les nouveaux clients',
            discountType: 'rate_reduction',
            discountValue: 0.5,
            conditions: ['Première demande', 'Montant minimum 500 000 FCFA'],
            validFrom: new Date('2024-01-01'),
            validTo: new Date('2024-12-31'),
            isActive: true,
            targetSegment: 'new_customers'
          }
        ],
        createdAt: new Date(),
        updatedAt: new Date()
      }
    ];

    return of(mockBanks).pipe(
      delay(500),
      tap(banks => {
        this.analyticsService.trackEvent('banks_loaded', {
          count: banks.length,
          active_count: banks.filter(b => b.isActive).length
        });
      })
    );
  }

  private simulateInternalBank(bank: Bank, input: MultiBankSimulationInput): Observable<BankResponse> {
    const baseRate = bank.baseInterestRate;
    const riskAdjustment = this.calculateRiskAdjustment(input);
    const finalRate = Math.max(baseRate + riskAdjustment, 5.0);
    const monthlyPayment = this.calculateMonthlyPayment(input.requestedAmount, finalRate, input.duration);
    const totalCost = monthlyPayment * input.duration;
    const approvalChance = this.calculateApprovalChance(bank, input);

    const offer: BankOffer = {
      bankId: bank.id,
      bankName: bank.name,
      bankLogo: bank.logo,
      bankColor: bank.color,
      interestRate: finalRate,
      monthlyPayment,
      totalCost,
      approvedAmount: input.requestedAmount,
      duration: input.duration,
      processingTime: bank.processingTime,
      approvalChance,
      competitiveAdvantages: this.generateCompetitiveAdvantages(bank, input),
      eligibilityStatus: approvalChance > 70 ? 'eligible' : approvalChance > 40 ? 'conditional' : 'not_eligible',
      fees: {
        applicationFee: bank.fees.applicationFee,
        processingFee: bank.fees.processingFee,
        insuranceFee: (input.requestedAmount * bank.fees.insuranceFee) / 100,
        totalFees: bank.fees.applicationFee + bank.fees.processingFee + ((input.requestedAmount * bank.fees.insuranceFee) / 100)
      },
      requiredDocuments: bank.requiredDocuments,
      specialConditions: this.getSpecialConditions(bank, input),
      contactInfo: bank.contactInfo,
      validUntil: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
      terms: this.generateTermsAndConditions(bank, input),
      creditType: ''
    };

    return of({
      bankId: bank.id,
      success: true,
      data: offer,
      responseTime: 0,
      timestamp: new Date()
    });
  }

  private simulateExternalBank(bank: Bank, input: MultiBankSimulationInput): Observable<BankResponse> {
    const baseRate = bank.baseInterestRate;
    const rateVariation = (Math.random() - 0.5) * 2;
    const finalRate = Math.max(baseRate + rateVariation, 6.0);
    const monthlyPayment = this.calculateMonthlyPayment(input.requestedAmount, finalRate, input.duration);
    const totalCost = monthlyPayment * input.duration;
    const approvalChance = this.calculateApprovalChance(bank, input);

    const offer: BankOffer = {
      bankId: bank.id,
      bankName: bank.name,
      bankLogo: bank.logo,
      bankColor: bank.color,
      interestRate: finalRate,
      monthlyPayment,
      totalCost,
      approvedAmount: Math.min(input.requestedAmount, this.calculateMaxApprovedAmount(bank, input)),
      duration: input.duration,
      processingTime: bank.processingTime,
      approvalChance,
      competitiveAdvantages: this.generateCompetitiveAdvantages(bank, input),
      eligibilityStatus: approvalChance > 60 ? 'eligible' : approvalChance > 30 ? 'conditional' : 'not_eligible',
      fees: {
        applicationFee: bank.fees.applicationFee,
        processingFee: bank.fees.processingFee,
        insuranceFee: (input.requestedAmount * bank.fees.insuranceFee) / 100,
        totalFees: bank.fees.applicationFee + bank.fees.processingFee + ((input.requestedAmount * bank.fees.insuranceFee) / 100)
      },
      requiredDocuments: bank.requiredDocuments,
      specialConditions: this.getSpecialConditions(bank, input),
      contactInfo: bank.contactInfo,
      validUntil: new Date(Date.now() + 15 * 24 * 60 * 60 * 1000),
      terms: this.generateTermsAndConditions(bank, input),
      creditType: ''
    };

    return of({
      bankId: bank.id,
      success: true,
      data: offer,
      responseTime: 0,
      timestamp: new Date()
    }).pipe(
      delay(Math.random() * 2000 + 500)
    );
  }
  private generateCompetitiveAdvantages(bank: Bank, input: MultiBankSimulationInput): string[] {
  const advantages: string[] = [];
  
  if (bank.id === 'bamboo') {
    advantages.push('Traitement rapide en 24h');
    advantages.push('Frais de dossier réduits');
  } else if (input.requestedAmount > 5000000) {
    advantages.push('Taux préférentiel pour gros montants');
  }
  
  if (bank.ratings.overall > 4) {
    advantages.push('Banque bien notée par les clients');
  }
  
  return advantages;
}
  private processBankResponses(responses: BankResponse[], input: MultiBankSimulationInput): MultiBankComparisonResult {
    const validOffers = responses
      .filter(response => response.success && response.data)
      .map(response => response.data as BankOffer)
      .filter(offer => offer.eligibilityStatus !== 'not_eligible');

    if (validOffers.length === 0) {
      throw new Error('Aucune offre éligible trouvée');
    }

    validOffers.sort((a, b) => a.interestRate - b.interestRate);

    const bestOffer = validOffers[0];
    const averageRate = validOffers.reduce((sum, offer) => sum + offer.interestRate, 0) / validOffers.length;
    const totalSavings = validOffers.length > 1 ? 
      validOffers[validOffers.length - 1].totalCost - bestOffer.totalCost : 0;

    return {
      requestId: this.generateRequestId(),
      bankOffers: validOffers,
      bestOffer,
      summary: {
        totalOffers: validOffers.length,
        averageRate,
        bestRate: bestOffer.interestRate,
        worstRate: validOffers[validOffers.length - 1]?.interestRate || bestOffer.interestRate,
        totalSavings,
        fastestProcessing: Math.min(...validOffers.map(o => o.processingTime)),
        highestApprovalChance: Math.max(...validOffers.map(o => o.approvalChance))
      },
      comparisonMetrics: {
        rateSpread: validOffers.length > 1 ? 
          validOffers[validOffers.length - 1].interestRate - bestOffer.interestRate : 0,
        paymentDifference: validOffers.length > 1 ?
          validOffers[validOffers.length - 1].monthlyPayment - bestOffer.monthlyPayment : 0,
        processingTimeRange: validOffers.length > 1 ?
          Math.max(...validOffers.map(o => o.processingTime)) - Math.min(...validOffers.map(o => o.processingTime)) : 0
      },
      marketAnalysis: {
        bestRate: bestOffer.interestRate,
        averageRate,
        averageProcessingTime: validOffers.reduce((sum, o) => sum + o.processingTime, 0) / validOffers.length,
        approvalRate: validOffers.filter(o => o.approvalChance > 70).length / validOffers.length * 100
      },
      recommendations: this.generateRecommendations(validOffers, input),
      createdAt: new Date(),
      expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000)
    };
  }

  private checkBasicEligibility(bank: Bank, input: MultiBankSimulationInput): boolean {
    const criteria = bank.eligibilityCriteria;
    
    if (input.monthlyIncome < criteria.minIncome) return false;
    if (input.requestedAmount < bank.minAmount || input.requestedAmount > bank.maxAmount) return false;
    if (input.duration < bank.minDuration || input.duration > bank.maxDuration) return false;
    if (!bank.supportedCreditTypes.includes(input.creditType)) return false;
    
    return true;
  }

  private calculateRiskAdjustment(input: MultiBankSimulationInput): number {
    let adjustment = 0;
    
    if (input.monthlyIncome < 500000) adjustment += 1.5;
    else if (input.monthlyIncome < 1000000) adjustment += 0.5;
    else adjustment -= 0.5;
    
    const debtToIncomeRatio = (input.requestedAmount / input.duration) / input.monthlyIncome;
    if (debtToIncomeRatio > 0.4) adjustment += 2;
    else if (debtToIncomeRatio > 0.3) adjustment += 1;
    
    if (input.duration > 48) adjustment += 0.5;
    else if (input.duration < 12) adjustment += 1;
    
    return Math.max(adjustment, -2);
  }

  private calculateMonthlyPayment(amount: number, annualRate: number, durationMonths: number): number {
    const monthlyRate = annualRate / 100 / 12;
    if (monthlyRate === 0) return amount / durationMonths;
    
    const payment = amount * (monthlyRate * Math.pow(1 + monthlyRate, durationMonths)) / 
                    (Math.pow(1 + monthlyRate, durationMonths) - 1);
    
    return Math.round(payment);
  }

  private calculateApprovalChance(bank: Bank, input: MultiBankSimulationInput): number {
    let chance = 80;
    
    if (input.monthlyIncome > bank.eligibilityCriteria.minIncome * 2) chance += 10;
    if (input.clientType === 'entreprise') chance += 5;
    
    const debtToIncomeRatio = (input.requestedAmount / input.duration) / input.monthlyIncome;
    if (debtToIncomeRatio > 0.4) chance -= 20;
    else if (debtToIncomeRatio > 0.3) chance -= 10;
    
    if (input.requestedAmount > bank.maxAmount * 0.8) chance -= 15;
    
    return Math.max(Math.min(chance, 95), 10);
  }

  private calculateMaxApprovedAmount(bank: Bank, input: MultiBankSimulationInput): number {
    const maxBasedOnIncome = input.monthlyIncome * input.duration * 0.4;
    return Math.min(input.requestedAmount, maxBasedOnIncome, bank.maxAmount);
  }

  private getSpecialConditions(bank: Bank, input: MultiBankSimulationInput): string[] {
    const conditions: string[] = [];
    
    if (input.monthlyIncome < bank.eligibilityCriteria.minIncome * 1.5) {
      conditions.push('Garantie supplémentaire requise');
    }
    
    if (input.requestedAmount > 5000000) {
      conditions.push('Étude de dossier approfondie');
    }
    
    if (input.clientType === 'entreprise') {
      conditions.push('Bilans des 3 dernières années requis');
    }
    
    return conditions;
  }

  private generateRecommendations(offers: BankOffer[], input: MultiBankSimulationInput): string[] {
    const recommendations: string[] = [];
    
    if (offers.length > 1) {
      const bestOffer = offers[0];
      const savings = offers[offers.length - 1].totalCost - bestOffer.totalCost;
      if (savings > 100000) {
        recommendations.push(`Économisez ${this.formatCurrency(savings)} en choisissant ${bestOffer.bankName}`);
      }
    }
    
    const fastestBank = offers.reduce((prev, current) => 
      prev.processingTime < current.processingTime ? prev : current
    );
    
    if (fastestBank.processingTime <= 48) {
      recommendations.push(`Obtenez une réponse rapide avec ${fastestBank.bankName} (${fastestBank.processingTime}h)`);
    }
    
    return recommendations;
  }

  private generateTermsAndConditions(bank: Bank, input: MultiBankSimulationInput): string {
    return `Offre valable 30 jours. Taux fixe sur ${input.duration} mois. Assurance décès-invalidité incluse. Frais de dossier: ${this.formatCurrency(bank.fees.processingFee)}.`;
  }

  private createIneligibleResponse(bankId: string, bankName: string, reason: string): BankResponse {
    return {
      bankId,
      success: false,
      error: {
        code: 'NOT_ELIGIBLE',
        message: reason
      },
      responseTime: 0,
      timestamp: new Date()
    };
  }

  private createErrorResponse(bankId: string, error: any): BankResponse {
    return {
      bankId,
      success: false,
      error: {
        code: 'SIMULATION_ERROR',
        message: error.message || 'Erreur de simulation',
        details: error
      },
      responseTime: 0,
      timestamp: new Date()
    };
  }

  private saveComparisonLocally(id: string, data: any): void {
    try {
      const saved = localStorage.getItem('bamboo_comparisons') || '{}';
      const comparisons = JSON.parse(saved);
      comparisons[id] = { ...data, savedLocally: true };
      localStorage.setItem('bamboo_comparisons', JSON.stringify(comparisons));
    } catch (error) {
      console.error('Erreur sauvegarde locale:', error);
    }
  }

  private generatePDFClientSide(results: MultiBankComparisonResult, formData: any): Observable<Blob> {
    const content = this.generatePDFContent(results, formData);
    const blob = new Blob([content], { type: 'application/pdf' });
    return of(blob);
  }

  private generatePDFContent(results: MultiBankComparisonResult, formData: any): string {
    return `
      COMPARAISON DE CRÉDITS - BAMBOO
      ================================
      
      Client: ${formData.fullName}
      Montant demandé: ${this.formatCurrency(formData.requestedAmount)}
      Durée: ${formData.duration} mois
      
      MEILLEURE OFFRE:
      ${results.bestOffer?.bankName} - ${results.bestOffer?.interestRate}%
      Mensualité: ${this.formatCurrency(results.bestOffer?.monthlyPayment || 0)}
      
      Date: ${new Date().toLocaleDateString('fr-FR')}
    `;
  }

  private initializeBankConfigs(): void {
    this.bankConfigs.set('bgfi', {
      bankId: 'bgfi',
      baseUrl: 'https://api.bgfibank.ga',
      apiKey: 'bgfi_api_key',
      endpoints: {
        simulation: '/v1/credit/simulate',
        application: '/v1/credit/apply',
        status: '/v1/credit/status',
        documents: '/v1/documents'
      },
      authMethod: 'api_key',
      rateLimit: {
        requestsPerMinute: 30,
        requestsPerDay: 1000
      },
      timeout: 15000,
      retryAttempts: 3
    });

    this.bankConfigs.set('ugb', {
      bankId: 'ugb',
      baseUrl: 'https://api.ugb.ga',
      apiKey: 'ugb_api_key',
      endpoints: {
        simulation: '/api/v2/loan/quote',
        application: '/api/v2/loan/submit',
        status: '/api/v2/loan/track',
        documents: '/api/v2/documents'
      },
      authMethod: 'oauth',
      rateLimit: {
        requestsPerMinute: 20,
        requestsPerDay: 500
      },
      timeout: 20000,
      retryAttempts: 2
    });

    this.bankConfigs.set('bicig', {
      bankId: 'bicig',
      baseUrl: 'https://services.bicig.ga',
      apiKey: 'bicig_api_key',
      endpoints: {
        simulation: '/credit/simulation',
        application: '/credit/application',
        status: '/credit/status',
        documents: '/documents/upload'
      },
      authMethod: 'basic_auth',
      rateLimit: {
        requestsPerMinute: 25,
        requestsPerDay: 800
      },
      timeout: 10000,
      retryAttempts: 3
    });
  }

  private startHealthChecks(): void {
    setInterval(() => {
      this.checkBankStatuses();
    }, 5 * 60 * 1000);

    this.checkBankStatuses();
  }

  private checkBankStatuses(): void {
    this.getAvailableBanks().subscribe(banks => {
      banks.forEach(bank => {
        this.checkBankHealth(bank.id);
      });
    });
  }

  private checkBankHealth(bankId: string): void {
    const startTime = Date.now();
    const config = this.bankConfigs.get(bankId);
    
    if (!config) return;

    const isOnline = Math.random() > 0.1;
    const responseTime = Math.random() * 2000 + 500;
    
    const status: BankIntegrationStatus = {
      bankId,
      isOnline,
      lastCheck: new Date(),
      averageResponseTime: responseTime,
      successRate: isOnline ? 95 + Math.random() * 5 : 0,
      healthScore: isOnline ? 85 + Math.random() * 15 : 20,
      lastError: isOnline ? undefined : 'Connection timeout'
    };

    const currentStatuses = this.bankStatuses$.value;
    currentStatuses.set(bankId, status);
    this.bankStatuses$.next(currentStatuses);
  }

  getBankStatuses(): Observable<Map<string, BankIntegrationStatus>> {
    return this.bankStatuses$.asObservable();
  }

  getBankStatus(bankId: string): Observable<BankIntegrationStatus | undefined> {
    return this.bankStatuses$.pipe(
      map(statuses => statuses.get(bankId))
    );
  }

  getUserComparisons(userId: string): Observable<MultiBankComparisonResult[]> {
    return this.http.get<MultiBankComparisonResult[]>(`${this.apiUrl}/users/${userId}/comparisons`).pipe(
      catchError(() => {
        try {
          const saved = localStorage.getItem('bamboo_comparisons') || '{}';
          const comparisons = JSON.parse(saved);
          return of(Object.values(comparisons) as MultiBankComparisonResult[]);
        } catch {
          return of([] as MultiBankComparisonResult[]);
        }
      })
    );
  }

  trackCreditApplication(trackingNumber: string): Observable<any> {
    return this.http.get(`${this.apiUrl}/applications/${trackingNumber}/status`).pipe(
      catchError(() => {
        return of({
          trackingNumber,
          status: 'in_review',
          lastUpdate: new Date(),
          estimatedCompletion: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
          steps: [
            { name: 'Soumission', completed: true, date: new Date() },
            { name: 'Vérification', completed: true, date: new Date() },
            { name: 'Analyse', completed: false, date: null },
            { name: 'Décision', completed: false, date: null }
          ]
        });
      })
    );
  }

  updateUserPreferences(preferences: any): Observable<any> {
    return this.http.put(`${this.apiUrl}/user/preferences`, preferences).pipe(
      catchError(() => {
        localStorage.setItem('bamboo_user_preferences', JSON.stringify(preferences));
        return of({ success: true });
      })
    );
  }

  private generateRequestId(): string {
    return 'req_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
  }

  private generateTrackingNumber(): string {
    const prefix = 'BMB';
    const timestamp = Date.now().toString().slice(-8);
    const random = Math.random().toString(36).substr(2, 4).toUpperCase();
    return `${prefix}${timestamp}${random}`;
  }

  private generateComparisonId(): string {
    return 'comp_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
  }

  private formatCurrency(amount: number): string {
    return new Intl.NumberFormat('fr-FR', {
      style: 'currency',
      currency: 'XAF',
      minimumFractionDigits: 0
    }).format(amount);
  }

  compareOffers(offer1: BankOffer, offer2: BankOffer): any {
    return {
      rateDifference: offer2.interestRate - offer1.interestRate,
      paymentDifference: offer2.monthlyPayment - offer1.monthlyPayment,
      totalCostDifference: offer2.totalCost - offer1.totalCost,
      processingTimeDifference: offer2.processingTime - offer1.processingTime,
      approvalChanceDifference: offer2.approvalChance - offer1.approvalChance,
      recommendation: offer1.totalCost < offer2.totalCost ? offer1.bankName : offer2.bankName
    };
  }

  calculateDetailedEligibility(bank: Bank, input: MultiBankSimulationInput): any {
    const criteria = bank.eligibilityCriteria;
    const checks = {
      income: input.monthlyIncome >= criteria.minIncome,
      amount: input.requestedAmount >= bank.minAmount && input.requestedAmount <= bank.maxAmount,
      duration: input.duration >= bank.minDuration && input.duration <= bank.maxDuration,
      creditType: bank.supportedCreditTypes.includes(input.creditType),
      profession: criteria.acceptedProfessions.length === 0 || 
                  criteria.acceptedProfessions.includes(input.profession || ''),
      blacklisted: !criteria.blacklistedProfessions.includes(input.profession || '')
    };

    const eligibilityScore = Object.values(checks).filter(Boolean).length / Object.keys(checks).length * 100;

    return {
      isEligible: Object.values(checks).every(Boolean),
      eligibilityScore,
      checks,
      recommendations: this.getEligibilityRecommendations(checks, criteria)
    };
  }

  private getEligibilityRecommendations(checks: any, criteria: any): string[] {
    const recs: string[] = [];
    
    if (!checks.income) {
      recs.push(`Augmentez vos revenus à minimum ${this.formatCurrency(criteria.minIncome)}`);
    }
    
    if (!checks.amount) {
      recs.push(`Ajustez le montant entre ${this.formatCurrency(criteria.minAmount)} et ${this.formatCurrency(criteria.maxAmount)}`);
    }
    
    if (!checks.profession) {
      recs.push('Vérifiez les professions acceptées par cette banque');
    }
    
    return recs;
  }

  getMarketStatistics(): Observable<any> {
    return of({
      averageRates: {
        consommation: 9.2,
        auto: 8.5,
        immobilier: 7.8,
        investissement: 10.1
      },
      marketTrends: {
        rateDirection: 'stable',
        demandLevel: 'high',
        approvalRates: 72
      },
      bankRankings: [
        { bankId: 'bamboo', rank: 1, score: 4.5 },
        { bankId: 'ugb', rank: 2, score: 4.1 },
        { bankId: 'bgfi', rank: 3, score: 4.0 },
        { bankId: 'bicig', rank: 4, score: 3.9 }
      ]
    });
  }

  cleanupExpiredData(): Observable<any> {
    try {
      const saved = localStorage.getItem('bamboo_comparisons') || '{}';
      const comparisons = JSON.parse(saved);
      const now = new Date();
      
      const cleaned = Object.keys(comparisons).reduce((acc, key) => {
        const comparison = comparisons[key];
        const expiresAt = new Date(comparison.expiresAt);
        
        if (expiresAt > now) {
          acc[key] = comparison;
        }
        
        return acc;
      }, {} as any);
      
      localStorage.setItem('bamboo_comparisons', JSON.stringify(cleaned));
      
      return of({ cleaned: Object.keys(comparisons).length - Object.keys(cleaned).length });
    } catch (error) {
      return throwError(() => error);
    }
  }
}