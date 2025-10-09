import { Column, CreateDateColumn, Entity, JoinColumn, ManyToOne, PrimaryGeneratedColumn } from "typeorm";
import { LongCreditRequestEntity } from "./long-credit-request.entity";

@Entity('demandes_credit_longues_documents')
export class LongCreditDocumentEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'long_credit_request_id' })
  longCreditRequestId: number;

  @ManyToOne(() => LongCreditRequestEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'long_credit_request_id' })
  longCreditRequest: LongCreditRequestEntity;

  @Column({ name: 'document_type' })
  documentType: string;

  @Column({ name: 'document_name' })
  documentName: string;

  @Column({ name: 'original_filename' })
  originalFilename: string;

  @Column({ name: 'file_path' })
  filePath: string;

  @Column({ name: 'file_size', type: 'bigint' })
  fileSize: number;

  @Column({ name: 'mime_type' })
  mimeType: string;

  @Column({ name: 'is_required', default: false })
  isRequired: boolean;

  @Column({ name: 'uploaded_by', nullable: true })
  uploadedBy: number;

  @Column({ nullable: true })
  checksum: string;

  @CreateDateColumn({ name: 'uploaded_at' })
  uploadedAt: Date;
}