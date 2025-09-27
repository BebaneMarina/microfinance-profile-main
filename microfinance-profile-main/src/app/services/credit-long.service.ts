// credit-long.service.ts - Service complet corrigé
import { Injectable } from '@angular/core';
import { HttpClient, HttpErrorResponse } from '@angular/common/http';
import { Observable, BehaviorSubject, of, throwError, from } from 'rxjs';
import { map, catchError, tap, retry, mergeMap, toArray, timeout } from 'rxjs/operators';

// ==================== INTERFACES ====================

export interface CreditLongRequest {
  id: string;
  userId: string;
  username: string;
  status: 'draft' | 'submitted' | 'under_review' | 'approved' | 'rejected' | 'cancelled';
  submissionDate: string;
  lastUpdated?: string;
  source?: 'server' | 'local';
  
  personalInfo: {
    fullName: string;
    email: string;
    phone: string;
    address: string;
    profession: string;
    company: string;
    maritalStatus: string;
    dependents: number;
  };
  
  creditDetails: {
    requestedAmount: number;
    duration: number;
    purpose: string;
    repaymentFrequency: string;
    preferredRate: number;
    guarantors: any[];
  };
  
  financialDetails: {
    monthlyIncome: number;
    monthlyExpenses: number;
    otherIncomes: any[];
    existingLoans: any[];
    assets: any[];
    employmentDetails: {
      employer: string;
      position: string;
      seniority: number;
      contractType: string;
      netSalary: number;
      grossSalary: number;
    };
  };
  
  documents: {
    identityProof: boolean;
    incomeProof: boolean;
    bankStatements: boolean;
    employmentCertificate: boolean;
    businessPlan: boolean;
    propertyDeeds: boolean;
    guarantorDocuments: boolean;
  };
  
  simulation?: {
    calculatedScore: number;
    riskLevel: string;
    recommendedAmount: number;
    suggestedRate: number;
    monthlyPayment: number;
    totalInterest: number;
    debtToIncomeRatio: number;
    approvalProbability: number;
  };
  
  reviewHistory: Array<{
    date: string;
    action: string;
    agent: string;
    comment: string;
  }>;
}

export interface CreditSimulation {
  success: boolean;
  requestedAmount: number;
  duration: number;
  clientProfile: any;
  results: {
    score: number;
    riskLevel: string;
    recommendedAmount: number;
    maxAmount: number;
    suggestedRate: number;
    monthlyPayment: number;
    totalAmount: number;
    totalInterest: number;
    debtToIncomeRatio: number;
    approvalProbability: number;
    keyFactors: Array<{
      factor: string;
      impact: 'positive' | 'negative' | 'neutral';
      description: string;
    }>;
    recommendations: string[];
    warnings: string[];
  };
  modelUsed: string;
  timestamp: string;
}

export interface TestResult {
  success: boolean;
  message: string;
  error?: string;
  details?: any;
}

export interface CreateCreditResponse {
  success: boolean;
  id?: string;
  message: string;
  request?: CreditLongRequest;
}

@Injectable({
  providedIn: 'root'
})
export class CreditLongService {
  
  // Configuration API - CORRIGÉE
  private readonly API_BASE_URL = 'http://localhost:3000';  // NestJS
  private readonly CREDIT_LONG_API = `${this.API_BASE_URL}/credit-long`;
  private readonly FLASK_API_URL = 'http://localhost:5000';  // Flask pour ML uniquement
  
  // Sujets pour la gestion d'état
  private userRequestsSubject = new BehaviorSubject<CreditLongRequest[]>([]);
  public userRequests$ = this.userRequestsSubject.asObservable();
  
  // Cache et configuration
  private requestsCache = new Map<string, CreditLongRequest[]>();
  private isOfflineMode = false;

  constructor(private http: HttpClient) {
    this.checkOfflineMode();
  }

  // ==================== MÉTHODES PRINCIPALES ====================

  /**
   * Charge toutes les demandes d'un utilisateur
   */
  loadUserRequests(username: string): Observable<CreditLongRequest[]> {
    if (!username) {
      console.warn('Username vide, retour d\'un tableau vide');
      return of([]);
    }

    if (this.requestsCache.has(username)) {
      const cachedRequests = this.requestsCache.get(username) || [];
      this.userRequestsSubject.next(cachedRequests);
      console.log(`${cachedRequests.length} demande(s) chargée(s) depuis le cache`);
    }

    if (this.isOfflineMode) {
      const localRequests = this.getLocalRequests(username);
      this.userRequestsSubject.next(localRequests);
      return of(localRequests);
    }

    return this.http.get<any>(`${this.CREDIT_LONG_API}/user/${username}`)
      .pipe(
        timeout(10000),
        map(response => {
          console.log('Réponse serveur brute:', response);
          
          let serverRequests: any[] = [];
          
          if (response && response.success) {
            serverRequests = response.requests || [];
          } else if (Array.isArray(response)) {
            serverRequests = response;
          } else if (response && response.data) {
            serverRequests = Array.isArray(response.data) ? response.data : [];
          } else {
            console.warn('Format de réponse non reconnu');
            serverRequests = [];
          }

          if (!Array.isArray(serverRequests)) {
            console.warn('serverRequests n\'est pas un tableau');
            serverRequests = [];
          }

          console.log(`${serverRequests.length} demande(s) reçue(s) du serveur`);

          const transformedRequests = serverRequests.map(req => this.transformServerRequest(req));
          const mergedRequests = this.mergeRequests(transformedRequests);
          
          this.requestsCache.set(username, mergedRequests);
          this.userRequestsSubject.next(mergedRequests);
          
          return mergedRequests;
        }),
        catchError(error => {
          console.error('Erreur chargement demandes:', error);
          
          const localRequests = this.requestsCache.get(username) || this.getLocalRequests(username);
          this.userRequestsSubject.next(localRequests);
          
          return of(localRequests);
        }),
        retry(1)
      );
  }

