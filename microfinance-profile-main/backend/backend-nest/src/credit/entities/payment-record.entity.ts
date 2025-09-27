import { Column, CreateDateColumn, Entity, ManyToOne, PrimaryGeneratedColumn } from "typeorm";
import { ShortCreditRequest } from "./short-credit-request.entity";

// payment-record.entity.ts
@Entity('payment_records')
export class PaymentRecord {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column('decimal', { precision: 12, scale: 2 })
  amount: number;

  @Column({ type: 'timestamp' })
  date: Date;

  @Column({
    type: 'enum',
    enum: ['partial', 'full'],
    default: 'partial'
  })
  type: string;

  @Column({ default: false })
  late: boolean;

  @Column({ default: 0 })
  daysLate: number;

  // Relations
  @ManyToOne(() => ShortCreditRequest, credit => credit.payments)
  shortCreditRequest: ShortCreditRequest;

  @CreateDateColumn()
  createdAt: Date;
}