import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, of, BehaviorSubject, forkJoin } from 'rxjs';
import { map, catchError, tap, switchMap } from 'rxjs/operators';

// Types pour les différents simulateurs
export interface SimulatorConfig {
  type: 'capacity' | 'payment' | 'rate';
  name: string;
  description: string;
  icon: string;
  route: string;
  features: string[];
}

export interface MarketRates {
  creditType: string;
  averageRate: number;
  minRate: number;
  maxRate: number;
  trend: 'up' | 'down' | 'stable';
  lastUpdate: Date;
  sources: string[];
}

export interface CreditCalculationRequest {
  type: 'capacity' | 'payment' | 'rate';
  parameters: any;
  userProfile?: UserProfile;
}

export interface UserProfile {
  id?: string;
  age: number;
  profession: string;
  monthlyIncome: number;
  workExperience: number;
  bankingHistory: string;
  creditHistory: CreditHistoryEntry[];
  preferences: UserPreferences;
}

export interface CreditHistoryEntry {
  type: string;
  amount: number;
  duration: number;
  status: 'active' | 'completed' | 'defaulted';
  monthlyPayment: number;
  remainingAmount: number;
  startDate: Date;
  endDate?: Date;
}

export interface UserPreferences {
  preferredBanks: string[];
  maxDuration: number;
  riskTolerance: 'low' | 'medium' | 'high';
  notificationSettings: NotificationSettings;
}

export interface NotificationSettings {
  rateChanges: boolean;
  newOffers: boolean;
  paymentReminders: boolean;
  marketUpdates: boolean;
}

export interface SimulationHistory {
  id: string;
  type: 'capacity' | 'payment' | 'rate';
  parameters: any;
  results: any;
  createdAt: Date;
  userId?: string;
  favorite: boolean;
  notes?: string;
}

export interface ComparisonData {
  baseSimulation: any;
  alternatives: AlternativeSimulation[];
  recommendations: string[];
  bestOption: any;
  savings: number;
}

export interface AlternativeSimulation {
  title: string;
  description: string;
  parameters: any;
  results: any;
  difference: number;
  pros: string[];
  cons: string[];
}

export interface MarketAnalysis {
  currentPosition: 'excellent' | 'good' | 'average' | 'poor';
  competitiveRates: BankRateInfo[];
  marketTrends: MarketTrend[];
  forecast: RateForecast;
  negotiationOpportunities: string[];
}

export interface BankRateInfo {
  bankId: string;
  bankName: string;
  currentRate: number;
  conditions: string[];
  specialOffers: string[];
  processingTime: number;
  customerRating: number;
}

export interface MarketTrend {
  period: string;
  rateChange: number;
  volume: number;
  factors: string[];
}

export interface RateForecast {
  timeframe: '3m' | '6m' | '12m';
  expectedChange: number;
  confidence: number;
  factors: string[];
}

@Injectable({
  providedIn: 'root'
})
export class EnhancedCreditSimulatorService {
  private readonly apiUrl = '/api/v2/simulator';
  private readonly localStorageKey = 'bamboo_simulator_data';
  
  // Observables pour le state management
  private simulationHistory$ = new BehaviorSubject<SimulationHistory[]>([]);
  private userProfile$ = new BehaviorSubject<UserProfile | null>(null);
  private marketRates$ = new BehaviorSubject<MarketRates[]>([]);
  private favoriteSimulations$ = new BehaviorSubject<SimulationHistory[]>([]);

  // Configuration des simulateurs
  private simulatorConfigs: SimulatorConfig[] = [
    {
      type: 'capacity',
      name: 'Capacité d\'emprunt',
      description: 'Découvrez combien vous pouvez emprunter selon vos revenus',
      icon: 'trending-up',
      route: '/simulators/capacity',
      features: ['Calcul instantané', 'Graphique d\'évolution', 'Recommandations personnalisées']
    },
    {
      type: 'payment',
      name: 'Calcul de mensualités',
      description: 'Estimez vos mensualités selon le montant et la durée',
      icon: 'calculator',
      route: '/simulators/payment',
      features: ['Tableau d\'amortissement', 'Visualisation graphique', 'Optimisation durée']
    },
    {
      type: 'rate',
      name: 'Taux personnalisé',
      description: 'Obtenez un taux adapté à votre profil',
      icon: 'dollar-sign',
      route: '/simulators/rate',
      features: ['Analyse du profil', 'Taux en temps réel', 'Comparaison banques']
    }
  ];
    exportSimulation: any;
    getDailyRates: any;

  constructor(private http: HttpClient) {
    this.loadFromStorage();
    this.initializeMarketRates();
  }

  // === MÉTHODES PRINCIPALES DE SIMULATION ===

  /**
   * Calcule une simulation selon le type et les paramètres
   */
  calculate(request: CreditCalculationRequest): Observable<any> {
    const startTime = Date.now();
    
    return this.validateRequest(request).pipe(
      switchMap(validatedRequest => {
        switch (validatedRequest.type) {
          case 'capacity':
            return this.calculateBorrowingCapacity(validatedRequest.parameters);
          case 'payment':
            return this.calculatePayments(validatedRequest.parameters);
          case 'rate':
            return this.calculatePersonalizedRate(validatedRequest.parameters, validatedRequest.userProfile);
          default:
            throw new Error('Type de simulation non supporté');
        }
      }),
      tap(result => {
        const processingTime = Date.now() - startTime;
        this.saveToHistory(request, result);
        this.trackSimulation(request.type, processingTime, result);
      }),
      catchError(error => {
        console.error('Erreur simulation:', error);
        throw new Error('Erreur lors du calcul de la simulation');
      })
    );
  }