  /**
   * Crée une demande de crédit
   */
  createCreditRequest(requestData: Partial<CreditLongRequest>): Observable<CreateCreditResponse> {
    const requestWithId = {
      ...requestData,
      id: requestData.id || `CR_${Date.now()}`,
      submissionDate: requestData.submissionDate || new Date().toISOString(),
      lastUpdated: new Date().toISOString(),
      status: 'submitted' as const
    };

    this.saveLocalRequest(requestWithId as CreditLongRequest);

    if (this.isOfflineMode) {
      return of({
        success: true,
        id: requestWithId.id,
        message: 'Demande sauvegardée localement (mode hors ligne)',
        request: requestWithId as CreditLongRequest
      });
    }

    return this.http.post<any>(`${this.CREDIT_LONG_API}/create`, requestWithId)
      .pipe(
        timeout(15000),
        map(response => {
          if (response && response.success) {
            return {
              success: true,
              id: response.id || requestWithId.id,
              message: response.message || 'Demande créée avec succès',
              request: response.request || requestWithId as CreditLongRequest
            };
          } else {
            throw new Error('Réponse de création invalide');
          }
        }),
        catchError(error => {
          console.warn('Création serveur échouée, sauvegarde locale conservée');
          return of({
            success: true,
            id: requestWithId.id,
            message: 'Demande sauvegardée localement uniquement',
            request: requestWithId as CreditLongRequest
          });
        })
      );
  }

  /**
   * Fusionne les demandes serveur et locales
   */
  private mergeRequests(serverRequests: CreditLongRequest[] = []): CreditLongRequest[] {
    try {
      if (!Array.isArray(serverRequests)) {
        console.warn('mergeRequests: serverRequests n\'est pas un tableau');
        serverRequests = [];
      }

      const localRequests = this.getAllLocalRequests();
      
      console.log(`Fusion: ${serverRequests.length} serveur + ${localRequests.length} local`);

      const mergedMap = new Map<string, CreditLongRequest>();

      serverRequests.forEach(request => {
        if (request && request.id) {
          mergedMap.set(request.id, {
            ...request,
            source: 'server' as const,
            lastUpdated: new Date().toISOString()
          });
        }
      });

      localRequests.forEach(request => {
        if (request && request.id && !mergedMap.has(request.id)) {
          mergedMap.set(request.id, {
            ...request,
            source: 'local' as const
          });
        }
      });

      const result = Array.from(mergedMap.values())
        .sort((a, b) => {
          const dateA = new Date(a.submissionDate || a.lastUpdated || 0);
          const dateB = new Date(b.submissionDate || b.lastUpdated || 0);
          return dateB.getTime() - dateA.getTime();
        });

      console.log(`Fusion terminée: ${result.length} demande(s) total`);
      return result;

    } catch (error) {
      console.error('Erreur dans mergeRequests:', error);
      return this.getAllLocalRequests();
    }
  }

