// models/dashboard.models.ts

export interface DashboardStats {
  rejectedRequests: number;
  approvedRequests: number;
  pendingRequests: number;
  totalRequests: number;
  availableBalance: number;
  activeCredits: number;
  creditScore: CreditScore;
  notifications: number;
  monthlyTrend?: number;
}

export interface CreditScore {
  value: number;
  max: number;
  rating: 'Excellent' | 'Très bon' | 'Bon' | 'Moyen' | 'Faible';
}

export interface RecentActivity {
  id: string;
  type: ActivityType;
  title: string;
  description: string;
  amount?: number;
  date: Date;
  status: ActivityStatus;
  creditId?: string;
}

export type ActivityType = 'payment' | 'approval' | 'rejection' | 'reminder' | 'disbursement' | 'application';

export type ActivityStatus = 'success' | 'warning' | 'error' | 'info' | 'pending';

export interface UpcomingPayment {
  id: string;
  creditType: string;
  amount: number;
  dueDate: Date;
  daysUntilDue: number;
  status: PaymentStatus;
  creditId: string;
  isOverdue?: boolean;
}

export type PaymentStatus = 'urgent' | 'normal' | 'overdue';

export interface QuickAction {
  id: string;
  label: string;
  icon: string;
  route?: string;
  action?: string;
  isVisible: boolean;
  badge?: number;
}

export interface NotificationItem {
  id: string;
  title: string;
  message: string;
  type: NotificationType;
  date: Date;
  isRead: boolean;
  actionUrl?: string;
}

export type NotificationType = 'payment' | 'approval' | 'document' | 'system' | 'promotion';

// Interface pour les données complètes du dashboard
export interface DashboardData {
  stats: DashboardStats;
  recentActivities: RecentActivity[];
  upcomingPayments: UpcomingPayment[];
  notifications: NotificationItem[];
  quickActions: QuickAction[];
}

// Interface pour les réponses API
export interface DashboardResponse {
  success: boolean;
  data: DashboardData;
  message?: string;
  error?: string;
}

// Énumérations pour les constantes
export enum CreditType {
  PERSONAL = 'Crédit Personnel',
  HOME = 'Crédit Immobilier',
  AUTO = 'Crédit Auto',
  BUSINESS = 'Crédit Professionnel',
  EDUCATION = 'Crédit Étudiant'
}

export enum PaymentMethod {
  BANK_TRANSFER = 'Virement bancaire',
  MOBILE_MONEY = 'Mobile Money',
  CASH = 'Espèces',
  CHECK = 'Chèque'
}

// Types utilitaires
export type CurrencyCode = 'XAF' | 'EUR' | 'USD';

export interface Currency {
  code: CurrencyCode;
  symbol: string;
  name: string;
}

// Configuration du dashboard
export interface DashboardConfig {
  refreshInterval: number; // en millisecondes
  maxRecentActivities: number;
  maxUpcomingPayments: number;
  maxNotifications: number;
  currency: Currency;
  dateFormat: string;
  timeFormat: string;
}