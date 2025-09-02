// =======================
// ANALYTICS.SERVICE.TS
// =======================

import { Injectable } from '@angular/core';
import { BehaviorSubject } from 'rxjs';

export interface AnalyticsEvent {
  name: string;
  parameters: Record<string, any>;
  timestamp: Date;
  sessionId: string;
  userId?: string;
}

export interface PageView {
  page: string;
  title: string;
  parameters?: Record<string, any>;
  timestamp: Date;
  sessionId: string;
  userId?: string;
}

@Injectable({
  providedIn: 'root'
})
export class AnalyticsService {
  private sessionId: string;
  private userId?: string;
  private events$ = new BehaviorSubject<AnalyticsEvent[]>([]);
  private pageViews$ = new BehaviorSubject<PageView[]>([]);

  constructor() {
    this.sessionId = this.generateSessionId();
    this.initializeAnalytics();
  }

  private initializeAnalytics(): void {
    // Initialize any third-party analytics here (Google Analytics, etc.)
    console.log('Analytics service initialized with session:', this.sessionId);
  }

  setUserId(userId: string): void {
    this.userId = userId;
  }

  trackEvent(eventName: string, parameters: Record<string, any> = {}): void {
    const event: AnalyticsEvent = {
      name: eventName,
      parameters: {
        ...parameters,
        user_agent: navigator.userAgent,
        url: window.location.href,
        referrer: document.referrer
      },
      timestamp: new Date(),
      sessionId: this.sessionId,
      userId: this.userId
    };

    // Add to local storage
    const currentEvents = this.events$.value;
    this.events$.next([...currentEvents, event]);

    // Send to analytics service (replace with your actual analytics endpoint)
    this.sendEventToAnalytics(event);

    console.log('Analytics Event:', event);
  }

  trackPageView(page: string, parameters: Record<string, any> = {}): void {
    const pageView: PageView = {
      page,
      title: document.title,
      parameters: {
        ...parameters,
        url: window.location.href,
        referrer: document.referrer,
        user_agent: navigator.userAgent
      },
      timestamp: new Date(),
      sessionId: this.sessionId,
      userId: this.userId
    };

    const currentPageViews = this.pageViews$.value;
    this.pageViews$.next([...currentPageViews, pageView]);

    // Send to analytics service
    this.sendPageViewToAnalytics(pageView);

    console.log('Analytics Page View:', pageView);
  }

  trackUserAction(action: string, category: string, label?: string, value?: number): void {
    this.trackEvent('user_action', {
      action,
      category,
      label,
      value
    });
  }

  trackError(error: Error, context?: Record<string, any>): void {
    this.trackEvent('error', {
      error_message: error.message,
      error_stack: error.stack,
      ...context
    });
  }

  trackTiming(category: string, variable: string, time: number, label?: string): void {
    this.trackEvent('timing', {
      category,
      variable,
      time,
      label
    });
  }

  // Méthodes pour obtenir les données analytiques
  getEvents() {
    return this.events$.asObservable();
  }

  getPageViews() {
    return this.pageViews$.asObservable();
  }

  getSessionId(): string {
    return this.sessionId;
  }

  getUserId(): string | undefined {
    return this.userId;
  }

  // Méthodes privées
  private sendEventToAnalytics(event: AnalyticsEvent): void {
    // Implement actual analytics sending logic here
    // Example: send to Google Analytics, Mixpanel, etc.
    
    // For development, we'll just log
    if (this.isProduction()) {
      // Example: gtag('event', event.name, event.parameters);
      // Example: mixpanel.track(event.name, event.parameters);
    }
  }

  private sendPageViewToAnalytics(pageView: PageView): void {
    // Implement actual page view tracking logic here
    
    if (this.isProduction()) {
      // Example: gtag('config', 'GA_MEASUREMENT_ID', { page_path: pageView.page });
    }
  }

  private isProduction(): boolean {
    return !!(window as any)['gtag'] || !!(window as any)['mixpanel'];
  }

  private generateSessionId(): string {
    return 'sess_' + Math.random().toString(36).substr(2, 9) + '_' + Date.now();
  }

  // Méthodes utilitaires pour les métriques business
  trackCreditSimulation(parameters: {
    amount: number;
    duration: number;
    creditType: string;
    clientType: string;
  }): void {
    this.trackEvent('credit_simulation', parameters);
  }

  trackBankSelection(bankId: string, bankName: string): void {
    this.trackEvent('bank_selected', {
      bank_id: bankId,
      bank_name: bankName
    });
  }

  trackFormValidationError(field: string, errorType: string): void {
    this.trackEvent('form_validation_error', {
      field,
      error_type: errorType
    });
  }

  trackLoanApplication(parameters: {
    bankId: string;
    amount: number;
    interestRate: number;
    duration: number;
  }): void {
    this.trackEvent('loan_application_submitted', parameters);
  }

  // Nettoyage des données anciennes
  clearOldData(daysToKeep: number = 30): void {
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - daysToKeep);

    const currentEvents = this.events$.value;
    const filteredEvents = currentEvents.filter(
      event => event.timestamp > cutoffDate
    );
    this.events$.next(filteredEvents);

    const currentPageViews = this.pageViews$.value;
    const filteredPageViews = currentPageViews.filter(
      pageView => pageView.timestamp > cutoffDate
    );
    this.pageViews$.next(filteredPageViews);
  }
}