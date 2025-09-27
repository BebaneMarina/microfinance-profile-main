// user-credits/entities/user-credit.entity.ts
import { Entity, Column, PrimaryGeneratedColumn, CreateDateColumn, UpdateDateColumn, Index } from 'typeorm';

@Entity('user_credits')
@Index(['username', 'status'])
export class UserCredit {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  @Index()
  username: string;

  @Column()
  type: string;

  @Column('decimal', { precision: 12, scale: 2 })
  amount: number;

  @Column('decimal', { precision: 12, scale: 2, name: 'total_amount' })
  totalAmount: number;

  @Column('decimal', { precision: 12, scale: 2, name: 'remaining_amount' })
  remainingAmount: number;

  @Column('decimal', { precision: 5, scale: 2, name: 'interest_rate' })
  interestRate: number;

  @Column({ default: 'active' })
  status: string;

  @Column({ name: 'approved_date' })
  approvedDate: string;

  @Column({ name: 'due_date' })
  dueDate: string;

  @Column({ nullable: true, name: 'next_payment_date' })
  nextPaymentDate?: string;

  @Column('decimal', { precision: 12, scale: 2, nullable: true, name: 'next_payment_amount' })
  nextPaymentAmount?: number;

  @Column('jsonb', { default: [], name: 'payments_history' })
  paymentsHistory: any[];

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}