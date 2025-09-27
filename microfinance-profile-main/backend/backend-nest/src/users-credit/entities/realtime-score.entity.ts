// user-credits/entities/realtime-score.entity.ts
import { Entity, Column, PrimaryGeneratedColumn, CreateDateColumn, Index } from 'typeorm';

@Entity('realtime_scores')
export class RealtimeScore {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  @Index()
  username: string;

  @Column('decimal', { precision: 3, scale: 1 })
  score: number;

  @Column('decimal', { precision: 3, scale: 1, nullable: true, name: 'previous_score' })
  previousScore?: number;

  @Column({ name: 'risk_level' })
  riskLevel: string;

  @Column('jsonb', { default: [] })
  factors: any[];

  // ✅ CORRECTION : Utiliser text[] au lieu de simple-array
  @Column('text', { array: true, default: '{}' })
  recommendations: string[];

  @Column({ default: true, name: 'is_real_time' })
  isRealTime: boolean;

  @Column('decimal', { precision: 3, scale: 1, default: 0, name: 'score_change' })
  scoreChange: number;

  @Column('jsonb', { nullable: true, name: 'payment_analysis' })
  paymentAnalysis?: any;

  @CreateDateColumn({ name: 'last_updated' })
  lastUpdated: Date;
}