import { Entity } from 'typeorm';
import { Column } from 'typeorm';
import { PrimaryGeneratedColumn } from 'typeorm';

export enum RequestStatus {
  SUBMITTED = 'soumise',
  IN_REVIEW = 'en_examen',
  APPROVED = 'approuvee',
  REJECTED = 'rejetee',
  PENDING_DOCS = 'en_attente_documents'
}

export enum CreditType {
  CONSOMMATION = 'consommation_generale',
  AVANCE_SALAIRE = 'avance_salaire',
  DEPANNAGE = 'depannage',
  INVESTISSEMENT = 'investissement',
  TONTINE = 'tontine',
  RETRAITE = 'retraite'
}

export enum RiskLevel {
  VERY_LOW = 'tres_bas',
  LOW = 'bas',
  MEDIUM = 'moyen',
  HIGH = 'eleve',
  VERY_HIGH = 'tres_eleve'
}

@Entity('demandes_credit_longues')
export class CreditRequest {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'numero_demande' })
  numero_demande: string;

  @Column({ name: 'utilisateur_id' })
  user_id: number;

  @Column({ name: 'type_credit', type: 'enum', enum: CreditType })
  credit_type: CreditType;

  @Column({ name: 'montant_demande', type: 'decimal', precision: 12, scale: 2 })
  montant_demande: number;

  @Column({ name: 'duree_mois' })
  duree_mois: number;

  @Column({ name: 'objectif', type: 'text' })
  objectif: string;

  @Column({ type: 'varchar', length: 50, default: 'soumise' })
  statut: string;

  @Column({ name: 'date_soumission', type: 'timestamp', default: () => 'NOW()' })
  date_soumission: Date;

  @Column({ name: 'date_decision', type: 'timestamp', nullable: true })
  date_decision?: Date;

  @Column({ name: 'decideur_id', nullable: true })
  decideur_id?: number;

  @Column({ name: 'montant_approuve', type: 'decimal', precision: 12, scale: 2, nullable: true })
  montant_approuve?: number;

  @Column({ name: 'taux_approuve', type: 'decimal', precision: 5, scale: 2, nullable: true })
  taux_approuve?: number;

  @Column({ name: 'notes_decision', type: 'text', nullable: true })
  notes_decision?: string;

  @Column({ name: 'score_au_moment_demande', type: 'decimal', precision: 3, scale: 1, nullable: true })
  score_au_moment_demande?: number;

  @Column({ name: 'niveau_risque_evaluation', type: 'enum', enum: RiskLevel, nullable: true })
  niveau_risque_evaluation?: RiskLevel;

  @Column({ type: 'decimal', precision: 5, scale: 2, nullable: true })
  probability?: number;

  @Column({ type: 'varchar', length: 50, nullable: true })
  decision?: string;

  @Column({ name: 'date_creation', type: 'timestamp', default: () => 'NOW()' })
  date_creation: Date;

  @Column({ name: 'date_modification', type: 'timestamp', default: () => 'NOW()' })
  date_modification: Date;

  // Getters pour compatibilité avec l'ancien code
  get requestNumber(): string {
    return this.numero_demande;
  }

  get status(): string {
    return this.statut;
  }

  get submissionDate(): Date {
    return this.date_soumission;
  }

  get requested_amount(): number {
    return Number(this.montant_demande);
  }

  get approved_amount(): number | null {
    return this.montant_approuve ? Number(this.montant_approuve) : null;
  }

  get duration_months(): number {
    return this.duree_mois;
  }

  get purpose(): string {
    return this.objectif;
  }

  get creditScore(): number | undefined {
    return this.score_au_moment_demande ? Number(this.score_au_moment_demande) : undefined;
  }

  get riskLevel(): RiskLevel | undefined {
    return this.niveau_risque_evaluation;
  }

  get created_at(): Date {
    return this.date_creation;
  }

  get updated_at(): Date {
    return this.date_modification;
  }
}