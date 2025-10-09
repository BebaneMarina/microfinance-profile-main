// =======================
// LOGIN.COMPONENT.TS - NAVIGATION MISE À JOUR AVEC SIMULATOR-HOME
// =======================

import { Component, OnInit, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ReactiveFormsModule, FormBuilder, FormGroup, Validators } from '@angular/forms';
import { Router, RouterModule } from '@angular/router';
import { AuthService, AuthResponse } from '../../services/auth.service';
import { StorageService } from '../../services/storage.service';
import { Subscription } from 'rxjs';

type DemoCredentialType = 'theobawana' | 'admin' | 'agent' | 'client';
type BankType = 'bgfi' | 'ugb' | 'bicig' | 'ecobank' | 'orabank' | 'uba' | 'bamboo';

interface DemoCredentials {
  [key: string]: { email: string; password: string; role: string };
}

interface BankInfo {
  id: string;
  name: string;
  shortName: string;
  logo: string;
  color: string;
  description: string;
  marketShare: string;
  processingTime: string;
  specialties: string[];
  advantage: string;
}

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule, RouterModule],
  templateUrl: './login.component.html',
  styleUrls: ['./login.component.scss']
})
export class LoginComponent implements OnInit, OnDestroy {
  public currentDate = new Date().toLocaleString('fr-FR');
  public currentUser = 'Système de Scoring Crédit Multi-Banques';

  loginForm!: FormGroup;
  isLoading = false;
  showPassword = false;
  showError = false;
  errorMessage = '';
  showBankSelection = false;
  showComparatorInfo = false;

  private readonly demoCredentials: DemoCredentials = {
    theobawana: { 
      email: 'theobawana@bamboo.ci', 
      password: 'theo123',
      role: 'Développeur Principal'
    },
    admin: { 
      email: 'admin@bamboo.ci', 
      password: 'admin123',
      role: 'Administrateur Système'
    },
    agent: { 
      email: 'agent@bamboo.ci', 
      password: 'agent123',
      role: 'Agent de Crédit'
    },
    client: { 
      email: 'client@exemple.com', 
      password: 'client123',
      role: 'Client Particulier'
    }
  };

  // Données réelles des banques gabonaises
  private readonly gabonBanks: Record<BankType, BankInfo> = {
    bgfi: {
      id: 'bgfi',
      name: 'BGFIBank Gabon',
      shortName: 'BGFI',
      logo: 'assets/banks/bgfi-logo.png',
      color: '#1B5E20',
      description: 'Leader du marché gabonais',
      marketShare: '50,6% des crédits',
      processingTime: '48h',
      specialties: ['Corporate Banking', 'Grandes entreprises', 'Particuliers haut de gamme'],
      advantage: 'Taux préférentiels grands comptes'
    },
    ugb: {
      id: 'ugb',
      name: 'Union Gabonaise de Banque',
      shortName: 'UGB',
      logo: 'assets/banks/ugb-logo.png',
      color: '#2E7D32',
      description: 'Premier réseau bancaire',
      marketShare: '36% des comptes',
      processingTime: '72h',
      specialties: ['Particuliers standards', 'PME', 'Services digitaux'],
      advantage: 'Plus grand réseau d\'agences'
    },
    bicig: {
      id: 'bicig',
      name: 'BICIG',
      shortName: 'BICIG',
      logo: 'assets/banks/bicig-logo.png',
      color: '#388E3C',
      description: 'Banque des fonctionnaires',
      marketShare: '28% des comptes',
      processingTime: '96h',
      specialties: ['Fonctionnaires', 'Secteur public', 'Crédit habitat'],
      advantage: 'Conditions préférentielles fonctionnaires'
    },
    ecobank: {
      id: 'ecobank',
      name: 'Ecobank Gabon',
      shortName: 'Ecobank',
      logo: 'assets/banks/ecobank-logo.png',
      color: '#43A047',
      description: 'Réseau panafricain',
      marketShare: '4,8% des crédits',
      processingTime: '120h',
      specialties: ['PME', 'Commerce international', 'Mobile Money'],
      advantage: 'Expertise commerce international'
    },
    orabank: {
      id: 'orabank',
      name: 'Orabank Gabon',
      shortName: 'Orabank',
      logo: 'assets/banks/orabank-logo.png',
      color: '#4CAF50',
      description: 'Innovation & inclusion',
      marketShare: '9,7% des crédits',
      processingTime: '48h',
      specialties: ['Innovation digitale', 'Microfinance', 'Inclusion financière'],
      advantage: 'Processus 100% digital'
    },
    uba: {
      id: 'uba',
      name: 'United Bank for Africa',
      shortName: 'UBA',
      logo: 'assets/banks/uba-logo.png',
      color: '#66BB6A',
      description: 'Expertise nigériane',
      marketShare: '1,1% des crédits',
      processingTime: '72h',
      specialties: ['TPE', 'Startups', 'Commerce'],
      advantage: 'Spécialiste entrepreneurs'
    },
    bamboo: {
      id: 'bamboo',
      name: 'Bamboo Credit',
      shortName: 'Bamboo',
      logo: 'assets/banks/bamboo-logo.png',
      color: '#1B5E20',
      description: 'Fintech & Scoring IA',
      marketShare: 'Leader fintech',
      processingTime: '24h',
      specialties: ['Scoring IA', 'Simulation instantanée', 'Microfinance digitale'],
      advantage: 'Décision automatique en 24h'
    }
  };

