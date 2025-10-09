// src/environments/environment.ts - VERSION CORRIGÉE COMPLÈTE

export const environment = {
  production: false,
  
  // ==========================================
  // CONFIGURATION NESTJS (Backend Principal)
  // ==========================================
  apiUrl: 'http://localhost:3000',
  nestUrl: 'http://localhost:3000',
  
  // ==========================================
  // CONFIGURATION FLASK (ML & Scoring)
  // ==========================================
  flaskUrl: 'http://localhost:5000',
  flaskApiUrl: 'http://localhost:5000',
  
  
  // ==========================================
  // TIMEOUTS
  // ==========================================
  apiTimeout: 10000,
  uploadTimeout: 30000,
  
  // ==========================================
  // CONFIGURATION CLIENT
  // ==========================================
  maxRetries: 2,
  enableOfflineMode: true,
  enableLocalStorage: true,
  
  // ==========================================
  // FONCTIONNALITÉS
  // ==========================================
  features: {
    creditLong: true,
    realTimeScoring: true,
    documentUpload: true,
    notifications: true,
    postgresqlIntegration: true
  },
  
  // ==========================================
  // DEBUG & LOGS
  // ==========================================
  debug: true,
  logLevel: 'info',
  
  // ==========================================
  // INFORMATIONS APPLICATION
  // ==========================================
  appName: 'Bamboo EMF - Microfinance Platform',
  version: '2.0.0'
};