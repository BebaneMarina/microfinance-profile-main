// entities/long-credit-document.entity.ts
import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, ManyToOne, JoinColumn } from 'typeorm';
import { LongCreditRequestEntity } from './long-credit-request.entity';

@Entity('long_credit_documents')
export class LongCreditDocumentEntity {
  @PrimaryGeneratedColumn('uuid')  // ✅ OK - UUID pour l'id du document
  id: string;

  @Column({ name: 'long_credit_request_id', type: 'integer' })  // ✅ INTEGER pour la clé étrangère
  longCreditRequestId: number;

  @Column({ name: 'document_type' })
  documentType: string;

  @Column({ name: 'document_name' })
  documentName: string;

  @Column({ name: 'original_filename' })
  originalFilename: string;

  @Column({ name: 'file_path' })
  filePath: string;

  @Column({ name: 'file_size', type: 'integer' })  // ✅ INTEGER au lieu de bigint
  fileSize: number;

  @Column({ name: 'mime_type' })
  mimeType: string;

  @Column({ name: 'is_required', default: false })
  isRequired: boolean;

  @Column({ name: 'uploaded_by', nullable: true })
  uploadedBy: number;

  @CreateDateColumn({ name: 'uploaded_at' })
  uploadedAt: Date;

  @Column({ nullable: true })
  checksum: string;

  @ManyToOne(() => LongCreditRequestEntity, request => request.documentsList, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'long_credit_request_id' })
  longCreditRequest: LongCreditRequestEntity;
}