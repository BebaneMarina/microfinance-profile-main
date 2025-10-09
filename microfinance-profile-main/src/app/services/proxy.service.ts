// proxy.service.ts - CORRECTION CONVERSION SCORE

import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, throwError } from 'rxjs';
import { catchError, map } from 'rxjs/operators';
import { environment } from '../environments/environment'; 

@Injectable({
  providedIn: 'root'
})
export class ApiProxyService {
  private nestUrl = environment.nestUrl || 'http://localhost:3000';
  private flaskUrl = environment.flaskUrl || 'http://localhost:5000';

  constructor(private http: HttpClient) {
    console.log('ApiProxyService initialise');
    console.log('NestJS URL:', this.nestUrl);
    console.log('Flask URL:', this.flaskUrl);
  }

  // ENDPOINTS NESTJS
  registerCredit(creditData: any): Observable<any> {
    return this.http.post(`${this.nestUrl}/api/credit/register-credit`, creditData);
  }

  getUserCredits(username: string): Observable<any> {
    return this.http.get(`${this.nestUrl}/api/credit/user-credits/${username}`);
  }

  getUserRestrictions(username: string): Observable<any> {
    return this.http.get(`${this.nestUrl}/api/credit/restrictions/${username}`);
  }

  processPayment(paymentData: any): Observable<any> {
    return this.http.post(`${this.nestUrl}/api/credit/process-payment`, paymentData);
  }

  createCreditRequest(creditData: any): Observable<any> {
    return this.http.post(`${this.nestUrl}/api/credit`, creditData);
  }

  getUserCreditRequests(userId: number): Observable<any> {
    return this.http.get(`${this.nestUrl}/api/credit?userId=${userId}`);
  }

  getCreditRequest(id: number): Observable<any> {
    return this.http.get(`${this.nestUrl}/api/credit/${id}`);
  }

  // CORRECTION PRINCIPALE - CONVERSION EN NOMBRE
  getUserScoring(userId: number, recalculate: boolean = false): Observable<any> {
    const params = recalculate ? '?recalculate=true' : '';
    return this.http.get(`${this.flaskUrl}/client-scoring/${userId}${params}`).pipe(
      map((response: any) => {
        console.log('Reponse Flask brute:', response);
        
        // CONVERSION FORCEE EN NOMBRE
        const score = Number(response.score) || 0;
        const score850 = Number(response.score_850) || 0;
        const modelConfidence = Number(response.model_confidence) || 0.75;
        const eligibleAmount = Number(response.eligible_amount) || 0;
        
        const result = {
          user_id: userId,
          score: score,
          score_850: score850,
          eligible_amount: eligibleAmount,
          risk_level: response.risk_level || 'medium',
          factors: response.details?.factors || [],
          recommendations: response.recommendations || [],
          last_updated: response.last_updated || new Date().toISOString(),
          is_real_time: true,
          
          model_type: response.model_used || response.model_type || 'rule_based',
          model_confidence: modelConfidence,
          
          payment_analysis: response.details
        };
        
        console.log('Score converti:', result.score, 'Montant eligible:', result.eligible_amount);
        
        return result;
      }),
      catchError(error => {
        console.error('Erreur getUserScoring:', error);
        return throwError(() => error);
      })
    );
  }

  recalculateUserScore(userId: number): Observable<any> {
    return this.http.post(`${this.flaskUrl}/recalculate-score/${userId}`, {}).pipe(
      map((response: any) => ({
        success: response.success || false,
        score: Number(response.score) || 0,
        score_850: Number(response.score_850) || 0,
        risk_level: response.risk_level || 'medium',
        eligible_amount: Number(response.eligible_amount) || 0,
        
        model_used: response.model_used || response.model_type || 'rule_based',
        model_confidence: Number(response.model_confidence) || 0.75,
        
        recommendations: response.recommendations || []
      })),
      catchError(error => {
        console.error('Erreur recalculateUserScore:', error);
        return throwError(() => error);
      })
    );
  }

  getPaymentAnalysis(userId: number): Observable<any> {
    return this.http.get(`${this.flaskUrl}/payment-analysis/${userId}`).pipe(
      map((response: any) => ({
        total_payments: Number(response.total_payments) || 0,
        on_time_payments: Number(response.on_time_payments) || 0,
        late_payments: Number(response.late_payments) || 0,
        missed_payments: Number(response.missed_payments) || 0,
        on_time_ratio: Number(response.on_time_ratio) || 0,
        avg_delay_days: Number(response.avg_delay_days) || 0,
        reliability: response.reliability || 'N/A',
        current_debt: Number(response.current_debt) || 0,
        debt_ratio: Number(response.debt_ratio) || 0,
        active_credits: Number(response.active_credits) || 0
      })),
      catchError(error => {
        console.error('Erreur getPaymentAnalysis:', error);
        return throwError(() => error);
      })
    );
  }

  checkUserEligibility(userId: number): Observable<any> {
    return this.http.get(`${this.flaskUrl}/check-eligibility/${userId}`).pipe(
      map((response: any) => ({
        eligible: response.eligible || false,
        raison: response.raison || '',
        montant_eligible: Number(response.montant_eligible) || 0,
        score: Number(response.score) || 0
      })),
      catchError(error => {
        console.error('Erreur checkUserEligibility:', error);
        return throwError(() => error);
      })
    );
  }

  getUserProfile(userId: number): Observable<any> {
    return this.http.get(`${this.flaskUrl}/user-profile/${userId}`);
  }

  getScoreTrend(username: string): Observable<any> {
    return this.http.get(`${this.flaskUrl}/score-trend/${username}`).pipe(
      catchError(error => {
        console.warn('Endpoint score-trend non disponible:', error);
        return throwError(() => ({
          success: false,
          recent_transactions: []
        }));
      })
    );
  }

  getSystemStatistics(): Observable<any> {
    return this.http.get(`${this.flaskUrl}/statistics`);
  }

  retrainModel(): Observable<any> {
    return this.http.post(`${this.flaskUrl}/retrain-model`, {});
  }

  // NOUVEAUX ENDPOINTS - STATISTIQUES COMPLETES
  getUserStats(userId: number): Observable<any> {
    return this.http.get(`${this.nestUrl}/api/credit/user-stats/${userId}`).pipe(
      map((response: any) => ({
        success: true,
        data: response.data || response
      })),
      catchError(error => {
        console.error('Erreur getUserStats:', error);
        return throwError(() => ({
          success: false,
          error: error.message || 'Erreur lors du chargement des statistiques'
        }));
      })
    );
  }

  getUserCreditsDetailed(userId: number): Observable<any> {
    return this.http.get(`${this.nestUrl}/api/credit/user-credits-detailed/${userId}`).pipe(
      map((response: any) => ({
        success: true,
        data: response.data || response || [],
        count: response.count || (response.data ? response.data.length : 0)
      })),
      catchError(error => {
        console.error('Erreur getUserCreditsDetailed:', error);
        return throwError(() => ({
          success: false,
          error: error.message || 'Erreur lors du chargement des credits detailles',
          data: [],
          count: 0
        }));
      })
    );
  }

  // ENDPOINTS UTILITAIRES
  checkFlaskHealth(): Observable<any> {
    return this.http.get(`${this.flaskUrl}/health`);
  }

  checkNestHealth(): Observable<any> {
    return this.http.get(`${this.nestUrl}/api/credit/health/check`);
  }

  testConnection(): Observable<any> {
    return this.http.get(`${this.flaskUrl}/test`);
  }
}