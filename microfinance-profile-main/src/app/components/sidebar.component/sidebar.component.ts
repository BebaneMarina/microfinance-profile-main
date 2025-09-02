import { Component, EventEmitter, Output, Input, OnInit, OnDestroy } from '@angular/core';
import { Router, NavigationEnd } from '@angular/router';
import { CommonModule } from '@angular/common';
import { RouterLink, RouterLinkActive } from '@angular/router';
import { Subscription } from 'rxjs';
import { filter } from 'rxjs/operators';
import { ClientProfil } from '../../models/client-profile.model';

export interface NavigationItem {
  id: string;
  label: string;
  icon: string;
  route?: string;
  action?: string;
  isActive?: boolean;
  isVisible?: boolean;
  badge?: number;
  submenu?: NavigationItem[];
}

@Component({
  selector: 'app-sidebar',
  standalone: true,
  imports: [CommonModule, RouterLink, RouterLinkActive],
  templateUrl: './sidebar.component.html',
  styleUrls: ['./sidebar.component.scss']
})
export class SidebarComponent implements OnInit, OnDestroy {
  @Input() client!: ClientProfil;
  @Input() isCollapsed: boolean = false;
  @Input() mobileMenuOpen: boolean = false;
  

  @Output() tabChange = new EventEmitter<string>();
  @Output() toggleSidebar = new EventEmitter<boolean>();
  @Output() creditFormOpen = new EventEmitter<void>();
  @Output() profileImageChange = new EventEmitter<string>();

  currentRoute = '';
  private routerSubscription?: Subscription;

  // ✅ Navigation items avec credit-request correctement configuré
  navigationItems: NavigationItem[] = [
    {
      id: 'dashboard',
      label: 'Tableau de bord',
      icon: 'dashboard',
      route: '/client/profile',
      isVisible: true
    },
    {
      id: 'credit-simulation',
      label: 'Simulateur de crédit',
      icon: 'calculate',
      route: '/client/credit-simulation',
      isVisible: true
    },
    {
      id: 'credit-request',
      label: 'Demande de crédit',
      icon: 'request_quote',
      route: '/client/credit-request',
      isVisible: true
    },
    {
      id: 'credit-list',
      label: 'Mes crédits',
      icon: 'account_balance_wallet',
      route: '/client/credit-list',
      isVisible: true
    },
    {
      id: 'profile',
      label: 'Mon profil',
      icon: 'person',
      route: '/client/monprofil',
      isVisible: true
    },
    {
      id: 'messages',
      label: 'Messages',
      icon: 'mail',
      route: '/client/messages',
      isVisible: true,
      badge: 3
    },
    {
      id: 'settings',
      label: 'Paramètres',
      icon: 'settings',
      route: '/client/parametre',
      isVisible: true
    },
    {
      id: 'help',
      label: 'Aide & Support',
      icon: 'help_outline',
      route: '/client/help',
      isVisible: true
    },
    {
      id: 'logout',
      label: 'Déconnexion',
      icon: 'logout',
      action: 'logout',
      isVisible: true
    }
  ];

  constructor(private router: Router) {}

  ngOnInit(): void {
    this.routerSubscription = this.router.events
      .pipe(filter(event => event instanceof NavigationEnd))
      .subscribe((event: any) => {
        this.currentRoute = event.url;
        this.updateActiveNavigation();
      });

    this.currentRoute = this.router.url;
    this.updateActiveNavigation();
  }

  ngOnDestroy(): void {
    this.routerSubscription?.unsubscribe();
  }

  private updateActiveNavigation(): void {
    this.navigationItems.forEach(item => {
      item.isActive = this.isRouteActive(item.route || '');
      item.submenu?.forEach(subItem => {
        subItem.isActive = this.isRouteActive(subItem.route || '');
      });
    });
  }

  isRouteActive(route: string): boolean {
    return route ? this.currentRoute === route || this.currentRoute.startsWith(route + '/') : false;
  }

  onNavigationClick(item: NavigationItem): void {
    if (item.route) {
      this.router.navigateByUrl(item.route);
    } else if (item.action) {
      this.handleAction(item.action);
    }
    this.tabChange.emit(item.id);
    
    // Fermer le menu mobile après navigation
    if (this.mobileMenuOpen) {
      this.closeMobileMenu();
    }
  }

  private handleAction(action: string): void {
    switch (action) {
      case 'logout':
        this.logout();
        break;
      case 'toggle-sidebar':
        this.toggleSidebarState();
        break;
      default:
        console.warn(`Action non gérée: ${action}`);
    }
  }

  openCreditForm(): void {
    this.creditFormOpen.emit();
    // ✅ Utilisation de la route correcte
    this.router.navigate(['/client/credit-request']);
  }

  toggleSidebarState(): void {
    this.isCollapsed = !this.isCollapsed;
    this.toggleSidebar.emit(this.isCollapsed);
  }

  logout(): void {
    // Confirmation avant déconnexion
    if (confirm('Êtes-vous sûr de vouloir vous déconnecter ?')) {
      localStorage.clear();
      this.router.navigate(['/login']);
    }
  }

  getVisibleNavigationItems(): NavigationItem[] {
    return this.navigationItems.filter(item => item.isVisible !== false);
  }

  triggerFileInput(): void {
    const fileInput = document.querySelector('input[type="file"]') as HTMLInputElement;
    fileInput?.click();
  }

  onFileSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    if (input.files && input.files.length > 0) {
      const file = input.files[0];
      if (!file.type.startsWith('image/')) {
        alert('Veuillez sélectionner un fichier image valide.');
        return;
      }
      if (file.size > 5 * 1024 * 1024) {
        alert("L'image dépasse la taille maximale de 5 Mo.");
        return;
      }

      const reader = new FileReader();
      reader.onload = () => {
        const result = reader.result as string;
        this.client.profileImage = result;
        // Sauvegarder dans le localStorage
        localStorage.setItem('profileImage', result);
        this.profileImageChange.emit(result);
      };
      reader.readAsDataURL(file);
    }
  }

  trackByNavigationId(index: number, item: NavigationItem): string {
    return item.id;
  }

  closeMobileMenu(): void {
    this.mobileMenuOpen = false;
  }
}