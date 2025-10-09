import { 
  Entity, 
  Column, 
  PrimaryGeneratedColumn, 
  ManyToOne,
  JoinColumn,
  CreateDateColumn, 
  UpdateDateColumn 
} from 'typeorm';
import { Utilisateur } from '../../app/auth/entities/user.entity';

export enum LongCreditStatus {
  DRAFT = 'draft',
  SUBMITTED = 'soumise',
  IN_REVIEW = 'in_review',
  REQUIRES_INFO = 'requires_info',
  APPROVED = 'approved',
  REJECTED = 'rejected',
  CANCELLED = 'cancelled',
  DISBURSED = 'disbursed'
}

export enum TypeCredit {
  CONSOMMATION_GENERALE = 'consommation_generale',
  AUTOMOBILE = 'automobile',
  IMMOBILIER = 'immobilier',
  EDUCATION = 'education',
  TRAVAUX = 'travaux',
  PROFESSIONNEL = 'professionnel'
}

export enum NiveauRisque {
  TRES_FAIBLE = 'tres_faible',
  FAIBLE = 'faible',
  MOYEN = 'moyen',
  ELEVE = 'eleve',
  TRES_ELEVE = 'tres_eleve'
}

@Entity('demandes_credit_longues')
export class LongCreditRequestEntity {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ 
    name: 'numero_demande', 
    type: 'varchar',
    length: 50,
    unique: true 
  })
  requestNumber: string;

  // Relation avec utilisateurs
  @Column({ name: 'utilisateur_id' })
  userId: number;

  @ManyToOne(() => Utilisateur, { eager: false })
  @JoinColumn({ name: 'utilisateur_id' })
  utilisateur: Utilisateur;

  // Username pour recherche rapide
  @Column({ 
    type: 'varchar',
    length: 255,
    nullable: true 
  })
  username: string;

  // Type et montant - utilise l'ENUM PostgreSQL
  @Column({ 
    name: 'type_credit',
    type: 'enum',
    enum: TypeCredit,
    enumName: 'type_credit' // Nom de l'enum dans PostgreSQL
  })
  creditType: TypeCredit;

  @Column({ 
    name: 'montant_demande', 
    type: 'decimal', 
    precision: 12, 
    scale: 2 
  })
  requestedAmount: number;

  @Column({ name: 'duree_mois', type: 'integer' })
  duration: number;

  @Column({ name: 'objectif', type: 'text' })
  purpose: string;

  // Statut et workflow
  @Column({ 
    name: 'statut',
    type: 'varchar',
    length: 50,
    default: 'soumise'
  })
  status: string;

  @Column({ 
    name: 'date_soumission', 
    type: 'timestamp',
    default: () => 'now()'
  })
  submissionDate: Date;

  @Column({ name: 'date_decision', type: 'timestamp', nullable: true })
  decisionDate: Date;

  @Column({ name: 'decideur_id', nullable: true })
  decisionBy: number;

  @ManyToOne(() => Utilisateur, { eager: false })
  @JoinColumn({ name: 'decideur_id' })
  decideur: Utilisateur;

  // Décision
  @Column({ 
    name: 'montant_approuve', 
    type: 'decimal', 
    precision: 12, 
    scale: 2,
    nullable: true 
  })
  approvedAmount: number;

  @Column({ 
    name: 'taux_approuve', 
    type: 'decimal', 
    precision: 5, 
    scale: 2,
    nullable: true 
  })
  approvedRate: number;

  @Column({ name: 'notes_decision', type: 'text', nullable: true })
  decisionNotes: string;

  @Column({ 
    type: 'varchar',
    length: 255,
    nullable: true 
  })
  decision: string;

  // Scoring au moment de la demande
  @Column({ 
    name: 'score_au_moment_demande',
    type: 'decimal',
    precision: 3,
    scale: 1,
    nullable: true
  })
  scoreAtSubmission: number;

  @Column({ 
    name: 'niveau_risque_evaluation',
    type: 'enum',
    enum: NiveauRisque,
    enumName: 'niveau_risque', // Nom de l'enum dans PostgreSQL
    nullable: true
  })
  riskLevel: NiveauRisque;

  // Données JSON pour flexibilité
  @Column({ name: 'personal_info', type: 'jsonb', nullable: true })
  personalInfo: {
    fullName: string;
    email: string;
    phone: string;
    address: string;
    profession: string;
    company: string;
    maritalStatus?: string;
    dependents?: number;
  };

  @Column({ name: 'credit_details', type: 'jsonb', nullable: true })
  creditDetails: {
    requestedAmount: number;
    duration: number;
    purpose: string;
    repaymentFrequency: string;
    preferredRate?: number;
    guarantors?: any[];
  };

  @Column({ name: 'financial_details', type: 'jsonb', nullable: true })
  financialDetails: {
    monthlyIncome: number;
    monthlyExpenses: number;
    otherIncomes?: any[];
    existingLoans?: any[];
    assets?: any[];
    employmentDetails?: {
      employer: string;
      position: string;
      seniority: number;
      contractType: string;
      netSalary: number;
      grossSalary: number;
    };
  };

  @Column({ name: 'documents', type: 'jsonb', nullable: true })
  documents: Record<string, boolean>;

  @Column({ name: 'simulation_results', type: 'jsonb', nullable: true })
  simulationResults: {
    calculatedScore: number;
    riskLevel: string;
    recommendedAmount: number;
    suggestedRate: number;
    monthlyPayment: number;
    totalInterest: number;
    debtToIncomeRatio: number;
    approvalProbability: number;
  };

  @Column({ name: 'special_conditions', type: 'text', nullable: true })
  specialConditions: string;

  @Column({ name: 'assigned_to', nullable: true })
  assignedTo: number;

  @Column({ name: 'review_started_date', type: 'timestamp', nullable: true })
  reviewStartedDate: Date;

  @Column({ name: 'created_by', nullable: true })
  createdBy: number;

  // Timestamps
  @CreateDateColumn({ 
    name: 'date_creation',
    type: 'timestamp',
    default: () => 'now()'
  })
  createdAt: Date;

  @UpdateDateColumn({ 
    name: 'date_modification',
    type: 'timestamp',
    default: () => 'now()'
  })
  updatedAt: Date;
}