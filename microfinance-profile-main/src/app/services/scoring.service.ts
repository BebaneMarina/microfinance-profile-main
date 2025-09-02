import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, of } from 'rxjs';
import { map, catchError } from 'rxjs/operators';
import { environment } from '../environments/environment';

@Injectable({
  providedIn: 'root'
})
export class ScoringService {
  private apiUrl = environment.apiUrl || 'http://localhost:5000';

  constructor(private http: HttpClient) {}

  calculateUserScore(client: any): Observable<any> {
    // S'assurer que toutes les données du client sont envoyées
    const scoringData = {
      username: client.username || 'theobawana',
      name: client.name || client.fullName,
      email: client.email,
      phone: client.phone,
      address: client.address,
      profession: client.profession,
      company: client.company,
      monthlyIncome: client.monthlyIncome || client.monthly_income,
      monthly_income: client.monthlyIncome || client.monthly_income,
      other_income: client.otherIncome || 0,
      monthlyCharges: client.monthlyCharges || 0,
      existingDebts: client.existingDebts || 0,
      employmentStatus: client.employmentStatus || 'cdi',
      jobSeniority: client.jobSeniority || 36,
      clientType: client.clientType || 'particulier',
      loan_amount: 1000000,  // Pour évaluation
      loan_duration: 1,
      credit_type: 'consommation_generale'
    };

    console.log('Données envoyées pour scoring:', scoringData);

    return this.http.post(`${this.apiUrl}/client-scoring`, scoringData).pipe(
      map((response: any) => {
        console.log('Réponse du scoring:', response);
        
        // Sauvegarder le score localement
        const scoreData = {
          score: response.score,
          eligibleAmount: response.eligible_amount,
          riskLevel: response.risk_level,
          recommendations: response.recommendations || [],
          scoreDetails: response,
          lastUpdate: new Date().toISOString()
        };
        
        localStorage.setItem('userCreditScore', JSON.stringify(scoreData));
        
        return response;
      }),
      catchError(error => {
        console.error('Erreur calcul score:', error);
        return of({
          score: 6.0,
          eligible_amount: 500000,
          risk_level: 'moyen',
          decision: 'à étudier',
          recommendations: ['Erreur lors du calcul du score']
        });
      })
    );
  }

  calculateEligibleAmount(clientData: any): Observable<any> {
    const data = {
      username: clientData.username || 'theobawana',
      name: clientData.name || clientData.fullName,
      email: clientData.email,
      phone: clientData.phone,
      profession: clientData.profession,
      company: clientData.company,
      monthlyIncome: clientData.monthlyIncome || clientData.monthly_income,
      monthly_income: clientData.monthlyIncome || clientData.monthly_income,
      other_income: clientData.otherIncome || 0,
      monthlyCharges: clientData.monthlyCharges || 0,
      existingDebts: clientData.existingDebts || 0,
      employmentStatus: clientData.employmentStatus || 'cdi',
      jobSeniority: clientData.jobSeniority || 36,
      clientType: clientData.clientType || 'particulier'
    };

    return this.http.post(`${this.apiUrl}/eligible-amount`, data).pipe(
      map((response: any) => {
        console.log('Montant éligible calculé:', response);
        return response;
      }),
      catchError(error => {
        console.error('Erreur calcul montant éligible:', error);
        const monthlyIncome = data.monthlyIncome || data.monthly_income || 500000;
        return of({
          eligible_amount: Math.min(monthlyIncome * 0.3333, 2000000),
          score: 6.0,
          risk_level: 'moyen',
          recommendations: ['Erreur lors du calcul']
        });
      })
    );
  }

  getCreditScore(username: string): Observable<any> {
    return this.http.get(`${this.apiUrl}/client-scoring/${username}`).pipe(
      catchError(error => {
        console.error('Erreur récupération score:', error);
        return of(null);
      })
    );
  }

  validateCreditRequest(requestData: any): Observable<any> {
    return this.http.post(`${this.apiUrl}/validate`, requestData).pipe(
      catchError(error => {
        console.error('Erreur validation:', error);
        return of({
          valid: true,
          errors: [],
          warnings: ['Validation en mode dégradé'],
          max_amount: 2000000,
          recommendations: []
        });
      })
    );
  }

  predictScore(data: any): Observable<any> {
    const scoringData = {
      ...data,
      username: data.username || 'unknown',
      monthly_income: data.monthly_income || data.monthlyIncome || 0,
      monthlyIncome: data.monthly_income || data.monthlyIncome || 0
    };

    return this.http.post(`${this.apiUrl}/predict`, scoringData).pipe(
      map((response: any) => {
        // S'assurer que le score est sur 10
        if (response.score > 10) {
          response.score = this.convertScoreTo10(response.score);
        }
        return response;
      }),
      catchError(error => {
        console.error('Erreur prédiction:', error);
        return of({
          score: 6.0,
          probability: 0.60,
          risk_level: 'moyen',
          decision: 'à étudier',
          factors: [],
          recommendations: ['Erreur lors de la prédiction']
        });
      })
    );
  }

  private convertScoreTo10(score850: number): number {
    // Conversion du score de 850 vers 10
    const score10 = ((score850 - 300) / 550) * 10;
    return Math.max(0, Math.min(10, Math.round(score10 * 10) / 10));
  }

  getCreditTypes(): Observable<any> {
    return this.http.get(`${this.apiUrl}/credit-types`).pipe(
      catchError(error => {
        console.error('Erreur récupération types de crédit:', error);
        return of({
          credit_types: {
            consommation_generale: {
              max_amount: 2000000,
              max_duration: 3,
              min_income: 200000,
              interest_rate: 0.05
            },
            avance_salaire: {
              max_amount: 2000000,
              max_duration: 1,
              min_income: 150000,
              interest_rate: 0.03
            },
            depannage: {
              max_amount: 1000000,
              max_duration: 1,
              min_income: 100000,
              interest_rate: 0.04
            }
          }
        });
      })
    );
  }

  getModelInfo(): Observable<any> {
    return this.http.get(`${this.apiUrl}/model-info`).pipe(
      catchError(error => {
        console.error('Erreur info modèle:', error);
        return of({
          model_type: 'Unknown',
          status: 'error'
        });
      })
    );
  }

  getStatistics(): Observable<any> {
    return this.http.get(`${this.apiUrl}/statistics`).pipe(
      catchError(error => {
        console.error('Erreur statistiques:', error);
        return of({
          applications: { total: 0, approved: 0, pending: 0, rejected: 0 },
          scoring: { total_clients: 0, average_score: 0 }
        });
      })
    );
  }

  retrainModel(): Observable<any> {
    return this.http.post(`${this.apiUrl}/retrain`, {}).pipe(
      catchError(error => {
        console.error('Erreur réentraînement:', error);
        return of({
          success: false,
          error: 'Erreur lors du réentraînement'
        });
      })
    );
  }
}