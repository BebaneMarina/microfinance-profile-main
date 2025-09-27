// credit-long-request.service.ts - VERSION FINALE CORRIGÉE
import { Injectable, BadRequestException, NotFoundException, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, FindManyOptions, Like } from 'typeorm';
import { HttpService } from '@nestjs/axios';
import { firstValueFrom } from 'rxjs';
import * as fs from 'fs/promises';
import * as path from 'path';
import { v4 as uuidv4 } from 'uuid';

import { LongCreditRequestEntity, LongCreditStatus } from './entities/long-credit-request.entity';
import { LongCreditDocumentEntity } from './entities/long-credit-document.entity';
import { LongCreditCommentEntity } from './entities/long-credit-comment.entity';
import { LongCreditReviewHistoryEntity } from './entities/long-credit-review-history.entity';
import { User } from '../app/auth/entities/user.entity';

import { 
  CreateLongCreditRequestDto,
  UpdateLongCreditRequestDto,
  SimulateCreditDto
} from './dto/long-credit-request.dto';

@Injectable()
export class CreditLongRequestService {
  private readonly logger = new Logger(CreditLongRequestService.name);
  private readonly uploadPath = process.env.UPLOAD_PATH || './uploads/credit-documents';
  private readonly mlApiUrl = process.env.ML_API_URL || 'http://localhost:5000';

  constructor(
    @InjectRepository(LongCreditRequestEntity)
    private requestRepository: Repository<LongCreditRequestEntity>,
    
    @InjectRepository(LongCreditDocumentEntity)
    private documentRepository: Repository<LongCreditDocumentEntity>,
    
    @InjectRepository(LongCreditCommentEntity)
    private commentRepository: Repository<LongCreditCommentEntity>,
    
    @InjectRepository(LongCreditReviewHistoryEntity)
    private historyRepository: Repository<LongCreditReviewHistoryEntity>,
    
    @InjectRepository(User)
    private userRepository: Repository<User>,

    private httpService: HttpService
  ) {
    this.ensureUploadDirectory();
  }

  private async ensureUploadDirectory(): Promise<void> {
    try {
      await fs.access(this.uploadPath);
    } catch {
      await fs.mkdir(this.uploadPath, { recursive: true });
      this.logger.log(`Created upload directory: ${this.uploadPath}`);
    }
  }

  // === GESTION DES DEMANDES ===

  async createRequest(requestData: CreateLongCreditRequestDto): Promise<LongCreditRequestEntity> {
  try {
    this.logger.log(`Creating long credit request for user: ${requestData.username}`);

    const user = await this.userRepository.findOne({ 
      where: [
        { email: requestData.username }
      ]
    });

    if (!user) {
      throw new BadRequestException(
        `Utilisateur non trouvé avec l'identifiant: ${requestData.username}`
      );
    }

    const requestNumber = await this.generateRequestNumber();

    const requestEntity = this.requestRepository.create({
      requestNumber,
      username: requestData.username,
      userId: user.id,
      status: requestData.status || LongCreditStatus.DRAFT,
      personalInfo: requestData.personalInfo,
      creditDetails: requestData.creditDetails,
      financialDetails: requestData.financialDetails,
      documents: requestData.documents || {},
      simulationResults: requestData.simulation,
      submissionDate: requestData.status === 'submitted' ? new Date() : undefined,  // ✅ undefined au lieu de null
      createdBy: user.id
    });

    const savedRequest = await this.requestRepository.save(requestEntity);

    // Ajouter une entrée d'historique
    await this.addHistoryEntry(savedRequest.id.toString(), {
      action: requestData.status === 'submitted' ? 'Demande créée et soumise' : 'Brouillon créé',
      agentName: 'Client',
      agentId: user.id,
      comment: requestData.status === 'submitted' 
        ? 'Demande créée et soumise directement par le client' 
        : 'Brouillon sauvegardé'
    });

    this.logger.log(`Long credit request created: ${savedRequest.id}`);
    return savedRequest;

  } catch (error) {
    this.logger.error(`Error creating request: ${error.message}`, error.stack);
    throw new BadRequestException(error.message || 'Impossible de créer la demande');
  }
}

