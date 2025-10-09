// backoffice-login.component.ts
import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { HttpClient, HttpClientModule } from '@angular/common/http';

@Component({
  selector: 'app-backoffice-login',
  standalone: true,
  imports: [CommonModule, FormsModule, HttpClientModule],
  template: `
    <div class="backoffice-login-container">
      <div class="login-card">
        <div class="login-header">
          <h1>Backoffice</h1>
          <p>Bamboo Credit - Administration</p>
        </div>

        <form (ngSubmit)="onLogin()" class="login-form">
          <div class="form-group">
            <label>Email</label>
            <input 
              type="email" 
              [(ngModel)]="credentials.email" 
              name="email"
              placeholder="admin@bamboo-credit.com"
              required>
          </div>

          <div class="form-group">
            <label>Mot de passe</label>
            <input 
              type="password" 
              [(ngModel)]="credentials.password" 
              name="password"
              placeholder="••••••••"
              required>
          </div>

          <div *ngIf="errorMessage" class="error-message">
             {{ errorMessage }}
          </div>

          <button 
            type="submit" 
            class="btn-login"
            [disabled]="isLoading">
            {{ isLoading ? 'Connexion...' : 'Se connecter' }}
          </button>
        </form>

        <div class="login-footer">
          <a routerLink="/login" class="link-client">
            ← Retour à l'espace client
          </a>
        </div>
      </div>
    </div>
  `,
  styles: [`
    .backoffice-login-container {
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      padding: 2rem;
    }

    .login-card {
      background: white;
      border-radius: 16px;
      padding: 3rem;
      max-width: 450px;
      width: 100%;
      box-shadow: 0 20px 60px rgba(0,0,0,0.3);
    }

    .login-header {
      text-align: center;
      margin-bottom: 2rem;

      h1 {
        margin: 0 0 0.5rem 0;
        color: #1e293b;
        font-size: 2rem;
      }

      p {
        margin: 0;
        color: #64748b;
        font-size: 0.95rem;
      }
    }

    .login-form {
      .form-group {
        margin-bottom: 1.5rem;

        label {
          display: block;
          margin-bottom: 0.5rem;
          color: #334155;
          font-weight: 500;
        }

        input {
          width: 100%;
          padding: 0.875rem;
          border: 2px solid #e2e8f0;
          border-radius: 8px;
          font-size: 1rem;
          transition: all 0.3s;

          &:focus {
            outline: none;
            border-color: #667eea;
          }
        }
      }

      .error-message {
        background: #fee;
        color: #c00;
        padding: 0.75rem;
        border-radius: 6px;
        margin-bottom: 1rem;
        font-size: 0.9rem;
      }

      .btn-login {
        width: 100%;
        padding: 1rem;
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        color: white;
        border: none;
        border-radius: 8px;
        font-size: 1rem;
        font-weight: 600;
        cursor: pointer;
        transition: all 0.3s;

        &:hover:not(:disabled) {
          transform: translateY(-2px);
          box-shadow: 0 8px 20px rgba(102,126,234,0.4);
        }

        &:disabled {
          opacity: 0.6;
          cursor: not-allowed;
        }
      }
    }

    .login-footer {
      margin-top: 2rem;
      text-align: center;

      .link-client {
        color: #667eea;
        text-decoration: none;
        font-size: 0.9rem;

        &:hover {
          text-decoration: underline;
        }
      }
    }
  `]
})
export class BackofficeLoginComponent {
  credentials = {
    email: '',
    password: ''
  };

  isLoading = false;
  errorMessage = '';

  constructor(
    private router: Router,
    private http: HttpClient
  ) {}

  async onLogin() {
    this.isLoading = true;
    this.errorMessage = '';

    try {
      // Appel API pour l'authentification backoffice
      const response: any = await this.http.post(
        'http://localhost:3000/api/auth/backoffice/login',
        this.credentials
      ).toPromise();

      // Vérifier si l'utilisateur a le rôle admin/agent
      if (response.user.role !== 'admin' && response.user.role !== 'agent') {
        this.errorMessage = 'Accès non autorisé. Réservé aux administrateurs.';
        this.isLoading = false;
        return;
      }

      // Stocker les données d'authentification
      localStorage.setItem('authToken', response.token);
      localStorage.setItem('userRole', response.user.role);
      localStorage.setItem('userData', JSON.stringify(response.user));

      // Rediriger vers le backoffice
      this.router.navigate(['/backoffice']);

    } catch (error: any) {
      console.error('Erreur de connexion:', error);
      this.errorMessage = error.error?.message || 'Email ou mot de passe incorrect';
    } finally {
      this.isLoading = false;
    }
  }
}