  constructor(
    private formBuilder: FormBuilder,
    private router: Router,
    private authService: AuthService,
    private storageService: StorageService
  ) {}

  ngOnInit(): void {
    this.initForm();
    this.loadDemoCredentials();
  }

  private initForm(): void {
    this.loginForm = this.formBuilder.group({
      email: ['', [Validators.required, Validators.email]],
      password: ['', [Validators.required, Validators.minLength(6)]],
      rememberMe: [false]
    });
  }

  private loadDemoCredentials(): void {
    if (window.location.hostname === 'localhost') {
      setTimeout(() => {
        this.fillDemoCredentials('theobawana');
      }, 500);
    }
  }

  fillDemoCredentials(type: DemoCredentialType): void {
    const credentials = this.demoCredentials[type];
    if (credentials) {
      this.loginForm.patchValue({
        email: credentials.email,
        password: credentials.password
      });
    }
  }

  public togglePasswordVisibility(): void {
    this.showPassword = !this.showPassword;
  }

  public toggleBankSelection(): void {
    this.showBankSelection = !this.showBankSelection;
  }

  public toggleComparatorInfo(): void {
    this.showComparatorInfo = !this.showComparatorInfo;
  }

  // ========================================
  // MÉTHODES DE NAVIGATION MISES À JOUR
  // ========================================

  // Navigation vers la page d'accueil des simulateurs
  public navigateToSimulatorHome(): void {
    this.router.navigate(['/simulateur-home']);
  }

  // Navigation vers le simulateur principal (hub)
  public navigateToSimulator(): void {
    this.router.navigate(['/simulateur']);
  }

  // Navigation vers le calculateur de mensualités
  public navigateToPaymentCalculator(): void {
    this.router.navigate(['/calculateur-mensualites']);
  }

  // Navigation vers le calculateur de capacité d'emprunt
  public navigateToBorrowingCapacity(): void {
    this.router.navigate(['/capacite-emprunt']);
  }

  // Navigation vers le comparateur multi-banques
  public navigateToComparator(): void {
    this.router.navigate(['/comparateur']);
  }

  // Navigation vers le comparateur public
  public navigateToPublicComparator(): void {
    this.router.navigate(['/comparateur-public']);
  }

  // Navigation vers le simulateur d'une banque spécifique
  public navigateToBankSimulator(bank: BankType): void {
    this.storageService.setSelectedBank(this.gabonBanks[bank]);
    this.router.navigate(['/banques', bank, 'simulateur']);
  }

  // Navigation vers la simulation publique (sans connexion)
  public navigateToPublicSimulator(): void {
    this.router.navigate(['/simulateur'], { 
      queryParams: { mode: 'public' } 
    });
  }

  // Navigation vers la page d'inscription
  public navigateToRegister(): void {
    this.router.navigate(['/inscription']);
  }

  // Navigation avec mode demo
  public startDemoMode(): void {
    this.storageService.setDemoMode(true);
    this.router.navigate(['/simulateur-home'], { 
      queryParams: { demo: true } 
    });
  }

  // Navigation vers page d'aide
  public navigateToHelp(): void {
    this.router.navigate(['/aide']);
  }

  // Navigation vers la documentation
  public navigateToDocumentation(): void {
    this.router.navigate(['/documentation']);
  }

  // Navigation vers la page de contact
  public navigateToContact(): void {
    this.router.navigate(['/contact']);
  }

  // Démarrer une simulation rapide avec paramètres prédéfinis
  public startQuickSimulation(creditType: string): void {
    const params = {
      type: creditType,
      quick: 'true'
    };

    switch (creditType) {
      case 'immobilier':
        this.router.navigate(['/simulateur-home'], { queryParams: { ...params, preset: 'immobilier' } });
        break;
      case 'consommation':
        this.router.navigate(['/calculateur-mensualites'], { queryParams: { ...params, preset: 'consommation' } });
        break;
      case 'auto':
        this.router.navigate(['/simulateur-home'], { queryParams: { ...params, preset: 'automobile' } });
        break;
      case 'professionnel':
        this.router.navigate(['/comparateur'], { queryParams: { ...params, preset: 'professionnel' } });
        break;
      default:
        this.navigateToSimulatorHome();
    }
  }