  /**
   * Calcul de la capacité d'emprunt
   */
  private calculateBorrowingCapacity(params: any): Observable<any> {
    return of(null).pipe(
      map(() => {
        const {
          monthlyIncome,
          additionalIncome = 0,
          currentDebts = 0,
          duration,
          interestRate,
          downPayment = 0,
          hasInsurance = true,
          insuranceRate = 0.36
        } = params;

        const totalIncome = monthlyIncome + additionalIncome;
        const maxDebtRatio = this.getMaxDebtRatio(params);
        const maxMonthlyPayment = (totalIncome * maxDebtRatio / 100) - currentDebts;

        if (maxMonthlyPayment <= 0) {
          throw new Error('Capacité d\'emprunt insuffisante');
        }

        // Calcul avec assurance
        let effectiveMonthlyPayment = maxMonthlyPayment;
        if (hasInsurance) {
          effectiveMonthlyPayment = maxMonthlyPayment / (1 + (insuranceRate / 100 / 12));
        }

        const monthlyRate = interestRate / 100 / 12;
        const borrowingCapacity = this.calculateLoanAmount(effectiveMonthlyPayment, monthlyRate, duration);
        const totalProjectCapacity = borrowingCapacity + downPayment;

        // Génération des données additionnelles
        const amortizationData = this.generateAmortizationData(borrowingCapacity, interestRate, duration);
        const evolutionData = this.generateCapacityEvolution(params);
        const recommendations = this.generateCapacityRecommendations(params, borrowingCapacity);

        return {
          borrowingCapacity: Math.round(borrowingCapacity),
          maxMonthlyPayment: Math.round(maxMonthlyPayment),
          totalProjectCapacity: Math.round(totalProjectCapacity),
          debtRatio: ((maxMonthlyPayment + currentDebts) / totalIncome) * 100,
          amortizationData,
          evolutionData,
          recommendations,
          calculatedAt: new Date()
        };
      })
    );
  }

  /**
   * Calcul des mensualités
   */
  private calculatePayments(params: any): Observable<any> {
    return of(null).pipe(
      map(() => {
        const {
          loanAmount,
          duration,
          interestRate,
          includeInsurance = true,
          insuranceRate = 0.36,
          applicationFee = 0,
          notaryFees = 0
        } = params;

        const monthlyRate = interestRate / 100 / 12;
        const baseMonthlyPayment = this.calculateMonthlyPayment(loanAmount, monthlyRate, duration);
        
        const monthlyInsurance = includeInsurance ? 
          (loanAmount * insuranceRate / 100 / 12) : 0;
        
        const totalMonthlyPayment = baseMonthlyPayment + monthlyInsurance;
        const totalInterest = (baseMonthlyPayment * duration) - loanAmount;
        const totalCost = loanAmount + totalInterest + (monthlyInsurance * duration) + applicationFee + notaryFees;

        // Génération du tableau d'amortissement complet
        const amortizationSchedule = this.generateDetailedAmortizationSchedule(params);
        const optimizations = this.generatePaymentOptimizations(params, totalCost);
        const comparisonData = this.generateDurationComparisons(params);

        return {
          monthlyPayment: Math.round(totalMonthlyPayment),
          totalInterest: Math.round(totalInterest),
          totalCost: Math.round(totalCost),
          effectiveRate: this.calculateEffectiveRate(loanAmount, totalMonthlyPayment, duration, applicationFee + notaryFees),
          amortizationSchedule,
          optimizations,
          comparisonData,
          calculatedAt: new Date()
        };
      })
    );
  }

  /**
   * Calcul du taux personnalisé
   */
  private calculatePersonalizedRate(params: any, userProfile?: UserProfile): Observable<any> {
    return forkJoin({
      marketRates: this.getMarketRates(params.creditType),
      bankOffers: this.generateBankOffers(params, userProfile),
      riskProfile: of(this.calculateRiskProfile(params, userProfile))
    }).pipe(
      map(({ marketRates, bankOffers, riskProfile }) => {
        const baseRate = marketRates.averageRate;
        const estimatedRate = this.adjustRateForProfile(baseRate, riskProfile, params);
        
        const monthlyPayment = this.calculateMonthlyPayment(
          params.loanAmount, 
          estimatedRate / 100 / 12, 
          params.duration
        );

        const marketComparison = this.generateMarketComparison(estimatedRate, marketRates);
        const negotiationTips = this.generateNegotiationTips(riskProfile, params);
        const improvementSuggestions = this.generateImprovementSuggestions(riskProfile, params);

        return {
          estimatedRate,
          rateRange: {
            min: Math.max(3, estimatedRate - 1),
            max: estimatedRate + 1.5
          },
          riskProfile,
          bankOffers,
          monthlyPayment: Math.round(monthlyPayment),
          totalCost: Math.round(monthlyPayment * params.duration),
          marketComparison,
          negotiationTips,
          improvementSuggestions,
          calculatedAt: new Date()
        };
      })
    );
  }

  // === MÉTHODES DE COMPARAISON ET ANALYSE ===

  /**
   * Compare plusieurs simulations
   */
  compareSimulations(simulations: SimulationHistory[]): Observable<ComparisonData> {
    return of(simulations).pipe(
      map(sims => {
        const baseSimulation = sims[0];
        const alternatives = sims.slice(1).map(sim => this.createAlternativeComparison(baseSimulation, sim));
        
        const bestOption = this.findBestOption(sims);
        const savings = this.calculateMaxSavings(sims);
        const recommendations = this.generateComparisonRecommendations(sims);

        return {
          baseSimulation: baseSimulation.results,
          alternatives,
          recommendations,
          bestOption: bestOption.results,
          savings
        };
      })
    );
  }

