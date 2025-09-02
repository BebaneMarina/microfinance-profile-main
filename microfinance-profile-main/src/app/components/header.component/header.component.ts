import { Component, EventEmitter, Output, Input } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterLink, Router } from '@angular/router'; // ✅ Ajout de Router
import { ClientProfil } from '../../models/client-profile.model';
import { trigger, state, style, transition, animate } from '@angular/animations';

interface Notification {
  id: number;
  message: string;
  temps: string;
  lue: boolean;
  type?: 'success' | 'warning' | 'info' | 'error';
}

@Component({
  selector: 'app-header',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  templateUrl: './header.component.html',
  styleUrls: ['./header.component.scss'],
  animations: [
    trigger('slideDown', [
      transition(':enter', [
        style({ opacity: 0, transform: 'translateY(-10px)' }),
        animate('200ms ease-out', style({ opacity: 1, transform: 'translateY(0)' }))
      ]),
      transition(':leave', [
        animate('150ms ease-in', style({ opacity: 0, transform: 'translateY(-10px)' }))
      ])
    ])
  ]
})
export class HeaderComponent {
  @Input() client: ClientProfil | null = null;
  @Input() titrePage: string = 'Tableau de bord';
  @Input() sidebarRepliee: boolean = false;
  @Input() afficherMenuMobile: boolean = true;
  @Input() masquerTexteProfil: boolean = false;

  @Output() mobileMenuToggle = new EventEmitter<void>();
  @Output() searchChange = new EventEmitter<string>();
  @Output() logoutClick = new EventEmitter<void>();

  requeteRecherche: string = '';
  afficherNotifications: boolean = false;
  afficherMenuUtilisateur: boolean = false;
  nombreNotifications: number = 3;

  notifications: Notification[] = [
    { 
      id: 1, 
      message: 'Votre demande de crédit a été approuvée', 
      temps: 'Il y a 2 min', 
      lue: false,
      type: 'success'
    },
    { 
      id: 2, 
      message: 'Rappel: Échéance de paiement dans 3 jours', 
      temps: 'Il y a 1 heure', 
      lue: false,
      type: 'warning'
    },
    { 
      id: 3, 
      message: 'Votre relevé mensuel est disponible', 
      temps: 'Il y a 3 heures', 
      lue: true,
      type: 'info'
    }
  ];

  // ✅ Injection du Router dans le constructeur
  constructor(private router: Router) {}

  basculerMenuMobile(): void {
    this.mobileMenuToggle.emit();
  }

  surRecherche(event: Event): void {
    const value = (event.target as HTMLInputElement).value;
    this.searchChange.emit(value);
  }

  effacerRecherche(): void {
    this.requeteRecherche = '';
    this.searchChange.emit('');
  }

  basculerNotifications(): void {
    this.afficherNotifications = !this.afficherNotifications;
    this.afficherMenuUtilisateur = false;
  }

  basculerMenuUtilisateur(): void {
    this.afficherMenuUtilisateur = !this.afficherMenuUtilisateur;
    this.afficherNotifications = false;
  }

  fermerTousLesMenus(): void {
    this.afficherNotifications = false;
    this.afficherMenuUtilisateur = false;
  }

  marquerToutesCommeLues(): void {
    this.notifications.forEach(notification => notification.lue = true);
    this.nombreNotifications = 0;
  }

  marquerCommeLue(notification: Notification): void {
    if (!notification.lue) {
      notification.lue = true;
      this.nombreNotifications = Math.max(0, this.nombreNotifications - 1);
    }
  }

  getNotificationIcon(notification: Notification): string {
    switch (notification.type) {
      case 'success': return 'check_circle';
      case 'warning': return 'warning';
      case 'error': return 'error';
      default: return 'info';
    }
  }

  getNotificationIconClass(notification: Notification): string {
    return `notification-icon-${notification.type || 'info'}`;
  }

  // ✅ Nouvelle méthode pour naviguer vers le profil
  naviguerVersProfil(): void {
    this.router.navigate(['/client/monprofil']);
    this.fermerTousLesMenus();
  }

  // ✅ Nouvelle méthode pour naviguer vers les paramètres
  naviguerVersParametres(): void {
    this.router.navigate(['/client/parametre']);
    this.fermerTousLesMenus();
  }

  // ✅ Nouvelle méthode pour naviguer vers les crédits
  naviguerVersCredits(): void {
    this.router.navigate(['/client/app-credit-list']);
    this.fermerTousLesMenus();
  }

  // ✅ Nouvelle méthode pour naviguer vers l'aide
  naviguerVersAide(): void {
    this.router.navigate(['/client/help']);
    this.fermerTousLesMenus();
  }

  deconnecter(): void {
    localStorage.clear(); // Nettoyer le localStorage
    this.logoutClick.emit();
    this.fermerTousLesMenus();
  }
}