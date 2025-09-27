import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, ManyToOne, JoinColumn } from 'typeorm';
import { LongCreditRequestEntity } from './long-credit-request.entity';

@Entity('long_credit_review_history')
export class LongCreditReviewHistoryEntity {
  @PrimaryGeneratedColumn()  // ✅ INTEGER au lieu de UUID
  id: number;

  @Column({ name: 'long_credit_request_id' })
  longCreditRequestId: number;  // ✅ INTEGER

  @Column()
  action: string;

  @Column({ name: 'previous_status', nullable: true })
  previousStatus?: string;

  @Column({ name: 'new_status', nullable: true })
  newStatus?: string;

  @Column({ name: 'agent_name' })
  agentName: string;

  @Column({ name: 'agent_id', nullable: true })
  agentId?: number;

  @Column({ type: 'text', nullable: true })
  comment?: string;

  @CreateDateColumn({ name: 'action_date' })
  actionDate: Date;

  @ManyToOne(() => LongCreditRequestEntity, request => request.reviewHistory, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'long_credit_request_id' })
  longCreditRequest: LongCreditRequestEntity;
}