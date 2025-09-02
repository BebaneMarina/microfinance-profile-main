// =======================
// NOTIFICATION.SERVICE.TS
// =======================

import { Injectable } from '@angular/core';
import { BehaviorSubject, Observable } from 'rxjs';

export interface Notification {
  id: string;
  type: 'success' | 'error' | 'warning' | 'info';
  message: string;
  duration?: number;
  timestamp: Date;
}

@Injectable({
  providedIn: 'root'
})
export class NotificationService {
  private notifications$ = new BehaviorSubject<Notification[]>([]);
  private defaultDuration = 5000; // 5 seconds

  constructor() {}

  getNotifications(): Observable<Notification[]> {
    return this.notifications$.asObservable();
  }

  showSuccess(message: string, duration?: number): void {
    this.addNotification('success', message, duration);
  }

  showError(message: string, duration?: number): void {
    this.addNotification('error', message, duration);
  }

  showWarning(message: string, duration?: number): void {
    this.addNotification('warning', message, duration);
  }

  showInfo(message: string, duration?: number): void {
    this.addNotification('info', message, duration);
  }

  private addNotification(type: Notification['type'], message: string, duration?: number): void {
    const notification: Notification = {
      id: this.generateId(),
      type,
      message,
      duration: duration || this.defaultDuration,
      timestamp: new Date()
    };

    const currentNotifications = this.notifications$.value;
    this.notifications$.next([...currentNotifications, notification]);

    // Auto-remove notification after duration
    if (notification.duration && notification.duration > 0) {
      setTimeout(() => {
        this.removeNotification(notification.id);
      }, notification.duration);
    }
  }

  removeNotification(id: string): void {
    const currentNotifications = this.notifications$.value;
    const filteredNotifications = currentNotifications.filter(n => n.id !== id);
    this.notifications$.next(filteredNotifications);
  }

  clearAll(): void {
    this.notifications$.next([]);
  }

  private generateId(): string {
    return Math.random().toString(36).substr(2, 9) + Date.now().toString(36);
  }
}