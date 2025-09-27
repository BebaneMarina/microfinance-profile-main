// credit-requests.service.ts - CORRECTION FINALE
import { Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { BehaviorSubject, Observable, of, forkJoin } from 'rxjs';
import { catchError, map, tap } from 'rxjs/operators';
import { environment } from '../environments/environment';

// Interfaces
export interface ShortCreditRequest {
  id: string;
  type: 'short';
  username: string;
  creditType: string;
  amount: number;
  totalAmount: number;
  status: 'active' | 'paid' | 'overdue';
  approvedDate: string;
  dueDate: string;
  nextPaymentDate?: string;
  nextPaymentAmount?: number;
  remainingAmount: number;
  interestRate: number;
  createdAt: string;
  disbursedAmount?: number;
}

export interface LongCreditRequest {
  id: string;
  type: 'long';
  username: string;
  status: 'draft' | 'submitted' | 'in_review' | 'approved' | 'rejected' | 'requires_info';
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
    preferredRate?: number;
    guarantors?: any[];
  };
  financialDetails?: {
    monthlyIncome: number;
    monthlyExpenses: number;
    otherIncomes?: any[];
    existingLoans?: any[];
    assets?: any[];
    employmentDetails?: any;
  };
  submissionDate?: string;
  createdAt: string;
  reviewHistory?: ReviewHistoryEntry[];
  simulation?: CreditSimulation;
  documents?: any;
}

export interface ReviewHistoryEntry {
  date: string;
  action: string;
  agent: string;
  comment?: string;
}

export interface CreditSimulation {
  calculatedScore: number;
  riskLevel: string;
  recommendedAmount: number;
  suggestedRate: number;
  monthlyPayment: number;
  totalInterest: number;
  debtToIncomeRatio: number;
  approvalProbability: number;
}

export type CreditRequest = ShortCreditRequest | LongCreditRequest;

export interface CreditRequestStats {
  total: number;
  short: number;
  long: number;
  active: number;
  pending: number;
  completed: number;
}

@Injectable({
  providedIn: 'root'
})
export class CreditRequestsService {

  // ✅ CORRECTION CRITIQUE : Utiliser le port 3000 pour NestJS
  private apiUrl = 'http://localhost:3000';  // NestJS Backend
  private flaskApiUrl = 'http://localhost:5000';  // Flask ML uniquement
  
  private requestsSubject = new BehaviorSubject<CreditRequest[]>([]);
  private statsSubject = new BehaviorSubject<CreditRequestStats>({
    total: 0,
    short: 0,
    long: 0,
    active: 0,
    pending: 0,
    completed: 0
  });

  public requests$ = this.requestsSubject.asObservable();
  public stats$ = this.statsSubject.asObservable();

  constructor(private http: HttpClient) {}

  // ========================================
  // MÉTHODES PRINCIPALES
  // ========================================

