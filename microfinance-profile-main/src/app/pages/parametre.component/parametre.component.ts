import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';

interface NotificationSetting {
  id: string;
  label: string;
  description: string;
  enabled: boolean;
  channels: {
    email: boolean;
    sms: boolean;
    push: boolean;
  };
}

interface SecurityLog {
  action: string;
  device: string;
  location: string;
  date: Date;
  ip: string;
}

@Component({
  selector: 'parametre',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './parametre.component.html',
  styleUrls: ['./parametre.component.scss']
})
export class ParametreComponent implements OnInit {
  activeSection: string = 'notifications';
  isSaving: boolean = false;
  showSuccessMessage: boolean = false;

  // Notifications
  notifications: NotificationSetting[] = [
    {
      id: 'transactions',
      label: 'Transactions',
      description: 'Recevez des alertes pour toutes vos transactions',
      enabled: true,
      channels: { email: true, sms: true, push: true }
    },
    {
      id: 'credits',
      label: 'Crédits',
      description: 'Notifications sur vos demandes et échéances de crédit',
      enabled: true,
      channels: { email: true, sms: false, push: true }
    },
    {
      id: 'marketing',
      label: 'Offres et promotions',
      description: 'Soyez informé de nos nouvelles offres',
      enabled: false,
      channels: { email: false, sms: false, push: false }
    },
    {
      id: 'security',
      label: 'Alertes de sécurité',
      description: 'Connexions suspectes et changements de sécurité',
      enabled: true,
      channels: { email: true, sms: true, push: true }
    }
  ];

  // Security
  twoFactorEnabled: boolean = false;
  biometricEnabled: boolean = false;
  sessionTimeout: string = '30';
  securityLogs: SecurityLog[] = [
    {
      action: 'Connexion réussie',
      device: 'iPhone 13 Pro',
      location: 'Libreville, Gabon',
      date: new Date('2025-07-14T10:30:00'),
      ip: '41.158.100.50'
    },
    {
      action: 'Changement de mot de passe',
      device: 'Windows PC',
      location: 'Port-Gentil, Gabon',
      date: new Date('2025-07-13T15:45:00'),
      ip: '41.158.100.75'
    }
  ];

  // Preferences
  language: string = 'fr';
  currency: string = 'XAF';
  dateFormat: string = 'DD/MM/YYYY';
  theme: string = 'light';

  constructor(private router: Router) {}

  ngOnInit(): void {
    this.loadSettings();
  }

  loadSettings(): void {
    // Charger les paramètres depuis le service ou localStorage
    const savedSettings = localStorage.getItem('userSettings');
    if (savedSettings) {
      const settings = JSON.parse(savedSettings);
      // Appliquer les paramètres sauvegardés
    }
  }

  toggleNotification(notification: NotificationSetting): void {
    if (!notification.enabled) {
      // Si on désactive, on désactive tous les canaux
      notification.channels = { email: false, sms: false, push: false };
    }
  }

  toggleChannel(notification: NotificationSetting, channel: string): void {
    // Logique pour gérer les canaux
  }

  enable2FA(): void {
    // Logique pour activer 2FA
    this.router.navigate(['/client/security/2fa-setup']);
  }

  enableBiometric(): void {
    // Logique pour activer la biométrie
    console.log('Configuration biométrique...');
  }

  changePassword(): void {
    this.router.navigate(['/client/security/change-password']);
  }

  downloadData(): void {
    console.log('Téléchargement des données...');
    // Implémenter le téléchargement
  }

  deleteAccount(): void {
    if (confirm('Êtes-vous sûr de vouloir supprimer votre compte ? Cette action est irréversible.')) {
      console.log('Suppression du compte...');
      // Implémenter la suppression
    }
  }

  logout(): void {
    localStorage.clear();
    this.router.navigate(['/login']);
  }

  saveSettings(): void {
    this.isSaving = true;
    
    // Simuler la sauvegarde
    setTimeout(() => {
      // Sauvegarder les paramètres
      const settings = {
        notifications: this.notifications,
        security: {
          twoFactorEnabled: this.twoFactorEnabled,
          biometricEnabled: this.biometricEnabled,
          sessionTimeout: this.sessionTimeout
        },
        preferences: {
          language: this.language,
          currency: this.currency,
          dateFormat: this.dateFormat,
          theme: this.theme
        }
      };
      
      localStorage.setItem('userSettings', JSON.stringify(settings));
      
      this.isSaving = false;
      this.showSuccessMessage = true;
      
      setTimeout(() => {
        this.showSuccessMessage = false;
      }, 3000);
    }, 1000);
  }

  formatDate(date: Date): string {
    const options: Intl.DateTimeFormatOptions = {
      day: 'numeric',
      month: 'long',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    };
    return new Intl.DateTimeFormat('fr-FR', options).format(date);
  }
}