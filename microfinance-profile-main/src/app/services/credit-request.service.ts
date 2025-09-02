// src/app/services/credit-request.service.ts
import { Injectable } from '@angular/core';
import { HttpClient, HttpErrorResponse, HttpParams } from '@angular/common/http';
import { Observable, catchError, throwError, of, map } from 'rxjs';
import { CreditRequest, CreditStats } from '../models/credit-request.model';

@Injectable({
  providedIn: 'root'
})
export class CreditRequestService {
  private apiUrl = 'http://localhost:3000/api/v1/credit-requests';

  constructor(private http: HttpClient) {}

  /**
   * Récupère toutes les demandes de crédit ou filtrées par statut
   */
  getCreditRequests(status?: string): Observable<CreditRequest[]> {
    let params = new HttpParams();
    if (status) {
      params = params.append('status', status);
    }
    
    return this.http.get<CreditRequest[]>(this.apiUrl, { params })
      .pipe(
        catchError(this.handleError<CreditRequest[]>('getCreditRequest', []))
      );
  }

  /**
   * Récupère une demande de crédit spécifique par ID
   */
  getCreditRequest(id: string): Observable<CreditRequest> {
    return this.http.get<CreditRequest>(`${this.apiUrl}/${id}`)
      .pipe(
        catchError(this.handleError<CreditRequest>('getCreditRequest'))
      );
  }

  /**
   * Récupère les statistiques des demandes de crédit
   */
  getStats(): Observable<CreditStats> {
    return this.http.get<any>(`${this.apiUrl}/stats`).pipe(
      map(response => ({
        total: response.totalRequests || 0,
        pending: response.pendingRequests || 0,
        approved: response.approvedRequests || 0,
        rejected: response.rejectedRequests || 0,
        approvalRate: response.approvalRate || 0
      })),
      catchError(() => of({
        total: 0,
        pending: 0,
        approved: 0,
        rejected: 0,
        approvalRate: 0
      }))
    );
  }

  /**
   * Crée une nouvelle demande de crédit
   */
  createCreditRequest(creditRequest: Partial<CreditRequest>): Observable<CreditRequest> {
    return this.http.post<CreditRequest>(this.apiUrl, creditRequest)
      .pipe(
        catchError(this.handleError<CreditRequest>('createCreditRequest'))
      );
  }

  /**
   * Met à jour une demande de crédit
   */
  updateCreditRequest(id: string, updates: Partial<CreditRequest>): Observable<CreditRequest> {
    return this.http.patch<CreditRequest>(`${this.apiUrl}/${id}`, updates)
      .pipe(
        catchError(this.handleError<CreditRequest>('updateCreditRequest'))
      );
  }

  /**
   * Supprime une demande de crédit
   */
  deleteCreditRequest(id: string): Observable<void> {
    return this.http.delete<void>(`${this.apiUrl}/${id}`)
      .pipe(
        catchError(this.handleError<void>('deleteCreditRequest'))
      );
  }

  /**
   * Assigne une demande à un agent
   */
  assignRequest(id: string, agentId: string): Observable<CreditRequest> {
    return this.http.patch<CreditRequest>(`${this.apiUrl}/${id}/assign`, { agentId })
      .pipe(
        catchError(this.handleError<CreditRequest>('assignRequest'))
      );
  }

  /**
   * Prend une décision sur une demande de crédit
   */
  makeDecision(id: string, decision: 'approved' | 'rejected', reason?: string): Observable<CreditRequest> {
    const payload = { status: decision, reason };
    return this.http.patch<CreditRequest>(`${this.apiUrl}/${id}/decision`, payload)
      .pipe(
        catchError(this.handleError<CreditRequest>('makeDecision'))
      );
  }

  /**
   * Recherche des demandes avec filtres
   */
  searchRequests(filters: {
    status?: string;
    minAmount?: number;
    maxAmount?: number;
    dateFrom?: string;
    dateTo?: string;
    applicantName?: string;
  }): Observable<CreditRequest[]> {
    return this.http.post<CreditRequest[]>(`${this.apiUrl}/search`, filters)
      .pipe(
        catchError(this.handleError<CreditRequest[]>('searchRequests', []))
      );
  }

  /**
   * Récupère les demandes récentes
   */
  getRecentRequests(limit: number = 5): Observable<CreditRequest[]> {
    const params = new HttpParams().set('limit', limit.toString());
    return this.http.get<CreditRequest[]>(`${this.apiUrl}/recent`, { params })
      .pipe(
        catchError(this.handleError<CreditRequest[]>('getRecentRequests', []))
      );
  }

  /**
   * Récupère les demandes en attente
   */
  getPendingRequests(): Observable<CreditRequest[]> {
    return this.getCreditRequests('pending');
  }

  /**
   * Récupère les demandes approuvées
   */
  getApprovedRequests(): Observable<CreditRequest[]> {
    return this.getCreditRequests('approved');
  }

  /**
   * Récupère les demandes rejetées
   */
  getRejectedRequests(): Observable<CreditRequest[]> {
    return this.getCreditRequests('rejected');
  }

  /**
   * Gestion centralisée des erreurs
   */
  private handleError<T>(operation = 'operation', result?: T) {
    return (error: HttpErrorResponse): Observable<T> => {
      console.error(`${operation} failed:`, error);
      
      // Log détaillé pour le développement
      if (error.error instanceof ErrorEvent) {
        // Erreur côté client
        console.error('Client Error:', error.error.message);
      } else {
        // Erreur côté serveur
        console.error(
          `Server Error: ${error.status}, ` +
          `Body: ${error.error}`
        );
      }

      // Retourner un résultat par défaut pour maintenir l'application en marche
      return of(result as T);
    };
  }

  /**
   * Vérifie si le service backend est disponible
   */
  checkHealth(): Observable<boolean> {
    return this.http.get(`${this.apiUrl}/health`)
      .pipe(
        map(() => true),
        catchError(() => of(false))
      );
  }
}