  async getUserRequests(
    username: string,
    options: { 
      status?: string; 
      page?: number; 
      limit?: number;
      includeHistory?: boolean;
      includeDocuments?: boolean;
    } = {}
  ): Promise<{
    requests: LongCreditRequestEntity[];
    total: number;
    page: number;
    totalPages: number;
  }> {
    try {
      const { status, page = 1, limit = 10 } = options;
      
      const queryBuilder = this.requestRepository
        .createQueryBuilder('request')
        .where('request.username = :username', { username })
        .orderBy('request.createdAt', 'DESC')
        .skip((page - 1) * limit)
        .take(limit);

      if (status && status !== 'all') {
        queryBuilder.andWhere('request.status = :status', { status });
      }

      const [requests, total] = await queryBuilder.getManyAndCount();

      return {
        requests,
        total,
        page,
        totalPages: Math.ceil(total / limit)
      };

    } catch (error) {
      this.logger.error(`Error fetching user requests: ${error.message}`, error.stack);
      throw new BadRequestException('Impossible de récupérer les demandes');
    }
  }

  async getRequestById(
    id: string, 
    includeRelations: boolean = false
  ): Promise<LongCreditRequestEntity> {
    try {
      const request = await this.requestRepository.findOne({ 
        where: { id: parseInt(id) }
      });

      if (!request) {
        throw new NotFoundException('Demande non trouvée');
      }

      return request;

    } catch (error) {
      if (error instanceof NotFoundException) {
        throw error;
      }
      this.logger.error(`Error fetching request: ${error.message}`, error.stack);
      throw new BadRequestException('Erreur lors de la récupération de la demande');
    }
  }

  async updateRequest(
    id: string, 
    updates: UpdateLongCreditRequestDto,
    agentId?: number
  ): Promise<LongCreditRequestEntity> {
    try {
      const request = await this.getRequestById(id, false);

      if (!this.canModifyRequest(request)) {
        throw new BadRequestException('Cette demande ne peut plus être modifiée');
      }

      const updateData: any = {
        updatedAt: new Date()
      };

      // Copier les champs simples
      if (updates.personalInfo !== undefined) updateData.personalInfo = updates.personalInfo;
      if (updates.creditDetails !== undefined) updateData.creditDetails = updates.creditDetails;
      if (updates.financialDetails !== undefined) updateData.financialDetails = updates.financialDetails;
      if (updates.documents !== undefined) updateData.documents = updates.documents;
      if (updates.simulationResults !== undefined) updateData.simulationResults = updates.simulationResults;
      if (updates.decisionNotes !== undefined) updateData.decisionNotes = updates.decisionNotes;
      if (updates.decision !== undefined) updateData.decision = updates.decision;
      if (updates.approvedAmount !== undefined) updateData.approvedAmount = updates.approvedAmount;
      if (updates.approvedRate !== undefined) updateData.approvedRate = updates.approvedRate;
      if (updates.approvedDuration !== undefined) updateData.approvedDuration = updates.approvedDuration;
      if (updates.specialConditions !== undefined) updateData.specialConditions = updates.specialConditions;
      if (updates.assignedTo !== undefined) updateData.assignedTo = updates.assignedTo;

      // Gérer les conversions de dates
      if (updates.submissionDate !== undefined) {
        updateData.submissionDate = typeof updates.submissionDate === 'string' 
          ? new Date(updates.submissionDate) 
          : updates.submissionDate;
      }

      if (updates.decisionDate !== undefined) {
        updateData.decisionDate = typeof updates.decisionDate === 'string' 
          ? new Date(updates.decisionDate) 
          : updates.decisionDate;
      }

      // Gérer le changement de statut
      if (updates.status && updates.status !== request.status) {
        updateData.status = updates.status;
        
        switch (updates.status) {
          case LongCreditStatus.SUBMITTED:
            if (!updateData.submissionDate) {
              updateData.submissionDate = new Date();
            }
            break;
          case LongCreditStatus.IN_REVIEW:
            updateData.reviewStartedDate = new Date();
            break;
          case LongCreditStatus.APPROVED:
          case LongCreditStatus.REJECTED:
            if (!updateData.decisionDate) {
              updateData.decisionDate = new Date();
            }
            updateData.decisionBy = agentId;
            break;
        }
      }

      await this.requestRepository.update(parseInt(id), updateData);

      // Ajouter une entrée à l'historique si changement de statut
      if (updates.status && updates.status !== request.status) {
        const agent = agentId ? await this.userRepository.findOne({ where: { id: agentId } }) : null;
        await this.addHistoryEntry(id, {
          action: `Statut changé: ${request.status} → ${updates.status}`,
          agentName: agent?.firstName || 'Système',
          agentId,
          comment: updates.decisionNotes || 'Changement de statut automatique'
        });
      }

      const updatedRequest = await this.getRequestById(id);
      this.logger.log(`Request updated: ${id}`);
      
      return updatedRequest;

    } catch (error) {
      if (error instanceof NotFoundException || error instanceof BadRequestException) {
        throw error;
      }
      this.logger.error(`Error updating request: ${error.message}`, error.stack);
      throw new BadRequestException('Impossible de mettre à jour la demande');
    }
  }

