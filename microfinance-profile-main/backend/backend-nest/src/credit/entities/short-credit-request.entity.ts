import { Column, CreateDateColumn, Entity, OneToMany, PrimaryGeneratedColumn, UpdateDateColumn } from "typeorm";
import { PaymentRecord } from "./payment-record.entity";

// short-credit-request.entity.ts
@Entity('short_credit_requests')
export class ShortCreditRequest {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  username: string;

  @Column()
  creditType: string;

  @Column('decimal', { precision: 12, scale: 2 })
  amount: number;

  @Column('decimal', { precision: 12, scale: 2 })
  totalAmount: number;

  @Column('decimal', { precision: 12, scale: 2 })
  remainingAmount: number;

  @Column('decimal', { precision: 5, scale: 4 })
  interestRate: number;

  @Column({
    type: 'enum',
    enum: ['active', 'paid', 'overdue'],
    default: 'active'
  })
  status: string;

  @Column({ type: 'timestamp' })
  approvedDate: Date;

  @Column({ type: 'timestamp' })
  dueDate: Date;

  @Column({ type: 'timestamp', nullable: true })
  nextPaymentDate: Date;

  @Column('decimal', { precision: 12, scale: 2, nullable: true })
  nextPaymentAmount: number;

  @Column('decimal', { precision: 12, scale: 2 })
  disbursedAmount: number;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;

  // Relations
  @OneToMany(() => PaymentRecord, payment => payment.shortCreditRequest)
  payments: PaymentRecord[];
}