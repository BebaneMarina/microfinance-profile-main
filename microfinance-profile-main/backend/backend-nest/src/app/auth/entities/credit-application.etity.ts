import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn } from 'typeorm';

@Entity('credit_applications')
export class CreditApplication {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  creditType: string;

  @Column('float')
  amount: number;

  @Column()
  duration: number;

  @Column('text')
  purpose: string;

  @Column('float')
  monthlyIncome: number;

  @Column()
  incomeType: string;

  @Column('float', { default: 0 })
  otherIncome: number;

  @Column('float')
  monthlyExpenses: number;

  @Column('float', { default: 0 })
  existingDebts: number;

  @Column()
  guarantorName: string;

  @Column()
  guarantorPhone: string;

  @Column()
  guarantorAddress: string;

  @Column({ nullable: true })
  collateral: string;

  @Column('float', { default: 0 })
  collateralValue: number;

  @Column({ default: false })
  hasIdDocument: boolean;

  @Column({ default: false })
  hasIncomeProof: boolean;

  @Column({ default: false })
  hasGuarantorId: boolean;

  @Column({ default: false })
  hasProofOfResidence: boolean;

  @Column('text', { nullable: true })
  additionalNotes: string;

  @Column('float', { default: 0 })
  score: number;

  @Column({ default: 'unknown' })
  riskLevel: string;

  @Column('float', { default: 0 })
  probabilityDefault: number;

  @Column({ default: 'submitted' })
  status: string;

  @CreateDateColumn()
  createdAt: Date;
}
