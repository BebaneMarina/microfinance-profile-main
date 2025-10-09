import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { HttpClient } from '@angular/common/http';
import { environment } from '../../environments/environment';
import { BackofficeService } from '../../services/backoffice.service';

interface CreditRequest {
  id: number;
  requestNumber: string;
  username: string;
  userId: number;
  creditType: string;
  requestedAmount: number;
  duration: number;
  purpose: string;
  status: string;
  submissionDate: string;
  personalInfo?: {
    fullName: string;
    email: string;
    phone: string;
  };
  creditDetails?: {
    requestedAmount: number;
    duration: number;
    purpose: string;
  };
  simulationResults?: {
    calculatedScore?: number;
    riskLevel: string;
    monthlyPayment: number;
  };
  scoreAtSubmission?: number;
  riskLevel?: string;
}

@Component({
  selector: 'app-backoffice',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './backoffice.component.html',
  styleUrls: ['./backoffice.component.scss']
})
export class BackofficeComponent implements OnInit {
  private apiUrl = environment.nestUrl || 'http://localhost:3000';

  requests: CreditRequest[] = [];
  filteredRequests: CreditRequest[] = [];
  selectedRequest: CreditRequest | null = null;
  showModal = false;
  loading = false;

  // Filtres
  statusFilter = 'all';
  searchTerm = '';
  dateFilter = 'all';

  // Statistiques
  stats = {
    total: 0,
    submitted: 0,
    inReview: 0,
    approved: 0,
    rejected: 0,
    totalAmount: 0
  };

  constructor(
    private http: HttpClient,
    private backofficeService: BackofficeService
  ) { }

  ngOnInit(): void {
    this.loadRequests();
  }

  applyFilters(): void {
    let filtered = [...this.requests];

    // Filtre par statut
    if (this.statusFilter !== 'all') {
      filtered = filtered.filter(r => r.status === this.statusFilter);
    }

    // Filtre par recherche
    if (this.searchTerm) {
      const search = this.searchTerm.toLowerCase();
      filtered = filtered.filter(r => 
        r.requestNumber.toLowerCase().includes(search) ||
        (r.personalInfo?.fullName || '').toLowerCase().includes(search) ||
        (r.personalInfo?.email || r.username || '').toLowerCase().includes(search)
      );
    }

    // Filtre par date
    if (this.dateFilter !== 'all') {
      const now = new Date();
      filtered = filtered.filter(r => {
        const date = new Date(r.submissionDate);
        const diffDays = Math.floor((now.getTime() - date.getTime()) / (1000 * 60 * 60 * 24));
        
        switch(this.dateFilter) {
          case 'today': return diffDays === 0;
          case 'week': return diffDays <= 7;
          case 'month': return diffDays <= 30;
          default: return true;
        }
      });
    }

    this.filteredRequests = filtered;
  }

  calculateStats(): void {
    this.stats = {
      total: this.requests.length,
      submitted: this.requests.filter(r => r.status === 'submitted' || r.status === 'soumise').length,
      inReview: this.requests.filter(r => r.status === 'in_review').length,
      approved: this.requests.filter(r => r.status === 'approved').length,
      rejected: this.requests.filter(r => r.status === 'rejected').length,
      totalAmount: this.requests.reduce((sum, r) => {
        const amount = r.creditDetails?.requestedAmount || r.requestedAmount || 0;
        return sum + amount;
      }, 0)
    };
  }

  loadRequests(): void {
    this.loading = true;
    this.backofficeService.getAllRequests({
      status: this.statusFilter !== 'all' ? this.statusFilter : undefined,
      page: 1,
      limit: 100
    }).subscribe({
      next: (response) => {
        console.log('📥 Réponse reçue:', response);
        if (response.success) {
          this.requests = response.requests || [];
          console.log('📋 Demandes chargées:', this.requests.length);
          console.log('🔍 Première demande:', this.requests[0]);
          this.applyFilters();
          this.loadStatistics();
        }
        this.loading = false;
      },
      error: (error) => {
        console.error('❌ Erreur chargement demandes:', error);
        this.showNotification('Erreur lors du chargement des demandes', 'error');
        this.loading = false;
      }
    });
  }

  loadStatistics(): void {
    this.backofficeService.getStatistics().subscribe({
      next: (response) => {
        if (response.success) {
          this.stats = {
            total: response.statistics.total,
            submitted: response.statistics.submitted,
            inReview: response.statistics.inReview,
            approved: response.statistics.approved,
            rejected: response.statistics.rejected,
            totalAmount: response.statistics.totalRequestedAmount
          };
        }
      },
      error: (error) => {
        console.error('❌ Erreur chargement statistiques:', error);
      }
    });
  }

