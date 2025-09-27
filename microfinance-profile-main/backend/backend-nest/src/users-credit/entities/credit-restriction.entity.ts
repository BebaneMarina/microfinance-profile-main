// user-credits/entities/credit-restriction.entity.ts
import { Entity, Column, PrimaryGeneratedColumn, CreateDateColumn, UpdateDateColumn, Index } from 'typeorm';

@Entity('credit_restrictions')
export class CreditRestriction {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true })
  @Index()
  username: string;

  @Column({ default: true, name: 'can_apply_for_credit' })
  canApplyForCredit: boolean;

  @Column({ default: 2, name: 'max_credits_allowed' })
  maxCreditsAllowed: number;

  @Column({ default: 0, name: 'active_credit_count' })
  activeCreditCount: number;

  @Column('decimal', { precision: 12, scale: 2, default: 0, name: 'total_active_debt' })
  totalActiveDebt: number;

  @Column('decimal', { precision: 5, scale: 2, default: 0, name: 'debt_ratio' })
  debtRatio: number;

  @Column({ nullable: true, name: 'next_eligible_date' })
  nextEligibleDate?: string;

  @Column({ nullable: true, name: 'last_application_date' })
  lastApplicationDate?: string;

  @Column({ nullable: true, name: 'blocking_reason' })
  blockingReason?: string;

  @Column({ default: 0, name: 'days_until_next_application' })
  daysUntilNextApplication: number;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}