import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn, CreateDateColumn } from 'typeorm';
import { Utilisateur } from '../../app/auth/entities/user.entity';
import { CreditRequest } from '../../credit/entities/credit-request.entity';

@Entity('credit_scoring')
export class CreditScoring {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ nullable: true })
  credit_request_id?: number;

  @Column()
  user_id: number;

  @Column()
  total_score: number;

  @Column()
  risk_level: string;

  @Column({ type: 'decimal', precision: 5, scale: 2, nullable: true })
  probability?: number;

  @Column({ nullable: true })
  decision?: string;

  @Column({ nullable: true })
  income_score?: number;

  @Column({ nullable: true })
  employment_score?: number;

  @Column({ nullable: true })
  debt_ratio_score?: number;

  @Column({ nullable: true })
  credit_history_score?: number;

  @Column({ nullable: true })
  behavioral_score?: number;

  @Column({ type: 'jsonb', nullable: true })
  factors?: any;

  @Column({ type: 'text', array: true, nullable: true })
  recommendations?: string[];

  @Column({ nullable: true })
  model_version?: string;

  @Column({ type: 'decimal', precision: 5, scale: 2, nullable: true })
  processing_time?: number;

  @CreateDateColumn()
  created_at: Date;

  @Column({ nullable: true })
  created_by?: number;

  // Relations
  @ManyToOne(() => Utilisateur)
  @JoinColumn({ name: 'user_id' })
  user: Utilisateur;

  @ManyToOne(() => CreditRequest)
  @JoinColumn({ name: 'credit_request_id' })
  creditRequest?: CreditRequest;
}