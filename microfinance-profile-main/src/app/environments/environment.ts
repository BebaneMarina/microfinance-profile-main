// environments/environment.ts - CORRIGÉ
export const environment = {
  production: false,
  
  // ✅ CORRECTION : Configuration API principale - Port 3000 pour NestJS
  apiUrl: 'http://localhost:3000',
  
  // ✅ CORRECTION : Configuration API crédit long - Port 3000 pour NestJS
  creditLongApiUrl: 'http://localhost:3000/credit-long',
  
  // Configuration Flask ML (optionnelle)
  flaskApiUrl: 'http://localhost:5000',
  mlApiUrl: 'http://localhost:5000/credit-simulation',
  
  // Timeouts en millisecondes
  apiTimeout: 10000,
  uploadTimeout: 30000,
  
  // Configuration du client
  maxRetries: 2,
  enableOfflineMode: true,
  enableLocalStorage: true,
  
  // Configuration des fonctionnalités
  features: {
    creditLong: true,
    realTimeScoring: true,
    documentUpload: true,
    notifications: true
  },
  
  // Configuration debug
  debug: true,
  logLevel: 'info',
  
  // Configuration de l'application
  appName: 'Microfinance Platform',
  version: '1.0.0'
};