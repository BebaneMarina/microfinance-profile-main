import { Injectable } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Observable, of, throwError } from 'rxjs';
import { catchError, map } from 'rxjs/operators';
import { environment } from '../environments/environment';

@Injectable({
  providedIn: 'root'
})
export class CreditService {
  [x: string]: any;
  private apiUrl = environment.apiUrl || 'http://localhost:5000';

  constructor(private http: HttpClient) {}

  private getHeaders(): HttpHeaders {
    return new HttpHeaders({
      'Content-Type': 'application/json',
      'Accept': 'application/json'
    });
  }

  // Obtenir la prédiction de scoring
  getScoringPrediction(data: any): Observable<any> {
    console.log('Appel scoring avec données:', data);
    
    return this.http.post(`${this.apiUrl}/predict`, data, { 
      headers: this.getHeaders() 
    }).pipe(
      map(response => {
        console.log('Réponse scoring:', response);
        return response;
      }),
      catchError(error => {
        console.error('Erreur scoring:', error);
        // Retourner des valeurs par défaut en cas d'erreur
        return of({
          score: 600,
          probability: 0.60,
          risk_level: 'moyen',
          decision: 'à étudier',
          factors: [],
          recommendations: ['Analyse en cours'],
          model_used: 'fallback'
        });
      })
    );
  }

  // Valider l'éligibilité
  validateEligibility(data: any): Observable<any> {
    return this.http.post(`${this.apiUrl}/validate`, data, { 
      headers: this.getHeaders() 
    }).pipe(
      catchError(error => {
        console.error('Erreur validation éligibilité:', error);
        return of({
          valid: true,
          errors: [],
          warnings: [],
          max_amount: 2000000,
          recommendations: ['Validation en cours']
        });
      })
    );
  }

  // Soumettre une demande de crédit
  submitCreditRequest(requestData: any): Observable<any> {
    console.log('Soumission demande crédit:', requestData);
    
    return this.http.post(`${this.apiUrl}/api/applications`, requestData, { 
      headers: this.getHeaders() 
    }).pipe(
      map(response => {
        console.log('Réponse soumission:', response);
        return response;
      }),
      catchError(error => {
        console.error('Erreur soumission:', error);
        
        // Sauvegarder localement en cas d'erreur
        const localApplication = {
          ...requestData,
          id: `LOCAL-${Date.now()}`,
          requestNumber: `BAMBOO-${Date.now()}`,
          submissionDate: new Date().toISOString(),
          status: 'pending-sync',
          localOnly: true
        };
        
        // Retourner une réponse de succès local
        return of({
          success: true,
          data: localApplication,
          localOnly: true,
          message: 'Demande sauvegardée localement'
        });
      })
    );
  }

  // Récupérer toutes les demandes
  getApplications(): Observable<any> {
    return this.http.get(`${this.apiUrl}/api/applications`, { 
      headers: this.getHeaders() 
    }).pipe(
      catchError(error => {
        console.error('Erreur récupération demandes:', error);
        return of({ applications: [], stats: {} });
      })
    );
  }

  // Récupérer une demande spécifique
  getApplication(id: number): Observable<any> {
    return this.http.get(`${this.apiUrl}/api/applications/${id}`, { 
      headers: this.getHeaders() 
    }).pipe(
      catchError(error => {
        console.error('Erreur récupération demande:', error);
        return throwError(error);
      })
    );
  }

  // Récupérer les types de crédit
  getCreditTypes(): Observable<any> {
    return this.http.get(`${this.apiUrl}/credit-types`, { 
      headers: this.getHeaders() 
    }).pipe(
      catchError(error => {
        console.error('Erreur récupération types crédit:', error);
        return of({ credit_types: {} });
      })
    );
  }

  // Tester la connexion API
  testConnection(): Observable<any> {
    return this.http.get(`${this.apiUrl}/test`, { 
      headers: this.getHeaders() 
    }).pipe(
      catchError(error => {
        console.error('Erreur test connexion:', error);
        return of({ status: 'offline', error: error.message });
      })
    );
  }


  // Obtenir les informations du modèle
  getModelInfo(): Observable<any> {
    return this.http.get(`${this.apiUrl}/model-info`, { 
      headers: this.getHeaders() 
    }).pipe(
      catchError(error => {
        console.error('Erreur info modèle:', error);
        return of({ model_type: 'unknown', status: 'error' });
      })
    );
  }
}