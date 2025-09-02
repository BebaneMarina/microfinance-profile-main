import { Injectable } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Observable, of, BehaviorSubject } from 'rxjs';
import { map, catchError, switchMap } from 'rxjs/operators';
import { Router } from '@angular/router';
import { environment } from '../environments/environment';

export interface User {
  id?: number;
  username: string;
  email: string;
  firstName?: string;
  lastName?: string;
  name?: string;
  fullName?: string;
  phone?: string;
  address?: string;
  profession?: string;
  company?: string;
  monthlyIncome?: number;
  employmentStatus?: string;
  jobSeniority?: number;
  clientType?: string;
  role?: string;
  creditScore?: number;
  eligibleAmount?: number;
  riskLevel?: string;
  recommendations?: string[];
  scoreDetails?: any;
  profileImage?: string;
  monthlyCharges?: number;
  existingDebts?: number;
  birthDate?: string;
}

export interface AuthResponse {
  success: boolean;
  message?: string;  
  user?: User;
  token?: string;
  error?: string;
}

export interface LoginCredentials {
  email: string;
  password: string;
  username?: string;
  rememberMe?: boolean;
}

@Injectable({
  providedIn: 'root'
})
export class AuthService {
  private apiUrl = environment.apiUrl || 'http://localhost:5000';
  private currentUserSubject = new BehaviorSubject<User | null>(null);
  public currentUser$ = this.currentUserSubject.asObservable();

  // Données de démo - correspondant exactement aux données de la base
  private demoUsers: { [key: string]: User } = {
    'marina@email.com': {
      id: 1,
      username: 'marina_brunelle',
      email: 'marina@email.com',
      firstName: 'Marina',
      lastName: 'Brunelle',
      name: 'BEBANE MOUKOUMBI MARINA BRUNELLE',
      fullName: 'BEBANE MOUKOUMBI MARINA BRUNELLE',
      phone: '077123456',
      address: 'Quartier Louis, Libreville, Gabon',
      profession: 'Cadre',
      company: 'Société Exemple SA',
      monthlyIncome: 900000,
      employmentStatus: 'cdi',
      jobSeniority: 36,
      clientType: 'particulier',
      role: 'client',
      monthlyCharges: 270000, // 30% du salaire
      existingDebts: 0,
      birthDate: '1990-06-15'
    },
    'jean@exemple.com': {
      id: 2,
      username: 'jean_ndong',
      email: 'jean@exemple.com',
      firstName: 'Jean',
      lastName: 'Ndong',
      name: 'Jean Ndong',
      fullName: 'Jean Ndong',
      phone: '074567890',
      address: 'Quartier Batterie IV, Port-Gentil',
      profession: 'Technicien',
      company: 'Petro Services',
      monthlyIncome: 450000,
      employmentStatus: 'cdd',
      jobSeniority: 18,
      clientType: 'particulier',
      role: 'client',
      monthlyCharges: 135000,
      existingDebts: 0,
      birthDate: '1985-03-22'
    },
    'pierre@mail.com': {
      id: 4,
      username: 'pierre_moussavou',
      email: 'pierre@mail.com',
      firstName: 'Pierre',
      lastName: 'Moussavou',
      name: 'Pierre Moussavou',
      fullName: 'Pierre Moussavou',
      phone: '077234567',
      address: 'Quartier Sablière, Libreville',
      profession: 'Ingénieur',
      company: 'Total Energies',
      monthlyIncome: 1500000,
      employmentStatus: 'cdi',
      jobSeniority: 72,
      clientType: 'particulier',
      role: 'client',
      monthlyCharges: 450000,
      existingDebts: 0,
      birthDate: '1982-07-30'
    },
    'sophie@test.com': {
      id: 9,
      username: 'sophie_mfoubou',
      email: 'sophie@mail.com',
      firstName: 'sophie',
      lastName: 'Mfoubou',
      name: 'sophie Mfoubou',
      fullName: 'sophie Mfoubou',
      phone: '077234528',
      address: 'Quartier Sablière, Libreville',
      profession: 'commercante',
      company: 'marché local',
      monthlyIncome: 180000,
      employmentStatus: 'cdi',
      jobSeniority: 24,
      clientType: 'particulier',
      role: 'client',
      monthlyCharges: 80000,
      existingDebts: 0,
      birthDate: '1992-07-30'
    },
    'theobawana@bamboo.ci': {
      id: 0,
      username: 'theobawana',
      email: 'theobawana@bamboo.ci',
      firstName: 'Théo',
      lastName: 'Bawana',
      name: 'BEBANE MOUKOUMBI MARINA BRUNELLE',
      fullName: 'BEBANE MOUKOUMBI MARINA BRUNELLE',
      phone: '0707123456',
      address: 'Quartier Louis, Libreville, Gabon',
      profession: 'Développeur',
      company: 'Tech Solutions CI',
      monthlyIncome: 750000,
      employmentStatus: 'cdi',
      jobSeniority: 36,
      clientType: 'particulier',
      role: 'Développeur',
      monthlyCharges: 225000,
      existingDebts: 0,
      birthDate: '1995-01-01'
    }

  };
    updateUserDebts: any;
    updateUserScore: any;

  constructor(private http: HttpClient, private router: Router) {
    // Charger l'utilisateur depuis le localStorage au démarrage
    this.loadCurrentUser();
  }