  async submitRequest(id: string): Promise<LongCreditRequestEntity> {
  try {
    const request = await this.getRequestById(id, false);

    if (request.status !== LongCreditStatus.DRAFT && request.status !== LongCreditStatus.REQUIRES_INFO) {
      throw new BadRequestException('Seuls les brouillons et demandes nécessitant des infos peuvent être soumis');
    }

    const validation = await this.validateRequestForSubmission(request);
    if (!validation.isValid) {
      throw new BadRequestException(`Demande invalide: ${validation.errors.join(', ')}`);
    }
  
    return await this.updateRequest(id, {
      status: LongCreditStatus.SUBMITTED,
      submissionDate: new Date()  // ✅ Passer Date directement
    });

  } catch (error) {
    if (error instanceof NotFoundException || error instanceof BadRequestException) {
      throw error;
    }
    this.logger.error(`Error submitting request: ${error.message}`, error.stack);
    throw new BadRequestException('Impossible de soumettre la demande');
  }
}

  async deleteRequest(id: string): Promise<void> {
  try {
    const request = await this.getRequestById(id, false);

    if (request.status !== LongCreditStatus.DRAFT) {
      throw new BadRequestException('Seuls les brouillons peuvent être supprimés');
    }

    const numericId = parseInt(id);
    
    await this.historyRepository.delete({ longCreditRequestId: numericId });
    await this.documentRepository.delete({ longCreditRequestId: numericId });
    
    // ✅ Correction pour les commentaires
    await this.commentRepository
      .createQueryBuilder()
      .delete()
      .where('long_credit_request_id = :id', { id: numericId })
      .execute();
      
    await this.requestRepository.delete(numericId);

    this.logger.log(`Request deleted: ${id}`);

  } catch (error) {
    if (error instanceof NotFoundException || error instanceof BadRequestException) {
      throw error;
    }
    this.logger.error(`Error deleting request: ${error.message}`, error.stack);
    throw new BadRequestException('Impossible de supprimer la demande');
  }
}
  async saveDraft(draftData: any): Promise<LongCreditRequestEntity> {
    try {
      const username = draftData.username;
      
      const existingDraft = await this.requestRepository.findOne({
        where: {
          username,
          status: LongCreditStatus.DRAFT
        },
        order: { createdAt: 'DESC' }
      });

      if (existingDraft) {
        return await this.updateRequest(existingDraft.id.toString(), {
          personalInfo: draftData.personalInfo,
          creditDetails: draftData.creditDetails,
          financialDetails: draftData.financialDetails,
          documents: draftData.documents,
          simulationResults: draftData.simulation
        });
      } else {
        return await this.createRequest({
          ...draftData,
          status: LongCreditStatus.DRAFT
        });
      }

    } catch (error) {
      this.logger.error(`Error saving draft: ${error.message}`, error.stack);
      throw new BadRequestException('Impossible de sauvegarder le brouillon');
    }
  }

  async getDraft(username: string): Promise<LongCreditRequestEntity | null> {
    try {
      const draft = await this.requestRepository.findOne({
        where: {
          username,
          status: LongCreditStatus.DRAFT
        },
        order: { updatedAt: 'DESC' }
      });

      return draft;

    } catch (error) {
      this.logger.error(`Error fetching draft: ${error.message}`, error.stack);
      return null;
    }
  }

  async deleteDraft(username: string): Promise<void> {
    try {
      const draft = await this.getDraft(username);
      
      if (draft) {
        await this.deleteRequest(draft.id.toString());
      }

    } catch (error) {
      this.logger.error(`Error deleting draft: ${error.message}`, error.stack);
      throw new BadRequestException('Impossible de supprimer le brouillon');
    }
  }