  /**
   * Transforme une demande du serveur
   */
  private transformServerRequest(serverRequest: any): CreditLongRequest {
    if (!serverRequest) {
      console.warn('Demande serveur vide');
      return this.createEmptyRequest();
    }

    try {
      return {
        id: serverRequest.id || `temp_${Date.now()}`,
        userId: serverRequest.userId || '',
        username: serverRequest.username || '',
        status: serverRequest.status || 'draft',
        submissionDate: serverRequest.submissionDate || new Date().toISOString(),
        lastUpdated: serverRequest.lastUpdated || new Date().toISOString(),
        source: 'server' as const,
        
        personalInfo: {
          fullName: serverRequest.personalInfo?.fullName || '',
          email: serverRequest.personalInfo?.email || '',
          phone: serverRequest.personalInfo?.phone || '',
          address: serverRequest.personalInfo?.address || '',
          profession: serverRequest.personalInfo?.profession || '',
          company: serverRequest.personalInfo?.company || '',
          maritalStatus: serverRequest.personalInfo?.maritalStatus || '',
          dependents: serverRequest.personalInfo?.dependents || 0,
          ...serverRequest.personalInfo
        },
        
        creditDetails: {
          requestedAmount: serverRequest.creditDetails?.requestedAmount || 0,
          duration: serverRequest.creditDetails?.duration || 12,
          purpose: serverRequest.creditDetails?.purpose || '',
          repaymentFrequency: serverRequest.creditDetails?.repaymentFrequency || 'mensuel',
          preferredRate: serverRequest.creditDetails?.preferredRate || 12,
          guarantors: serverRequest.creditDetails?.guarantors || [],
          ...serverRequest.creditDetails
        },
        
        financialDetails: {
          monthlyIncome: serverRequest.financialDetails?.monthlyIncome || 0,
          monthlyExpenses: serverRequest.financialDetails?.monthlyExpenses || 0,
          otherIncomes: serverRequest.financialDetails?.otherIncomes || [],
          existingLoans: serverRequest.financialDetails?.existingLoans || [],
          assets: serverRequest.financialDetails?.assets || [],
          employmentDetails: {
            employer: '',
            position: '',
            seniority: 0,
            contractType: 'CDI',
            netSalary: 0,
            grossSalary: 0,
            ...serverRequest.financialDetails?.employmentDetails
          },
          ...serverRequest.financialDetails
        },
        
        documents: {
          identityProof: false,
          incomeProof: false,
          bankStatements: false,
          employmentCertificate: false,
          businessPlan: false,
          propertyDeeds: false,
          guarantorDocuments: false,
          ...serverRequest.documents
        },
        
        simulation: serverRequest.simulation ? {
          calculatedScore: serverRequest.simulation.calculatedScore || 0,
          riskLevel: serverRequest.simulation.riskLevel || 'moyen',
          recommendedAmount: serverRequest.simulation.recommendedAmount || 0,
          suggestedRate: serverRequest.simulation.suggestedRate || 12,
          monthlyPayment: serverRequest.simulation.monthlyPayment || 0,
          totalInterest: serverRequest.simulation.totalInterest || 0,
          debtToIncomeRatio: serverRequest.simulation.debtToIncomeRatio || 0,
          approvalProbability: serverRequest.simulation.approvalProbability || 0
        } : undefined,
        
        reviewHistory: Array.isArray(serverRequest.reviewHistory) ? 
          serverRequest.reviewHistory : []
      };
      
    } catch (error) {
      console.error('Erreur transformation demande serveur:', error, serverRequest);
      return this.createEmptyRequest();
    }
  }

  /**
   * Crée une demande vide
   */
  private createEmptyRequest(): CreditLongRequest {
    return {
      id: `empty_${Date.now()}`,
      userId: '',
      username: '',
      status: 'draft',
      submissionDate: new Date().toISOString(),
      lastUpdated: new Date().toISOString(),
      source: 'local' as const,
      personalInfo: {
        fullName: '', email: '', phone: '', address: '',
        profession: '', company: '', maritalStatus: '', dependents: 0
      },
      creditDetails: {
        requestedAmount: 0, duration: 12, purpose: '',
        repaymentFrequency: 'mensuel', preferredRate: 12, guarantors: []
      },
      financialDetails: {
        monthlyIncome: 0, monthlyExpenses: 0,
        otherIncomes: [], existingLoans: [], assets: [],
        employmentDetails: {
          employer: '', position: '', seniority: 0,
          contractType: 'CDI', netSalary: 0, grossSalary: 0
        }
      },
      documents: {
        identityProof: false, incomeProof: false, bankStatements: false,
        employmentCertificate: false, businessPlan: false,
        propertyDeeds: false, guarantorDocuments: false
      },
      reviewHistory: []
    };
  }

  // ==================== MÉTHODES DE DIAGNOSTIC ====================

  /**
   * Test de connectivité
   */
  testConnection(): Observable<TestResult> {
    if (this.isOfflineMode) {
      return of({
        success: false,
        message: 'Mode hors ligne activé',
        details: { mode: 'offline', fallback: true }
      });
    }

    return this.http.get<any>(`${this.CREDIT_LONG_API}/health`)
      .pipe(
        timeout(5000),
        map(response => {
          if (response && response.success) {
            return {
              success: true,
              message: 'Connexion API établie',
              details: {
                service: response.service || 'credit-long',
                status: response.status || 'healthy',
                version: response.version || '1.0.0',
                endpoints: response.endpoints || []
              }
            };
          } else {
            return {
              success: false,
              message: 'Réponse API inattendue',
              details: response
            };
          }
        }),
        catchError((error: HttpErrorResponse) => {
          console.warn('API non accessible, mode fallback activé');
          
          let errorMessage = 'Erreur de connexion';
          let errorDetails: any = {};

          if (error.status === 0) {
            errorMessage = 'Serveur non accessible';
            errorDetails = {
              type: 'network_error',
              message: 'Impossible de joindre le serveur',
              url: `${this.CREDIT_LONG_API}/health`
            };
          } else if (error.status === 404) {
            errorMessage = 'Endpoint health non trouvé';
            errorDetails = {
              type: 'endpoint_not_found',
              status: 404,
              url: error.url
            };
          } else {
            errorMessage = `Erreur HTTP ${error.status}`;
            errorDetails = {
              type: 'http_error',
              status: error.status,
              message: error.message,
              statusText: error.statusText
            };
          }

          return of({
            success: false,
            message: errorMessage,
            error: error.message || 'Erreur inconnue',
            details: errorDetails
          });
        })
      );
  }

