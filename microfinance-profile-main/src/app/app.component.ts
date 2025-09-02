import { Component, OnInit } from '@angular/core';
import { RouterOutlet } from '@angular/router';
import { CommonModule } from '@angular/common';
import { CreditSimulationService } from './services/credit-simulation.service';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [
    CommonModule,
    RouterOutlet  // Seulement ce qui est utilisé dans le template
  ],
  template: `
    <div class="app-container">
      <div class="main-content">
        <router-outlet></router-outlet>
      </div>
    </div>
  `,
  styles: [`
    .app-container {
      height: 100vh;
      display: flex;
      flex-direction: column;
    }
    
    .main-content {
      flex: 1;
      overflow: auto;
    }
  `]
})
export class AppComponent implements OnInit {
  title = 'bamboo-emf';

  constructor(private creditService: CreditSimulationService) {}

  async ngOnInit() {
    // Charger le logo Bamboo au démarrage
    await this.loadBambooLogo();
    
    // Initialiser les données du profil par défaut pour theobawana
    this.initializeDefaultProfile();
  }

  async loadBambooLogo() {
    try {
      // Vérifier si le logo est déjà en cache
      const cachedLogo = localStorage.getItem('bambooLogo');
      if (!cachedLogo) {
        // Charger le logo depuis les assets locaux
        const logoBase64 = await this.creditService.loadLogoFromAssets();
        if (logoBase64) {
          localStorage.setItem('bambooLogo', logoBase64);
          console.log('Logo Bamboo chargé avec succès');
        }
      }
    } catch (error) {
      console.error('Erreur lors du chargement du logo:', error);
      
      // Logo de secours en SVG
      const fallbackLogo = this.generateFallbackLogo();
      localStorage.setItem('bambooLogo', fallbackLogo);
    }
  }

  private initializeDefaultProfile() {
    // Vérifier si un profil existe déjà
    const existingProfile = localStorage.getItem('currentClient');
    
    if (!existingProfile) {
      // Créer le profil par défaut 
      const defaultProfile = {
        id: 'CLIENT-001',
        fullName: 'marina brunelle',
        email: 'bebanemb@gmail.com',
        phone: '+241 07 XX XX XX',
        monthlyIncome: 750000,
        clientType: 'particulier',
        accountNumber: `PAR${Date.now().toString().slice(-8)}`,
        createdAt: new Date().toISOString()
      };
      
      localStorage.setItem('currentClient', JSON.stringify(defaultProfile));
      console.log('Profil par défaut créé pour marina');
    }
  }

  private generateFallbackLogo(): string {
    // Générer un logo SVG de secours encodé en base64
    const svgLogo = `
      <svg width="200" height="60" viewBox="0 0 200 60" xmlns="http://www.w3.org/2000/svg">
        <g fill="#4CAF50">
          <!-- Icône bambou stylisée -->
          <path d="M20,50 Q20,30 22,25 Q24,20 26,25 Q28,30 28,50 Z" fill="#4CAF50" opacity="0.8"/>
          <path d="M32,50 Q32,35 33.5,32 Q35,29 36.5,32 Q38,35 38,50 Z" fill="#4CAF50" opacity="0.9"/>
          <path d="M42,50 Q42,40 43,38 Q44,36 45,38 Q46,40 46,50 Z" fill="#4CAF50"/>
          
          <!-- Feuilles -->
          <ellipse cx="26" cy="22" rx="8" ry="3" fill="#4CAF50" transform="rotate(-30 26 22)"/>
          <ellipse cx="35" cy="28" rx="7" ry="2.5" fill="#4CAF50" transform="rotate(25 35 28)"/>
          <ellipse cx="44" cy="35" rx="6" ry="2" fill="#4CAF50" transform="rotate(-20 44 35)"/>
          
          <!-- Texte Bamboo -->
          <text x="60" y="40" font-family="Arial Black, sans-serif" font-size="32" font-weight="bold" fill="#4CAF50">Bamboo</text>
          
          <!-- Sous-titre EMF -->
          <text x="62" y="52" font-family="Arial, sans-serif" font-size="10" fill="#666">Établissement de Microfinance</text>
        </g>
      </svg>
    `;
    
    // Encoder en base64
    const base64 = 'data:image/svg+xml;base64,' + btoa(svgLogo);
    return base64;
  }
}