  /**
   * Analyse du marché pour un type de crédit
   */
  analyzeMarket(creditType: string, amount: number, duration: number): Observable<MarketAnalysis> {
    return forkJoin({
      marketRates: this.getMarketRates(creditType),
      bankRates: this.getBankRates(creditType, amount, duration),
      trends: this.getMarketTrends(creditType),
      forecast: this.getRateForecast(creditType)
    }).pipe(
      map(({ marketRates, bankRates, trends, forecast }) => {
        const currentPosition = this.determineMarketPosition(marketRates.averageRate, bankRates);
        const negotiationOpportunities = this.identifyNegotiationOpportunities(bankRates, trends);

        return {
          currentPosition,
          competitiveRates: bankRates,
          marketTrends: trends,
          forecast,
          negotiationOpportunities
        };
      })
    );
  }

  // === GESTION DE L'HISTORIQUE ET DES FAVORIS ===

  /**
   * Sauvegarde une simulation dans l'historique
   */
  private saveToHistory(request: CreditCalculationRequest, result: any): void {
    const simulation: SimulationHistory = {
      id: this.generateId(),
      type: request.type,
      parameters: request.parameters,
      results: result,
      createdAt: new Date(),
      favorite: false,
      userId: request.userProfile?.id
    };

    const currentHistory = this.simulationHistory$.value;
    currentHistory.unshift(simulation);
    
    // Garder seulement les 100 dernières simulations
    if (currentHistory.length > 100) {
      currentHistory.splice(100);
    }

    this.simulationHistory$.next(currentHistory);
    this.saveToStorage();
  }

  /**
   * Récupère l'historique des simulations
   */
  getSimulationHistory(): Observable<SimulationHistory[]> {
    return this.simulationHistory$.asObservable();
  }

  /**
   * Marque une simulation comme favorite
   */
  toggleFavorite(simulationId: string): Observable<boolean> {
    const history = this.simulationHistory$.value;
    const simulation = history.find(s => s.id === simulationId);
    
    if (simulation) {
      simulation.favorite = !simulation.favorite;
      this.simulationHistory$.next(history);
      this.updateFavorites();
      this.saveToStorage();
      return of(simulation.favorite);
    }
    
    return of(false);
  }

  /**
   * Récupère les simulations favorites
   */
  getFavoriteSimulations(): Observable<SimulationHistory[]> {
    return this.favoriteSimulations$.asObservable();
  }

  /**
   * Supprime une simulation de l'historique
   */
  deleteSimulation(simulationId: string): Observable<boolean> {
    const history = this.simulationHistory$.value;
    const index = history.findIndex(s => s.id === simulationId);
    
    if (index > -1) {
      history.splice(index, 1);
      this.simulationHistory$.next(history);
      this.updateFavorites();
      this.saveToStorage();
      return of(true);
    }
    
    return of(false);
  }

  // === GESTION DES TAUX DE MARCHÉ ===

  /**
   * Récupère les taux du marché pour un type de crédit
   */
  getMarketRates(creditType: string): Observable<MarketRates> {
    // En production, ceci ferait appel à une API en temps réel
    const mockRates: Record<string, MarketRates> = {
      'immobilier': {
        creditType: 'immobilier',
        averageRate: 6.2,
        minRate: 5.1,
        maxRate: 8.5,
        trend: 'stable',
        lastUpdate: new Date(),
        sources: ['Banque Centrale', 'BGFI', 'UGB', 'BICIG']
      },
      'consommation': {
        creditType: 'consommation',
        averageRate: 12.5,
        minRate: 9.5,
        maxRate: 18.0,
        trend: 'down',
        lastUpdate: new Date(),
        sources: ['Banque Centrale', 'BGFI', 'UGB', 'BICIG']
      },
      'auto': {
        creditType: 'auto',
        averageRate: 8.9,
        minRate: 6.9,
        maxRate: 12.5,
        trend: 'stable',
        lastUpdate: new Date(),
        sources: ['Banque Centrale', 'BGFI', 'UGB', 'BICIG']
      }
    };

    return of(mockRates[creditType] || mockRates['immobilier']);
  }

  /**
   * Met à jour les taux de marché
   */
  refreshMarketRates(): Observable<MarketRates[]> {
    const creditTypes = ['immobilier', 'consommation', 'auto', 'travaux', 'professionnel'];
    
    return forkJoin(
      creditTypes.map(type => this.getMarketRates(type))
    ).pipe(
      tap(rates => {
        this.marketRates$.next(rates);
        this.saveToStorage();
      })
    );
  }

  // === MÉTHODES UTILITAIRES ===

  private calculateMonthlyPayment(amount: number, monthlyRate: number, duration: number): number {
    if (monthlyRate === 0) return amount / duration;
    
    const factor = Math.pow(1 + monthlyRate, duration);
    return amount * (monthlyRate * factor) / (factor - 1);
  }

  private calculateLoanAmount(monthlyPayment: number, monthlyRate: number, duration: number): number {
    if (monthlyRate === 0) return monthlyPayment * duration;
    
    const factor = Math.pow(1 + monthlyRate, duration);
    return monthlyPayment * (factor - 1) / (monthlyRate * factor);
  }

  private calculateEffectiveRate(principal: number, monthlyPayment: number, duration: number, fees: number = 0): number {
    const totalPaid = monthlyPayment * duration + fees;
    const totalInterest = totalPaid - principal;
    return (totalInterest / principal) / (duration / 12) * 100;
  }

  private getMaxDebtRatio(params: any): number {
    let baseRatio = 33;
    
    // Ajustements selon le profil
    if (params.incomeStability === 'very_stable') baseRatio += 2;
    if (params.incomeStability === 'unstable') baseRatio -= 3;
    if (params.monthlyIncome > 1500000) baseRatio += 2;
    if (params.workExperience > 10) baseRatio += 1;
    if (params.age > 50) baseRatio -= 2;
    
    return Math.max(25, Math.min(baseRatio, 35));
  }

