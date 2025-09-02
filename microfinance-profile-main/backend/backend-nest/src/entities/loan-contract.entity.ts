import { Entity, Column, PrimaryGeneratedColumn, ManyToOne, JoinColumn, CreateDateColumn, UpdateDateColumn } from 'typeorm';
import { User } from '../app/auth/entities/user.entity';
import { CreditRequest } from '../credit/entities/credit-request.entity';

@Entity('loan_contracts')
export class LoanContract {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ unique: true })
  contract_number: string;

  @Column()
  credit_request_id: number;

  @ManyToOne(() => CreditRequest)
  @JoinColumn({ name: 'credit_request_id' })
  creditRequest: CreditRequest;

  @Column()
  user_id: number;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column('decimal', { precision: 12, scale: 2 })
  loan_amount: number;

  @Column('decimal', { precision: 5, scale: 2 })
  interest_rate: number;

  @Column()
  duration_months: number;

  @Column('decimal', { precision: 12, scale: 2 })
  monthly_payment: number;

  @Column('decimal', { precision: 12, scale: 2 })
  total_amount: number;

  @Column('decimal', { precision: 12, scale: 2 })
  total_interest: number;

  @Column('date')
  start_date: Date;

  @Column('date')
  end_date: Date;

  @Column('date')
  first_payment_date: Date;

  @Column({ default: 'active' })
  status: string;

  @Column('date', { nullable: true })
  early_settlement_date: Date;

  @Column('decimal', { precision: 12, scale: 2, nullable: true })
  early_settlement_amount: number;

  @Column('timestamp', { nullable: true })
  signed_date: Date;

  @Column({ nullable: true })
  signature_method: string;

  @CreateDateColumn()
  created_at: Date;

  @UpdateDateColumn()
  updated_at: Date;
}