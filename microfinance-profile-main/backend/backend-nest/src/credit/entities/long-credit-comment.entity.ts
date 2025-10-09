// entities/long-credit-comment.entity.ts
import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, ManyToOne, JoinColumn } from 'typeorm';
import { LongCreditRequestEntity } from './long-credit-request.entity';

@Entity('demandes_credit_longues_comments')
export class LongCreditCommentEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'long_credit_request_id' })
  longCreditRequestId: number;

  @ManyToOne(() => LongCreditRequestEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'long_credit_request_id' })
  longCreditRequest: LongCreditRequestEntity;

  @Column({ name: 'author_name' })
  authorName: string;

  @Column({ name: 'author_id', nullable: true })
  authorId: number;

  @Column({ name: 'comment_type', default: 'general' })
  commentType: string;

  @Column({ type: 'text' })
  content: string;

  @Column({ name: 'is_private', default: false })
  isPrivate: boolean;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