  private loadCurrentUser(): void {
    try {
      const savedUser = localStorage.getItem('currentUser');
      if (savedUser) {
        const user = JSON.parse(savedUser);
        this.currentUserSubject.next(user);
      }
    } catch (error) {
      console.error('Erreur lors du chargement de l\'utilisateur:', error);
      localStorage.removeItem('currentUser');
    }
  }

  login(credentials: LoginCredentials): Observable<AuthResponse> {
    console.log('🔐 Tentative de connexion:', credentials.email);

    // Vérifier si c'est un utilisateur de démo
    const demoUser = this.demoUsers[credentials.email];
    
    if (demoUser) {
      console.log('👤 Utilisateur de démo trouvé:', demoUser.name);
      
      // Calculer le score automatiquement avec le backend
      return this.calculateUserScoreOnLogin(demoUser).pipe(
        map((scoringResult: any) => {
          // Combiner les données utilisateur avec le scoring
          const userWithScore: User = {
            ...demoUser,
            creditScore: scoringResult.score,
            eligibleAmount: scoringResult.eligible_amount,
            riskLevel: scoringResult.risk_level,
            recommendations: scoringResult.recommendations || [],
            scoreDetails: scoringResult
          };

          // Sauvegarder l'utilisateur
          this.setCurrentUser(userWithScore);
          
          console.log('✅ Connexion réussie avec score:', {
            user: userWithScore.name,
            score: userWithScore.creditScore,
            eligibleAmount: userWithScore.eligibleAmount
          });

          return {
            success: true,
            message: 'Connexion réussie',
            user: userWithScore
          };
        }),
        catchError((error) => {
          console.error('❌ Erreur lors du calcul du score:', error);
          
          // Connexion réussie mais sans score (fallback)
          const userWithDefaultScore: User = {
            ...demoUser,
            creditScore: 6.0,
            eligibleAmount: 500000,
            riskLevel: 'moyen',
            recommendations: ['Score calculé en mode dégradé']
          };

          this.setCurrentUser(userWithDefaultScore);

          return of({
            success: true,
            message: 'Connexion réussie (score par défaut)',
            user: userWithDefaultScore
          });
        })
      );
    }

    // Si ce n'est pas un utilisateur de démo, retourner une erreur
    console.log('❌ Utilisateur non trouvé');
    return of({
      success: false,
      message: 'Email ou mot de passe incorrect'
    });
  }

  private calculateUserScoreOnLogin(user: User): Observable<any> {
    const scoringData = {
      username: user.username,
      name: user.name,
      email: user.email,
      phone: user.phone,
      address: user.address,
      profession: user.profession,
      company: user.company,
      monthlyIncome: user.monthlyIncome,
      monthly_income: user.monthlyIncome,
      employmentStatus: user.employmentStatus,
      jobSeniority: user.jobSeniority,
      monthlyCharges: user.monthlyCharges,
      existingDebts: user.existingDebts,
      clientType: user.clientType
    };

    console.log('📊 Calcul du score pour:', scoringData.name);

    return this.http.post(`${this.apiUrl}/client-scoring`, scoringData).pipe(
      map((response: any) => {
        console.log('✅ Score calculé:', response);
        return response;
      }),
      catchError((error) => {
        console.error('❌ Erreur calcul score:', error);
        throw error;
      })
    );
  }

  private setCurrentUser(user: User): void {
    this.currentUserSubject.next(user);
    localStorage.setItem('currentUser', JSON.stringify(user));
    localStorage.setItem('currentClient', JSON.stringify(user));
    
    // Sauvegarder le score séparément
    if (user.creditScore !== undefined) {
      const scoreData = {
        score: user.creditScore,
        eligibleAmount: user.eligibleAmount || 0,
        riskLevel: user.riskLevel || 'moyen',
        recommendations: user.recommendations || [],
        scoreDetails: user.scoreDetails,
        lastUpdate: new Date().toISOString()
      };
      localStorage.setItem('userCreditScore', JSON.stringify(scoreData));
    }
  }

  getCurrentUser(): User | null {
    return this.currentUserSubject.value;
  }

  isAuthenticated(): boolean {
    return this.currentUserSubject.value !== null;
  }

  logout(): void {
    this.currentUserSubject.next(null);
    localStorage.removeItem('currentUser');
    localStorage.removeItem('currentClient');
    localStorage.removeItem('userCreditScore');
    localStorage.removeItem('profileImage');
    this.router.navigate(['/login']);
  }

  refreshUserScore(): Observable<any> {
    const currentUser = this.getCurrentUser();
    if (!currentUser) {
      return of(null);
    }

    return this.calculateUserScoreOnLogin(currentUser).pipe(
      map((scoringResult: any) => {
        const updatedUser: User = {
          ...currentUser,
          creditScore: scoringResult.score,
          eligibleAmount: scoringResult.eligible_amount,
          riskLevel: scoringResult.risk_level,
          recommendations: scoringResult.recommendations || [],
          scoreDetails: scoringResult
        };

        this.setCurrentUser(updatedUser);
        return scoringResult;
      })
    );
  }

  updateUserProfile(userData: Partial<User>): Observable<User> {
    const currentUser = this.getCurrentUser();
    if (!currentUser) {
      return of(currentUser as unknown as User);
    }

    const updatedUser: User = { ...currentUser, ...userData };
    this.setCurrentUser(updatedUser);
    
    return of(updatedUser);
  }
}