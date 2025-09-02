// realtime-scoring.service.ts
import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { BehaviorSubject, Observable, interval } from 'rxjs';
import { catchError, tap, switchMap } from 'rxjs/operators';

export interface TransactionData {
  userId: string;
  transactionType: 'payment' | 'late_payment' | 'missed_payment' | 'early_payment' | 
                   'new_loan' | 'loan_closure' | 'income_update' | 'employment_change';
  amount: number;
  scheduledDate: string;
  actualDate: string;
  loanId?: string;
  metadata?: any;
}

export interface ScoreUpdateResult {
  success: boolean;
  userId: string;
  previousScore: number;
  newScore: number;
  scoreChange: number;
  riskLevel: string;
  eligibleAmount: number;
  transactionImpact: any;
  behavioralInsights: any;
  updatedAt: string;
}

export interface UserScoreData {
  score: number;
  score850: number;
  riskLevel: string;
  eligibleAmount: number;
  lastUpdate: string;
  behavioralFactors: {
    punctualityScore: number;
    recentTransactionsCount: number;
    lastTransactionType: string;
    paymentConsistency: number;
    debtTrend: string;
  };
}

@Injectable({
  providedIn: 'root'
})
export class RealtimeScoringService {
  private apiUrl = 'http://localhost:5000';
  private currentScoreSubject = new BehaviorSubject<UserScoreData | null>(null);
  private scoreHistorySubject = new BehaviorSubject<any[]>([]);
  private isMonitoringSubject = new BehaviorSubject<boolean>(false);

  public currentScore$ = this.currentScoreSubject.asObservable();
  public scoreHistory$ = this.scoreHistorySubject.asObservable();
  public isMonitoring$ = this.isMonitoringSubject.asObservable();

  constructor(private http: HttpClient) {
    console.log('🚀 Service de scoring temps réel initialisé');
  }

}