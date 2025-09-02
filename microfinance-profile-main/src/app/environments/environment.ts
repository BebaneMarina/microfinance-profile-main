// environments/environment.ts
export const environment = {
  production: false,
  
  // Configuration API principale
  apiUrl: 'http://localhost:5000',
  
  // Configuration API crédit long
  creditLongApiUrl: 'http://localhost:5000/api/credit-long',
  
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