  private generateAmortizationData(capital: number, rate: number, duration: number): any[] {
    const monthlyRate = rate / 100 / 12;
    const monthlyPayment = this.calculateMonthlyPayment(capital, monthlyRate, duration);
    
    let remainingCapital = capital;
    const data = [];
    
    for (let month = 1; month <= Math.min(duration, 60); month++) {
      const interestPayment = remainingCapital * monthlyRate;
      const principalPayment = monthlyPayment - interestPayment;
      remainingCapital -= principalPayment;
      
      if (month % 12 === 0 || month <= 12) {
        data.push({
          year: Math.ceil(month / 12),
          remainingDebt: Math.round(Math.max(0, remainingCapital)),
          paidPrincipal: Math.round(capital - remainingCapital),
          monthlyPayment: Math.round(monthlyPayment)
        });
      }
    }
    
    return data;
  }

  private validateRequest(request: CreditCalculationRequest): Observable<CreditCalculationRequest> {
    // Validation des paramètres selon le type
    const validationErrors: string[] = [];
    
    if (!request.type) {
      validationErrors.push('Type de simulation requis');
    }
    
    if (!request.parameters) {
      validationErrors.push('Paramètres requis');
    }
    
    // Validation spécifique selon le type
    switch (request.type) {
      case 'capacity':
        this.validateCapacityParams(request.parameters, validationErrors);
        break;
      case 'payment':
        this.validatePaymentParams(request.parameters, validationErrors);
        break;
      case 'rate':
        this.validateRateParams(request.parameters, validationErrors);
        break;
    }
    
    if (validationErrors.length > 0) {
      throw new Error(`Erreurs de validation: ${validationErrors.join(', ')}`);
    }
    
    return of(request);
  }

  private validateCapacityParams(params: any, errors: string[]): void {
    if (!params.monthlyIncome || params.monthlyIncome < 100000) {
      errors.push('Revenus mensuels invalides');
    }
    if (!params.duration || params.duration < 12 || params.duration > 360) {
      errors.push('Durée invalide (12-360 mois)');
    }
    if (!params.interestRate || params.interestRate < 1 || params.interestRate > 25) {
      errors.push('Taux d\'intérêt invalide (1-25%)');
    }
  }

  private validatePaymentParams(params: any, errors: string[]): void {
    if (!params.loanAmount || params.loanAmount < 100000) {
      errors.push('Montant du prêt invalide');
    }
    if (!params.duration || params.duration < 12 || params.duration > 360) {
      errors.push('Durée invalide (12-360 mois)');
    }
    if (!params.interestRate || params.interestRate < 1 || params.interestRate > 25) {
      errors.push('Taux d\'intérêt invalide (1-25%)');
    }
  }

  private validateRateParams(params: any, errors: string[]): void {
    if (!params.loanAmount || params.loanAmount < 100000) {
      errors.push('Montant du prêt invalide');
    }
    if (!params.creditType) {
      errors.push('Type de crédit requis');
    }
    if (!params.monthlyIncome || params.monthlyIncome < 100000) {
      errors.push('Revenus mensuels invalides');
    }
  }

  // Méthodes de stockage
  private loadFromStorage(): void {
    try {
      const saved = localStorage.getItem(this.localStorageKey);
      if (saved) {
        const data = JSON.parse(saved);
        if (data.simulationHistory) {
          this.simulationHistory$.next(data.simulationHistory);
        }
        if (data.userProfile) {
          this.userProfile$.next(data.userProfile);
        }
        if (data.marketRates) {
          this.marketRates$.next(data.marketRates);
        }
        this.updateFavorites();
      }
    } catch (error) {
      console.warn('Erreur chargement localStorage:', error);
    }
  }

  private saveToStorage(): void {
    try {
      const data = {
        simulationHistory: this.simulationHistory$.value,
        userProfile: this.userProfile$.value,
        marketRates: this.marketRates$.value,
        lastUpdate: new Date().toISOString()
      };
      localStorage.setItem(this.localStorageKey, JSON.stringify(data));
    } catch (error) {
      console.warn('Erreur sauvegarde localStorage:', error);
    }
  }

  private updateFavorites(): void {
    const favorites = this.simulationHistory$.value.filter(s => s.favorite);
    this.favoriteSimulations$.next(favorites);
  }

