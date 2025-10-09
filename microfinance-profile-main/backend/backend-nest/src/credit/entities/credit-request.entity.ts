import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn, CreateDateColumn, UpdateDateColumn } from 'typeorm';
import { Utilisateur } from '../../app/auth/entities/user.entity';

// Enums
export enum RequestStatus {
  DRAFT = 'draft',
  SUBMITTED = 'submitted',
  IN_REVIEW = 'in_review',
  APPROVED = 'approved',
  REJECTED = 'rejected',
  CANCELLED = 'cancelled',
  DISBURSED = 'disbursed',
  COMPLETED = 'completed'
}

export enum CreditType {
  CONSOMMATION = 'consommation_generale',
  AVANCE_SALAIRE = 'avance_salaire',
  DEPANNAGE = 'depannage',
  INVESTISSEMENT = 'investissement',
  AVANCE_FACTURE = 'avance_facture',
  AVANCE_COMMANDE = 'avance_commande',
  TONTINE = 'tontine',
  RETRAITE = 'retraite',
  SPOT = 'spot'
}

export enum RiskLevel {
  VERY_LOW = 'very_low',
  LOW = 'low',
  MEDIUM = 'medium',
  HIGH = 'high',
  VERY_HIGH = 'very_high'
}

@Entity('credit_requests')
export class CreditRequest {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ unique: true })
  request_number: string;

  @Column()
  user_id: number;

  @Column({
    type: 'enum',
    enum: CreditType
  })
  credit_type: CreditType;

  @Column({
    type: 'enum',
    enum: RequestStatus,
    default: RequestStatus.DRAFT
  })
  status: RequestStatus;

  @Column({ type: 'decimal', precision: 12, scale: 2 })
  requested_amount: number;

  @Column({ type: 'decimal', precision: 12, scale: 2, nullable: true })
  approved_amount?: number;

  @Column()
  duration_months: number;

  @Column({ type: 'decimal', precision: 5, scale: 2, nullable: true })
  interest_rate?: number;

  @Column()
  purpose: string;

  @Column({ nullable: true })
  repayment_mode?: string;

  @Column({ nullable: true })
  repayment_frequency?: string;

  @Column({ nullable: true })
  credit_score?: number;

  @Column({
    type: 'enum',
    enum: RiskLevel,
    nullable: true
  })
  risk_level?: RiskLevel;

  @Column({ type: 'decimal', precision: 5, scale: 2, nullable: true })
  probability?: number;

  @Column({ nullable: true })
  decision?: string;

  @Column({ nullable: true })
  decision_date?: Date;

  @Column({ nullable: true })
  decision_by?: number;

  @Column({ nullable: true })
  decision_notes?: string;

  @Column({ nullable: true })
  submission_date?: Date;

  @CreateDateColumn()
  created_at: Date;

  @UpdateDateColumn()
  updated_at: Date;

  // Relations
  @ManyToOne(() => Utilisateur, user => user.creditRequests)
  @JoinColumn({ name: 'user_id' })
  user: Utilisateur;

  // Propriétés virtuelles pour compatibilité
  recommendations?: string[];
  scoringFactors?: any[];

  // Getters pour la compatibilité camelCase
  get userId(): number {
    return this.user_id;
  }

  set userId(value: number) {
    this.user_id = value;
  }

  get requestNumber(): string {
    return this.request_number;
  }

  set requestNumber(value: string) {
    this.request_number = value;
  }

  get creditType(): CreditType {
    return this.credit_type;
  }

  set creditType(value: CreditType) {
    this.credit_type = value;
  }

  get requestedAmount(): number {
    return this.requested_amount;
  }

  set requestedAmount(value: number) {
    this.requested_amount = value;
  }

  get approvedAmount(): number | undefined {
    return this.approved_amount;
  }

  set approvedAmount(value: number | undefined) {
    this.approved_amount = value;
  }

  get durationMonths(): number {
    return this.duration_months;
  }

  set durationMonths(value: number) {
    this.duration_months = value;
  }

  get creditScore(): number | undefined {
    return this.credit_score;
  }

  set creditScore(value: number | undefined) {
    this.credit_score = value;
  }

  get riskLevel(): RiskLevel | undefined {
    return this.risk_level;
  }

  set riskLevel(value: RiskLevel | undefined) {
    this.risk_level = value;
  }

  get decisionDate(): Date | undefined {
    return this.decision_date;
  }

  set decisionDate(value: Date | undefined) {
    this.decision_date = value;
  }

  get decisionBy(): number | undefined {
    return this.decision_by;
  }

  set decisionBy(value: number | undefined) {
    this.decision_by = value;
  }

  get submissionDate(): Date | undefined {
    return this.submission_date;
  }

  set submissionDate(value: Date | undefined) {
    this.submission_date = value;
  }

  get decisionNotes(): string | undefined {
    return this.decision_notes;
  }

  set decisionNotes(value: string | undefined) {
    this.decision_notes = value;
  }
}