  async uploadDocument(
    requestId: string, 
    documentType: string, 
    file: Express.Multer.File,
    uploadedBy?: number
  ): Promise<LongCreditDocumentEntity> {
    try {
      await this.getRequestById(requestId, false);

      const validation = this.validateUploadedFile(file, documentType);
      if (!validation.isValid) {
        throw new BadRequestException(validation.errors.join(', '));
      }

      const filename = `${uuidv4()}-${file.originalname}`;
      const filePath = path.join(this.uploadPath, filename);
      
      await fs.writeFile(filePath, file.buffer);

      const document = this.documentRepository.create({
        longCreditRequestId: parseInt(requestId),
        documentType,
        documentName: this.getDocumentDisplayName(documentType),
        originalFilename: file.originalname,
        filePath,
        fileSize: file.size,
        mimeType: file.mimetype,
        isRequired: this.isDocumentRequired(documentType),
        uploadedBy,
        checksum: await this.calculateFileChecksum(file.buffer)
      });

      const savedDocument = await this.documentRepository.save(document);

      await this.addHistoryEntry(requestId, {
        action: `Document uploadé: ${this.getDocumentDisplayName(documentType)}`,
        agentName: 'Client',
        agentId: uploadedBy,
        comment: `Fichier: ${file.originalname}`
      });

      this.logger.log(`Document uploaded for request ${requestId}: ${filename}`);
      return savedDocument;

    } catch (error) {
      this.logger.error(`Error uploading document: ${error.message}`, error.stack);
      throw new BadRequestException('Impossible d\'uploader le document');
    }
  }

  async getRequestDocuments(requestId: string): Promise<LongCreditDocumentEntity[]> {
    try {
      return await this.documentRepository.find({
        where: { longCreditRequestId: parseInt(requestId) },
        order: { uploadedAt: 'DESC' }
      });

    } catch (error) {
      this.logger.error(`Error fetching documents: ${error.message}`, error.stack);
      return [];
    }
  }

  async deleteDocument(requestId: string, documentId: string): Promise<void> {
    try {
      const document = await this.documentRepository.findOne({
        where: { 
          id: documentId,
          longCreditRequestId: parseInt(requestId)
        }
      });

      if (!document) {
        throw new NotFoundException('Document non trouvé');
      }

      try {
        await fs.unlink(document.filePath);
      } catch (error) {
        this.logger.warn(`Could not delete file: ${document.filePath}`);
      }

      await this.documentRepository.delete(documentId);

      await this.addHistoryEntry(requestId, {
        action: `Document supprimé: ${document.documentName}`,
        agentName: 'Client',
        comment: `Fichier: ${document.originalFilename}`
      });

      this.logger.log(`Document deleted: ${documentId}`);

    } catch (error) {
      if (error instanceof NotFoundException) {
        throw error;
      }
      this.logger.error(`Error deleting document: ${error.message}`, error.stack);
      throw new BadRequestException('Impossible de supprimer le document');
    }
  }

  async addHistoryEntry(
    requestId: string, 
    entry: {
      action: string;
      agentName: string;
      agentId?: number;
      comment?: string;
      previousStatus?: string;
      newStatus?: string;
    }
  ): Promise<LongCreditReviewHistoryEntity> {
    try {
      const historyEntry = this.historyRepository.create({
        longCreditRequestId: parseInt(requestId),
        action: entry.action,
        previousStatus: entry.previousStatus,
        newStatus: entry.newStatus,
        agentName: entry.agentName,
        agentId: entry.agentId,
        comment: entry.comment
      });

      return await this.historyRepository.save(historyEntry);

    } catch (error) {
      this.logger.error(`Error adding history entry: ${error.message}`, error.stack);
      throw new BadRequestException('Impossible d\'ajouter l\'entrée à l\'historique');
    }
  }

  async getRequestHistory(requestId: string): Promise<LongCreditReviewHistoryEntity[]> {
    try {
      return await this.historyRepository.find({
        where: { longCreditRequestId: parseInt(requestId) },
        order: { actionDate: 'DESC' }
      });

    } catch (error) {
      this.logger.error(`Error fetching history: ${error.message}`, error.stack);
      return [];
    }
  }

  async addComment(
  requestId: string, 
  comment: string, 
  authorName: string, 
  authorId?: number,
  commentType: string = 'general',
  isPrivate: boolean = false
): Promise<LongCreditCommentEntity> {
  try {
    await this.getRequestById(requestId, false);

    const commentEntity = this.commentRepository.create({
      longCreditRequestId: parseInt(requestId),
      authorName,
      authorId,
      commentType,
      content: comment,
      isPrivate
    });

    const savedComment = await this.commentRepository.save(commentEntity);

    await this.addHistoryEntry(requestId, {
      action: 'Commentaire ajouté',
      agentName: authorName,
      agentId: authorId,
      comment: isPrivate ? '[Commentaire privé]' : comment.substring(0, 100) + '...'
    });

    return savedComment;

  } catch (error) {
    this.logger.error(`Error adding comment: ${error.message}`, error.stack);
    throw new BadRequestException('Impossible d\'ajouter le commentaire');
  }
}

  // === VALIDATION ===