  private generateId(): string {
    return `sim_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  private trackSimulation(type: string, processingTime: number, result: any): void {
    // Analytics tracking
    console.log(`Simulation ${type} completed in ${processingTime}ms`, result);
  }

  // === MÉTHODES PRIVÉES POUR LES CALCULS AVANCÉS ===

  private generateCapacityEvolution(params: any): any[] {
    const durations = [120, 180, 240, 300, 360];
    const totalIncome = params.monthlyIncome + (params.additionalIncome || 0);
    const maxDebtRatio = this.getMaxDebtRatio(params);
    const maxMonthlyPayment = (totalIncome * maxDebtRatio / 100) - (params.currentDebts || 0);
    
    return durations.map(duration => {
      const monthlyRate = params.interestRate / 100 / 12;
      const capacity = this.calculateLoanAmount(maxMonthlyPayment, monthlyRate, duration);
      
      return {
        duration: duration / 12,
        capacity: Math.round(capacity),
        monthlyPayment: Math.round(maxMonthlyPayment),
        totalCost: Math.round(maxMonthlyPayment * duration)
      };
    });
  }

  private generateCapacityRecommendations(params: any, capacity: number): string[] {
    const recommendations: string[] = [];
    const debtRatio = ((params.currentDebts || 0) / params.monthlyIncome) * 100;
    
    if (debtRatio > 30) {
      recommendations.push('Réduisez vos charges actuelles pour améliorer votre capacité');
    }
    
    if ((params.downPayment || 0) < capacity * 0.1) {
      recommendations.push('Constituez un apport personnel de 10-20% pour de meilleures conditions');
    }
    
    if (params.duration > 300) {
      recommendations.push('Une durée plus courte réduirait le coût total du crédit');
    }
    
    if (recommendations.length === 0) {
      recommendations.push('Votre profil est excellent pour un emprunt !');
    }
    
    return recommendations;
  }

  private generateDetailedAmortizationSchedule(params: any): any[] {
    const { loanAmount, duration, interestRate, includeInsurance, insuranceRate } = params;
    const monthlyRate = interestRate / 100 / 12;
    const basePayment = this.calculateMonthlyPayment(loanAmount, monthlyRate, duration);
    
    let remainingCapital = loanAmount;
    let cumulativeInterest = 0;
    const schedule = [];
    
    for (let month = 1; month <= duration; month++) {
      const interestPayment = remainingCapital * monthlyRate;
      const capitalPayment = basePayment - interestPayment;
      const insurancePayment = includeInsurance ? (loanAmount * (insuranceRate || 0.36) / 100 / 12) : 0;
      
      remainingCapital -= capitalPayment;
      cumulativeInterest += interestPayment;
      
      schedule.push({
        month,
        year: Math.ceil(month / 12),
        monthlyPayment: Math.round(basePayment + insurancePayment),
        capitalPayment: Math.round(capitalPayment),
        interestPayment: Math.round(interestPayment),
        insurancePayment: Math.round(insurancePayment),
        remainingCapital: Math.round(Math.max(0, remainingCapital)),
        cumulativeInterest: Math.round(cumulativeInterest)
      });
    }
    
    return schedule;
  }

  private generatePaymentOptimizations(params: any, totalCost: number): any[] {
    const optimizations = [];
    
    // Optimisation par réduction de durée
    if (params.duration > 120) {
      const shorterDuration = Math.max(120, params.duration - 60);
      const shorterRate = params.interestRate / 100 / 12;
      const shorterPayment = this.calculateMonthlyPayment(params.loanAmount, shorterRate, shorterDuration);
      const shorterTotalCost = shorterPayment * shorterDuration;
      
      optimizations.push({
        type: 'duration',
        title: 'Réduire la durée',
        description: `Passer de ${params.duration/12} à ${shorterDuration/12} ans`,
        savings: Math.round(totalCost - shorterTotalCost),
        newMonthlyPayment: Math.round(shorterPayment)
      });
    }
    
    // Optimisation par négociation de taux
    if (params.interestRate > 5) {
      const betterRate = Math.max(5, params.interestRate - 0.5);
      const betterMonthlyRate = betterRate / 100 / 12;
      const betterPayment = this.calculateMonthlyPayment(params.loanAmount, betterMonthlyRate, params.duration);
      const betterTotalCost = betterPayment * params.duration;
      
      optimizations.push({
        type: 'rate',
        title: 'Négocier le taux',
        description: `Obtenir ${betterRate}% au lieu de ${params.interestRate}%`,
        savings: Math.round(totalCost - betterTotalCost),
        newMonthlyPayment: Math.round(betterPayment)
      });
    }
    
    return optimizations;
  }

  private generateDurationComparisons(params: any): any[] {
    const durations = [120, 180, 240, 300, 360].filter(d => d !== params.duration);
    durations.push(params.duration);
    durations.sort((a, b) => a - b);
    
    const monthlyRate = params.interestRate / 100 / 12;
    const currentPayment = this.calculateMonthlyPayment(params.loanAmount, monthlyRate, params.duration);
    const currentTotalCost = currentPayment * params.duration;
    
    return durations.map(duration => {
      const monthlyPayment = this.calculateMonthlyPayment(params.loanAmount, monthlyRate, duration);
      const totalCost = monthlyPayment * duration;
      
      return {
        duration: duration / 12,
        monthlyPayment: Math.round(monthlyPayment),
        totalCost: Math.round(totalCost),
        totalInterest: Math.round(totalCost - params.loanAmount),
        savings: Math.round(currentTotalCost - totalCost)
      };
    });
  }

  private calculateRiskProfile(params: any, userProfile?: UserProfile): any {
    let riskScore = 50;
    const factors = [];
    
    // Facteurs liés aux revenus
    if (params.monthlyIncome > 1500000) {
      riskScore += 15;
      factors.push({ name: 'Revenus élevés', impact: 'positive' });
    } else if (params.monthlyIncome < 500000) {
      riskScore -= 10;
      factors.push({ name: 'Revenus modestes', impact: 'negative' });
    }
    
    // Facteurs liés à l'âge
    if (params.age >= 25 && params.age <= 45) {
      riskScore += 10;
      factors.push({ name: 'Âge optimal', impact: 'positive' });
    } else if (params.age > 55) {
      riskScore -= 15;
      factors.push({ name: 'Âge élevé', impact: 'negative' });
    }
    
    // Facteurs professionnels
    if (userProfile?.profession === 'civil_servant') {
      riskScore += 20;
      factors.push({ name: 'Fonctionnaire', impact: 'positive' });
    } else if (userProfile?.profession === 'entrepreneur') {
      riskScore -= 10;
      factors.push({ name: 'Entrepreneur', impact: 'negative' });
    }
    
    // Historique bancaire
    if (userProfile?.bankingHistory === 'excellent') {
      riskScore += 15;
      factors.push({ name: 'Historique excellent', impact: 'positive' });
    } else if (userProfile?.bankingHistory === 'poor') {
      riskScore -= 25;
      factors.push({ name: 'Incidents bancaires', impact: 'negative' });
    }
    
    const level = riskScore >= 80 ? 'very_low' :
                 riskScore >= 65 ? 'low' :
                 riskScore >= 45 ? 'medium' :
                 riskScore >= 25 ? 'high' : 'very_high';
    
    return {
      level,
      score: Math.max(0, Math.min(100, riskScore)),
      factors
    };
  }

  private adjustRateForProfile(baseRate: number, riskProfile: any, params: any): number {
    let rate = baseRate;
    
    // Ajustement selon le risque
    const riskAdjustments = {
      'very_low': -1.2,
      'low': -0.6,
      'medium': 0,
      'high': 1.0,
      'very_high': 2.5
    };
    
    
    // Ajustements selon le montant
    if (params.loanAmount > 25000000) {
      rate -= 0.2;
    } else if (params.loanAmount < 2000000) {
      rate += 0.3;
    }
    
    // Ajustements selon la durée
    if (params.duration > 300) {
      rate += 0.3;
    } else if (params.duration < 120) {
      rate -= 0.2;
    }
    
    return Math.max(3.0, Math.round(rate * 100) / 100);
  }

  private generateBankOffers(params: any, userProfile?: UserProfile): Observable<any[]> {
    const banks = [
      { id: 'bamboo', name: 'Bamboo', baseRate: 0, processingTime: 24 },
      { id: 'bgfi', name: 'BGFI Bank', baseRate: 0.2, processingTime: 72 },
      { id: 'ugb', name: 'UGB', baseRate: 0.1, processingTime: 48 },
      { id: 'bicig', name: 'BICIG', baseRate: 0.3, processingTime: 96 }
    ];
    
    return this.getMarketRates(params.creditType).pipe(
      map(marketRates => {
        return banks.map(bank => {
          const variation = (Math.random() - 0.5) * 0.4;
          const estimatedRate = Math.max(3.0, marketRates.averageRate + bank.baseRate + variation);
          
          return {
            bankId: bank.id,
            bankName: bank.name,
            estimatedRate: Math.round(estimatedRate * 100) / 100,
            rateRange: {
              min: Math.max(3.0, estimatedRate - 0.3),
              max: estimatedRate + 0.5
            },
            processingTime: bank.processingTime,
            approvalProbability: this.calculateApprovalProbability(params, userProfile, bank.id),
            conditions: this.generateBankConditions(params, bank.id),
            specialOffers: this.generateSpecialOffers(params, bank.id)
          };
        }).sort((a, b) => a.estimatedRate - b.estimatedRate);
      })
    );
  }

  private calculateApprovalProbability(params: any, userProfile?: UserProfile, bankId?: string): number {
    let probability = 70;
    
    // Ajustements selon les revenus
    if (params.monthlyIncome > 1000000) {
      probability += 15;
    } else if (params.monthlyIncome < 500000) {
      probability -= 20;
    }
    
    // Ajustements selon l'endettement
    const debtRatio = ((params.currentDebts || 0) / params.monthlyIncome) * 100;
    if (debtRatio > 33) {
      probability -= 25;
    } else if (debtRatio < 20) {
      probability += 10;
    }
    
    // Ajustements selon l'apport
    if (params.downPayment && params.loanAmount) {
      const downPaymentRatio = params.downPayment / params.loanAmount;
      if (downPaymentRatio > 0.2) {
        probability += 15;
      } else if (downPaymentRatio < 0.1) {
        probability -= 10;
      }
    }
    
    // Ajustements selon la banque
    if (bankId === 'bamboo') {
      probability += 10; // Plus flexible
    } else if (bankId === 'bicig') {
      probability -= 5; // Plus sélective
    }
    
    return Math.max(10, Math.min(95, probability));
  }

  private generateBankConditions(params: any, bankId: string): string[] {
    const conditions: string[] = [];
    
    const debtRatio = ((params.currentDebts || 0) / params.monthlyIncome) * 100;
    if (debtRatio > 30) {
      conditions.push('Justificatifs de revenus renforcés');
    }
    
    if (params.downPayment && params.loanAmount) {
      const downPaymentRatio = params.downPayment / params.loanAmount;
      if (downPaymentRatio < 0.1) {
        conditions.push('Apport personnel minimum 10%');
      }
    }
    
    if (params.age && params.age < 25) {
      conditions.push('Caution parentale requise');
    }
    
    if (bankId !== 'bamboo') {
      conditions.push('Domiciliation des revenus');
    }
    
    return conditions;
  }

  private generateSpecialOffers(params: any, bankId: string): string[] {
    const offers: string[] = [];
    
    if (params.firstTimeBuyer && params.creditType === 'immobilier') {
      offers.push('Taux primo-accédant');
    }
    
    if (params.age && params.age < 30) {
      offers.push('Offre jeunes -0.2%');
    }
    
    if (params.profession === 'civil_servant') {
      offers.push('Taux fonctionnaire privilégié');
    }
    
    if (bankId === 'bamboo') {
      offers.push('Frais de dossier offerts');
      offers.push('Simulation gratuite');
    }
    
    return offers;
  }

  private generateMarketComparison(estimatedRate: number, marketRates: MarketRates): any {
    const position = ((estimatedRate - marketRates.minRate) / (marketRates.maxRate - marketRates.minRate)) * 100;
    const potentialSavings = Math.max(0, (estimatedRate - marketRates.minRate) * 0.5);
    
    return {
      averageRate: marketRates.averageRate,
      bestRate: marketRates.minRate,
      worstRate: marketRates.maxRate,
      yourPosition: Math.max(0, Math.min(100, position)),
      potentialSavings,
      trend: marketRates.trend
    };
  }

  private generateNegotiationTips(riskProfile: any, params: any): string[] {
    const tips: string[] = [];
    
    if (riskProfile.level === 'very_low' || riskProfile.level === 'low') {
      tips.push('Mettez en avant votre excellent profil');
      tips.push('Jouez la concurrence entre banques');
    }
    
    if (params.loanAmount > 15000000) {
      tips.push('Négociez les frais sur les gros montants');
    }
    
    if (params.downPayment > params.loanAmount * 0.2) {
      tips.push('Valorisez votre apport important');
    }
    
    tips.push('Négociez l\'assurance emprunteur');
    tips.push('Demandez plusieurs devis');
    
    return tips;
  }

  private generateImprovementSuggestions(riskProfile: any, params: any): any[] {
    const suggestions = [];
    
    if (params.monthlyIncome < 1000000) {
      suggestions.push({
        category: 'income',
        title: 'Augmenter les revenus',
        description: 'Négocier une augmentation',
        rateImprovement: 0.3,
        difficulty: 'medium'
      });
    }
    
    const debtRatio = ((params.currentDebts || 0) / params.monthlyIncome) * 100;
    if (debtRatio > 25) {
      suggestions.push({
        category: 'debt',
        title: 'Réduire l\'endettement',
        description: 'Rembourser les crédits en cours',
        rateImprovement: 0.5,
        difficulty: 'medium'
      });
    }
    
    if (!params.downPayment || params.downPayment < params.loanAmount * 0.15) {
      suggestions.push({
        category: 'guarantees',
        title: 'Augmenter l\'apport',
        description: 'Constituer 15-20% d\'apport',
        rateImprovement: 0.4,
        difficulty: 'medium'
      });
    }
    
    return suggestions;
  }

  // === MÉTHODES POUR LA COMPARAISON ===

  private createAlternativeComparison(base: SimulationHistory, alternative: SimulationHistory): AlternativeSimulation {
    const baseCost = this.extractTotalCost(base);
    const altCost = this.extractTotalCost(alternative);
    
    return {
      title: this.getSimulationTitle(alternative),
      description: this.getSimulationDescription(alternative),
      parameters: alternative.parameters,
      results: alternative.results,
      difference: altCost - baseCost,
      pros: this.generatePros(alternative, base),
      cons: this.generateCons(alternative, base)
    };
  }

  private extractTotalCost(simulation: SimulationHistory): number {
    if (simulation.results.totalCost) return simulation.results.totalCost;
    if (simulation.results.monthlyPayment && simulation.parameters.duration) {
      return simulation.results.monthlyPayment * simulation.parameters.duration;
    }
    return 0;
  }

  private getSimulationTitle(simulation: SimulationHistory): string {
    switch (simulation.type) {
      case 'capacity': return 'Capacité d\'emprunt';
      case 'payment': return 'Calcul mensualités';
      case 'rate': return 'Taux personnalisé';
      default: return 'Simulation';
    }
  }

  private getSimulationDescription(simulation: SimulationHistory): string {
    const { parameters } = simulation;
    return `${this.formatCurrency(parameters.loanAmount || parameters.borrowingCapacity || 0)} sur ${(parameters.duration || 240) / 12} ans`;
  }

  private generatePros(simulation: SimulationHistory, base: SimulationHistory): string[] {
    const pros: string[] = [];
    
    if (this.extractTotalCost(simulation) < this.extractTotalCost(base)) {
      pros.push('Coût total plus faible');
    }
    
    if (simulation.results.monthlyPayment && base.results.monthlyPayment) {
      if (simulation.results.monthlyPayment < base.results.monthlyPayment) {
        pros.push('Mensualité plus faible');
      }
    }
    
    return pros;
  }

  private generateCons(simulation: SimulationHistory, base: SimulationHistory): string[] {
    const cons: string[] = [];
    
    if (this.extractTotalCost(simulation) > this.extractTotalCost(base)) {
      cons.push('Coût total plus élevé');
    }
    
    if (simulation.parameters.duration > base.parameters.duration) {
      cons.push('Durée de remboursement plus longue');
    }
    
    return cons;
  }

  private findBestOption(simulations: SimulationHistory[]): SimulationHistory {
    return simulations.reduce((best, current) => {
      const bestCost = this.extractTotalCost(best);
      const currentCost = this.extractTotalCost(current);
      return currentCost < bestCost ? current : best;
    });
  }

  private calculateMaxSavings(simulations: SimulationHistory[]): number {
    const costs = simulations.map(s => this.extractTotalCost(s));
    return Math.max(...costs) - Math.min(...costs);
  }

  private generateComparisonRecommendations(simulations: SimulationHistory[]): string[] {
    const recommendations: string[] = [];
    const bestOption = this.findBestOption(simulations);
    
    recommendations.push(`L'option ${this.getSimulationTitle(bestOption)} offre le meilleur rapport qualité-prix`);
    
    const maxSavings = this.calculateMaxSavings(simulations);
    if (maxSavings > 100000) {
      recommendations.push(`Économies potentielles de ${this.formatCurrency(maxSavings)}`);
    }
    
    return recommendations;
  }