  // Navigation selon le profil utilisateur
  public navigateByProfile(profile: string): void {
    switch (profile) {
      case 'particulier':
        this.router.navigate(['/simulateur-home'], { queryParams: { profile: 'particulier' } });
        break;
      case 'professionnel':
        this.router.navigate(['/comparateur'], { queryParams: { profile: 'professionnel' } });
        break;
      case 'entreprise':
        this.router.navigate(['/comparateur'], { queryParams: { profile: 'entreprise' } });
        break;
      case 'fonctionnaire':
        this.navigateToBankSimulator('bicig'); // BICIG spécialisée pour les fonctionnaires
        break;
      default:
        this.navigateToSimulatorHome();
    }
  }

  // Méthodes utilitaires pour les données bancaires
  public getGabonBanks(): BankInfo[] {
    return Object.values(this.gabonBanks);
  }

  public getBankKeys(): BankType[] {
    return Object.keys(this.gabonBanks) as BankType[];
  }

  public getBankInfo(bank: BankType): BankInfo {
    return this.gabonBanks[bank];
  }

  hasError(controlName: string, errorType: string): boolean {
    const control = this.loginForm.get(controlName);
    return control?.errors?.[errorType] && control?.touched || false;
  }

  onSubmit(): void {
    if (this.loginForm.invalid || this.isLoading) {
      return;
    }

    this.isLoading = true;
    this.errorMessage = '';
    this.showLoadingMessage('Connexion en cours...');

    const credentials = {
      ...this.loginForm.value,
      username: this.loginForm.value.email,
      currentDate: this.currentDate,
      currentUser: this.currentUser
    };

    this.authService.login(credentials).subscribe(
      (response: AuthResponse): void => {
        if (response.success) {
          this.showLoadingMessage('Calcul de votre score de crédit multi-banques...');
          
          this.storageService.setCurrentUser(response.user);
          
          if (response.user && response.user.creditScore !== undefined) {
            let scoreOn10 = response.user.creditScore;
            if (scoreOn10 > 10) {
              scoreOn10 = Math.round(((scoreOn10 - 300) / 550) * 10 * 10) / 10;
            }
            
            this.storageService.setCreditScore({
              score: scoreOn10,
              eligibleAmount: response.user.eligibleAmount || 0,
              riskLevel: response.user.riskLevel || 'medium',
              recommendations: response.user.recommendations || [],
              scoreDetails: response.user.scoreDetails || null,
              lastUpdate: new Date().toISOString()
            });
          }
          
          setTimeout(() => {
            this.removeLoadingMessage();
            this.router.navigate(['/client/profile']);
          }, 2000);
        } else {
          this.handleLoginError(response.message || 'Erreur de connexion');
        }
      },
      (error) => {
        this.handleLoginError(error.message || 'Erreur de connexion');
      }
    );
  }

  private handleLoginError(message: string): void {
    this.errorMessage = message;
    this.isLoading = false;
    this.removeLoadingMessage();
    this.showErrorNotification(this.errorMessage);
  }

  public quickTestLogin(profileType: 'excellent' | 'bon' | 'moyen' | 'risque'): void {
  const testAccounts = {
    excellent: { email: 'jp.obame@email.ga', password: 'gabon2025' },
    bon: { email: 'm.bouyou@email.ga', password: 'gabon2025' },
    moyen: { email: 'a.sambabiyo@email.ga', password: 'gabon2025' },
    risque: { email: 'j.ndoumba@email.ga', password: 'gabon2025' }
  };

  const account = testAccounts[profileType];
  this.loginForm.patchValue(account);
  this.onSubmit();
}

  private showLoadingMessage(message: string): void {
    const loadingDiv = document.createElement('div');
    loadingDiv.id = 'scoring-loading';
    loadingDiv.innerHTML = `
      <div class="loading-overlay">
        <div class="loading-content">
          <div class="spinner-container">
            <div class="credit-spinner">
              <div class="spinner-ring"></div>
              <div class="spinner-ring"></div>
              <div class="spinner-ring"></div>
            </div>
          </div>
          <div class="loading-text">
            <h5>${message}</h5>
            <p>Analyse des meilleures offres du marché gabonais...</p>
          </div>
        </div>
      </div>
    `;
    
    this.removeLoadingMessage();
    document.body.appendChild(loadingDiv);
  }

  private removeLoadingMessage(): void {
    const loading = document.getElementById('scoring-loading');
    if (loading) {
      loading.remove();
    }
  }

  private showErrorNotification(message: string): void {
    const notification = document.createElement('div');
    notification.className = 'error-notification';
    notification.innerHTML = `
      <div class="notification-content">
        <div class="notification-header">
          <i class="material-icons">error_outline</i>
          <h6>Erreur de connexion</h6>
          <button onclick="this.parentElement.parentElement.parentElement.remove()">×</button>
        </div>
        <p>${message}</p>
      </div>
    `;
    
    document.body.appendChild(notification);
    
    setTimeout(() => {
      if (notification.parentNode) {
        notification.classList.add('fade-out');
        setTimeout(() => notification.remove(), 300);
      }
    }, 5000);
  }

  ngOnDestroy(): void {
    this.removeLoadingMessage();
  }
}