// requests-list.component.ts
import { Component, OnInit, OnDestroy } from '@angular/core';
import { Router } from '@angular/router';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Subscription } from 'rxjs';
import { HttpClient } from '@angular/common/http';
import { CreditRequestsService } from '../../services/credit-requests.service';
import { AuthService, User } from '../../services/auth.service';
import { environment } from '../../environments/environment';

interface ShortCreditRequest {
  id: string;
  type: 'short';
  username: string;
  creditType: string;
  amount: number;
  totalAmount: number;
  status: 'active' | 'paid' | 'overdue';
  approvedDate: string;
  dueDate: string;
  nextPaymentDate?: string;
  nextPaymentAmount?: number;
  remainingAmount: number;
  interestRate: number;
  createdAt: string;
  disbursedAmount?: number;
}

interface LongCreditRequest {
  id: string;
  type: 'long';
  username: string;
  status: 'draft' | 'submitted' | 'in_review' | 'approved' | 'rejected' | 'requires_info';
  personalInfo?: {
    fullName: string;
    email: string;
    phone: string;
    address: string;
    profession: string;
    company: string;
  };
  creditDetails?: {
    requestedAmount: number;
    duration: number;
    purpose: string;
    repaymentFrequency: string;
  };
  financialDetails?: {
    monthlyIncome: number;
    monthlyExpenses: number;
  };
  submissionDate?: string;
  createdAt: string;
  reviewHistory?: any[];
  simulation?: any;
}

type CreditRequest = ShortCreditRequest | LongCreditRequest;

@Component({
  selector: 'app-requests-list',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './request-list.component.html',
  styleUrls: ['./request-list.component.scss']
})
export class RequestsListComponent implements OnInit, OnDestroy {

  // État
  isLoading = false;
  currentUser: User | null = null;
  Math = Math;
  
  // Données des demandes
  allRequests: CreditRequest[] = [];
  filteredRequests: CreditRequest[] = [];
  
  // Filtres
  selectedType: 'all' | 'short' | 'long' = 'all';
  selectedStatus: string = 'all';
  searchTerm: string = '';
  
  // Pagination
  currentPage = 1;
  itemsPerPage = 10;
  totalPages = 1;
  
  // Modal
  showRequestModal = false;
  selectedRequest: CreditRequest | null = null;
  
  // Statistiques
  stats = {
    total: 0,
    short: 0,
    long: 0,
    active: 0,
    pending: 0,
    completed: 0
  };

  private subscriptions: Subscription[] = [];
  private apiUrl = environment.apiUrl || 'http://localhost:5000';

  constructor(
    private router: Router,
    private authService: AuthService,
    private http: HttpClient,
    private creditRequestsService: CreditRequestsService 
  ) {}

  ngOnInit(): void {
  this.subscriptions.push(
    this.authService.currentUser$.subscribe(user => {
      if (user) {
        this.currentUser = user;
        this.loadRequests();
      } else {
        this.router.navigate(['/profile']);
      }
    })
  );

  // S'abonner aux changements de demandes du service
  this.subscriptions.push(
    this.creditRequestsService.requests$.subscribe(requests => {
      this.allRequests = requests;
      this.updateStats();
      this.applyFilters();
    })
  );

  // S'abonner aux statistiques du service
  this.subscriptions.push(
    this.creditRequestsService.stats$.subscribe(stats => {
      this.stats = stats;
    })
  );
}

  ngOnDestroy(): void {
    this.subscriptions.forEach(sub => sub.unsubscribe());
  }

  // ========================================
  // CHARGEMENT DES DONNÉES
  // ========================================

  async loadRequests(): Promise<void> {
  if (!this.currentUser?.username && !this.currentUser?.email) return;
  
  this.isLoading = true;
  
  try {
    // Utiliser le service pour charger toutes les demandes
    const username = this.currentUser.username || this.currentUser.email;
    await this.creditRequestsService.loadUserRequests(username);
    
    // Les données seront automatiquement mises à jour via les observables
    console.log('Demandes chargées avec succès');
    
  } catch (error) {
    console.error('Erreur chargement demandes:', error);
    this.showNotification('Erreur lors du chargement des demandes', 'error');
  } finally {
    this.isLoading = false;
  }
}


