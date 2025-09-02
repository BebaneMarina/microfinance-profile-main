import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type DocumentStorageDocument = DocumentStorage & Document;

@Schema({ 
  timestamps: true,
  collection: 'documents'
})
export class DocumentStorage {
  @Prop({ required: true, index: true })
  creditRequestId: number;

  @Prop({ required: true, index: true })
  userId: number;

  @Prop({ required: true })
  documentType: string;

  @Prop({ required: true })
  fileName: string;

  @Prop({ required: true })
  fileUrl: string;

  @Prop()
  fileSize: number;

  @Prop()
  mimeType: string;

  @Prop({ type: Object })
  metadata: {
    uploadedBy: string;
    uploadedAt: Date;
    source: string;
    ipAddress?: string;
  };

  @Prop({ type: Object })
  ocrData: Record<string, any>;

  @Prop({ type: Object })
  verificationStatus: {
    isVerified: boolean;
    verifiedBy?: string;
    verifiedAt?: Date;
    verificationMethod?: string;
    verificationNotes?: string;
    anomalies?: string[];
    confidence?: number;
  };

  @Prop({ default: 'active' })
  status: string;

  @Prop({ type: Object })
  extractedData: Record<string, any>;
}

export const DocumentStorageSchema = SchemaFactory.createForClass(DocumentStorage);

// Index composé pour les recherches fréquentes
DocumentStorageSchema.index({ creditRequestId: 1, documentType: 1 });
DocumentStorageSchema.index({ userId: 1, status: 1 });