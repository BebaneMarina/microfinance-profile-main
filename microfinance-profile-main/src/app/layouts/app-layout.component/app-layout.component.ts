import { Component, OnInit, OnDestroy } from '@angular/core';
import { Router, NavigationEnd } from '@angular/router';
import { Subscription } from 'rxjs';
import { filter } from 'rxjs/operators';

import { SidebarComponent } from '../../components/sidebar.component/sidebar.component';
import { HeaderComponent } from '../../components/header.component/header.component';
import { ClientProfil } from '../../models/client-profile.model';
import { RouterModule } from '@angular/router';

@Component({
  selector: 'app-app-layout',
  templateUrl: './app-layout.component.html',
  styleUrls: ['./app-layout.component.scss'],
  standalone: true,
  imports: [SidebarComponent, HeaderComponent, RouterModule]
})
export class LayoutComponent implements OnInit, OnDestroy {
  sidebarCollapsed = false;
  mobileMenuOpen = false;
  isMobile = false;
  currentPageTitle = 'Tableau de bord';
  client!: ClientProfil;
  navigationItems: any[] = [];

  config = {
    pageTitle: ''
  };

  private routerSubscription?: Subscription;

  constructor(private router: Router) {
    this.isMobile = window.innerWidth < 768;
    window.addEventListener('resize', () => {
      this.isMobile = window.innerWidth < 768;
    });
  }

  ngOnInit(): void {
    this.initClient();
    this.initNavigation();
    this.subscribeToRouterEvents();
  }

  ngOnDestroy(): void {
    this.routerSubscription?.unsubscribe();
    window.removeEventListener('resize', () => {});
  }

  private initClient(): void {
    // Charger le client depuis le localStorage s'il existe
    const savedClient = localStorage.getItem('currentClient');
    
    if (savedClient) {
      try {
        this.client = JSON.parse(savedClient);
      } catch (error) {
        console.error('Erreur lors du chargement du client sauvegardé:', error);
        this.setDefaultClient();
      }
    } else {
      this.setDefaultClient();
    }
  }

  private setDefaultClient(): void {
    this.client = {
      username: 'marina',
      clientId: 'BAMBOO-TB-2025',
      clientType: 'particulier',
      initiales: 'TB',
      name: 'BEBANE MOUKOUMBI MARINA',
      fullName: 'BEBANE MOUKOUMBI MARINA BRUNELLE',
      role: 'Client Bamboo',
      accountNumber: 'BAMBOO-ACC-2025-001',
      profileImage: 'assets/default-avatar.png',
      ProfileImage: 'assets/default-avatar.png', // Ajout pour compatibilité
      monthlyIncome: 750000,
      profession: 'Développeur',
      company: 'Tech Solutions CI',
      email: 'marina@email.com',
      phone: '0707123456',
      address: 'Quartier Louis, Libreville, Gabon',
      employmentStatus: 'cdi', // Ajout des champs manquants
      jobSeniority: 24, // 2 ans d'ancienneté par défaut
      birthDate: '1990-01-01', // Date de naissance par défaut
      monthlyCharges: 150000, // Charges mensuelles par défaut
      existingDebts: 0 // Dettes existantes par défaut
    };
    
    // Sauvegarder le client par défaut
    localStorage.setItem('currentClient', JSON.stringify(this.client));
  }

  private initNavigation(): void {
    this.navigationItems = [
      { id: 'profile', label: 'Mon Profil', icon: '👤', route: '/profile', isVisible: true },
      { id: 'transactions', label: 'Transactions', icon: '💸', route: '/transactions', isVisible: true },
      { id: 'credits', label: 'Mes Crédits', icon: '💰', route: '/credit-list', isVisible: true },
      { id: 'messages', label: 'Messages', icon: '📬', route: '/inbox', isVisible: true, badge: 1 }
    ];
  }

  private subscribeToRouterEvents(): void {
    this.routerSubscription = this.router.events
      .pipe(filter(event => event instanceof NavigationEnd))
      .subscribe(() => {
        this.updatePageTitle();
      });
  }

