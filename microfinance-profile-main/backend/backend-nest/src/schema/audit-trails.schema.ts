import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type AuditTrailDocument = AuditTrail & Document;

@Schema({ 
  timestamps: { createdAt: true, updatedAt: false },
  collection: 'audit_trails'
})
export class AuditTrail {
  @Prop({ required: true, index: true })
  userId: number;

  @Prop({ required: true })
  userEmail: string;

  @Prop({ required: true, index: true })
  action: string;

  @Prop({ required: true, index: true })
  module: string;

  @Prop({ required: true })
  entityType: string;

  @Prop({ required: true })
  entityId: string;

  @Prop({ type: Object })
  changes: {
    before: Record<string, any>;
    after: Record<string, any>;
    diff?: Record<string, any>;
  };

  @Prop({ type: Object })
  context: {
    ipAddress: string;
    userAgent: string;
    browser?: string;
    os?: string;
    device?: string;
    location?: {
      country?: string;
      city?: string;
      coordinates?: {
        lat: number;
        lng: number;
      };
    };
  };

  @Prop({ type: Object })
  metadata: Record<string, any>;

  @Prop()
  severity: string; // 'low', 'medium', 'high', 'critical'

  @Prop({ default: false })
  flagged: boolean;

  @Prop()
  notes: string;
}

export const AuditTrailSchema = SchemaFactory.createForClass(AuditTrail);

// Index pour les recherches par date
AuditTrailSchema.index({ createdAt: -1 });
AuditTrailSchema.index({ userId: 1, createdAt: -1 });
AuditTrailSchema.index({ action: 1, module: 1 });