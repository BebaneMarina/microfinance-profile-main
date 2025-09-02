import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { AuditLog } from '../entities/audit-log.entity';
import { AuditTrail, AuditTrailDocument } from '../schema/audit-trails.schema';

@Injectable()
export class AuditService {
  private readonly logger = new Logger(AuditService.name);

  constructor(
    @InjectRepository(AuditLog)
    private auditLogRepository: Repository<AuditLog>,
    @InjectModel(AuditTrail.name)
    private auditTrailModel: Model<AuditTrailDocument>,
  ) {}

  // Enregistrer dans PostgreSQL (pour requêtes simples)
  async logToPostgres(data: {
    userId?: number;
    action: string;
    module: string;
    entityType?: string;
    entityId?: number;
    changes?: any;
    ipAddress?: string;
    userAgent?: string;
  }): Promise<AuditLog> {
    const auditLog = this.auditLogRepository.create(data);
    return this.auditLogRepository.save(auditLog);
  }

  // Enregistrer dans MongoDB (pour données détaillées)
  async logToMongoDB(data: {
    userId: number;
    userEmail: string;
    action: string;
    module: string;
    entityType: string;
    entityId: string;
    changes?: any;
    context?: any;
    metadata?: any;
  }): Promise<AuditTrailDocument> {
    const auditTrail = new this.auditTrailModel({
      ...data,
      severity: this.determineSeverity(data.action),
    });
    
    return auditTrail.save();
  }

  // Enregistrer dans les deux bases
  async log(data: any): Promise<void> {
    try {
      // PostgreSQL pour les requêtes rapides
      await this.logToPostgres({
        userId: data.userId,
        action: data.action,
        module: data.module,
        entityType: data.entityType,
        entityId: data.entityId,
        changes: data.changes,
        ipAddress: data.context?.ipAddress,
        userAgent: data.context?.userAgent,
      });

      // MongoDB pour les détails complets
      await this.logToMongoDB(data);

      this.logger.debug(`Audit logged: ${data.action} by user ${data.userId}`);
    } catch (error) {
      this.logger.error('Failed to log audit', error);
    }
  }

  private determineSeverity(action: string): string {
    const criticalActions = ['delete', 'approve_credit', 'disbursement'];
    const highActions = ['update_amount', 'change_status', 'verify_document'];
    const mediumActions = ['update', 'create'];
    
    if (criticalActions.includes(action.toLowerCase())) return 'critical';
    if (highActions.includes(action.toLowerCase())) return 'high';
    if (mediumActions.includes(action.toLowerCase())) return 'medium';
    return 'low';
  }

  async getAuditTrail(filters: {
    userId?: number;
    module?: string;
    action?: string;
    startDate?: Date;
    endDate?: Date;
  }): Promise<AuditTrailDocument[]> {
    const query: any = {};

    if (filters.userId) query.userId = filters.userId;
    if (filters.module) query.module = filters.module;
    if (filters.action) query.action = filters.action;
    
    if (filters.startDate || filters.endDate) {
      query.createdAt = {};
      if (filters.startDate) query.createdAt.$gte = filters.startDate;
      if (filters.endDate) query.createdAt.$lte = filters.endDate;
    }

    return this.auditTrailModel
      .find(query)
      .sort({ createdAt: -1 })
      .limit(1000)
      .exec();
  }
}