  private async loadShortRequests(): Promise<ShortCreditRequest[]> {
    try {
      // Charger depuis le localStorage (demandes courtes locales)
      const storageKey = `user_credits_${this.currentUser?.username}`;
      const savedCredits = localStorage.getItem(storageKey);
      
      let shortRequests: ShortCreditRequest[] = [];
      
      if (savedCredits) {
        const credits = JSON.parse(savedCredits);
        shortRequests = credits.map((credit: any) => ({
          id: credit.id,
          type: 'short' as const,
          username: this.currentUser?.username || '',
          creditType: credit.type,
          amount: credit.amount,
          totalAmount: credit.totalAmount,
          status: credit.status,
          approvedDate: credit.approvedDate,
          dueDate: credit.dueDate,
          nextPaymentDate: credit.nextPaymentDate,
          nextPaymentAmount: credit.nextPaymentAmount,
          remainingAmount: credit.remainingAmount,
          interestRate: credit.interestRate,
          createdAt: credit.approvedDate,
          disbursedAmount: credit.amount // Montant décaissé = montant du crédit
        }));
      }

      // Essayer de charger depuis l'API aussi
      try {
        const response = await this.http.get<any[]>(`${this.apiUrl}/user-credits/${this.currentUser?.username}`).toPromise();
        if (response && response.length > 0) {
          // Fusionner avec les données locales sans doublons
          response.forEach(apiCredit => {
            if (!shortRequests.find(local => local.id === apiCredit.id)) {
              shortRequests.push({
                id: apiCredit.id,
                type: 'short',
                username: this.currentUser?.username || '',
                creditType: apiCredit.type,
                amount: apiCredit.amount,
                totalAmount: apiCredit.totalAmount,
                status: apiCredit.status,
                approvedDate: apiCredit.approvedDate,
                dueDate: apiCredit.dueDate,
                remainingAmount: apiCredit.remainingAmount,
                interestRate: apiCredit.interestRate,
                createdAt: apiCredit.approvedDate,
                disbursedAmount: apiCredit.amount
              });
            }
          });
        }
      } catch (apiError) {
        console.log('API non disponible, utilisation des données locales uniquement');
      }

      return shortRequests;
      
    } catch (error) {
      console.error('Erreur chargement demandes courtes:', error);
      return [];
    }
  }

  private async loadLongRequests(): Promise<LongCreditRequest[]> {
    try {
      const response = await this.http.get<any>(`${this.apiUrl}/credit-long/user/${this.currentUser?.username}`)
        .toPromise();
      
      if (response && response.requests) {
        return response.requests.map((request: any) => ({
          id: request.id,
          type: 'long' as const,
          username: request.username,
          status: request.status,
          personalInfo: request.personalInfo,
          creditDetails: request.creditDetails,
          financialDetails: request.financialDetails,
          submissionDate: request.submissionDate,
          createdAt: request.createdAt || request.submissionDate,
          reviewHistory: request.reviewHistory,
          simulation: request.simulation
        }));
      }
      
      return [];
      
    } catch (error) {
      console.error('Erreur chargement demandes longues:', error);
      return [];
    }
  }

  // ========================================
  // FILTRES ET RECHERCHE
  // ========================================

  applyFilters(): void {
    let filtered = [...this.allRequests];

    // Filtre par type
    if (this.selectedType !== 'all') {
      filtered = filtered.filter(req => req.type === this.selectedType);
    }

    // Filtre par statut
    if (this.selectedStatus !== 'all') {
      filtered = filtered.filter(req => req.status === this.selectedStatus);
    }

    // Recherche textuelle
    if (this.searchTerm.trim()) {
      const term = this.searchTerm.toLowerCase();
      filtered = filtered.filter(req => {
        if (req.type === 'short') {
          return req.creditType.toLowerCase().includes(term) ||
                 req.id.toLowerCase().includes(term);
        } else {
          return req.personalInfo?.fullName?.toLowerCase().includes(term) ||
                 req.creditDetails?.purpose?.toLowerCase().includes(term) ||
                 req.id.toLowerCase().includes(term);
        }
      });
    }

    this.filteredRequests = filtered;
    this.updatePagination();
  }

  updatePagination(): void {
    this.totalPages = Math.ceil(this.filteredRequests.length / this.itemsPerPage);
    if (this.currentPage > this.totalPages) {
      this.currentPage = 1;
    }
  }

