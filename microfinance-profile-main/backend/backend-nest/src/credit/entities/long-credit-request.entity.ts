// entities/long-credit-request.entity.ts
import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, UpdateDateColumn, ManyToOne, OneToMany, JoinColumn } from 'typeorm';
import { User } from '../../app/auth/entities/user.entity';
import { LongCreditReviewHistoryEntity } from './long-credit-review-history.entity';
import { LongCreditDocumentEntity } from './long-credit-document.entity';
import { LongCreditCommentEntity } from './long-credit-comment.entity';

export enum LongCreditStatus {
  DRAFT = 'draft',
  SUBMITTED = 'submitted',
  IN_REVIEW = 'in_review',
  REQUIRES_INFO = 'requires_info',
  APPROVED = 'approved',
  REJECTED = 'rejected',
  CANCELLED = 'cancelled',
  DISBURSED = 'disbursed',
  COMPLETED = 'completed'
}

@Entity('long_credit_requests')
export class LongCreditRequestEntity {
  @PrimaryGeneratedColumn()  // ✅ INTEGER au lieu de UUID
  id: number;

  @Column({ unique: true, nullable: true })
  requestNumber: string;

  @Column()
  username: string;

  @Column()
  userId: number;

  @Column({
    type: 'varchar',
    default: LongCreditStatus.DRAFT
  })
  status: string;

  @Column('jsonb')
  personalInfo: any;

  @Column('jsonb')
  creditDetails: any;

  @Column('jsonb')
  financialDetails: any;

  @Column('jsonb', { default: {} })
  documents: any;

  @Column('jsonb', { nullable: true })
  simulationResults: any;

  @Column({ nullable: true })
  submissionDate: Date;

  @Column({ nullable: true })
  reviewStartedDate: Date;

  @Column({ nullable: true })
  decisionDate: Date;

  @Column({ nullable: true })
  decisionBy: number;

  @Column({ nullable: true })
  decision: string;

  @Column('text', { nullable: true })
  decisionNotes: string;

  @Column('decimal', { precision: 12, scale: 2, nullable: true })
  approvedAmount: number;

  @Column('decimal', { precision: 5, scale: 2, nullable: true })
  approvedRate: number;

  @Column({ nullable: true })
  approvedDuration: number;

  @Column('text', { nullable: true })
  specialConditions: string;

  @Column({ nullable: true })
  assignedTo: number;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;

  @Column({ nullable: true })
  createdBy: number;

  // ✅ Relations corrigées
  @ManyToOne(() => User)
  @JoinColumn({ name: 'userId' })
  user: User;

  @OneToMany(() => LongCreditReviewHistoryEntity, history => history.longCreditRequest)
  reviewHistory: LongCreditReviewHistoryEntity[];

  @OneToMany(() => LongCreditDocumentEntity, doc => doc.longCreditRequest)
  documentsList: LongCreditDocumentEntity[];  // ✅ Nom cohérent avec long-credit-document.entity

  @OneToMany(() => LongCreditCommentEntity, comment => comment.longCreditRequest)
  comments: LongCreditCommentEntity[];
}