  approveRequest(request: CreditRequest): void {
    const amount = request.creditDetails?.requestedAmount || request.requestedAmount || 0;
    if (confirm(`Approuver la demande ${request.requestNumber} ?`)) {
      this.backofficeService.approveRequest(request.id.toString(), {
        approvedAmount: amount,
        notes: 'Demande approuvée par le back-office'
      }).subscribe({
        next: (response) => {
          if (response.success) {
            this.showNotification('Demande approuvée avec succès', 'success');
            this.loadRequests();
            this.closeModal();
          }
        },
        error: (error) => {
          console.error('❌ Erreur approbation:', error);
          this.showNotification('Erreur lors de l\'approbation', 'error');
        }
      });
    }
  }

  rejectRequest(request: CreditRequest): void {
    const reason = prompt('Raison du rejet:');
    if (reason) {
      this.backofficeService.rejectRequest(request.id.toString(), reason).subscribe({
        next: (response) => {
          if (response.success) {
            this.showNotification('Demande rejetée', 'success');
            this.loadRequests();
            this.closeModal();
          }
        },
        error: (error) => {
          console.error('❌ Erreur rejet:', error);
          this.showNotification('Erreur lors du rejet', 'error');
        }
      });
    }
  }

  putInReview(request: CreditRequest): void {
    this.backofficeService.putInReview(request.id.toString()).subscribe({
      next: (response) => {
        if (response.success) {
          this.showNotification('Demande mise en examen', 'success');
          this.loadRequests();
          this.closeModal();
        }
      },
      error: (error) => {
        console.error('❌ Erreur mise en examen:', error);
        this.showNotification('Erreur lors de la mise en examen', 'error');
      }
    });
  }

  viewDetails(request: CreditRequest): void {
    this.selectedRequest = request;
    this.showModal = true;
  }

  closeModal(): void {
    this.showModal = false;
    this.selectedRequest = null;
  }

  updateStatus(requestId: number, newStatus: string, notes?: string): void {
    this.http.patch(`${this.apiUrl}/api/credit-long/requests/${requestId}`, {
      status: newStatus,
      decisionNotes: notes
    }).subscribe({
      next: () => {
        this.loadRequests();
        this.closeModal();
        this.showNotification('Statut mis à jour avec succès', 'success');
      },
      error: (error) => {
        console.error('❌ Erreur mise à jour:', error);
        this.showNotification('Erreur lors de la mise à jour', 'error');
      }
    });
  }

  // Méthodes utilitaires pour récupérer les valeurs avec fallback
  getClientName(request: CreditRequest): string {
    return request.personalInfo?.fullName || request.username || 'N/A';
  }

  getAmount(request: CreditRequest): number {
    return request.creditDetails?.requestedAmount || request.requestedAmount || 0;
  }

  getDuration(request: CreditRequest): number {
    return request.creditDetails?.duration || request.duration || 0;
  }

  getScore(request: CreditRequest): number {
    return request.simulationResults?.calculatedScore || request.scoreAtSubmission || 0;
  }

  getRiskLevel(request: CreditRequest): string {
    return request.simulationResults?.riskLevel || request.riskLevel || 'N/A';
  }

  formatCurrency(amount: number): string {
    return new Intl.NumberFormat('fr-FR', {
      style: 'currency',
      currency: 'XAF',
      minimumFractionDigits: 0
    }).format(amount);
  }

  formatDate(dateString: string): string {
    if (!dateString) return 'N/A';
    return new Date(dateString).toLocaleDateString('fr-FR', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  }

  getStatusBadgeClass(status: string): string {
    const classes: Record<string, string> = {
      'draft': 'badge-draft',
      'submitted': 'badge-submitted',
      'soumise': 'badge-submitted',
      'in_review': 'badge-review',
      'approved': 'badge-approved',
      'rejected': 'badge-rejected'
    };
    return classes[status] || 'badge-default';
  }

  getStatusText(status: string): string {
    const texts: Record<string, string> = {
      'draft': 'Brouillon',
      'submitted': 'Soumise',
      'soumise': 'Soumise',
      'in_review': 'En examen',
      'approved': 'Approuvée',
      'rejected': 'Rejetée'
    };
    return texts[status] || status;
  }

  getRiskColor(riskLevel: string): string {
    const colors: Record<string, string> = {
      'tres_faible': '#28a745',
      'Très faible': '#28a745',
      'faible': '#6bcf7f',
      'Faible': '#6bcf7f',
      'moyen': '#ffc107',
      'Moyen': '#ffc107',
      'eleve': '#fd7e14',
      'Élevé': '#fd7e14',
      'tres_eleve': '#dc3545',
      'Très élevé': '#dc3545'
    };
    return colors[riskLevel] || '#6c757d';
  }

  private showNotification(message: string, type: 'success' | 'error'): void {
    alert(message);
  }
}