  async validateRequestForSubmission(request: LongCreditRequestEntity): Promise<{
    isValid: boolean;
    errors: string[];
  }> {
    const errors: string[] = [];

    if (!request.personalInfo?.fullName) {
      errors.push('Nom complet requis');
    }
    if (!request.personalInfo?.email) {
      errors.push('Email requis');
    }
    if (!request.personalInfo?.phone) {
      errors.push('Téléphone requis');
    }

    if (!request.creditDetails?.requestedAmount || request.creditDetails.requestedAmount <= 0) {
      errors.push('Montant du crédit requis');
    }
    if (!request.creditDetails?.duration || request.creditDetails.duration <= 0) {
      errors.push('Durée du crédit requise');
    }

    if (!request.financialDetails?.monthlyIncome || request.financialDetails.monthlyIncome <= 0) {
      errors.push('Revenus mensuels requis');
    }

    const documents = await this.getRequestDocuments(request.id.toString());
    const requiredDocs = ['identityProof', 'incomeProof', 'employmentCertificate'];
    
    for (const docType of requiredDocs) {
      if (!documents.find(d => d.documentType === docType)) {
        errors.push(`Document requis manquant: ${this.getDocumentDisplayName(docType)}`);
      }
    }

    return {
      isValid: errors.length === 0,
      errors
    };
  }

  canModifyRequest(request: LongCreditRequestEntity): boolean {
    return [
      LongCreditStatus.DRAFT, 
      LongCreditStatus.REQUIRES_INFO
    ].includes(request.status as LongCreditStatus);
  }

  validateUploadedFile(file: Express.Multer.File, documentType: string): {
    isValid: boolean;
    errors: string[];
  } {
    const errors: string[] = [];

    if (file.size > 10 * 1024 * 1024) {
      errors.push('Le fichier ne peut pas dépasser 10MB');
    }

    const allowedTypes = [
      'application/pdf',
      'image/jpeg',
      'image/png',
      'image/jpg',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
    ];

    if (!allowedTypes.includes(file.mimetype)) {
      errors.push('Type de fichier non autorisé');
    }

    return {
      isValid: errors.length === 0,
      errors
    };
  }

  // === UTILITAIRES PRIVÉS ===

  private async generateRequestNumber(): Promise<string> {
    const date = new Date();
    const dateStr = date.toISOString().slice(0, 10).replace(/-/g, '');
    
    const count = await this.requestRepository.count({
      where: {
        requestNumber: Like(`LCR-${dateStr}-%`)
      }
    });

    return `LCR-${dateStr}-${String(count + 1).padStart(4, '0')}`;
  }

  private async calculateFileChecksum(buffer: Buffer): Promise<string> {
    const crypto = require('crypto');
    return crypto.createHash('sha256').update(buffer).digest('hex');
  }

  private getDocumentDisplayName(documentType: string): string {
    const names: { [key: string]: string } = {
      'identityProof': 'Pièce d\'identité',
      'incomeProof': 'Justificatif de revenus',
      'bankStatements': 'Relevés bancaires',
      'employmentCertificate': 'Attestation de travail',
      'businessPlan': 'Plan d\'affaires',
      'propertyDeeds': 'Titre de propriété',
      'guarantorDocuments': 'Documents du garant'
    };
    return names[documentType] || documentType;
  }

  private isDocumentRequired(documentType: string): boolean {
    const requiredDocs = ['identityProof', 'incomeProof', 'employmentCertificate'];
    return requiredDocs.includes(documentType);
  }

  async getUserStatistics(username: string): Promise<any> {
    try {
      const requests = await this.requestRepository.find({
        where: { username }
      });

      const stats = {
        totalRequests: requests.length,
        draftRequests: requests.filter(r => r.status === LongCreditStatus.DRAFT).length,
        submittedRequests: requests.filter(r => r.status === LongCreditStatus.SUBMITTED).length,
        approvedRequests: requests.filter(r => r.status === LongCreditStatus.APPROVED).length,
        rejectedRequests: requests.filter(r => r.status === LongCreditStatus.REJECTED).length,
        totalRequestedAmount: requests.reduce((sum, r) => sum + (r.creditDetails?.requestedAmount || 0), 0),
        averageRequestedAmount: requests.length > 0 
          ? requests.reduce((sum, r) => sum + (r.creditDetails?.requestedAmount || 0), 0) / requests.length 
          : 0
      };

      return stats;

    } catch (error) {
      this.logger.error(`Error fetching user statistics: ${error.message}`, error.stack);
      return {
        totalRequests: 0,
        draftRequests: 0,
        submittedRequests: 0,
        approvedRequests: 0,
        rejectedRequests: 0,
        totalRequestedAmount: 0,
        averageRequestedAmount: 0
      };
    }
  }
}