  /**
   * Test de simulation
   */
  testSimulation(): Observable<TestResult> {
    const testData = {
      requestedAmount: 1000000,
      duration: 12,
      clientProfile: {
        monthlyIncome: 500000,
        creditScore: 6,
        username: 'diagnostic_test'
      },
      financialDetails: {
        monthlyExpenses: 200000
      }
    };

    if (this.isOfflineMode) {
      return of({
        success: true,
        message: 'Simulation de test (mode hors ligne)',
        details: {
          mode: 'offline',
          monthlyPayment: this.calculateMonthlyPayment(testData.requestedAmount, 12, testData.duration),
          fallback: true
        }
      });
    }

    return this.http.post<any>(`${this.FLASK_API_URL}/credit-simulation`, testData)
      .pipe(
        timeout(8000),
        map(response => {
          if (response && response.success) {
            return {
              success: true,
              message: 'Simulation de test réussie',
              details: {
                score: response.results?.score,
                riskLevel: response.results?.riskLevel,
                monthlyPayment: response.results?.monthlyPayment,
                modelUsed: response.modelUsed
              }
            };
          } else {
            return {
              success: false,
              message: 'Simulation échouée',
              details: response
            };
          }
        }),
        catchError((error: HttpErrorResponse) => {
          return of({
            success: false,
            message: `Erreur simulation: ${error.status}`,
            error: error.message || 'Erreur simulation',
            details: {
              status: error.status,
              statusText: error.statusText,
              url: error.url
            }
          });
        })
      );
  }

  /**
   * Test de sauvegarde brouillon
   */
  testDraftSave(): Observable<TestResult> {
    const testDraft = {
      username: 'diagnostic_test',
      personalInfo: {
        fullName: 'Test Diagnostic',
        email: 'test@diagnostic.com'
      },
      creditDetails: {
        requestedAmount: 500000,
        duration: 6
      },
      status: 'draft'
    };

    if (this.isOfflineMode) {
      this.saveLocalRequest(testDraft as CreditLongRequest);
      return of({
        success: true,
        message: 'Sauvegarde locale réussie (mode hors ligne)',
        details: { mode: 'offline', localSave: true }
      });
    }

    return this.http.post<any>(`${this.CREDIT_LONG_API}/draft`, testDraft)
      .pipe(
        timeout(5000),
        map(response => {
          if (response && response.success) {
            return {
              success: true,
              message: 'Sauvegarde brouillon réussie',
              details: response
            };
          } else {
            return {
              success: false,
              message: 'Sauvegarde brouillon échouée',
              details: response
            };
          }
        }),
        catchError((error: HttpErrorResponse) => {
          return of({
            success: false,
            message: `Erreur sauvegarde: ${error.status}`,
            error: error.message || 'Erreur sauvegarde',
            details: {
              status: error.status,
              statusText: error.statusText
            }
          });
        })
      );
  }

  /**
   * Diagnostic complet
   */
  runDiagnostic(): Observable<{
    success: boolean;
    message: string;
    tests: Array<{
      name: string;
      success: boolean;
      message: string;
      responseTime?: number;
      details?: any;
    }>;
  }> {
    const startTime = Date.now();
    
    return from([
      { name: 'health', test: this.testConnection() },
      { name: 'simulation', test: this.testSimulation() },
      { name: 'draft', test: this.testDraftSave() }
    ]).pipe(
      mergeMap(({ name, test }) => {
        const testStartTime = Date.now();
        return test.pipe(
          map(result => ({
            name,
            success: result.success,
            message: result.message,
            responseTime: Date.now() - testStartTime,
            details: result.details,
            error: result.error
          }))
        );
      }),
      toArray(),
      map(tests => {
        const successCount = tests.filter(t => t.success).length;
        const totalTime = Date.now() - startTime;
        
        return {
          success: successCount > 0,
          message: `Diagnostic terminé: ${successCount}/${tests.length} tests réussis en ${totalTime}ms`,
          tests
        };
      }),
      catchError(error => {
        return of({
          success: false,
          message: `Erreur diagnostic: ${error.message}`,
          tests: []
        });
      })
    );
  }

  // ==================== API PRINCIPALES ====================

