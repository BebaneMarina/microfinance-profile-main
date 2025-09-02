// credit-request.model.ts
export interface CreditRequest {
  id: string;
  clientId: string;
  clientName: string;
  amount: number;
  duration: number;
  purpose: string;
  status: 'pending' | 'under_review' | 'approved' | 'rejected';
  riskLevel: string;
  createdAt: Date;
  updatedAt?: Date;
  agentComment?: string;
  
  // Propriétés utilisées dans le template
  creditType?: string;        // Utilisé dans le template
  score?: number;             // Score de crédit sur 1000
  requestDate?: Date;         // Date de la demande
}

export interface User {
  id: string;
  name: string;
}

export interface CreditStats {
  // Propriétés retournées par le service
  total: number;
  pending: number;
  approved: number;
  rejected: number;
  approvalRate: number;
  
  // Propriétés optionnelles pour la compatibilité
  underReview?: number;
  totalAmount?: number;
}

export interface AgentStats extends CreditStats {
  totalAssigned: number;
}

export interface CreditRequestTimeline {
  date: Date;
  event: string;
  description: string;
}
// Interface pour les stats d'agent qui étend CreditStats
export interface AgentStats extends CreditStats {
  totalAssigned: number;
}
export interface FilterCreditRequestDto {
  status?: string;
  minAmount?: number;
  maxAmount?: number;
  minDate?: Date;
  maxDate?: Date;
  riskLevel?: string;
  assignedTo?: string;
  sortBy?: string;
  sortOrder?: 'ASC' | 'DESC';
}

export interface DecisionCreditRequestDto {
  agentId: string;
  decision: boolean;
  notes?: string;
  approvedAmount?: number;
  approvedDuration?: number;
}