  get paginatedRequests(): CreditRequest[] {
    const startIndex = (this.currentPage - 1) * this.itemsPerPage;
    return this.filteredRequests.slice(startIndex, startIndex + this.itemsPerPage);
  }

  // ========================================
  // STATISTIQUES
  // ========================================

  updateStats(): void {
    this.stats = {
      total: this.allRequests.length,
      short: this.allRequests.filter(req => req.type === 'short').length,
      long: this.allRequests.filter(req => req.type === 'long').length,
      active: this.allRequests.filter(req => 
        req.status === 'active' || req.status === 'approved' || req.status === 'submitted'
      ).length,
      pending: this.allRequests.filter(req => 
        req.status === 'submitted' || req.status === 'in_review'
      ).length,
      completed: this.allRequests.filter(req => 
        req.status === 'paid' || req.status === 'approved'
      ).length
    };
  }

  // ========================================
  // ACTIONS
  // ========================================

  viewRequest(request: CreditRequest): void {
    this.selectedRequest = request;
    this.showRequestModal = true;
  }

  closeRequestModal(): void {
    this.showRequestModal = false;
    this.selectedRequest = null;
  }

  editRequest(request: CreditRequest): void {
  if (request.type === 'long' && this.canEditLongRequest(request as LongCreditRequest)) {
    this.router.navigate(['/credit-long-request'], { 
      queryParams: { edit: request.id } 
    });
  }
}

  deleteRequest(request: CreditRequest): void {
    if (request.type === 'long' && request.status === 'draft') {
      if (confirm('Êtes-vous sûr de vouloir supprimer ce brouillon ?')) {
        this.performDeleteRequest(request.id);
      }
    }
  }

  private async performDeleteRequest(requestId: string): Promise<void> {
    try {
      await this.http.delete(`${this.apiUrl}/credit-long/request/${requestId}`).toPromise();
      this.loadRequests(); // Recharger la liste
      this.showNotification('Demande supprimée avec succès', 'success');
    } catch (error) {
      console.error('Erreur suppression:', error);
      this.showNotification('Erreur lors de la suppression', 'error');
    }
  }

  // ========================================
  // UTILITAIRES
  // ========================================

  getCreditTypeName(creditTypeId: string): string {
    const types: Record<string, string> = {
      'consommation_generale': 'Crédit Consommation',
      'avance_salaire': 'Avance sur Salaire',
      'depannage': 'Crédit Dépannage',
      'investissement': 'Crédit Investissement',
      'tontine': 'Crédit Tontine',
      'retraite': 'Crédit Retraite'
    };
    return types[creditTypeId] || creditTypeId;
  }

  getStatusText(status: string): string {
  const statusMap: Record<string, string> = {
    // Statuts courts
    'active': 'Actif',
    'paid': 'Remboursé',
    'overdue': 'En retard',
    // Statuts longs
    'draft': 'Brouillon',
    'submitted': 'Soumise',
    'in_review': 'En examen',
    'approved': 'Approuvée',
    'rejected': 'Rejetée',
    'requires_info': 'Info requise'
  };
  return statusMap[status] || status;
}

  getStatusClass(status: string): string {
  const classes: Record<string, string> = {
    // Statuts courts
    'active': 'status-active',
    'paid': 'status-completed',
    'overdue': 'status-overdue',
    // Statuts longs
    'draft': 'status-draft',
    'submitted': 'status-pending',
    'in_review': 'status-pending',
    'approved': 'status-approved',
    'rejected': 'status-rejected',
    'requires_info': 'status-warning'
  };
  return classes[status] || 'status-default';
}
getLongRequestDisplayInfo(request: LongCreditRequest): any {
  return {
    title: request.creditDetails?.purpose || 'Demande de crédit long terme',
    amount: request.creditDetails?.requestedAmount || 0,
    duration: request.creditDetails?.duration || 0,
    submissionDate: request.submissionDate || request.createdAt,
    clientName: request.personalInfo?.fullName || 'N/A',
    riskLevel: request.simulation?.riskLevel || 'Non évalué',
    monthlyPayment: request.simulation?.monthlyPayment || 0
  };
}

// 12. MÉTHODE POUR VÉRIFIER SI UNE DEMANDE PEUT ÊTRE MODIFIÉE
canEditLongRequest(request: LongCreditRequest): boolean {
  return ['draft', 'requires_info'].includes(request.status);
}

// 13. MÉTHODE POUR VÉRIFIER SI UNE DEMANDE PEUT ÊTRE SUPPRIMÉE
canDeleteLongRequest(request: LongCreditRequest): boolean {
  return request.status === 'draft';
}
  formatCurrency(amount: number): string {
    return new Intl.NumberFormat('fr-FR', {
      style: 'currency',
      currency: 'XAF',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0
    }).format(amount || 0);
  }

