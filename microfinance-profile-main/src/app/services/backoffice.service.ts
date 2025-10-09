import { Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../environments/environment';

export interface BackofficeStats {
  [x: string]: number;
  total: number;
  submitted: number;
  inReview: number;
  approved: number;
  rejected: number;
  totalRequestedAmount: number;
  totalApprovedAmount: number;
  averageRequestedAmount: number;
  todayRequests: number;
  thisWeekRequests: number;
  thisMonthRequests: number;
}

@Injectable({
  providedIn: 'root'
})
export class BackofficeService {
  private apiUrl = environment.nestUrl || 'http://localhost:3000';

  constructor(private http: HttpClient) {}

  /**
   * Récupérer toutes les demandes
   */
  getAllRequests(filters: {
    status?: string;
    page?: number;
    limit?: number;
  } = {}): Observable<any> {
    let params = new HttpParams();
    
    if (filters.status) {
      params = params.set('status', filters.status);
    }
    if (filters.page) {
      params = params.set('page', filters.page.toString());
    }
    if (filters.limit) {
      params = params.set('limit', filters.limit.toString());
    }

    return this.http.get(`${this.apiUrl}/api/credit-long/all-requests`, { params });
  }

  /**
   * Récupérer les détails d'une demande
   */
  getRequestDetails(id: string): Observable<any> {
    return this.http.get(`${this.apiUrl}/api/credit-long/requests/${id}`);
  }

  /**
   * Mettre à jour le statut d'une demande
   */
  updateRequestStatus(id: string, data: {
    status?: string;
    decisionNotes?: string;
    approvedAmount?: number;
    approvedRate?: number;
    approvedDuration?: number;
  }): Observable<any> {
    return this.http.patch(`${this.apiUrl}/api/credit-long/requests/${id}`, data);
  }

  /**
   * Approuver une demande
   */
  approveRequest(id: string, data: {
    approvedAmount?: number;
    approvedRate?: number;
    approvedDuration?: number;
    notes?: string;
  }): Observable<any> {
    return this.http.post(`${this.apiUrl}/api/credit-long/requests/${id}/approve`, data);
  }

  /**
   * Rejeter une demande
   */
  rejectRequest(id: string, reason: string): Observable<any> {
    return this.http.post(`${this.apiUrl}/api/credit-long/requests/${id}/reject`, { reason });
  }

  /**
   * Mettre en examen
   */
  putInReview(id: string): Observable<any> {
    return this.http.post(`${this.apiUrl}/api/credit-long/requests/${id}/review`, {});
  }

  /**
   * Récupérer les statistiques
   */
  getStatistics(): Observable<{ success: boolean; statistics: BackofficeStats }> {
    return this.http.get<{ success: boolean; statistics: BackofficeStats }>(
      `${this.apiUrl}/api/credit-long/statistics`
    );
  }

  /**
   * Ajouter un commentaire
   */
  addComment(id: string, comment: string, isPrivate: boolean = false): Observable<any> {
    return this.http.post(`${this.apiUrl}/api/credit-long/requests/${id}/comments`, {
      comment,
      isPrivate,
      commentType: 'general'
    });
  }

  /**
   * Exporter les demandes
   */
  exportRequests(status?: string, format: string = 'json'): Observable<any> {
    let params = new HttpParams();
    
    if (status) {
      params = params.set('status', status);
    }
    params = params.set('format', format);

    return this.http.get(`${this.apiUrl}/api/credit-long/export`, { params });
  }
}
