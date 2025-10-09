import { Injectable } from '@angular/core';
import { CanActivate, ActivatedRouteSnapshot, RouterStateSnapshot, Router } from '@angular/router';
import { Observable } from 'rxjs';

@Injectable({
  providedIn: 'root'
})
export class BackofficeGuard implements CanActivate {
  
  // 🔧 MODE DÉVELOPPEMENT - Mettre à false en production
  private readonly DEV_MODE = true;
  
  constructor(private router: Router) {}

  canActivate(
    route: ActivatedRouteSnapshot,
    state: RouterStateSnapshot
  ): Observable<boolean> | Promise<boolean> | boolean {
    
    // 🚀 EN MODE DEV: Accès direct sans authentification
    if (this.DEV_MODE) {
      console.log('🔓 Mode développement: Accès backoffice autorisé');
      this.setupDevAuth();
      return true;
    }

    // ✅ EN PRODUCTION: Vérification complète
    const isAuthenticated = this.checkAuthentication();
    
    if (!isAuthenticated) {
      console.warn('⚠️ Accès backoffice refusé: non authentifié');
      this.router.navigate(['/login'], { 
        queryParams: { returnUrl: state.url } 
      });
      return false;
    }

    const hasAdminRole = this.checkAdminRole();
    
    if (!hasAdminRole) {
      console.warn('⚠️ Accès backoffice refusé: rôle insuffisant');
      this.router.navigate(['/client/profile']);
      return false;
    }

    console.log('✅ Accès backoffice autorisé');
    return true;
  }

  /**
   * Configure un utilisateur admin fictif pour le développement
   */
  private setupDevAuth(): void {
    // Vérifier si les données existent déjà
    if (!localStorage.getItem('authToken')) {
      const devToken = 'dev-token-' + Date.now();
      const devUser = {
        id: 999,
        prenom: 'Admin',
        nom: 'Dev',
        email: 'admin@bamboo-credit.com',
        role: 'admin'
      };

      localStorage.setItem('authToken', devToken);
      localStorage.setItem('userRole', 'admin');
      localStorage.setItem('userData', JSON.stringify(devUser));
      
      console.log('🔧 Authentification dev configurée:', devUser);
    }
  }

  private checkAuthentication(): boolean {
    const token = localStorage.getItem('authToken') || sessionStorage.getItem('authToken');
    
    if (!token) {
      return false;
    }

    try {
      const tokenData = this.parseJwt(token);
      const currentTime = Date.now() / 1000;
      
      if (tokenData.exp && tokenData.exp < currentTime) {
        console.warn('Token expiré');
        this.clearAuthData();
        return false;
      }
      
      return true;
    } catch (error) {
      // Si le parsing échoue, c'est peut-être un token dev
      return token.startsWith('dev-token-');
    }
  }

  private checkAdminRole(): boolean {
    // Méthode 1: Via localStorage
    const userRole = localStorage.getItem('userRole');
    if (userRole === 'admin' || userRole === 'agent') {
      return true;
    }

    // Méthode 2: Via userData
    const userDataStr = localStorage.getItem('userData');
    if (userDataStr) {
      try {
        const userData = JSON.parse(userDataStr);
        return userData.role === 'admin' || userData.role === 'agent';
      } catch (error) {
        console.error('Erreur parsing userData:', error);
      }
    }

    // Méthode 3: Via token JWT
    const token = localStorage.getItem('authToken');
    if (token) {
      try {
        const tokenData = this.parseJwt(token);
        return tokenData.role === 'admin' || tokenData.role === 'agent';
      } catch (error) {
        // Token non JWT (mode dev)
        return token.startsWith('dev-token-');
      }
    }

    return false;
  }

  private parseJwt(token: string): any {
    try {
      const base64Url = token.split('.')[1];
      const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
      const jsonPayload = decodeURIComponent(
        atob(base64)
          .split('')
          .map(c => '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2))
          .join('')
      );
      return JSON.parse(jsonPayload);
    } catch (error) {
      throw new Error('Invalid token format');
    }
  }

  private clearAuthData(): void {
    localStorage.removeItem('authToken');
    localStorage.removeItem('userRole');
    localStorage.removeItem('userData');
    sessionStorage.removeItem('authToken');
  }
}