  formatDate(dateString: string): string {
    if (!dateString) return 'Non défini';
    
    try {
      const date = new Date(dateString);
      return date.toLocaleDateString('fr-FR', {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric'
      });
    } catch {
      return 'Date invalide';
    }
  }

  getTimeAgo(dateString: string): string {
    if (!dateString) return '';
    
    try {
      const date = new Date(dateString);
      const now = new Date();
      const diffMs = now.getTime() - date.getTime();
      const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));
      
      if (diffDays === 0) return 'Aujourd\'hui';
      if (diffDays === 1) return 'Hier';
      if (diffDays < 7) return `Il y a ${diffDays} jours`;
      if (diffDays < 30) return `Il y a ${Math.floor(diffDays / 7)} semaines`;
      if (diffDays < 365) return `Il y a ${Math.floor(diffDays / 30)} mois`;
      return `Il y a ${Math.floor(diffDays / 365)} ans`;
    } catch {
      return '';
    }
  }

  // ========================================
  // NAVIGATION ET PAGINATION
  // ========================================

  goToPage(page: number): void {
    if (page >= 1 && page <= this.totalPages) {
      this.currentPage = page;
    }
  }

  previousPage(): void {
    if (this.currentPage > 1) {
      this.currentPage--;
    }
  }

  nextPage(): void {
    if (this.currentPage < this.totalPages) {
      this.currentPage++;
    }
  }

  get pageNumbers(): number[] {
    const pages: number[] = [];
    const start = Math.max(1, this.currentPage - 2);
    const end = Math.min(this.totalPages, start + 4);
    
    for (let i = start; i <= end; i++) {
      pages.push(i);
    }
    
    return pages;
  }

  // ========================================
  // GESTION DES FILTRES
  // ========================================

  onTypeFilterChange(): void {
    this.currentPage = 1;
    this.applyFilters();
  }

  onStatusFilterChange(): void {
    this.currentPage = 1;
    this.applyFilters();
  }

  onSearchChange(): void {
    this.currentPage = 1;
    this.applyFilters();
  }

  clearFilters(): void {
    this.selectedType = 'all';
    this.selectedStatus = 'all';
    this.searchTerm = '';
    this.currentPage = 1;
    this.applyFilters();
  }

  // ========================================
  // NOTIFICATIONS
  // ========================================

  private showNotification(message: string, type: 'success' | 'error' | 'warning' | 'info' = 'info'): void {
    // Implémentation simple avec console, à remplacer par un service de notification
    console.log(`${type.toUpperCase()}: ${message}`);
    
    // Notification visuelle temporaire
    const notification = document.createElement('div');
    notification.className = `notification notification-${type}`;
    notification.textContent = message;
    notification.style.cssText = `
      position: fixed;
      top: 20px;
      right: 20px;
      padding: 12px 20px;
      border-radius: 6px;
      color: white;
      z-index: 10000;
      max-width: 400px;
      animation: slideInRight 0.3s ease-out;
    `;
    
    switch (type) {
      case 'success': notification.style.backgroundColor = '#28a745'; break;
      case 'error': notification.style.backgroundColor = '#dc3545'; break;
      case 'warning': notification.style.backgroundColor = '#ffc107'; break;
      default: notification.style.backgroundColor = '#17a2b8'; break;
    }
    
    document.body.appendChild(notification);
    
    setTimeout(() => {
      notification.remove();
    }, 4000);
  }

  // ========================================
  // NOUVELLES DEMANDES
  // ========================================

  createNewShortRequest(): void {
    this.router.navigate(['/profile']); 
  }

  createNewLongRequest(): void {
    this.router.navigate(['/credit-long-request']);
  }

refreshRequests(): void {
  if (this.currentUser?.username || this.currentUser?.email) {
    const username = this.currentUser.username || this.currentUser.email;
    this.creditRequestsService.refreshData(username);
  }
}

}