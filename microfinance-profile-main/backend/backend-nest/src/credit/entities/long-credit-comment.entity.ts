// entities/long-credit-comment.entity.ts
import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, ManyToOne, JoinColumn } from 'typeorm';
import { LongCreditRequestEntity } from './long-credit-request.entity';

@Entity('long_credit_comments')
export class LongCreditCommentEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'long_credit_request_id' })
  longCreditRequestId: number;  // ✅ INTEGER (pas string)

  @Column({ name: 'author_name' })
  authorName: string;

  @Column({ name: 'author_id', nullable: true })
  authorId?: number;

  @Column({ name: 'comment_type', default: 'general' })
  commentType: string;

  @Column('text')
  content: string;

  @Column({ name: 'is_private', default: false })
  isPrivate: boolean;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @ManyToOne(() => LongCreditRequestEntity, request => request.comments, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'long_credit_request_id' })
  longCreditRequest: LongCreditRequestEntity;
}