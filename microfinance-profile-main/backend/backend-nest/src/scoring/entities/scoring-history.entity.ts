import { Entity, Column, PrimaryGeneratedColumn, CreateDateColumn } from 'typeorm';

@Entity('scoring_history')
export class ScoringHistory {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'client_id' })
  clientId: string;

  @Column({ name: 'scoring_id' })
  scoringId: string;

  @Column({ name: 'score', type: 'decimal', precision: 6, scale: 2 })
  score: number;

  @Column({ name: 'decision' })
  decision: string;

  @CreateDateColumn({ name: 'timestamp' })
  timestamp: Date;
}