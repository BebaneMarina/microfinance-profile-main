import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, ManyToOne, JoinColumn } from 'typeorm';
import { LongCreditRequestEntity } from './long-credit-request.entity';

@Entity('demandes_credit_longues_history')
export class LongCreditReviewHistoryEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'long_credit_request_id' })
  longCreditRequestId: number;

  @ManyToOne(() => LongCreditRequestEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'long_credit_request_id' })
  longCreditRequest: LongCreditRequestEntity;

  @Column()
  action: string;

  @Column({ name: 'previous_status', nullable: true })
  previousStatus: string;

  @Column({ name: 'new_status', nullable: true })
  newStatus: string;

  @Column({ name: 'agent_name' })
  agentName: string;

  @Column({ name: 'agent_id', nullable: true })
  agentId: number;

  @Column({ type: 'text', nullable: true })
  comment: string;

  @CreateDateColumn({ name: 'action_date' })
  actionDate: Date;
}