  // === MÉTHODES POUR L'ANALYSE DE MARCHÉ ===

  private getBankRates(creditType: string, amount: number, duration: number): Observable<BankRateInfo[]> {
    // Mock data - en production, appel API
    const banks: BankRateInfo[] = [
      {
        bankId: 'bamboo',
        bankName: 'Bamboo',
        currentRate: 6.1,
        conditions: ['Domiciliation optionnelle'],
        specialOffers: ['Frais offerts', 'Taux jeunes'],
        processingTime: 24,
        customerRating: 4.5
      },
      {
        bankId: 'bgfi',
        bankName: 'BGFI Bank',
        currentRate: 6.3,
        conditions: ['Domiciliation requise'],
        specialOffers: ['Taux négociable'],
        processingTime: 72,
        customerRating: 4.0
      }
    ];
    
    return of(banks);
  }

  private getMarketTrends(creditType: string): Observable<MarketTrend[]> {
    const trends: MarketTrend[] = [
      {
        period: '3 derniers mois',
        rateChange: -0.1,
        volume: 15000000000,
        factors: ['Politique monétaire', 'Stabilité économique']
      },
      {
        period: '6 derniers mois',
        rateChange: -0.2,
        volume: 28000000000,
        factors: ['Concurrence bancaire', 'Demande soutenue']
      }
    ];
    
    return of(trends);
  }