  /**
   * Simulation de crédit
   */
  simulateCredit(simulationData: any): Observable<CreditSimulation> {
    if (this.isOfflineMode) {
      return this.simulateCreditOffline(simulationData);
    }

    return this.http.post<any>(`${this.FLASK_API_URL}/credit-simulation`, simulationData)
      .pipe(
        timeout(10000),
        map(response => {
          if (response && response.success) {
            return response as CreditSimulation;
          }
          throw new Error('Réponse de simulation invalide');
        }),
        catchError(error => {
          console.warn('Simulation serveur échouée, mode fallback');
          return this.simulateCreditOffline(simulationData);
        })
      );
  }

  /**
   * Simulation hors ligne
   */
  private simulateCreditOffline(simulationData: any): Observable<CreditSimulation> {
    const amount = simulationData.requestedAmount || 0;
    const duration = simulationData.duration || 12;
    const monthlyIncome = simulationData.clientProfile?.monthlyIncome || 500000;
    const monthlyExpenses = simulationData.financialDetails?.monthlyExpenses || 0;
    const contractType = simulationData.financialDetails?.employmentDetails?.contractType || 'CDI';
    const seniority = simulationData.financialDetails?.employmentDetails?.seniority || 0;
    
    const monthlyPayment = this.calculateMonthlyPayment(amount, 12, duration);
    const totalAmount = monthlyPayment * duration;
    const totalInterest = totalAmount - amount;
    const debtToIncomeRatio = (monthlyPayment / monthlyIncome) * 100;
    
    let score = 8;
    let riskLevel = 'faible';
    let approvalProbability = 0.85;
    
    if (debtToIncomeRatio > 40) {
      score = 5;
      riskLevel = 'élevé';
      approvalProbability = 0.45;
    } else if (debtToIncomeRatio > 30) {
      score = 6;
      riskLevel = 'moyen';
      approvalProbability = 0.65;
    }

    const keyFactors: Array<{
      factor: string;
      impact: 'positive' | 'negative' | 'neutral';
      description: string;
    }> = [
      {
        factor: 'revenus_mensuels',
        impact: monthlyIncome >= 1000000 ? 'positive' : monthlyIncome >= 500000 ? 'neutral' : 'negative',
        description: `Revenus mensuels: ${this.formatAmount(monthlyIncome)}`
      },
      {
        factor: 'taux_endettement',
        impact: debtToIncomeRatio < 30 ? 'positive' : debtToIncomeRatio < 45 ? 'neutral' : 'negative',
        description: `Taux d'endettement: ${debtToIncomeRatio.toFixed(1)}%`
      },
      {
        factor: 'duree_credit',
        impact: duration <= 24 ? 'positive' : duration <= 60 ? 'neutral' : 'negative',
        description: `Durée du crédit: ${duration} mois`
      },
      {
        factor: 'type_contrat',
        impact: contractType === 'CDI' || contractType === 'Fonctionnaire' ? 'positive' : 
               contractType === 'CDD' ? 'neutral' : 'negative',
        description: `Type de contrat: ${contractType}`
      },
      {
        factor: 'anciennete',
        impact: seniority >= 24 ? 'positive' : seniority >= 12 ? 'neutral' : 'negative',
        description: `Ancienneté: ${seniority} mois`
      }
    ];

    const recommendations: string[] = [
      'Simulation calculée en mode hors ligne'
    ];

    if (debtToIncomeRatio < 30) {
      recommendations.push('Profil favorable pour un crédit personnel');
    } else if (debtToIncomeRatio > 40) {
      recommendations.push('Considérez réduire le montant ou augmenter la durée');
    } else {
      recommendations.push('Profil équilibré, conditions standard');
    }

    if (monthlyIncome >= 1000000) {
      recommendations.push('Revenus élevés, éligible aux taux préférentiels');
    }

    if (duration > 48) {
      recommendations.push('Durée étendue, vérifiez le coût total');
    }

    const warnings: string[] = [];
    if (debtToIncomeRatio > 40) {
      warnings.push('Taux d\'endettement élevé');
    }
    if (amount > monthlyIncome * 40) {
      warnings.push('Montant élevé par rapport aux revenus');
    }
    if (contractType === 'CDD' && duration > 24) {
      warnings.push('Contrat temporaire pour une longue durée');
    }

    const simulation: CreditSimulation = {
      success: true,
      requestedAmount: amount,
      duration: duration,
      clientProfile: simulationData.clientProfile,
      results: {
        score: score,
        riskLevel: riskLevel,
        recommendedAmount: Math.min(amount, monthlyIncome * 30),
        maxAmount: monthlyIncome * 40,
        suggestedRate: contractType === 'CDI' && monthlyIncome >= 1000000 ? 10.5 : 12,
        monthlyPayment: monthlyPayment,
        totalAmount: totalAmount,
        totalInterest: totalInterest,
        debtToIncomeRatio: debtToIncomeRatio,
        approvalProbability: approvalProbability,
        keyFactors: keyFactors,
        recommendations: recommendations,
        warnings: warnings
      },
      modelUsed: 'calculateur_hors_ligne_avance',
      timestamp: new Date().toISOString()
    };

    return of(simulation);
  }

