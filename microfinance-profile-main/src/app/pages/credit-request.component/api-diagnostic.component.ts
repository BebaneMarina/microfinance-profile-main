// api-diagnostic.component.ts - Version corrigée avec les bonnes interfaces
import { Component, OnInit } from '@angular/core';
import { HttpClient, HttpErrorResponse } from '@angular/common/http';
import { CommonModule } from '@angular/common';
import { Observable, throwError, of, from } from 'rxjs';
import { catchError, map, timeout, mergeMap, toArray } from 'rxjs/operators';
import { environment } from '../../environments/environment';
import { CreditLongService, TestResult } from '../../services/credit-long.service'; // Import TestResult

interface DiagnosticResult {
  endpoint: string;
  status: 'success' | 'error' | 'testing';
  message: string;
  responseTime?: number;
  details?: any;
  solution?: string;
}

@Component({
  selector: 'app-api-diagnostic',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="diagnostic-container">
      <div class="diagnostic-header">
        <h2>🔧 Diagnostic API Crédit Long</h2>
        <p>Vérification de la connectivité et des endpoints</p>
        
        <div class="diagnostic-controls">
          <button 
            (click)="runFullDiagnostic()" 
            [disabled]="isRunning"
            class="btn btn-primary">
            {{ isRunning ? '🔄 Test en cours...' : '▶️ Lancer le diagnostic' }}
          </button>
          
          <button 
            (click)="runQuickTest()" 
            [disabled]="isRunning"
            class="btn btn-success">
            ⚡ Test rapide
          </button>
          
          <button 
            (click)="clearResults()" 
            class="btn btn-secondary">
            🗑️ Effacer
          </button>
          
          <button 
            (click)="exportResults()" 
            class="btn btn-info"
            [disabled]="results.length === 0">
            📋 Exporter
          </button>
        </div>
      </div>

      <div class="diagnostic-summary" *ngIf="results.length > 0">
        <div class="summary-card success" *ngIf="successCount > 0">
          <span class="count">{{ successCount }}</span>
          <span class="label">Succès</span>
        </div>
        
        <div class="summary-card error" *ngIf="errorCount > 0">
          <span class="count">{{ errorCount }}</span>
          <span class="label">Erreurs</span>
        </div>
        
        <div class="summary-card info">
          <span class="count">{{ averageResponseTime }}ms</span>
          <span class="label">Temps moyen</span>
        </div>
      </div>

      <div class="diagnostic-results">
        <div 
          *ngFor="let result of results" 
          class="result-item"
          [ngClass]="result.status">
          
          <div class="result-header">
            <div class="status-icon">
              <span *ngIf="result.status === 'success'">✅</span>
              <span *ngIf="result.status === 'error'">❌</span>
              <span *ngIf="result.status === 'testing'">🔄</span>
            </div>
            
            <div class="endpoint-info">
              <strong>{{ result.endpoint }}</strong>
              <span class="response-time" *ngIf="result.responseTime">
                {{ result.responseTime }}ms
              </span>
            </div>
          </div>
          
          <div class="result-message">{{ result.message }}</div>
          
          <div class="result-details" *ngIf="result.details">
            <pre>{{ formatDetails(result.details) }}</pre>
          </div>
          
          <div class="result-solution" *ngIf="result.solution">
            <strong>💡 Solution suggérée:</strong>
            <p>{{ result.solution }}</p>
          </div>
        </div>
      </div>

      <div class="diagnostic-help" *ngIf="results.length === 0">
        <div class="help-section">
          <h3>🎯 À quoi sert ce diagnostic ?</h3>
          <ul>
            <li>Vérifier que l'API backend est accessible</li>
            <li>Tester tous les endpoints crédit long</li>
            <li>Mesurer les temps de réponse</li>
            <li>Identifier les problèmes de configuration</li>
            <li>Proposer des solutions automatiques</li>
          </ul>
        </div>

        <div class="help-section">
          <h3>🔧 Configuration actuelle</h3>
          <div class="config-info">
            <div class="config-item">
              <strong>URL API:</strong> {{ currentApiUrl }}
            </div>
            <div class="config-item">
              <strong>Environnement:</strong> {{ environment.production ? 'Production' : 'Développement' }}
            </div>
            <div class="config-item">
              <strong>Service:</strong> CreditLongService
            </div>
            <div class="config-item">
              <strong>Mode hors ligne:</strong> {{ isOfflineModeEnabled ? 'Activé' : 'Désactivé' }}
            </div>
          </div>
        </div>
      </div>

      <div class="quick-fixes" *ngIf="errorCount > 0">
        <h3>🚀 Corrections rapides</h3>
        
        <div class="fix-item" *ngIf="hasConnectionError">
          <strong>Problème de connexion détecté</strong>
          <button (click)="tryAlternativeUrl()" class="btn btn-sm btn-warning">
            Essayer une URL alternative
          </button>
        </div>
        
        <div class="fix-item" *ngIf="hasTimeoutError">
          <strong>Timeouts détectés</strong>
          <button (click)="increaseTimeout()" class="btn btn-sm btn-warning">
            Augmenter le timeout
          </button>
        </div>
        
        <div class="fix-item" *ngIf="has404Error">
          <strong>Endpoints non trouvés (404)</strong>
          <button (click)="enableFallbackMode()" class="btn btn-sm btn-success">
            Activer le mode fallback
          </button>
        </div>
      </div>
    </div>
  `,
  styles: [`
    .diagnostic-container {
      max-width: 1200px;
      margin: 0 auto;
      padding: 20px;
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
    }

    .diagnostic-header {
      text-align: center;
      margin-bottom: 30px;
    }

    .diagnostic-header h2 {
      color: #333;
      margin-bottom: 10px;
    }

    .diagnostic-controls {
      display: flex;
      gap: 10px;
      justify-content: center;
      margin-top: 20px;
      flex-wrap: wrap;
    }

    .btn {
      padding: 10px 20px;
      border: none;
      border-radius: 5px;
      cursor: pointer;
      font-weight: 500;
      transition: all 0.3s ease;
    }

    .btn:disabled {
      opacity: 0.6;
      cursor: not-allowed;
    }

    .btn-primary {
      background: #007bff;
      color: white;
    }

    .btn-primary:hover:not(:disabled) {
      background: #0056b3;
    }

    .btn-success {
      background: #28a745;
      color: white;
    }

    .btn-success:hover:not(:disabled) {
      background: #218838;
    }

    .btn-secondary {
      background: #6c757d;
      color: white;
    }

    .btn-info {
      background: #17a2b8;
      color: white;
    }

    .btn-warning {
      background: #ffc107;
      color: #212529;
    }

    .btn-sm {
      padding: 5px 10px;
      font-size: 12px;
    }

    .diagnostic-summary {
      display: flex;
      gap: 20px;
      justify-content: center;
      margin-bottom: 30px;
      flex-wrap: wrap;
    }

    .summary-card {
      padding: 20px;
      border-radius: 10px;
      text-align: center;
      min-width: 120px;
    }

    .summary-card.success {
      background: #d4edda;
      border: 1px solid #c3e6cb;
      color: #155724;
    }

    .summary-card.error {
      background: #f8d7da;
      border: 1px solid #f5c6cb;
      color: #721c24;
    }

    .summary-card.info {
      background: #d1ecf1;
      border: 1px solid #bee5eb;
      color: #0c5460;
    }

    .summary-card .count {
      display: block;
      font-size: 24px;
      font-weight: bold;
      margin-bottom: 5px;
    }

    .summary-card .label {
      font-size: 14px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }

    .diagnostic-results {
      margin-bottom: 30px;
    }

    .result-item {
      border: 1px solid #e0e0e0;
      border-radius: 8px;
      padding: 15px;
      margin-bottom: 15px;
      transition: all 0.3s ease;
    }

    .result-item.success {
      border-left: 4px solid #28a745;
      background: #f8fff9;
    }

    .result-item.error {
      border-left: 4px solid #dc3545;
      background: #fff8f8;
    }

    .result-item.testing {
      border-left: 4px solid #ffc107;
      background: #fffcf5;
    }

    .result-header {
      display: flex;
      align-items: center;
      margin-bottom: 10px;
    }

    .status-icon {
      margin-right: 10px;
      font-size: 16px;
    }

    .endpoint-info {
      flex: 1;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }

    .response-time {
      background: #e9ecef;
      padding: 2px 8px;
      border-radius: 12px;
      font-size: 12px;
      color: #495057;
    }

    .result-message {
      margin-bottom: 10px;
      color: #555;
    }

    .result-details {
      background: #f8f9fa;
      padding: 10px;
      border-radius: 4px;
      margin-bottom: 10px;
    }

    .result-details pre {
      margin: 0;
      font-size: 12px;
      color: #666;
      white-space: pre-wrap;
      max-height: 200px;
      overflow-y: auto;
    }

    .result-solution {
      background: #e7f3ff;
      padding: 10px;
      border-radius: 4px;
      border-left: 3px solid #007bff;
    }

    .result-solution strong {
      color: #007bff;
    }

    .result-solution p {
      margin: 5px 0 0 0;
      color: #555;
    }

    .diagnostic-help {
      margin-bottom: 30px;
    }

    .help-section {
      background: #f8f9fa;
      padding: 20px;
      border-radius: 8px;
      margin-bottom: 20px;
    }

    .help-section h3 {
      color: #333;
      margin-bottom: 15px;
    }

    .help-section ul {
      margin: 0;
      padding-left: 20px;
    }

    .help-section li {
      margin-bottom: 5px;
      color: #555;
    }

    .config-info {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
      gap: 15px;
    }

    .config-item {
      background: white;
      padding: 15px;
      border-radius: 6px;
      border: 1px solid #e0e0e0;
    }

    .config-item strong {
      display: block;
      color: #333;
      margin-bottom: 5px;
    }

    .quick-fixes {
      background: #fff3cd;
      border: 1px solid #ffeaa7;
      border-radius: 8px;
      padding: 20px;
    }

    .quick-fixes h3 {
      color: #856404;
      margin-bottom: 15px;
    }

    .fix-item {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 10px 0;
      border-bottom: 1px solid #f0f0f0;
    }

    .fix-item:last-child {
      border-bottom: none;
    }

    .fix-item strong {
      color: #856404;
      flex: 1;
    }

    @keyframes pulse {
      0% { transform: scale(1); }
      50% { transform: scale(1.05); }
      100% { transform: scale(1); }
    }

    .result-item.testing {
      animation: pulse 2s infinite;
    }

    @media (max-width: 768px) {
      .diagnostic-controls {
        flex-direction: column;
        align-items: center;
      }
      
      .btn {
        width: 100%;
        max-width: 200px;
      }
      
      .diagnostic-summary {
        flex-direction: column;
        align-items: center;
      }
      
      .fix-item {
        flex-direction: column;
        align-items: flex-start;
        gap: 10px;
      }
    }
  `]
})
export class ApiDiagnosticComponent implements OnInit {
  results: DiagnosticResult[] = [];
  isRunning = false;
  currentApiUrl = environment.apiUrl || 'http://localhost:5000';
  environment = environment;

  // Endpoints à tester
  private endpoints = [
    { path: '/api/test', method: 'GET', description: 'Test API générale' },
    { path: '/api/credit-long/health', method: 'GET', description: 'Santé service crédit long' },
    { path: '/api/credit-long/test', method: 'GET', description: 'Test crédit long' },
    { path: '/api/credit-long/simulate', method: 'POST', description: 'Simulation crédit', 
      data: {
        requestedAmount: 1000000,
        duration: 12,
        clientProfile: { monthlyIncome: 500000, creditScore: 6 },
        financialDetails: { monthlyExpenses: 200000 }
      }
    },
    { path: '/api/credit-long/quick-simulate', method: 'POST', description: 'Simulation rapide',
      data: { amount: 1000000, duration: 12, username: 'test' }
    }
  ];

  constructor(
    private http: HttpClient,
    private creditLongService: CreditLongService
  ) {}

  ngOnInit(): void {
    // Test de connexion initial
    this.testBasicConnectivity();
  }

  async runFullDiagnostic(): Promise<void> {
    this.isRunning = true;
    this.results = [];

    console.log('🔧 Démarrage du diagnostic complet...');

    // Tests des endpoints
    for (const endpoint of this.endpoints) {
      await this.testEndpoint(endpoint);
      await this.delay(200);
    }

    // Tests du service
    await this.testServiceMethods();
    await this.testLocalStorage();
    await this.testCors();

    this.isRunning = false;
    console.log('✅ Diagnostic terminé');

    this.analyzeResults();
  }

  async runQuickTest(): Promise<void> {
    this.isRunning = true;
    this.results = [];

    console.log('⚡ Test rapide...');

    // Test rapide avec diagnostic intégré du service
    const result: DiagnosticResult = {
      endpoint: 'Service Diagnostic',
      status: 'testing',
      message: 'Test rapide du service...'
    };

    this.results.push(result);
    this.results = [...this.results];

    try {
      const startTime = Date.now();
      
      // Utiliser la nouvelle méthode du service
      const diagnosticResult = await this.creditLongService.runDiagnostic()
        .pipe(timeout(10000))
        .toPromise();

      const responseTime = Date.now() - startTime;

      if (diagnosticResult?.success) {
        result.status = 'success';
        result.message = diagnosticResult.message;
        result.responseTime = responseTime;
        result.details = {
          totalTests: diagnosticResult.tests.length,
          successfulTests: diagnosticResult.tests.filter(t => t.success).length,
          tests: diagnosticResult.tests
        };
      } else {
        result.status = 'error';
        result.message = diagnosticResult?.message || 'Test rapide échoué';
        result.responseTime = responseTime;
        result.details = diagnosticResult;
        result.solution = 'Vérifiez la connectivité API ou activez le mode fallback';
      }

    } catch (error: any) {
      result.status = 'error';
      result.message = `Erreur test rapide: ${error.message || 'Erreur inconnue'}`;
      result.solution = 'Le service est probablement en mode fallback';
      result.details = { error: error.message || 'Erreur inconnue' };
    }

    this.results = [...this.results];
    this.isRunning = false;
  }

  private async testEndpoint(endpoint: any): Promise<void> {
    const result: DiagnosticResult = {
      endpoint: `${endpoint.method} ${endpoint.path}`,
      status: 'testing',
      message: `Test de ${endpoint.description}...`
    };

    this.results.push(result);
    this.results = [...this.results];

    const startTime = Date.now();
    const url = `${this.currentApiUrl}${endpoint.path}`;

    try {
      let request$: Observable<any>;
      
      if (endpoint.method === 'GET') {
        request$ = this.http.get(url);
      } else if (endpoint.method === 'POST') {
        request$ = this.http.post(url, endpoint.data || {});
      } else {
        throw new Error(`Méthode non supportée: ${endpoint.method}`);
      }

      const response = await request$
        .pipe(
          timeout(8000),
          catchError((error: HttpErrorResponse) => {
            throw error;
          })
        )
        .toPromise();

      const responseTime = Date.now() - startTime;

      result.status = 'success';
      result.message = `✅ ${endpoint.description} fonctionne`;
      result.responseTime = responseTime;
      result.details = {
        status: 'OK',
        response: this.formatResponseForDisplay(response)
      };

    } catch (error: any) {
      const responseTime = Date.now() - startTime;
      
      result.status = 'error';
      result.responseTime = responseTime;
      
      if (error.status === 404) {
        result.message = `❌ Endpoint non trouvé (404)`;
        result.solution = `Vérifiez que le serveur backend est démarré et que l'endpoint ${endpoint.path} est configuré`;
      } else if (error.status === 0) {
        result.message = `❌ Impossible de se connecter au serveur`;
        result.solution = `Vérifiez que le serveur backend tourne sur ${this.currentApiUrl}`;
      } else if (error.name === 'TimeoutError') {
        result.message = `❌ Timeout (${responseTime}ms)`;
        result.solution = `Le serveur met trop de temps à répondre. Augmentez le timeout ou vérifiez les performances`;
      } else {
        result.message = `❌ Erreur: ${error.message || 'Erreur inconnue'}`;
        result.solution = `Vérifiez les logs du serveur pour plus de détails`;
      }

      result.details = {
        status: error.status || 'Network Error',
        message: error.message || 'Erreur inconnue',
        url: url,
        name: error.name
      };
    }

    this.results = [...this.results];
  }

  private async testServiceMethods(): Promise<void> {
    const result: DiagnosticResult = {
      endpoint: 'Service Connection Test',
      status: 'testing',
      message: 'Test de connectivité du service...'
    };

    this.results.push(result);

    try {
      const startTime = Date.now();
      
      const connectionTest: TestResult = await this.creditLongService.testConnection()
        .pipe(
          timeout(5000),
          catchError((error: any) => of({ 
            success: false, 
            error: error.message,
            message: 'Service en mode fallback'
          } as TestResult))
        )
        .toPromise() as TestResult; // Correction: cast explicite
      
      const responseTime = Date.now() - startTime;

      if (connectionTest?.success) {
        result.status = 'success';
        result.message = '✅ Service CreditLongService opérationnel';
        result.responseTime = responseTime;
        result.details = connectionTest.details || connectionTest;
      } else {
        result.status = 'error';
        result.message = '⚠️ Service en mode fallback';
        result.responseTime = responseTime;
        result.solution = 'Le service fonctionne en mode hors ligne avec des données simulées';
        result.details = connectionTest;
      }

    } catch (error: any) {
      result.status = 'error';
      result.message = `❌ Erreur service: ${error.message || 'Erreur inconnue'}`;
      result.solution = 'Problème avec le service CreditLongService';
      result.details = { error: error.message || 'Erreur inconnue' };
    }

    this.results = [...this.results];
  }

  private async testLocalStorage(): Promise<void> {
    const result: DiagnosticResult = {
      endpoint: 'Local Storage',
      status: 'testing',
      message: 'Test du stockage local...'
    };

    this.results.push(result);

    try {
      const testKey = 'diagnostic_test';
      const testValue = { test: true, timestamp: Date.now() };
      
      localStorage.setItem(testKey, JSON.stringify(testValue));
      const retrieved = JSON.parse(localStorage.getItem(testKey) || '{}');
      localStorage.removeItem(testKey);

      if (retrieved.test === true) {
        result.status = 'success';
        result.message = '✅ Stockage local fonctionnel';
        result.details = { available: true, testPassed: true };
      } else {
        throw new Error('Test de lecture/écriture échoué');
      }

    } catch (error: any) {
      result.status = 'error';
      result.message = `❌ Problème stockage local: ${error.message || 'Erreur inconnue'}`;
      result.solution = 'Le mode hors ligne ne fonctionnera pas correctement';
      result.details = { available: false, error: error.message || 'Erreur inconnue' };
    }

    this.results = [...this.results];
  }

  private async testCors(): Promise<void> {
    const result: DiagnosticResult = {
      endpoint: 'CORS Configuration',
      status: 'testing',
      message: 'Test de la configuration CORS...'
    };

    this.results.push(result);

    try {
      const response = await this.http.options(this.currentApiUrl, {
        observe: 'response'
      })
      .pipe(
        timeout(3000),
        catchError((error: HttpErrorResponse) => {
          throw error;
        })
      )
      .toPromise();

      result.status = 'success';
      result.message = '✅ Configuration CORS OK';
      result.details = {
        accessControlAllowOrigin: response?.headers.get('Access-Control-Allow-Origin'),
        accessControlAllowMethods: response?.headers.get('Access-Control-Allow-Methods'),
        accessControlAllowHeaders: response?.headers.get('Access-Control-Allow-Headers')
      };

    } catch (error: any) {
      if (error.status === 404) {
        result.status = 'success';
        result.message = '✅ CORS probablement configuré (pas d\'endpoint OPTIONS)';
        result.details = { note: 'Endpoint OPTIONS non implémenté, mais pas d\'erreur CORS détectée' };
      } else {
        result.status = 'error';
        result.message = `⚠️ Problème CORS potentiel: ${error.message || 'Erreur CORS'}`;
        result.solution = 'Vérifiez la configuration CORS du serveur backend';
        result.details = { error: error.message || 'Erreur CORS', status: error.status };
      }
    }

    this.results = [...this.results];
  }

  private testBasicConnectivity(): void {
    console.log('🔄 Test de connectivité de base...');
    
    this.creditLongService.testConnection()
      .pipe(
        timeout(3000),
        catchError((error: any) => of({ 
          success: false, 
          error: error.message,
          message: 'Connexion échouée'
        } as TestResult))
      )
      .subscribe({
        next: (response: TestResult) => { // Correction: typage explicite
          if (response.success) {
            console.log('✅ Connexion API établie');
          } else {
            console.warn('⚠️ API en mode fallback:', response.error);
          }
        },
        error: (error: any) => { // Correction: typage explicite
          console.error('❌ Problème de connectivité:', error);
        }
      });
  }

  private analyzeResults(): void {
    const errors = this.results.filter(r => r.status === 'error');
    
    if (errors.length > 0) {
      console.group('📊 Analyse des erreurs');
      errors.forEach(error => {
        console.error(`❌ ${error.endpoint}: ${error.message}`);
      });
      console.groupEnd();
    }

    const suggestions = this.generateSuggestions();
    if (suggestions.length > 0) {
      console.group('💡 Suggestions');
      suggestions.forEach(suggestion => {
        console.info(`💡 ${suggestion}`);
      });
      console.groupEnd();
    }
  }

  private generateSuggestions(): string[] {
    const suggestions: string[] = [];
    const errors = this.results.filter(r => r.status === 'error');

    if (errors.some(e => e.message.includes('404'))) {
      suggestions.push('Vérifiez que le serveur backend est démarré avec les bonnes routes');
    }

    if (errors.some(e => e.message.includes('se connecter'))) {
      suggestions.push('Vérifiez que le serveur tourne sur le bon port');
    }

    if (errors.some(e => e.message.includes('Timeout'))) {
      suggestions.push('Augmentez les timeouts ou optimisez les performances du serveur');
    }

    if (errors.length === this.endpoints.length) {
      suggestions.push('Aucun endpoint ne fonctionne - problème de connectivité global');
    }

    return suggestions;
  }

  private formatResponseForDisplay(response: any): string {
    if (typeof response === 'string') {
      return response.length > 500 ? response.substring(0, 500) + '...' : response;
    }
    
    try {
      const jsonStr = JSON.stringify(response, null, 2);
      return jsonStr.length > 1000 ? jsonStr.substring(0, 1000) + '\n...' : jsonStr;
    } catch (error) {
      return String(response);
    }
  }

  // Getters pour les statistiques
  get successCount(): number {
    return this.results.filter(r => r.status === 'success').length;
  }

  get errorCount(): number {
    return this.results.filter(r => r.status === 'error').length;
  }

  get averageResponseTime(): number {
    const timesWithResponse = this.results
      .filter(r => r.responseTime)
      .map(r => r.responseTime!);
    
    if (timesWithResponse.length === 0) return 0;
    
    return Math.round(timesWithResponse.reduce((a, b) => a + b, 0) / timesWithResponse.length);
  }

  get hasConnectionError(): boolean {
    return this.results.some(r => r.message.includes('se connecter'));
  }

  get hasTimeoutError(): boolean {
    return this.results.some(r => r.message.includes('Timeout'));
  }

  get has404Error(): boolean {
    return this.results.some(r => r.message.includes('404'));
  }

  get isOfflineModeEnabled(): boolean {
    return localStorage.getItem('force_fallback_mode') === 'true';
  }

  // Actions de correction
  clearResults(): void {
    this.results = [];
    console.log('🗑️ Résultats effacés');
  }

  exportResults(): void {
    const exportData = {
      timestamp: new Date().toISOString(),
      apiUrl: this.currentApiUrl,
      environment: environment.production ? 'production' : 'development',
      results: this.results,
      summary: {
        total: this.results.length,
        success: this.successCount,
        errors: this.errorCount,
        averageResponseTime: this.averageResponseTime
      },
      suggestions: this.generateSuggestions()
    };

    const dataStr = JSON.stringify(exportData, null, 2);
    const dataUri = 'data:application/json;charset=utf-8,'+ encodeURIComponent(dataStr);
    
    const exportFileDefaultName = `api-diagnostic-${Date.now()}.json`;
    
    const linkElement = document.createElement('a');
    linkElement.setAttribute('href', dataUri);
    linkElement.setAttribute('download', exportFileDefaultName);
    linkElement.click();

    console.log('📋 Résultats exportés:', exportFileDefaultName);
  }

  tryAlternativeUrl(): void {
    const alternatives = [
      'http://localhost:5000',
      'http://127.0.0.1:5000',
      'http://localhost:3000',
      'http://127.0.0.1:3000',
      'http://localhost:8000',
      'http://127.0.0.1:8000'
    ];

    const currentIndex = alternatives.indexOf(this.currentApiUrl);
    const nextIndex = (currentIndex + 1) % alternatives.length;
    
    this.currentApiUrl = alternatives[nextIndex];
    console.log(`🔄 Tentative avec URL alternative: ${this.currentApiUrl}`);
    
    // Relancer un test rapide
    this.testBasicConnectivity();
  }

  increaseTimeout(): void {
    console.log('⏱️ Augmentation des timeouts recommandée');
    const message = `Pour augmenter les timeouts:

1. Modifiez environment.ts:
   export const environment = {
     apiTimeout: 15000  // 15 secondes
   };

2. Dans les services, utilisez:
   .pipe(timeout(15000))

3. Redémarrez l'application

Timeout actuel détecté: ${this.averageResponseTime}ms`;

    alert(message);
  }

  enableFallbackMode(): void {
    console.log('🔧 Activation du mode fallback');
    localStorage.setItem('force_fallback_mode', 'true');
    
    const message = `Mode fallback activé !

L'application fonctionnera avec:
✅ Données simulées
✅ Sauvegarde locale uniquement  
✅ Interface complète

Actualisez la page pour appliquer les changements.`;

    alert(message);
  }

  formatDetails(details: any): string {
    if (typeof details === 'string') {
      return details;
    }
    try {
      return JSON.stringify(details, null, 2);
    } catch (error) {
      return String(details);
    }
  }

  private delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}