  private getRateForecast(creditType: string): Observable<RateForecast> {
    const forecast: RateForecast = {
      timeframe: '6m',
      expectedChange: 0.1,
      confidence: 75,
      factors: ['Inflation attendue', 'Politique BCE', 'Évolution économique']
    };
    
    return of(forecast);
  }

  private determineMarketPosition(averageRate: number, bankRates: BankRateInfo[]): 'excellent' | 'good' | 'average' | 'poor' {
    const bestRate = Math.min(...bankRates.map(b => b.currentRate));
    
    if (bestRate < averageRate - 0.5) return 'excellent';
    if (bestRate < averageRate) return 'good';
    if (bestRate < averageRate + 0.3) return 'average';
    return 'poor';
  }

  private identifyNegotiationOpportunities(bankRates: BankRateInfo[], trends: MarketTrend[]): string[] {
    const opportunities: string[] = [];
    
    const rateSpread = Math.max(...bankRates.map(b => b.currentRate)) - Math.min(...bankRates.map(b => b.currentRate));
    if (rateSpread > 0.5) {
      opportunities.push('Écart important entre banques - négociation possible');
    }
    
    const recentTrend = trends[0];
    if (recentTrend.rateChange < 0) {
      opportunities.push('Tendance baissière - bon moment pour emprunter');
    }
    
    opportunities.push('Comparez les conditions annexes (assurance, frais)');
    
    return opportunities;
  }

