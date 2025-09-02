import { Injectable } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Observable, BehaviorSubject } from 'rxjs';
import { map, catchError } from 'rxjs/operators';
import { of } from 'rxjs';

export interface ScoringResult {
  score: number;
  eligibleAmount: number;
  riskLevel: string;
  decision: string;
  factors: Array<{
    name: string;
    value: number;
    impact: number;
  }>;
  recommendations: string[];
  modelUsed: string;
  lastCalculated: string;
}

export interface ClientFinancialData {
  username: string;
  age: number;
  monthly_income: number;
  other_income: number;
  monthly_charges: number;
  existing_debts: number;
  job_seniority: number;
  employment_status: string;
  loan_amount: number;
  loan_duration: number;
  credit_type: string;
  marital_status: string;
  education: string;
  dependents: number;
  repayment_frequency: string;
  profession: string;
  company: string;
  clientType: string;
}

@Injectable({
  providedIn: 'root'
})
export class ScoringAutoService {
  private apiUrl = 'http://localhost:5000';
  
  // BehaviorSubject pour stocker les résultats de scoring
  private scoringResultSubject = new BehaviorSubject<ScoringResult | null>(null);
  public scoringResult$ = this.scoringResultSubject.asObservable();
  
  private httpOptions = {
    headers: new HttpHeaders({
      'Content-Type': 'application/json',
      'Accept': 'application/json'
    })
  };

  constructor(private http: HttpClient) {}

  /**
   * Calcule automatiquement le score et la capacité de remboursement pour un client
   */
  calculateClientScoring(clientData: any): Observable<ScoringResult> {
    console.log('=== CALCUL AUTOMATIQUE DU SCORING ===');
    console.log('Client:', clientData.name || clientData.username);
    
    // Préparer les données financières pour l'API de scoring
    const financialData = this.prepareFinancialData(clientData);
    
    console.log('Données préparées pour le scoring:', financialData);
    
    // Appeler l'API pour calculer le score et le montant éligible
    return this.callScoringAPI(financialData).pipe(
      map(result => {
        const scoringResult: ScoringResult = {
          score: result.score || 600,
          eligibleAmount: result.eligible_amount || 500000,
          riskLevel: result.risk_level || 'moyen',
          decision: result.decision || 'à étudier',
          factors: result.factors || [],
          recommendations: result.recommendations || [],
          modelUsed: result.model_used || 'unknown',
          lastCalculated: new Date().toISOString()
        };
        
        // Sauvegarder dans localStorage pour persistance
        this.saveClientScoring(clientData.username, scoringResult);
        
        // Mettre à jour le BehaviorSubject
        this.scoringResultSubject.next(scoringResult);
        
        console.log('Scoring calculé:', scoringResult);
        return scoringResult;
      }),
      catchError(error => {
        console.error('Erreur lors du calcul du scoring:', error);
        
        // Retourner un scoring par défaut en cas d'erreur
        const defaultScoring: ScoringResult = {
          score: 600,
          eligibleAmount: Math.min(clientData.monthlyIncome || 500000, 2000000),
          riskLevel: 'moyen',
          decision: 'à étudier',
          factors: [
            { name: 'monthly_income', value: 70, impact: 20 },
            { name: 'employment_status', value: 65, impact: 15 }
          ],
          recommendations: ['Calcul en cours, veuillez patienter'],
          modelUsed: 'fallback',
          lastCalculated: new Date().toISOString()
        };
        
        this.scoringResultSubject.next(defaultScoring);
        return of(defaultScoring);
      })
    );
  }

  /**
   * Prépare les données du client pour l'API de scoring
   */
  private prepareFinancialData(clientData: any): ClientFinancialData {
    // Calculer l'âge approximatif (si pas fourni)
    const estimatedAge = this.estimateAge(clientData);
    
    // Estimer l'ancienneté (si pas fournie)
    const estimatedSeniority = this.estimateJobSeniority(clientData);
    
    // Estimer les charges mensuelles (30% du revenu par défaut)
    const estimatedCharges = (clientData.monthlyIncome || 0) * 0.3;
    
    return {
      username: clientData.username || '',
      age: estimatedAge,
      monthly_income: clientData.monthlyIncome || 0,
      other_income: 0, // À ajuster selon vos données
      monthly_charges: estimatedCharges,
      existing_debts: 0, // À ajuster selon vos données
      job_seniority: estimatedSeniority,
      employment_status: this.mapEmploymentStatus(clientData.profession),
      loan_amount: 1000000, // Montant type pour évaluation
      loan_duration: 1,
      credit_type: 'consommation_generale',
      marital_status: 'single', // À ajuster selon vos données
      education: 'superieur',
      dependents: 2,
      repayment_frequency: 'mensuel',
      profession: clientData.profession || '',
      company: clientData.company || '',
      clientType: clientData.clientType || 'particulier'
    };
  }