  /**
   * Sauvegarde de brouillon
   */
  saveDraft(draftData: Partial<CreditLongRequest>): Observable<any> {
    if (draftData.id) {
      this.saveLocalRequest(draftData as CreditLongRequest);
    }

    if (this.isOfflineMode) {
      return of({ success: true, message: 'Brouillon sauvegardé localement' });
    }

    return this.http.post<any>(`${this.CREDIT_LONG_API}/draft`, draftData)
      .pipe(
        timeout(5000),
        catchError(error => {
          console.warn('Sauvegarde serveur échouée, sauvegarde locale conservée');
          return of({ success: true, message: 'Sauvegardé localement uniquement' });
        })
      );
  }

  /**
   * Récupération de brouillon
   */
  getDraft(username: string): Observable<Partial<CreditLongRequest> | null> {
    if (this.isOfflineMode) {
      const localRequests = this.getLocalRequests(username);
      const draftRequest = localRequests.find(req => req.status === 'draft');
      return of(draftRequest || null);
    }

    return this.http.get<any>(`${this.CREDIT_LONG_API}/draft/${username}`)
      .pipe(
        timeout(5000),
        map(response => response?.draft || null),
        catchError(error => {
          console.warn('Récupération brouillon serveur échouée, vérification locale');
          const localRequests = this.getLocalRequests(username);
          const draftRequest = localRequests.find(req => req.status === 'draft');
          return of(draftRequest || null);
        })
      );
  }

  /**
   * Upload de document
   */
 /**
   * Upload de document
   */
  uploadDocument(requestId: string, documentType: string, file: File): Observable<any> {
    if (this.isOfflineMode) {
      return of({
        success: true,
        message: 'Document sauvegardé localement (mode hors ligne)',
        filename: file.name,
        type: documentType,
        offline: true
      });
    }

    const formData = new FormData();
    formData.append('file', file);
    formData.append('type', documentType);

    return this.http.post<any>(`${this.CREDIT_LONG_API}/${requestId}/documents`, formData)
      .pipe(
        timeout(30000),
        catchError(error => {
          console.warn('Upload serveur échoué');
          return of({
            success: false,
            error: error.message,
            message: 'Upload échoué, fichier conservé localement'
          });
        })
      );
  }

  // ==================== GESTION LOCALE ====================

  /**
   * Récupère toutes les demandes locales
   */
  private getAllLocalRequests(): CreditLongRequest[] {
    try {
      const localData = localStorage.getItem('credit_long_requests');
      if (!localData) return [];
      
      const parsed = JSON.parse(localData);
      return Array.isArray(parsed) ? parsed : [];
    } catch (error) {
      console.error('Erreur lecture localStorage:', error);
      return [];
    }
  }

  /**
   * Récupère les demandes locales d'un utilisateur
   */
  private getLocalRequests(username: string): CreditLongRequest[] {
    if (!username) return [];
    
    return this.getAllLocalRequests()
      .filter(req => req.username === username);
  }

  /**
   * Sauvegarde une demande localement
   */
  private saveLocalRequest(request: CreditLongRequest): void {
    try {
      const allRequests = this.getAllLocalRequests();
      const existingIndex = allRequests.findIndex(req => req.id === request.id);
      
      const requestToSave: CreditLongRequest = { 
        ...request, 
        lastUpdated: new Date().toISOString(),
        source: (request.source || 'local') as 'server' | 'local'
      };
      
      if (existingIndex >= 0) {
        allRequests[existingIndex] = requestToSave;
      } else {
        allRequests.push(requestToSave);
      }
      
      localStorage.setItem('credit_long_requests', JSON.stringify(allRequests));
      console.log(`Demande ${request.id} sauvegardée localement`);
    } catch (error) {
      console.error('Erreur sauvegarde locale:', error);
    }
  }

  /**
   * Vérifie le mode hors ligne
   */
  private checkOfflineMode(): void {
    this.isOfflineMode = localStorage.getItem('force_fallback_mode') === 'true';
    if (this.isOfflineMode) {
      console.warn('Mode hors ligne activé');
    }
  }

  // ==================== UTILITAIRES ====================

  /**
   * Formatage des montants
   */
  formatAmount(amount: number): string {
    if (isNaN(amount)) return '0 FCFA';
    return new Intl.NumberFormat('fr-FR').format(amount) + ' FCFA';
  }

  /**
   * Calcul de mensualité
   */
  calculateMonthlyPayment(amount: number, annualRate: number, durationMonths: number): number {
    if (annualRate === 0 || amount === 0 || durationMonths === 0) {
      return amount / durationMonths;
    }
    
    const monthlyRate = annualRate / 100 / 12;
    const payment = amount * (monthlyRate * Math.pow(1 + monthlyRate, durationMonths)) / 
                   (Math.pow(1 + monthlyRate, durationMonths) - 1);
    
    return Math.round(payment);
  }