  private initializeMarketRates(): void {
    this.refreshMarketRates().subscribe();
  }

  // === MÉTHODES PUBLIQUES ADDITIONNELLES ===

  /**
   * Récupère la configuration des simulateurs
   */
  getSimulatorConfigs(): SimulatorConfig[] {
    return this.simulatorConfigs;
  }

  /**
   * Exporte les résultats en PDF
   */
  exportToPDF(simulation: SimulationHistory): Observable<Blob> {
    const exportData = {
      simulation,
      generatedAt: new Date(),
      metadata: {
        version: '2.0',
        type: simulation.type
      }
    };

    // En production, appel API pour génération PDF
    return this.http.post(`${this.apiUrl}/export/pdf`, exportData, {
      responseType: 'blob'
    }).pipe(
      catchError(() => {
        // Fallback: génération simple côté client
        const content = this.generateSimpleReport(simulation);
        const blob = new Blob([content], { type: 'text/plain' });
        return of(blob);
      })
    );
  }

  /**
   * Génère un rapport simple pour l'export
   */
  private generateSimpleReport(simulation: SimulationHistory): string {
    const { type, parameters, results, createdAt } = simulation;
    
    return `
SIMULATION DE CRÉDIT - ${type.toUpperCase()}
=========================================

Date: ${createdAt.toLocaleDateString('fr-FR')}

PARAMÈTRES:
${Object.entries(parameters).map(([key, value]) => `- ${key}: ${value}`).join('\n')}

RÉSULTATS:
${Object.entries(results).map(([key, value]) => `- ${key}: ${value}`).join('\n')}

Généré par Bamboo Credit Simulator v2.0
    `.trim();
  }

  /**
   * Partage une simulation
   */
  shareSimulation(simulation: SimulationHistory): Observable<{ shareUrl: string }> {
    const shareData = {
      simulationId: simulation.id,
      type: simulation.type,
      summary: this.generateShareSummary(simulation)
    };

    return this.http.post<{ shareUrl: string }>(`${this.apiUrl}/share`, shareData).pipe(
      catchError(() => {
        // Fallback: génération d'URL locale
        const shareUrl = `${window.location.origin}/share/${simulation.id}`;
        return of({ shareUrl });
      })
    );
  }

  private generateShareSummary(simulation: SimulationHistory): string {
    const { type, results } = simulation;
    
    switch (type) {
      case 'capacity':
        return `Capacité d'emprunt: ${this.formatCurrency(results.borrowingCapacity)}`;
      case 'payment':
        return `Mensualité: ${this.formatCurrency(results.monthlyPayment)}`;
      case 'rate':
        return `Taux estimé: ${results.estimatedRate}%`;
      default:
        return 'Simulation de crédit';
    }
  }

  /**
   * Nettoie les données expirées
   */
  cleanupExpiredData(): Observable<{ cleaned: number }> {
    const history = this.simulationHistory$.value;
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
    
    const validSimulations = history.filter(s => 
      s.favorite || new Date(s.createdAt) > thirtyDaysAgo
    );
    
    const cleaned = history.length - validSimulations.length;
    
    if (cleaned > 0) {
      this.simulationHistory$.next(validSimulations);
      this.updateFavorites();
      this.saveToStorage();
    }
    
    return of({ cleaned });
  }

  private formatCurrency(amount: number): string {
    return new Intl.NumberFormat('fr-FR', {
      style: 'currency',
      currency: 'XAF',
      minimumFractionDigits: 0
    }).format(amount);
  }
}