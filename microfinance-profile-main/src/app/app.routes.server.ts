import { Routes } from '@angular/router';
import { LayoutComponent } from './layouts/app-layout.component/app-layout.component';
import { LoginComponent } from './components/login.component/login.component';
import { ProfileComponent } from './pages/profile/profile.component';
import { ParametreComponent } from './pages/parametre.component/parametre.component';
import { MonprofilComponent } from './pages/monprofil.component/monprofil.component';
import { CreditSimulateurComponent } from './pages/credit-simulation.component/credit-simulation.component';
import { MultiBankComparatorComponent } from './simulateur-bank/components/multi-bank-comparator.component/multi-bank-comparator.component';
import { CreditLongRequestComponent } from './pages/credit-request.component/credit-long-request.component';

// Nouveaux composants ajoutés
import { SimulatorHomeComponent } from './simulateur-bank/components/simulator-home/simulator-home.component';
import { PaymentCalculatorComponent } from './simulateur-bank/components/payment-calculator/payment-calculator.component';
import { BorrowingCapacityComponent } from './simulateur-bank/components/capacite-emprunt/boworing-capacity.component';

export const routes: Routes = [
  {
    path: '',
    redirectTo: 'accueil',
    pathMatch: 'full'
  },

  // Routes publiques (sans connexion requise)
  {
    path: 'accueil',
    component: LoginComponent,
    title: 'Accueil - Bamboo Credit'
  },
  {
    path: 'login',
    component: LoginComponent,
    title: 'Connexion - Bamboo Credit'
  },

  // Routes des simulateurs publics
  {
    path: 'simulateur',
    component: SimulatorHomeComponent,
    title: 'Simulateur de Crédit - Bamboo Credit',
    data: { 
      public: true,
      description: 'Simulateur de crédit multi-banques gratuit'
    }
  },
  {
    path: 'simulateur-home',
    component: SimulatorHomeComponent,
    title: 'Accueil Simulateur - Bamboo Credit',
    data: { 
      public: true,
      description: 'Hub des simulateurs de crédit'
    }
  },
  {
    path: 'payment-calculator',
    component: PaymentCalculatorComponent,
    title: 'Calculateur de Mensualités - Bamboo Credit',
    data: { 
      public: true,
      description: 'Calculez vos mensualités de crédit'
    }
  },
  {
    path: 'borrowing-capacity',
    component: BorrowingCapacityComponent,
    title: 'Capacité d\'Emprunt - Bamboo Credit',
    data: { 
      public: true,
      description: 'Calculez votre capacité d\'emprunt'
    }
  },
  {
    path: 'comparateur',
    component: MultiBankComparatorComponent,
    title: 'Comparateur Multi-Banques - Bamboo Credit',
    data: { 
      public: true,
      description: 'Comparez les offres de toutes les banques du Gabon'
    }
  },

  // Routes avec authentification
  {
    path: 'client',
    children: [
      {
        path: 'login',
        component: LoginComponent,
        title: 'Connexion Client'
      },
      {
        path: '',
        component: LayoutComponent, 
        children: [
          {
            path: 'profile',
            component: ProfileComponent,
            title: 'Mon Profil',
            data: { role: 'client', requiresAuth: true }
          },
          {
            path: 'parametre',    
            component: ParametreComponent,
            title: 'Paramètres',
            data: { requiresAuth: true }
          },
          {
            path: 'monprofil',    
            component: MonprofilComponent,
            title: 'Mon Profil Détaillé',
            data: { requiresAuth: true }
          },
          {
            path: 'credit-simulation',    
            component: CreditSimulateurComponent,
            title: 'Mon Simulateur de Crédit',
            data: { requiresAuth: true }
          },
          {
            path: 'simulateur-avance',    
            component: SimulatorHomeComponent,
            title: 'Simulateur Avancé',
            data: { requiresAuth: true, enhanced: true }
          },
          {
            path: 'payment-calculator',    
            component: PaymentCalculatorComponent,
            title: 'Mon Calculateur de Mensualités',
            data: { requiresAuth: true, enhanced: true }
          },
          {
            path: 'capacite-emprunt',    
            component: BorrowingCapacityComponent,
            title: 'Ma Capacité d\'Emprunt',
            data: { requiresAuth: true, enhanced: true }
          },
          {
            path: 'credit-request',    
            component: CreditLongRequestComponent,
            title: 'Demande de Crédit',
            data: { 
              requiresAuth: true,
              description: 'Formulaire complet de demande de crédit'
            }
          },
          {
            path: 'comparateur',    
            component: MultiBankComparatorComponent,
            title: 'Mon Comparateur Multi-Banques',
            data: { requiresAuth: true, enhanced: true }
          }
        ]
      }
    ]
  },

  // Routes spécifiques par banque (publiques)
  {
    path: 'banques/:bankId/simulateur',
    component: SimulatorHomeComponent,
    title: 'Simulateur Bancaire',
    data: { 
      public: true,
      bankSpecific: true,
      description: 'Simulateur spécifique à une banque'
    }
  },

  {
    path: 'register',
    redirectTo: 'inscription',
    pathMatch: 'full'
  },

  // Redirections et alias utiles
  {
    path: 'connexion',
    redirectTo: 'login',
    pathMatch: 'full'
  },
  {
    path: 'simulation',
    redirectTo: 'simulateur',
    pathMatch: 'full'
  },

  // Route 404
  {
    path: '**',
    redirectTo: 'accueil'
  }
];