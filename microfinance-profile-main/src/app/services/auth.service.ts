// auth.service.ts - MISE À JOUR
import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { BehaviorSubject, Observable, of } from 'rxjs';
import { map, catchError, tap } from 'rxjs/operators';
import { environment } from '../environments/environment';

export interface User {
  [x: string]: any;
  birthDate: string;
  id: number;
  uuid?: string;
  name: string;
  fullName: string;
  email: string;
  phone: string;
  username: string;
  
  // Géographique
  address?: string;
  ville?: string;
  quartier?: string;
  province?: string;
  
  // Professionnel
  profession?: string;
  company?: string;
  employmentStatus?: string;
  jobSeniority?: number;
  monthlyIncome?: number;
  monthlyCharges?: number;
  existingDebts?: number;
  
  // Scoring
  creditScore: number;
  score850?: number;
  riskLevel: string;
  eligibleAmount: number;
  
  // Restrictions
  canApplyForCredit?: boolean;
  activeCreditCount?: number;
  maxCreditsAllowed?: number;
  totalActiveDebt?: number;
  debtRatio?: number;
  blockingReason?: string;
  
  // Stats
  totalCredits?: number;
  paidCredits?: number;
  lateCredits?: number;
  
  // Méta
  clientType?: string;
  profileImage?: string;
  accountCreated?: string;
  lastLogin?: string;
  
  // Détails
  recommendations?: string[];
  scoreDetails?: any;
}

export interface AuthResponse {
  success: boolean;
  message?: string;
  user?: User;
  token?: string;
}

@Injectable({
  providedIn: 'root'
})
export class AuthService {
  updateUserDebts(newTotalDebts: number) {
    throw new Error('Method not implemented.');
  }
  updateUserScore(score: any, eligible_amount: any, risk_level: any) {
    throw new Error('Method not implemented.');
  }
  private apiUrl = environment.apiUrl || 'http://localhost:3000';
  private currentUserSubject = new BehaviorSubject<User | null>(null);
  public currentUser$ = this.currentUserSubject.asObservable();

  constructor(private http: HttpClient) {
    this.loadStoredUser();
  }

  private loadStoredUser(): void {
    const storedUser = localStorage.getItem('currentUser');
    if (storedUser) {
      try {
        const user = JSON.parse(storedUser);
        this.currentUserSubject.next(user);
      } catch (e) {
        console.error('Erreur chargement utilisateur stocké:', e);
        localStorage.removeItem('currentUser');
      }
    }
  }

  login(credentials: { email: string; password: string }): Observable<AuthResponse> {
    return this.http.post<AuthResponse>(`${this.apiUrl}/auth/login`, credentials)
      .pipe(
        tap(response => {
          if (response.success && response.user) {
            this.currentUserSubject.next(response.user);
            localStorage.setItem('currentUser', JSON.stringify(response.user));
            
            if (response.token) {
              localStorage.setItem('authToken', response.token);
            }
          }
        }),
        catchError(error => {
          console.error('Erreur de connexion:', error);
          return of({
            success: false,
            message: error.error?.message || 'Erreur de connexion au serveur'
          });
        })
      );
  }

  register(userData: any): Observable<AuthResponse> {
    return this.http.post<AuthResponse>(`${this.apiUrl}/auth/register`, userData)
      .pipe(
        catchError(error => {
          console.error('Erreur d\'inscription:', error);
          return of({
            success: false,
            message: error.error?.message || 'Erreur lors de l\'inscription'
          });
        })
      );
  }

  logout(): void {
    this.currentUserSubject.next(null);
    localStorage.removeItem('currentUser');
    localStorage.removeItem('authToken');
    localStorage.removeItem('creditScore');
  }

  getCurrentUser(): User | null {
    return this.currentUserSubject.value;
  }

  isAuthenticated(): boolean {
    return this.currentUserSubject.value !== null;
  }

  getAuthToken(): string | null {
    return localStorage.getItem('authToken');
  }
}