  /**
   * Estime l'âge du client (logique à adapter selon vos données)
   */
  private estimateAge(clientData: any): number {
    // Si vous avez la date de naissance, calculez l'âge
    // Sinon, estimation basée sur la profession ou autres critères
    const profession = (clientData.profession || '').toLowerCase();
    
    if (profession.includes('étudiant') || profession.includes('stagiaire')) {
      return 25;
    } else if (profession.includes('senior') || profession.includes('directeur')) {
      return 45;
    } else {
      return 35; // Âge par défaut
    }
  }

  /**
   * Estime l'ancienneté professionnelle
   */
  private estimateJobSeniority(clientData: any): number {
    const profession = (clientData.profession || '').toLowerCase();
    
    if (profession.includes('senior') || profession.includes('directeur')) {
      return 60; // 5 ans
    } else if (profession.includes('développeur') || profession.includes('ingénieur')) {
      return 36; // 3 ans
    } else {
      return 24; // 2 ans par défaut
    }
  }

  /**
   * Mappe la profession vers un statut d'emploi
   */
  private mapEmploymentStatus(profession: string): string {
    const prof = (profession || '').toLowerCase();
    
    if (prof.includes('développeur') || prof.includes('ingénieur') || 
        prof.includes('manager') || prof.includes('analyst')) {
      return 'cdi';
    } else if (prof.includes('consultant') || prof.includes('freelance') || 
               prof.includes('indépendant')) {
      return 'independant';
    } else if (prof.includes('contractuel') || prof.includes('temporaire')) {
      return 'cdd';
    } else {
      return 'cdi'; // Par défaut
    }
  }

  /**
   * Appelle l'API de scoring
   */
  private callScoringAPI(financialData: ClientFinancialData): Observable<any> {
    // Appeler l'endpoint de calcul du montant éligible qui calcule aussi le score
    return this.http.post(`${this.apiUrl}/eligible-amount`, financialData, this.httpOptions);
  }

  /**
   * Sauvegarde le scoring du client dans localStorage
   */
  private saveClientScoring(username: string, scoring: ScoringResult): void {
    try {
      const key = `clientScoring_${username}`;
      localStorage.setItem(key, JSON.stringify(scoring));
      
      // Sauvegarder aussi dans la clé générique pour compatibilité
      localStorage.setItem('clientEligibility', JSON.stringify({
        creditScore: scoring.score,
        eligibleAmount: scoring.eligibleAmount,
        riskLevel: scoring.riskLevel,
        lastCalculated: scoring.lastCalculated
      }));
      
      console.log(`Scoring sauvegardé pour ${username}:`, scoring);
    } catch (error) {
      console.error('Erreur lors de la sauvegarde du scoring:', error);
    }
  }

  /**
   * Récupère le scoring sauvegardé d'un client
   */
  getClientScoring(username: string): ScoringResult | null {
    try {
      const key = `clientScoring_${username}`;
      const saved = localStorage.getItem(key);
      
      if (saved) {
        const scoring = JSON.parse(saved);
        
        // Vérifier si le scoring n'est pas trop ancien (24h)
        const lastCalc = new Date(scoring.lastCalculated);
        const now = new Date();
        const diffHours = (now.getTime() - lastCalc.getTime()) / (1000 * 60 * 60);
        
        if (diffHours < 24) {
          this.scoringResultSubject.next(scoring);
          return scoring;
        }
      }
      
      return null;
    } catch (error) {
      console.error('Erreur lors de la récupération du scoring:', error);
      return null;
    }
  }

  /**
   * Force le recalcul du scoring pour un client
   */
  refreshClientScoring(clientData: any): Observable<ScoringResult> {
    console.log('Rafraîchissement du scoring pour:', clientData.name);
    
    // Supprimer l'ancien scoring
    const key = `clientScoring_${clientData.username}`;
    localStorage.removeItem(key);
    localStorage.removeItem('clientEligibility');
    
    // Recalculer
    return this.calculateClientScoring(clientData);
  }

  /**
   * Vérifie si l'API de scoring est disponible
   */
  checkScoringAPI(): Observable<boolean> {
    return this.http.get(`${this.apiUrl}/test`, this.httpOptions).pipe(
      map(() => true),
      catchError(() => of(false))
    );
  }

  /**
   * Calcule la capacité de remboursement mensuelle
   */
  calculateRepaymentCapacity(clientData: any, loanAmount: number, duration: number): number {
    const monthlyIncome = clientData.monthlyIncome || 0;
    const estimatedCharges = monthlyIncome * 0.3; // 30% des revenus en charges
    const availableIncome = monthlyIncome - estimatedCharges;
    
    // Capacité de remboursement = 40% du revenu disponible maximum
    const maxMonthlyPayment = availableIncome * 0.4;
    
    // Calculer le paiement mensuel requis
    const monthlyPayment = loanAmount / duration;
    
    return Math.min(maxMonthlyPayment, monthlyPayment);
  }

  /**
   * Émets un événement personnalisé quand le score est calculé
   */
  private emitScoreCalculatedEvent(scoring: ScoringResult): void {
    const event = new CustomEvent('scoreCalculated', {
      detail: scoring
    });
    window.dispatchEvent(event);
  }
}