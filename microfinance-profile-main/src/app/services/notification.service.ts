import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, BehaviorSubject, interval } from 'rxjs';
import { switchMap, catchError, tap } from 'rxjs/operators';
import { environment } from '../environments/environment';

export interface Notification {
  id: number;
  type: string;
  titre: string;
  message: string;
  lu: boolean;
  date_creation: string;
  date_lecture?: string;
}

export interface NotificationsResponse {
  user_id: number;
  notifications: Notification[];
  total: number;
  unread_count: number;
}

@Injectable({
  providedIn: 'root'
})
export class NotificationService {
  private apiUrl = environment.nestUrl || 'http://localhost:3000';
  
  private notificationsSubject = new BehaviorSubject<Notification[]>([]);
  public notifications$ = this.notificationsSubject.asObservable();
  
  private unreadCountSubject = new BehaviorSubject<number>(0);
  public unreadCount$ = this.unreadCountSubject.asObservable();

  constructor(private http: HttpClient) {}

  // ==========================================
  // RECUPERATION NOTIFICATIONS
  // ==========================================

  getUserNotifications(userId: number, unreadOnly: boolean = false, limit: number = 20): Observable<any> {
    const params = {
      unread_only: unreadOnly.toString(),
      limit: limit.toString()
    };
    
    return this.http.get(`${this.apiUrl}/api/credit/notifications/${userId}`, { params }).pipe(
      tap((response: any) => {
        if (response.success && response.data) {
          this.notificationsSubject.next(response.data.notifications);
          this.unreadCountSubject.next(response.data.unread_count);
        }
      }),
      catchError(error => {
        console.error('Erreur recuperation notifications:', error);
        return [];
      })
    );
  }

  // ==========================================
  // MARQUAGE LECTURE
  // ==========================================

  markAsRead(notificationId: number): Observable<any> {
    return this.http.post(
      `${this.apiUrl}/api/credit/notifications/${notificationId}/mark-read`,
      {}
    ).pipe(
      tap(() => {
        const notifications = this.notificationsSubject.value;
        const updated = notifications.map(n => 
          n.id === notificationId ? { ...n, lu: true, date_lecture: new Date().toISOString() } : n
        );
        this.notificationsSubject.next(updated);
        
        const unreadCount = updated.filter(n => !n.lu).length;
        this.unreadCountSubject.next(unreadCount);
      })
    );
  }

  markAllAsRead(userId: number): Observable<any> {
    return this.http.post(
      `${this.apiUrl}/api/credit/notifications/${userId}/mark-all-read`,
      {}
    ).pipe(
      tap(() => {
        const notifications = this.notificationsSubject.value;
        const updated = notifications.map(n => ({ 
          ...n, 
          lu: true, 
          date_lecture: new Date().toISOString() 
        }));
        this.notificationsSubject.next(updated);
        this.unreadCountSubject.next(0);
      })
    );
  }

  // ==========================================
  // POLLING AUTOMATIQUE
  // ==========================================

  startPolling(userId: number, intervalMs: number = 30000) {
    return interval(intervalMs).pipe(
      switchMap(() => this.getUserNotifications(userId)),
      catchError(error => {
        console.error('Erreur polling notifications:', error);
        return [];
      })
    );
  }

  // ==========================================
  // UTILITAIRES
  // ==========================================

  getNotificationIcon(type: string): string {
    const icons: { [key: string]: string } = {
      'score_improvement': 'trending_up',
      'score_decline': 'trending_down',
      'payment_reminder': 'event',
      'credit_approved': 'check_circle',
      'credit_rejected': 'cancel',
      'payment_received': 'payment',
      'payment_late': 'warning',
      'eligibility_restored': 'verified'
    };
    
    return icons[type] || 'notifications';
  }

  getNotificationColor(type: string): string {
    const colors: { [key: string]: string } = {
      'score_improvement': '#4CAF50',
      'score_decline': '#f44336',
      'payment_reminder': '#FF9800',
      'credit_approved': '#4CAF50',
      'credit_rejected': '#f44336',
      'payment_received': '#2196F3',
      'payment_late': '#FF5722',
      'eligibility_restored': '#4CAF50'
    };
    
    return colors[type] || '#757575';
  }

  formatRelativeTime(dateString: string): string {
    const date = new Date(dateString);
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffMinutes = Math.floor(diffMs / (1000 * 60));
    
    if (diffMinutes < 1) return 'A l\'instant';
    if (diffMinutes < 60) return `Il y a ${diffMinutes} min`;
    
    const diffHours = Math.floor(diffMinutes / 60);
    if (diffHours < 24) return `Il y a ${diffHours}h`;
    
    const diffDays = Math.floor(diffHours / 24);
    if (diffDays === 1) return 'Hier';
    if (diffDays < 7) return `Il y a ${diffDays} jours`;
    
    return date.toLocaleDateString('fr-FR');
  }

  // ==========================================
  // GESTION LOCALE
  // ==========================================

  clearNotifications() {
    this.notificationsSubject.next([]);
    this.unreadCountSubject.next(0);
  }

  getCurrentNotifications(): Notification[] {
    return this.notificationsSubject.value;
  }

  getCurrentUnreadCount(): number {
    return this.unreadCountSubject.value;
  }
}