  /**
   * Validation d'une demande
   */
  validateRequest(request: Partial<CreditLongRequest>): string[] {
    const errors: string[] = [];

    if (!request.personalInfo?.fullName?.trim()) {
      errors.push('Nom complet requis');
    }
    if (!request.personalInfo?.email?.trim()) {
      errors.push('Email requis');
    }
    if (!this.isValidEmail(request.personalInfo?.email || '')) {
      errors.push('Format email invalide');
    }
    if (!request.personalInfo?.phone?.trim()) {
      errors.push('Numéro de téléphone requis');
    }

    if (!request.creditDetails?.requestedAmount || request.creditDetails.requestedAmount <= 0) {
      errors.push('Montant demandé invalide');
    }
    if (!request.creditDetails?.duration || request.creditDetails.duration <= 0) {
      errors.push('Durée invalide');
    }
    if (!request.creditDetails?.purpose?.trim()) {
      errors.push('Objet du crédit requis');
    }

    if (!request.financialDetails?.monthlyIncome || request.financialDetails.monthlyIncome <= 0) {
      errors.push('Revenus mensuels invalides');
    }

    if (request.creditDetails?.requestedAmount && request.financialDetails?.monthlyIncome) {
      const maxAmount = request.financialDetails.monthlyIncome * 40;
      if (request.creditDetails.requestedAmount > maxAmount) {
        errors.push(`Montant trop élevé (max: ${this.formatAmount(maxAmount)})`);
      }
    }

    return errors;
  }

  /**
   * Validation email
   */
  private isValidEmail(email: string): boolean {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
  }

  /**
   * Calcul du score de crédit basique
   */
  calculateBasicCreditScore(request: Partial<CreditLongRequest>): number {
    let score = 5;

    if (!request.financialDetails || !request.creditDetails) {
      return score;
    }

    const monthlyIncome = request.financialDetails.monthlyIncome || 0;
    const requestedAmount = request.creditDetails.requestedAmount || 0;
    const duration = request.creditDetails.duration || 12;
    const monthlyExpenses = request.financialDetails.monthlyExpenses || 0;

    const monthlyPayment = this.calculateMonthlyPayment(requestedAmount, 12, duration);
    const debtRatio = ((monthlyPayment + monthlyExpenses) / monthlyIncome) * 100;
    const amountToIncomeRatio = (requestedAmount / monthlyIncome);

    if (monthlyIncome >= 1000000) score += 1;
    if (monthlyIncome >= 2000000) score += 1;
    
    if (debtRatio <= 30) score += 2;
    else if (debtRatio <= 40) score += 1;
    else if (debtRatio > 50) score -= 2;

    if (amountToIncomeRatio <= 20) score += 1;
    else if (amountToIncomeRatio > 35) score -= 1;

    const contractType = request.financialDetails.employmentDetails?.contractType;
    if (contractType === 'CDI' || contractType === 'Fonctionnaire') score += 1;
    
    const seniority = request.financialDetails.employmentDetails?.seniority || 0;
    if (seniority >= 24) score += 1;

    return Math.max(1, Math.min(10, score));
  }

  /**
   * Détermine le niveau de risque
   */
  getRiskLevel(score: number): string {
    if (score >= 8) return 'très faible';
    if (score >= 7) return 'faible';
    if (score >= 5) return 'moyen';
    if (score >= 3) return 'élevé';
    return 'très élevé';
  }

  /**
   * Calcule la probabilité d'approbation
   */
  getApprovalProbability(score: number): number {
    const probabilities: { [key: number]: number } = {
      10: 0.95, 9: 0.90, 8: 0.85, 7: 0.75, 6: 0.65,
      5: 0.50, 4: 0.35, 3: 0.25, 2: 0.15, 1: 0.05
    };
    return probabilities[score] || 0.50;
  }

  /**
   * Synchronise avec le serveur
   */
  syncWithServer(username: string): Observable<{ success: boolean; synced: number; errors: number }> {
    if (this.isOfflineMode) {
      return of({ success: false, synced: 0, errors: 0 });
    }

    const localRequests = this.getLocalRequests(username)
      .filter(req => req.source === 'local' && req.status === 'submitted');

    if (localRequests.length === 0) {
      return of({ success: true, synced: 0, errors: 0 });
    }

    return from(localRequests).pipe(
      mergeMap(request => 
        this.http.post<any>(`${this.CREDIT_LONG_API}/create`, request).pipe(
          map(() => ({ success: true, request })),
          catchError(() => of({ success: false, request }))
        )
      ),
      toArray(),
      map(results => {
        const synced = results.filter(r => r.success).length;
        const errors = results.filter(r => !r.success).length;
        
        results.filter(r => r.success).forEach(result => {
          const updatedRequest: CreditLongRequest = { 
            ...result.request, 
            source: 'server' as const
          };
          this.saveLocalRequest(updatedRequest);
        });

        return { success: synced > 0, synced, errors };
      })
    );
  }

