import { Component, OnInit, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Subscription } from 'rxjs';
import { NotificationService, Notification } from '../../services/notification.service';
import { AuthService } from '../../services/auth.service';

@Component({
  selector: 'app-notifications',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="notifications-container">
      <!-- Badge nombre notifications -->
      <div class="notification-badge" (click)="togglePanel()">
        <i class="material-icons">notifications</i>
        <span class="badge-count" *ngIf="unreadCount > 0">{{ unreadCount }}</span>
      </div>

      <!-- Panel notifications -->
      <div class="notifications-panel" *ngIf="showPanel" [@slideDown]>
        <div class="panel-header">
          <h3>Notifications</h3>
          <button class="mark-all-read" (click)="markAllAsRead()" *ngIf="unreadCount > 0">
            <i class="material-icons">done_all</i>
            Tout marquer comme lu
          </button>
          <button class="close-btn" (click)="closePanel()">
            <i class="material-icons">close</i>
          </button>
        </div>

        <div class="panel-body">
          <!-- Liste notifications -->
          <div class="notifications-list" *ngIf="notifications.length > 0">
            <div 
              class="notification-item" 
              *ngFor="let notification of notifications"
              [class.unread]="!notification.lu"
              (click)="markAsRead(notification)">
              
              <div class="notification-icon" [style.background-color]="getNotificationColor(notification.type)">
                <i class="material-icons">{{ getNotificationIcon(notification.type) }}</i>
              </div>

              <div class="notification-content">
                <h4>{{ notification.titre }}</h4>
                <p>{{ notification.message }}</p>
                <span class="notification-time">{{ formatTime(notification.date_creation) }}</span>
              </div>

              <div class="notification-status" *ngIf="!notification.lu">
                <span class="unread-dot"></span>
              </div>
            </div>
          </div>

          <!-- Aucune notification -->
          <div class="no-notifications" *ngIf="notifications.length === 0">
            <i class="material-icons">notifications_none</i>
            <p>Aucune notification</p>
          </div>
        </div>

        <div class="panel-footer" *ngIf="notifications.length > 0">
          <button class="view-all-btn" (click)="viewAllNotifications()">
            Voir toutes les notifications
          </button>
        </div>
      </div>

      <!-- Overlay -->
      <div class="overlay" *ngIf="showPanel" (click)="closePanel()"></div>
    </div>
  `,
  styles: [`
    .notifications-container {
      position: relative;
    }

    .notification-badge {
      position: relative;
      width: 40px;
      height: 40px;
      border-radius: 50%;
      background: #f5f5f5;
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      transition: all 0.3s;
    }

    .notification-badge:hover {
      background: #e0e0e0;
      transform: scale(1.05);
    }

    .notification-badge i {
      color: #666;
      font-size: 24px;
    }

    .badge-count {
      position: absolute;
      top: -4px;
      right: -4px;
      background: #f44336;
      color: white;
      border-radius: 50%;
      min-width: 20px;
      height: 20px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 12px;
      font-weight: 600;
      padding: 0 6px;
      animation: pulse 2s infinite;
    }

    @keyframes pulse {
      0%, 100% { transform: scale(1); }
      50% { transform: scale(1.1); }
    }

    .notifications-panel {
      position: absolute;
      top: calc(100% + 10px);
      right: 0;
      width: 400px;
      max-height: 600px;
      background: white;
      border-radius: 12px;
      box-shadow: 0 8px 32px rgba(0,0,0,0.2);
      z-index: 1000;
      display: flex;
      flex-direction: column;
      animation: slideDown 0.3s ease-out;
    }

    @keyframes slideDown {
      from {
        opacity: 0;
        transform: translateY(-20px);
      }
      to {
        opacity: 1;
        transform: translateY(0);
      }
    }

    .panel-header {
      padding: 16px 20px;
      border-bottom: 1px solid #e0e0e0;
      display: flex;
      align-items: center;
      gap: 12px;
    }

    .panel-header h3 {
      flex: 1;
      margin: 0;
      font-size: 1.2rem;
      color: #333;
    }

    .mark-all-read {
      display: flex;
      align-items: center;
      gap: 6px;
      padding: 6px 12px;
      background: #f5f5f5;
      border: none;
      border-radius: 6px;
      font-size: 0.85rem;
      cursor: pointer;
      transition: all 0.3s;
    }

    .mark-all-read:hover {
      background: #e0e0e0;
    }

    .mark-all-read i {
      font-size: 18px;
    }

    .close-btn {
      background: transparent;
      border: none;
      cursor: pointer;
      padding: 4px;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: all 0.3s;
    }

    .close-btn:hover {
      background: #f5f5f5;
    }

    .close-btn i {
      color: #666;
      font-size: 24px;
    }

    .panel-body {
      flex: 1;
      overflow-y: auto;
      max-height: 500px;
    }

    .panel-body::-webkit-scrollbar {
      width: 6px;
    }

    .panel-body::-webkit-scrollbar-track {
      background: #f1f1f1;
    }

    .panel-body::-webkit-scrollbar-thumb {
      background: #888;
      border-radius: 3px;
    }

    .notifications-list {
      display: flex;
      flex-direction: column;
    }

    .notification-item {
      display: flex;
      gap: 12px;
      padding: 16px 20px;
      border-bottom: 1px solid #f0f0f0;
      cursor: pointer;
      transition: all 0.3s;
      position: relative;
    }

    .notification-item:hover {
      background: #f8f9fa;
    }

    .notification-item.unread {
      background: #f0f7ff;
    }

    .notification-icon {
      width: 40px;
      height: 40px;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      flex-shrink: 0;
    }

    .notification-icon i {
      color: white;
      font-size: 20px;
    }

    .notification-content {
      flex: 1;
      min-width: 0;
    }

    .notification-content h4 {
      margin: 0 0 6px 0;
      font-size: 0.95rem;
      color: #333;
      font-weight: 600;
    }

    .notification-content p {
      margin: 0 0 6px 0;
      font-size: 0.85rem;
      color: #666;
      line-height: 1.4;
      overflow: hidden;
      text-overflow: ellipsis;
      display: -webkit-box;
      -webkit-line-clamp: 2;
      -webkit-box-orient: vertical;
    }

    .notification-time {
      font-size: 0.75rem;
      color: #999;
    }

    .notification-status {
      display: flex;
      align-items: center;
      padding-left: 8px;
    }

    .unread-dot {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background: #2196F3;
    }

    .no-notifications {
      padding: 60px 20px;
      text-align: center;
      color: #999;
    }

    .no-notifications i {
      font-size: 64px;
      margin-bottom: 16px;
      opacity: 0.5;
    }

    .no-notifications p {
      margin: 0;
      font-size: 1rem;
    }

    .panel-footer {
      padding: 12px 20px;
      border-top: 1px solid #e0e0e0;
    }

    .view-all-btn {
      width: 100%;
      padding: 10px;
      background: #2196F3;
      color: white;
      border: none;
      border-radius: 6px;
      font-size: 0.95rem;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.3s;
    }

    .view-all-btn:hover {
      background: #1976D2;
    }

    .overlay {
      position: fixed;
      inset: 0;
      background: rgba(0,0,0,0.3);
      z-index: 999;
      animation: fadeIn 0.3s ease-out;
    }

    @keyframes fadeIn {
      from { opacity: 0; }
      to { opacity: 1; }
    }

    @media (max-width: 768px) {
      .notifications-panel {
        width: calc(100vw - 40px);
        right: -10px;
      }
    }
  `]
})
export class NotificationsComponent implements OnInit, OnDestroy {
  showPanel = false;
  notifications: Notification[] = [];
  unreadCount = 0;
  
  private notificationsSubscription?: Subscription;
  private unreadCountSubscription?: Subscription;
  private pollingSubscription?: Subscription;
  private currentUserId?: number;

  constructor(
    private notificationService: NotificationService,
    private authService: AuthService
  ) {}

  ngOnInit(): void {
    // Recuperer user ID
    this.authService.currentUser$.subscribe(user => {
      if (user && user.id) {
        this.currentUserId = user.id;
        this.loadNotifications();
        this.startPolling();
      }
    });

    // S'abonner aux notifications
    this.notificationsSubscription = this.notificationService.notifications$.subscribe(
      notifications => {
        this.notifications = notifications;
      }
    );

    // S'abonner au compteur
    this.unreadCountSubscription = this.notificationService.unreadCount$.subscribe(
      count => {
        this.unreadCount = count;
      }
    );
  }

  ngOnDestroy(): void {
    this.notificationsSubscription?.unsubscribe();
    this.unreadCountSubscription?.unsubscribe();
    this.pollingSubscription?.unsubscribe();
  }

  loadNotifications(): void {
    if (!this.currentUserId) return;
    
    this.notificationService.getUserNotifications(this.currentUserId, false, 20)
      .subscribe();
  }

  startPolling(): void {
    if (!this.currentUserId) return;
    
    // Polling toutes les 30 secondes
    this.pollingSubscription = this.notificationService
      .startPolling(this.currentUserId, 30000)
      .subscribe();
  }

  togglePanel(): void {
    this.showPanel = !this.showPanel;
  }

  closePanel(): void {
    this.showPanel = false;
  }

  markAsRead(notification: Notification): void {
    if (!notification.lu) {
      this.notificationService.markAsRead(notification.id).subscribe();
    }
  }

  markAllAsRead(): void {
    if (!this.currentUserId) return;
    
    this.notificationService.markAllAsRead(this.currentUserId).subscribe({
      next: () => {
        console.log('Toutes les notifications marquees comme lues');
      },
      error: (error) => {
        console.error('Erreur marquage notifications:', error);
      }
    });
  }

  viewAllNotifications(): void {
    // Naviguer vers page complete des notifications
    this.closePanel();
    // TODO: Implementer navigation
  }

  getNotificationIcon(type: string): string {
    return this.notificationService.getNotificationIcon(type);
  }

  getNotificationColor(type: string): string {
    return this.notificationService.getNotificationColor(type);
  }

  formatTime(dateString: string): string {
    return this.notificationService.formatRelativeTime(dateString);
  }
}