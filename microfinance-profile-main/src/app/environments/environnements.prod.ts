// environments/environment.prod.ts
export const environment = {
  production: true,
  
  // Configuration API production
  apiUrl: 'https://your-api-domain.com',
  creditLongApiUrl: 'https://your-api-domain.com/api/credit-long',
  
  // Timeouts pour production
  apiTimeout: 15000,
  uploadTimeout: 60000,
  
  // Configuration client production
  maxRetries: 3,
  enableOfflineMode: true,
  enableLocalStorage: true,
  
  // Fonctionnalités
  features: {
    creditLong: true,
    realTimeScoring: true,
    documentUpload: true,
    notifications: true
  },
  
  // Configuration production
  debug: false,
  logLevel: 'warn',
  
  // Informations application
  appName: 'Microfinance Platform',
  version: '1.0.0'
};