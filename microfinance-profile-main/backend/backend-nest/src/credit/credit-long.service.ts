// credit-long.service.ts - Version corrigée
import { Injectable, BadRequestException, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { HttpService } from '@nestjs/axios';
import { firstValueFrom } from 'rxjs';
import * as fs from 'fs/promises';
import * as path from 'path';
import { v4 as uuidv4 } from 'uuid';

import { 
  CreditLongRequestEntity,
  CreditSimulationResult,
  CreateCreditLongRequestDto,
  UpdateCreditLongRequestDto,
  SimulateCreditDto,
  ContractType,
  CreditLongStatus,
  ReviewHistoryEntryDto
} from './credit-long.dto';
import { User } from '../app/auth/entities/user.entity';
import { NotificationsService } from '../notification/notification.service';
// import { EmailService } from '../email/email.service'; // Commenté temporairement

@Injectable()
export class CreditLongService {
  
  private readonly uploadPath = process.env.UPLOAD_PATH || './uploads/credit-documents';
  private readonly mlApiUrl = process.env.ML_API_URL || 'http://localhost:5000';
    simulateCredit: any;
    quickSimulation: any;

  constructor(
    @InjectRepository(CreditLongRequestEntity)
    private requestRepository: Repository<CreditLongRequestEntity>,
    private httpService: HttpService,
    private notificationService: NotificationsService,
    // private emailService: EmailService // Commenté temporairement
  ) {
    this.ensureUploadDirectory();
  }

  private async ensureUploadDirectory(): Promise<void> {
    try {
      await fs.access(this.uploadPath);
    } catch {
      await fs.mkdir(this.uploadPath, { recursive: true });
    }
  }

  // === GESTION DES DEMANDES ===

  async createRequest(requestData: CreateCreditLongRequestDto): Promise<CreditLongRequestEntity> {
    try {
      // Préparer l'historique initial
      const initialHistory: ReviewHistoryEntryDto[] = [{
        date: new Date().toISOString(),
        action: 'Demande créée',
        agent: 'Système',
        comment: 'Demande créée par le client'
      }];

      // Créer l'entité avec tous les champs requis
      const requestEntity = this.requestRepository.create({
        userId: requestData.userId || 0,
        username: requestData.username || '',
        personalInfo: requestData.personalInfo,
        creditDetails: requestData.creditDetails,
        financialDetails: requestData.financialDetails,
        documents: requestData.documents,
        status: CreditLongStatus.DRAFT,
        submissionDate: null, // Explicitement null pour le type nullable
        reviewHistory: initialHistory,
        simulation: requestData.simulation || null,
        decision: requestData.decision || null
      });

      const savedRequest = await this.requestRepository.save(requestEntity);
      
      console.log('✅ Demande de crédit long créée:', savedRequest.id);
      return savedRequest;

    } catch (error) {
      console.error('❌ Erreur création demande:', error);
      throw new BadRequestException('Impossible de créer la demande');
    }
  }

  async getUserRequests(
    username: string,
    options: { status?: string; page?: number; limit?: number }
  ): Promise<{
    requests: CreditLongRequestEntity[];
    total: number;
    page: number;
    totalPages: number;
  }> {
    try {
      const { status, page = 1, limit = 10 } = options;
      
      const queryBuilder = this.requestRepository
        .createQueryBuilder('request')
        .where('request.username = :username', { username })
        .orderBy('request.submissionDate', 'DESC');

      if (status) {
        queryBuilder.andWhere('request.status = :status', { status });
      }

      const [requests, total] = await queryBuilder
        .skip((page - 1) * limit)
        .take(limit)
        .getManyAndCount();

      return {
        requests,
        total,
        page,
        totalPages: Math.ceil(total / limit)
      };

    } catch (error) {
      console.error('❌ Erreur récupération demandes utilisateur:', error);
      throw new BadRequestException('Impossible de récupérer les demandes');
    }
  }

  async getRequestById(id: string): Promise<CreditLongRequestEntity | null> {
    try {
      return await this.requestRepository.findOne({ where: { id } });
    } catch (error) {
      console.error('❌ Erreur récupération demande par ID:', error);
      return null;
    }
  }

  async updateRequest(id: string, updates: UpdateCreditLongRequestDto): Promise<CreditLongRequestEntity> {
    try {
      await this.requestRepository.update(id, updates);
      
      const updatedRequest = await this.getRequestById(id);
      if (!updatedRequest) {
        throw new NotFoundException('Demande non trouvée après mise à jour');
      }

      return updatedRequest;

    } catch (error) {
      console.error('❌ Erreur mise à jour demande:', error);
      throw new BadRequestException('Impossible de mettre à jour la demande');
    }
  }

  async submitRequest(id: string): Promise<CreditLongRequestEntity> {
    try {
      const request = await this.getRequestById(id);
      if (!request) {
        throw new NotFoundException('Demande non trouvée');
      }

      // Créer la nouvelle entrée d'historique
      const newHistoryEntry: ReviewHistoryEntryDto = {
        date: new Date().toISOString(),
        action: 'Demande soumise',
        agent: 'Client',
        comment: 'Demande soumise pour examen'
      };

      // Mettre à jour le statut et ajouter à l'historique
      const updatedHistory = [...request.reviewHistory, newHistoryEntry];

      await this.requestRepository.update(id, {
        status: CreditLongStatus.SUBMITTED,
        submissionDate: new Date().toISOString(),
        reviewHistory: updatedHistory
      });

      const submittedRequest = await this.getRequestById(id);
      if (!submittedRequest) {
        throw new NotFoundException('Demande non trouvée après soumission');
      }

      return submittedRequest;

    } catch (error) {
      console.error('❌ Erreur soumission demande:', error);
      throw new BadRequestException('Impossible de soumettre la demande');
    }
  }

  // === VALIDATION ===

  async validateUserCanCreateRequest(user: User): Promise<void> {
    // Vérifier si l'utilisateur a des demandes en cours
    const pendingRequests = await this.requestRepository.count({
      where: {
        userId: user.id,
        status: CreditLongStatus.SUBMITTED
      }
    });

    if (pendingRequests >= 3) {
      throw new BadRequestException(
        'Vous avez déjà 3 demandes en cours d\'examen. Veuillez attendre une réponse avant de faire une nouvelle demande.'
      );
    }

    // Autres validations métier...
  }

  async validateRequestForSubmission(request: CreditLongRequestEntity): Promise<{
    isValid: boolean;
    errors: string[];
  }> {
    const errors: string[] = [];

    // Vérifier les informations personnelles
    if (!request.personalInfo?.fullName) {
      errors.push('Nom complet requis');
    }
    if (!request.personalInfo?.email) {
      errors.push('Email requis');
    }
    if (!request.personalInfo?.phone) {
      errors.push('Téléphone requis');
    }

    // Vérifier les détails du crédit
    if (!request.creditDetails?.requestedAmount || request.creditDetails.requestedAmount <= 0) {
      errors.push('Montant du crédit requis');
    }
    if (!request.creditDetails?.duration || request.creditDetails.duration <= 0) {
      errors.push('Durée du crédit requise');
    }
    if (!request.creditDetails?.purpose) {
      errors.push('Objet du crédit requis');
    }

    // Vérifier les informations financières
    if (!request.financialDetails?.monthlyIncome || request.financialDetails.monthlyIncome <= 0) {
      errors.push('Revenus mensuels requis');
    }

    // Vérifier les documents obligatoires
    if (!request.documents?.identityProof) {
      errors.push('Pièce d\'identité requise');
    }
    if (!request.documents?.incomeProof) {
      errors.push('Justificatifs de revenus requis');
    }
    if (!request.documents?.employmentCertificate) {
      errors.push('Attestation de travail requise');
    }

    return {
      isValid: errors.length === 0,
      errors
    };
  }

  canModifyRequest(request: CreditLongRequestEntity): boolean {
    return [CreditLongStatus.DRAFT, CreditLongStatus.REQUIRES_INFO].includes(request.status);
  }

  // === UTILITAIRES ===

  private formatAmount(amount: number): string {
    return new Intl.NumberFormat('fr-FR', {
      style: 'currency',
      currency: 'XAF',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0
    }).format(amount);
  }

  // === MÉTHODES AVEC IMPLÉMENTATIONS DE BASE ===

  async saveDraft(draftData: any): Promise<CreditLongRequestEntity> {
    try {
      // Préparer l'historique initial
      const initialHistory: ReviewHistoryEntryDto[] = [{
        date: new Date().toISOString(),
        action: 'Brouillon créé',
        agent: 'Système',
        comment: 'Brouillon sauvegardé'
      }];

      // Créer un brouillon temporaire
      const draft = this.requestRepository.create({
        userId: draftData.userId || 0,
        username: draftData.username || '',
        personalInfo: draftData.personalInfo,
        creditDetails: draftData.creditDetails,
        financialDetails: draftData.financialDetails,
        documents: draftData.documents,
        status: CreditLongStatus.DRAFT,
        submissionDate: null,
        reviewHistory: initialHistory,
        simulation: draftData.simulation || null,
        decision: null
      });

      const savedDraft = await this.requestRepository.save(draft);
      return savedDraft;
    } catch (error) {
      console.error('❌ Erreur sauvegarde brouillon:', error);
      throw new BadRequestException('Impossible de sauvegarder le brouillon');
    }
  }

  async getDraft(username: string): Promise<CreditLongRequestEntity | null> {
    try {
      const draft = await this.requestRepository.findOne({
        where: {
          username: username,
          status: CreditLongStatus.DRAFT
        },
        order: {
          createdAt: 'DESC'
        }
      });

      return draft;
    } catch (error) {
      console.error('❌ Erreur récupération brouillon:', error);
      return null;
    }
  }

  async deleteDraft(username: string): Promise<void> {
    try {
      await this.requestRepository.delete({
        username: username,
        status: CreditLongStatus.DRAFT
      });
    } catch (error) {
      console.error('❌ Erreur suppression brouillon:', error);
      throw new BadRequestException('Impossible de supprimer le brouillon');
    }
  }

  async uploadDocument(requestId: string, type: string, file: any): Promise<any> {
    try {
      // Logique d'upload simplifiée
      const filename = `${uuidv4()}-${file.originalname}`;
      const filePath = path.join(this.uploadPath, filename);
      
      // Sauvegarder le fichier
      await fs.writeFile(filePath, file.buffer);
      
      // Retourner les informations du document
      return {
        id: uuidv4(),
        type: type,
        filename: filename,
        originalName: file.originalname,
        size: file.size,
        uploadDate: new Date().toISOString(),
        path: filePath
      };
    } catch (error) {
      console.error('❌ Erreur upload document:', error);
      throw new BadRequestException('Impossible d\'uploader le document');
    }
  }

  async getRequestDocuments(requestId: string): Promise<any[]> {
    try {
      // Simuler la récupération des documents
      // En réalité, vous auriez une table séparée pour les documents
      const request = await this.getRequestById(requestId);
      if (!request) {
        return [];
      }

      // Retourner une liste vide pour l'instant
      // À implémenter selon votre structure de base de données
      return [];
    } catch (error) {
      console.error('❌ Erreur récupération documents:', error);
      return [];
    }
  }

  async deleteDocument(requestId: string, documentId: string): Promise<void> {
    try {
      // Logique de suppression de document
      console.log(`Suppression document ${documentId} pour demande ${requestId}`);
      // À implémenter selon votre structure
    } catch (error) {
      console.error('❌ Erreur suppression document:', error);
      throw new BadRequestException('Impossible de supprimer le document');
    }
  }

  async getRequestHistory(requestId: string): Promise<ReviewHistoryEntryDto[]> {
    try {
      const request = await this.getRequestById(requestId);
      if (!request) {
        return [];
      }

      return request.reviewHistory || [];
    } catch (error) {
      console.error('❌ Erreur récupération historique:', error);
      return [];
    }
  }

  async addComment(requestId: string, comment: string, author: string, type: string): Promise<any> {
    try {
      const request = await this.getRequestById(requestId);
      if (!request) {
        throw new NotFoundException('Demande non trouvée');
      }

      const newComment = {
        id: uuidv4(),
        requestId: requestId,
        author: author,
        type: type,
        content: comment,
        createdAt: new Date().toISOString()
      };

      // Créer la nouvelle entrée d'historique
      const newHistoryEntry: ReviewHistoryEntryDto = {
        date: new Date().toISOString(),
        action: 'Commentaire ajouté',
        agent: author,
        comment: comment
      };

      // Ajouter à l'historique
      const updatedHistory = [...request.reviewHistory, newHistoryEntry];

      await this.requestRepository.update(requestId, {
        reviewHistory: updatedHistory
      });

      return newComment;
    } catch (error) {
      console.error('❌ Erreur ajout commentaire:', error);
      throw new BadRequestException('Impossible d\'ajouter le commentaire');
    }
  }

  async getUserNotifications(username: string, unreadOnly: boolean): Promise<any[]> {
    try {
      // Simuler les notifications utilisateur
      // À implémenter avec une vraie table de notifications
      const notifications = [
        {
          id: uuidv4(),
          username: username,
          title: 'Demande en cours d\'examen',
          message: 'Votre demande de crédit est en cours d\'analyse',
          type: 'info',
          isRead: false,
          createdAt: new Date().toISOString()
        }
      ];

      return unreadOnly ? notifications.filter(n => !n.isRead) : notifications;
    } catch (error) {
      console.error('❌ Erreur récupération notifications:', error);
      return [];
    }
  }

  async markNotificationAsRead(notificationId: string, username: string): Promise<void> {
    try {
      // Logique de marquage de notification
      console.log(`Notification ${notificationId} marquée comme lue pour ${username}`);
      // À implémenter avec une vraie table de notifications
    } catch (error) {
      console.error('❌ Erreur marquage notification:', error);
      throw new BadRequestException('Impossible de marquer la notification');
    }
  }

  async getUserStatistics(username: string): Promise<any> {
    try {
      // Calculer les statistiques utilisateur
      const userRequests = await this.requestRepository.find({
        where: { username: username }
      });

      const stats = {
        totalRequests: userRequests.length,
        pendingRequests: userRequests.filter(r => r.status === CreditLongStatus.SUBMITTED).length,
        approvedRequests: userRequests.filter(r => r.status === CreditLongStatus.APPROVED).length,
        rejectedRequests: userRequests.filter(r => r.status === CreditLongStatus.REJECTED).length,
        averageAmount: userRequests.length > 0 
          ? userRequests.reduce((sum, r) => sum + (r.creditDetails?.requestedAmount || 0), 0) / userRequests.length 
          : 0
      };

      return stats;
    } catch (error) {
      console.error('❌ Erreur récupération statistiques:', error);
      return {
        totalRequests: 0,
        pendingRequests: 0,
        approvedRequests: 0,
        rejectedRequests: 0,
        averageAmount: 0
      };
    }
  }

  async notifyBackOfficeAgents(request: CreditLongRequestEntity): Promise<void> {
    try {
      // Logique de notification des agents back-office
      console.log(`Notification agents pour demande ${request.id}`);
      
      // Utiliser le service de notifications
      await this.notificationService.notifyAgents({
        type: 'new_credit_request',
        requestId: request.id,
        clientUsername: request.username,
        amount: request.creditDetails?.requestedAmount || 0,
        urgency: 'normal'
      });

      // Envoyer email si le service est disponible
      // if (this.emailService) {
      //   await this.emailService.sendToBackOffice({
      //     subject: 'Nouvelle demande de crédit long',
      //     requestId: request.id,
      //     clientName: request.personalInfo?.fullName
      //   });
      // }
    } catch (error) {
      console.error('❌ Erreur notification agents:', error);
      // Ne pas faire échouer la création de demande pour une erreur de notification
    }
  }

  validateUploadedFile(file: any, type: string): { isValid: boolean; errors: string[] } {
    const errors: string[] = [];

    // Vérifier la taille du fichier (max 5MB)
    if (file.size > 5 * 1024 * 1024) {
      errors.push('Le fichier ne peut pas dépasser 5MB');
    }

    // Vérifier le type de fichier
    const allowedTypes = [
      'application/pdf',
      'image/jpeg',
      'image/png',
      'image/jpg',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
    ];

    if (!allowedTypes.includes(file.mimetype)) {
      errors.push('Type de fichier non autorisé. Formats acceptés: PDF, JPEG, PNG, DOC, DOCX');
    }

    // Vérifier le nom du fichier
    if (!file.originalname || file.originalname.length > 255) {
      errors.push('Nom de fichier invalide');
    }

    return {
      isValid: errors.length === 0,
      errors
    };
  }
}