  private updatePageTitle(): void {
    const route = this.router.url;
    const routeTitles: { [key: string]: string } = {
      '/client/profile': 'Tableau de bord',
      '/client/app-credit-list': 'Mes crédits',
      '/client/monprofil': 'Mon profil',
      '/client/messages': 'Messages',
      '/client/parametre': 'Paramètres',
      '/client/help': 'Aide',
      '/client/credit-request': 'Nouvelle demande de crédit',
      '/client/app-requests-list': 'liste de demande',
      '/client/transactions': 'Transactions',
      '/client/payment-history': 'Historique des paiements',
      '/client/documents': 'Mes documents',
      '/client/credit-simulator': 'Simulateur de crédit'
    };

    this.currentPageTitle = routeTitles[route] || 'Tableau de bord';
  }

  toggleMobileMenu(): void {
    this.mobileMenuOpen = !this.mobileMenuOpen;
  }

  onTabChange(tabId: string): void {
    console.log('Onglet changé:', tabId);
  }

  onToggleSidebar(isCollapsed: boolean): void {
    this.sidebarCollapsed = isCollapsed;
  }

  openCreditForm(): void {
    this.router.navigate(['/client/credit-request']);
  }

  onProfileImageChange(imageUrl: string): void {
    if (this.client) {
      this.client.profileImage = imageUrl;
      this.client.ProfileImage = imageUrl;
      // Sauvegarder les changements
      localStorage.setItem('currentClient', JSON.stringify(this.client));
    }
  }

  onSearchChange(searchQuery: string): void {
    console.log('Recherche:', searchQuery);
    // Implémenter la logique de recherche ici
  }

  logout(): void {
    // Nettoyer les données de session
    localStorage.clear();
    sessionStorage.clear();
    this.router.navigate(['/login']);
  }

  // Additional helper methods for client data management
  updateClientProfile(updates: Partial<ClientProfil>): void {
    if (this.client) {
      this.client = { ...this.client, ...updates };
      // Sauvegarder les changements
      localStorage.setItem('currentClient', JSON.stringify(this.client));
    }
  }

  getClientDisplayName(): string {
    return this.client?.fullName || this.client?.name || 'Client';
  }

  formatClientIncome(): string {
    if (!this.client?.monthlyIncome) return '0 FCFA';
    return new Intl.NumberFormat('fr-FR', {
      style: 'currency',
      currency: 'XAF',
      minimumFractionDigits: 0
    }).format(this.client.monthlyIncome);
  }

  // Méthode pour vérifier l'éligibilité aux différents types de crédits
  checkCreditEligibility(): { [key: string]: boolean } {
    const eligibility: { [key: string]: boolean } = {
      consommation_generale: true,
      avance_salaire: true,
      depannage: true,
      investissement: false, // Non disponible pour les particuliers par défaut
      tontine: false,
      retraite: false,
      spot: true,
      facture: true,
      bonCommande: true
    };

    // Si c'est une entreprise, seul le crédit investissement est disponible
    if (this.client?.clientType === 'entreprise') {
      Object.keys(eligibility).forEach(key => {
        eligibility[key] = key === 'investissement';
      });
    } else {
      // Pour les particuliers, vérifier des conditions spécifiques
      
      // Vérifier si le client est retraité
      if (this.client?.profession?.toLowerCase().includes('retraité')) {
        eligibility['retraite'] = true;
      }
      
      // Vérifier si le client est membre d'une tontine
      const isTontineMember = localStorage.getItem('isTontineMember') === 'true';
      if (isTontineMember) {
        eligibility['tontine'] = true;
      }
    }

    return eligibility;
  }

  // Méthode pour obtenir le type de client
  getClientType(): 'particulier' | 'entreprise' {
    return (this.client?.clientType as 'particulier' | 'entreprise') || 'particulier';
  }

  // Méthode pour changer le type de client
  setClientType(type: 'particulier' | 'entreprise'): void {
    if (this.client) {
      this.client.clientType = type;
      this.updateClientProfile({ clientType: type });
    }
  }

  // Méthode pour obtenir le montant éligible maximum
  getMaxEligibleAmount(): number {
    if (this.client?.clientType === 'entreprise') {
      return 100000000; // 100M pour les entreprises
    }
    
    // Pour les particuliers, le max est 2M
    const maxParticulier = 2000000;
    
    // Si on a le salaire, on peut calculer un montant plus précis
    if (this.client?.monthlyIncome) {
      return Math.min(maxParticulier, this.client.monthlyIncome * 3); // Max 3 mois de salaire ou 2M
    }
    
    return maxParticulier;
  }
}