  /**
   * Nettoie les données anciennes
   */
  cleanupOldData(daysOld: number = 30): void {
    try {
      const allRequests = this.getAllLocalRequests();
      const cutoffDate = new Date();
      cutoffDate.setDate(cutoffDate.getDate() - daysOld);

      const filteredRequests = allRequests.filter(request => {
        if (!request.lastUpdated) return true;
        
        const requestDate = new Date(request.lastUpdated);
        return requestDate > cutoffDate || request.status === 'draft';
      });

      if (filteredRequests.length < allRequests.length) {
        localStorage.setItem('credit_long_requests', JSON.stringify(filteredRequests));
        console.log(`${allRequests.length - filteredRequests.length} anciennes demandes supprimées`);
      }
    } catch (error) {
      console.error('Erreur nettoyage:', error);
    }
  }

  /**
   * Statistiques utilisateur
   */
  getUserStats(username: string): Observable<{
    totalRequests: number;
    draftRequests: number;
    submittedRequests: number;
    approvedRequests: number;
    rejectedRequests: number;
    totalRequestedAmount: number;
    averageAmount: number;
  }> {
    return this.loadUserRequests(username).pipe(
      map(requests => {
        const stats = {
          totalRequests: requests.length,
          draftRequests: requests.filter(r => r.status === 'draft').length,
          submittedRequests: requests.filter(r => r.status === 'submitted').length,
          approvedRequests: requests.filter(r => r.status === 'approved').length,
          rejectedRequests: requests.filter(r => r.status === 'rejected').length,
          totalRequestedAmount: requests.reduce((sum, r) => sum + (r.creditDetails?.requestedAmount || 0), 0),
          averageAmount: 0
        };

        if (stats.totalRequests > 0) {
          stats.averageAmount = stats.totalRequestedAmount / stats.totalRequests;
        }

        return stats;
      })
    );
  }

  /**
   * Exporte les données utilisateur
   */
  exportUserData(username: string): Observable<string> {
    return this.loadUserRequests(username).pipe(
      map(requests => {
        const exportData = {
          exportDate: new Date().toISOString(),
          username: username,
          totalRequests: requests.length,
          requests: requests.map(request => ({
            ...request,
            personalInfo: {
              ...request.personalInfo,
              phone: this.maskPhone(request.personalInfo.phone),
              address: this.maskAddress(request.personalInfo.address)
            }
          }))
        };

        return JSON.stringify(exportData, null, 2);
      })
    );
  }

  /**
   * Masque le téléphone
   */
  private maskPhone(phone: string): string {
    if (!phone || phone.length < 4) return phone;
    return phone.substring(0, 2) + '*'.repeat(phone.length - 4) + phone.substring(phone.length - 2);
  }

  /**
   * Masque l'adresse
   */
  private maskAddress(address: string): string {
    if (!address) return address;
    const words = address.split(' ');
    if (words.length <= 2) return address;
    
    return words[0] + ' ' + '*'.repeat(words.slice(1, -1).join(' ').length) + ' ' + words[words.length - 1];
  }

  /**
   * Nettoie les données utilisateur
   */
  clearUserData(): void {
    this.userRequestsSubject.next([]);
    this.requestsCache.clear();
    console.log('Cache utilisateur nettoyé');
  }

  /**
   * Active/désactive le mode hors ligne
   */
  setOfflineMode(enabled: boolean): void {
    this.isOfflineMode = enabled;
    if (enabled) {
      localStorage.setItem('force_fallback_mode', 'true');
      console.log('Mode hors ligne activé');
    } else {
      localStorage.removeItem('force_fallback_mode');
      console.log('Mode en ligne activé');
    }
  }

  /**
   * Vérifie si en mode hors ligne
   */
  isInOfflineMode(): boolean {
    return this.isOfflineMode;
  }

  /**
   * Gestion des erreurs HTTP
   */
  private handleError = (error: HttpErrorResponse): Observable<never> => {
    let errorMessage = 'Une erreur est survenue';

    if (error.error instanceof ErrorEvent) {
      errorMessage = `Erreur: ${error.error.message}`;
    } else {
      switch (error.status) {
        case 0:
          errorMessage = 'Impossible de contacter le serveur';
          break;
        case 404:
          errorMessage = 'Endpoint non trouvé';
          break;
        case 500:
          errorMessage = 'Erreur interne du serveur';
          break;
        case 503:
          errorMessage = 'Service temporairement indisponible';
          break;
        default:
          errorMessage = `Erreur ${error.status}: ${error.error?.message || error.message}`;
      }
    }

    console.error('Erreur HTTP:', errorMessage, error);
    return throwError(errorMessage);
  };

  /**
   * État de santé du service
   */
  getServiceHealth(): Observable<{
    status: 'healthy' | 'degraded' | 'offline';
    message: string;
    details: any;
  }> {
    if (this.isOfflineMode) {
      return of({
        status: 'offline',
        message: 'Service en mode hors ligne',
        details: { mode: 'offline', fallback: true }
      });
    }

    return this.testConnection().pipe(
      map(result => ({
        status: result.success ? 'healthy' : 'degraded',
        message: result.message,
        details: result.details || {}
      }))
    );
  }
}