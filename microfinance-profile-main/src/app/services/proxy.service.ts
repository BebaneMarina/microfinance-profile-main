import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

@Injectable({
  providedIn: 'root'
})
export class ApiProxyService {
  private nestUrl = 'http://localhost:3000';
  private flaskUrl = 'http://localhost:5000';

  constructor(private http: HttpClient) {}

  // Endpoints NestJS - Données & CRUD
  getUserCredits(username: string): Observable<any> {
    return this.http.get(`${this.nestUrl}/user-credits/${username}`);
  }

  createCredit(creditData: any): Observable<any> {
    return this.http.post(`${this.nestUrl}/user-credits`, creditData);
  }

  getRestrictions(username: string): Observable<any> {
    return this.http.get(`${this.nestUrl}/credit-restrictions/${username}`);
  }

  processPayment(paymentData: any): Observable<any> {
    return this.http.post(`${this.nestUrl}/process-payment`, paymentData);
  }

  // Endpoints Flask - ML & Scoring
  calculateScore(userData: any): Observable<any> {
    return this.http.post(`${this.flaskUrl}/client-scoring`, userData);
  }

  getRealtimeScore(userData: any): Observable<any> {
    return this.http.post(`${this.flaskUrl}/realtime-scoring`, userData);
  }

  getScoreTrend(username: string): Observable<any> {
    return this.http.get(`${this.flaskUrl}/score-trend/${username}`);
  }

  simulateTransaction(data: any): Observable<any> {
    return this.http.post(`${this.flaskUrl}/simulate-transaction`, data);
  }
}