  async loadUserRequests(username: string): Promise<CreditRequest[]> {
    try {
      console.log('Chargement des demandes pour:', username);

      const [shortRequestsResult, longRequestsResult] = await Promise.all([
        this.loadShortRequests(username).toPromise(),
        this.loadLongRequests(username).toPromise()
      ]);

      const shortRequests: ShortCreditRequest[] = shortRequestsResult || [];
      const longRequests: LongCreditRequest[] = longRequestsResult || [];

      const allRequests = [...shortRequests, ...longRequests]
        .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());

      this.requestsSubject.next(allRequests);
      this.updateStats(allRequests);

      console.log('Demandes chargées:', allRequests.length);
      return allRequests;

    } catch (error) {
      console.error('Erreur chargement demandes:', error);
      
      const emptyRequests: CreditRequest[] = [];
      this.requestsSubject.next(emptyRequests);
      this.updateStats(emptyRequests);
      
      return emptyRequests;
    }
  }

  async createShortRequest(requestData: any): Promise<ShortCreditRequest> {
    try {
      console.log('Création demande courte:', requestData);

      const shortRequest: ShortCreditRequest = {
        id: this.generateId(),
        type: 'short',
        username: requestData.username,
        creditType: requestData.type,
        amount: requestData.amount,
        totalAmount: requestData.totalAmount || requestData.amount,
        status: 'active',
        approvedDate: new Date().toISOString(),
        dueDate: this.calculateDueDate(requestData.type),
        remainingAmount: requestData.totalAmount || requestData.amount,
        interestRate: this.getCreditInterestRate(requestData.type),
        createdAt: new Date().toISOString(),
        disbursedAmount: requestData.amount
      };

      await this.saveShortRequestLocally(shortRequest);

      try {
        await this.http.post(`${this.apiUrl}/credit/short`, shortRequest).toPromise();
        console.log('Demande courte sauvegardée sur serveur');
      } catch (apiError) {
        console.warn('API non disponible, sauvegarde locale uniquement');
      }

      try {
        await this.http.post(`${this.flaskApiUrl}/register-credit`, {
          username: requestData.username,
          credit: shortRequest,
          client_data: requestData.client_data
        }).toPromise();
      } catch (flaskError) {
        console.warn('Flask API non disponible');
      }

      this.loadUserRequests(requestData.username);

      return shortRequest;

    } catch (error) {
      console.error('Erreur création demande courte:', error);
      throw error;
    }
  }

  // ✅ TOUTES LES MÉTHODES LONGUES UTILISENT LE PORT 3000
  async createLongRequest(requestData: any): Promise<LongCreditRequest> {
    try {
      console.log('Création demande longue complète:', requestData);

      const response = await this.http.post<any>(
        `${this.apiUrl}/credit-long/create`,  // ✅ Port 3000
        requestData
      ).toPromise();
      
      const createdRequest: LongCreditRequest = this.mapLongRequest(response.request || response);

      if (requestData.username) {
        this.loadUserRequests(requestData.username);
      }

      console.log('Demande longue créée avec succès:', createdRequest.id);
      return createdRequest;

    } catch (error) {
      console.error('Erreur création demande longue:', error);
      throw error;
    }
  }

  async getLongRequestDraft(username: string): Promise<LongCreditRequest | null> {
    try {
      const response = await this.http.get<any>(
        `${this.apiUrl}/credit-long/user/${username}/draft`  // ✅ Port 3000
      ).toPromise();
      
      if (response && response.request) {
        return this.mapLongRequest(response.request);
      }
      
      return null;

    } catch (error) {
      console.error('Erreur récupération brouillon:', error);
      return null;
    }
  }

  async updateLongRequest(requestId: string, updates: Partial<LongCreditRequest>): Promise<LongCreditRequest> {
    try {
      const response = await this.http.put<any>(
        `${this.apiUrl}/credit-long/request/${requestId}`,  // ✅ Port 3000
        updates
      ).toPromise();
      return this.mapLongRequest(response.request || response);
    } catch (error) {
      console.error('Erreur mise à jour demande longue:', error);
      throw error;
    }
  }

  async submitLongRequestForReview(requestId: string): Promise<LongCreditRequest> {
    try {
      const response = await this.http.post<any>(
        `${this.apiUrl}/credit-long/request/${requestId}/submit`,  // ✅ Port 3000
        {}
      ).toPromise();
      
      return this.mapLongRequest(response.request || response);

    } catch (error) {
      console.error('Erreur soumission demande longue:', error);
      throw error;
    }
  }

  async uploadLongRequestDocument(
    requestId: string, 
    documentType: string, 
    file: File
  ): Promise<any> {
    try {
      const formData = new FormData();
      formData.append('file', file);
      formData.append('documentType', documentType);

      const response = await this.http.post<any>(
        `${this.apiUrl}/credit-long/request/${requestId}/documents`,  // ✅ Port 3000
        formData
      ).toPromise();

      return response;

    } catch (error) {
      console.error('Erreur upload document:', error);
      throw error;
    }
  }

  async saveLongRequestDraft(draftData: any): Promise<LongCreditRequest> {
    try {
      console.log('Sauvegarde brouillon demande longue:', draftData.username);

      const existingDraft = await this.getLongRequestDraft(draftData.username);
      
      if (existingDraft) {
        const updatedData = {
          ...draftData,
          updatedAt: new Date().toISOString(),
          reviewHistory: [
            ...existingDraft.reviewHistory || [],
            {
              date: new Date().toISOString(),
              action: 'Brouillon mis à jour',
              agent: 'Client',
              comment: 'Sauvegarde automatique'
            }
          ]
        };
        
        return await this.updateLongRequest(existingDraft.id, updatedData);
      } else {
        const newDraft = {
          ...draftData,
          status: 'draft',
          createdAt: new Date().toISOString()
        };
        
        return await this.createLongRequest(newDraft);
      }

    } catch (error) {
      console.error('Erreur sauvegarde brouillon:', error);
      throw error;
    }
  }

  // ========================================
  // CHARGEMENT DES DONNÉES
  // ========================================

  private loadShortRequests(username: string): Observable<ShortCreditRequest[]> {
    return new Observable<ShortCreditRequest[]>(observer => {
      Promise.all([
        this.loadShortRequestsFromStorage(username),
        this.loadShortRequestsFromAPI(username)
      ]).then(([localRequests, apiRequests]) => {
        const safeLocalRequests = localRequests || [];
        const safeApiRequests = apiRequests || [];
        
        const allRequests = [...safeLocalRequests];
        
        safeApiRequests.forEach(apiRequest => {
          if (!allRequests.find(local => local.id === apiRequest.id)) {
            allRequests.push(apiRequest);
          }
        });

        observer.next(allRequests);
        observer.complete();
      }).catch(error => {
        console.error('Erreur chargement demandes courtes:', error);
        observer.next([]);
        observer.complete();
      });
    });
  }

  private loadLongRequests(username: string): Observable<LongCreditRequest[]> {
    return this.http.get<any>(`${this.apiUrl}/credit-long/user/${username}`).pipe(  // ✅ Port 3000
      map(response => {
        if (response && response.requests && Array.isArray(response.requests)) {
          return response.requests.map((request: any) => this.mapLongRequest(request));
        }
        return [];
      }),
      catchError(error => {
        console.error('Erreur chargement demandes longues:', error);
        return of([]);
      })
    );
  }

  private async loadShortRequestsFromStorage(username: string): Promise<ShortCreditRequest[]> {
    try {
      const storageKey = `user_credits_${username}`;
      const savedCredits = localStorage.getItem(storageKey);
      
      if (!savedCredits) {
        return [];
      }

      const credits = JSON.parse(savedCredits);
      
      if (!Array.isArray(credits)) {
        console.warn('Format invalide dans localStorage');
        return [];
      }

      return credits.map((credit: any) => ({
        id: credit.id || '',
        type: 'short' as const,
        username: username,
        creditType: credit.type || '',
        amount: Number(credit.amount) || 0,
        totalAmount: Number(credit.totalAmount) || 0,
        status: credit.status || 'active',
        approvedDate: credit.approvedDate || new Date().toISOString(),
        dueDate: credit.dueDate || new Date().toISOString(),
        nextPaymentDate: credit.nextPaymentDate,
        nextPaymentAmount: Number(credit.nextPaymentAmount) || 0,
        remainingAmount: Number(credit.remainingAmount) || 0,
        interestRate: Number(credit.interestRate) || 0,
        createdAt: credit.approvedDate || new Date().toISOString(),
        disbursedAmount: Number(credit.amount) || 0
      }));
      
    } catch (error) {
      console.error('Erreur chargement localStorage:', error);
      return [];
    }
  }

  private async loadShortRequestsFromAPI(username: string): Promise<ShortCreditRequest[]> {
    try {
      const response = await this.http.get<any[]>(`${this.apiUrl}/user-credits/${username}`).toPromise();
      
      if (!response || !Array.isArray(response)) {
        return [];
      }
      
      return response.map(apiCredit => ({
        id: apiCredit.id || '',
        type: 'short' as const,
        username: username,
        creditType: apiCredit.type || '',
        amount: Number(apiCredit.amount) || 0,
        totalAmount: Number(apiCredit.totalAmount) || 0,
        status: apiCredit.status || 'active',
        approvedDate: apiCredit.approvedDate || new Date().toISOString(),
        dueDate: apiCredit.dueDate || new Date().toISOString(),
        remainingAmount: Number(apiCredit.remainingAmount) || 0,
        interestRate: Number(apiCredit.interestRate) || 0,
        createdAt: apiCredit.approvedDate || new Date().toISOString(),
        disbursedAmount: Number(apiCredit.amount) || 0
      }));
      
    } catch (error) {
      console.warn('API non disponible pour demandes courtes');
      return [];
    }
  }

  // ========================================
  // SAUVEGARDE LOCALE
  // ========================================

  private async saveShortRequestLocally(request: ShortCreditRequest): Promise<void> {
    try {
      const storageKey = `user_credits_${request.username}`;
      let existingCredits = [];

      const saved = localStorage.getItem(storageKey);
      if (saved) {
        existingCredits = JSON.parse(saved);
      }

      const creditForStorage = {
        id: request.id,
        type: request.creditType,
        amount: request.amount,
        totalAmount: request.totalAmount,
        remainingAmount: request.remainingAmount,
        interestRate: request.interestRate,
        status: request.status,
        approvedDate: request.approvedDate,
        dueDate: request.dueDate,
        nextPaymentDate: request.nextPaymentDate,
        nextPaymentAmount: request.nextPaymentAmount,
        paymentsHistory: []
      };

      const existingIndex = existingCredits.findIndex((c: any) => c.id === request.id);
      if (existingIndex >= 0) {
        existingCredits[existingIndex] = creditForStorage;
      } else {
        existingCredits.push(creditForStorage);
      }

      localStorage.setItem(storageKey, JSON.stringify(existingCredits));
      console.log('Demande courte sauvegardée localement');

    } catch (error) {
      console.error('Erreur sauvegarde locale:', error);
    }
  }

  // ========================================
  // ACTIONS SUR LES DEMANDES
  // ========================================

  async deleteLongRequest(requestId: string): Promise<void> {
    try {
      await this.http.delete(`${this.apiUrl}/credit-long/request/${requestId}`).toPromise();
      console.log('Demande longue supprimée');
    } catch (error) {
      console.error('Erreur suppression demande longue:', error);
      throw error;
    }
  }

  // ========================================
  // UTILITAIRES
  // ========================================

  private generateId(): string {
    return `REQ_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
  }

  private calculateDueDate(creditType: string): string {
    const dueDate = new Date();
    
    switch (creditType) {
      case 'avance_salaire':
        dueDate.setMonth(dueDate.getMonth() + 1);
        dueDate.setDate(new Date(dueDate.getFullYear(), dueDate.getMonth() + 1, 0).getDate());
        break;
      case 'depannage':
        dueDate.setDate(dueDate.getDate() + 30);
        break;
      case 'consommation_generale':
        dueDate.setDate(dueDate.getDate() + 45);
        break;
      default:
        dueDate.setDate(dueDate.getDate() + 30);
    }
    
    return dueDate.toISOString();
  }

  private getCreditInterestRate(creditType: string): number {
    const rates: Record<string, number> = {
      'consommation_generale': 0.05,
      'avance_salaire': 0.03,
      'depannage': 0.04,
      'investissement': 0.08,
      'tontine': 0.06,
      'retraite': 0.04
    };
    return rates[creditType] || 0.05;
  }

  private mapLongRequest(apiRequest: any): LongCreditRequest {
    return {
      id: apiRequest.id,
      type: 'long',
      username: apiRequest.username,
      status: apiRequest.status,
      personalInfo: apiRequest.personalInfo,
      creditDetails: apiRequest.creditDetails,
      financialDetails: apiRequest.financialDetails,
      submissionDate: apiRequest.submissionDate,
      createdAt: apiRequest.createdAt || apiRequest.submissionDate,
      reviewHistory: apiRequest.reviewHistory || [],
      simulation: apiRequest.simulation || apiRequest.simulationResults
    };
  }

  private updateStats(requests: CreditRequest[]): void {
    const stats: CreditRequestStats = {
      total: requests.length,
      short: requests.filter(req => req.type === 'short').length,
      long: requests.filter(req => req.type === 'long').length,
      active: requests.filter(req => 
        req.status === 'active' || req.status === 'approved' || req.status === 'submitted'
      ).length,
      pending: requests.filter(req => 
        req.status === 'submitted' || req.status === 'in_review'
      ).length,
      completed: requests.filter(req => 
        req.status === 'paid' || req.status === 'approved'
      ).length
    };

    this.statsSubject.next(stats);
  }

  getRequestById(requestId: string): Observable<CreditRequest | null> {
    return this.requests$.pipe(
      map(requests => requests.find(req => req.id === requestId) || null)
    );
  }

  filterRequests(
    requests: CreditRequest[],
    filters: {
      type?: 'all' | 'short' | 'long';
      status?: string;
      searchTerm?: string;
    }
  ): CreditRequest[] {
    let filtered = [...requests];

    if (filters.type && filters.type !== 'all') {
      filtered = filtered.filter(req => req.type === filters.type);
    }

    if (filters.status && filters.status !== 'all') {
      filtered = filtered.filter(req => req.status === filters.status);
    }

    if (filters.searchTerm?.trim()) {
      const term = filters.searchTerm.toLowerCase();
      filtered = filtered.filter(req => {
        if (req.type === 'short') {
          return req.creditType.toLowerCase().includes(term) ||
                 req.id.toLowerCase().includes(term);
        } else {
          return req.personalInfo?.fullName?.toLowerCase().includes(term) ||
                 req.creditDetails?.purpose?.toLowerCase().includes(term) ||
                 req.id.toLowerCase().includes(term);
        }
      });
    }

    return filtered;
  }

  getCurrentStats(): CreditRequestStats {
    return this.statsSubject.value;
  }

  async refreshData(username: string): Promise<void> {
    await this.loadUserRequests(username);
  }
}