// ============================================
// CONTROLLER NESTJS - credit-long-backoffice.controller.ts
// ============================================

import { 
  Controller, 
  Get, 
  Post,
  Patch,
  Delete,
  Param, 
  Query,
  Body,
  HttpStatus,
  HttpCode,
  Logger,
  UseGuards
} from '@nestjs/common';
import { CreditLongRequestService } from '../credit/credit-long-request.service';
import { JwtAuthGuard } from '../app/auth/guards/jwt-auth.guard';

@Controller('api/credit-long')
export class CreditLongBackofficeController {
  private readonly logger = new Logger(CreditLongBackofficeController.name);

  constructor(
    private readonly creditLongService: CreditLongRequestService
  ) {}

  // ==========================================
  // RÉCUPÉRER TOUTES LES DEMANDES (BACKOFFICE)
  // ==========================================

  @Get('all-requests')
  @HttpCode(HttpStatus.OK)
  async getAllRequests(
    @Query('status') status?: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string
  ) {
    try {
      this.logger.log('📋 Récupération de toutes les demandes');

      const pageNum = page ? parseInt(page, 10) : 1;
      const limitNum = limit ? parseInt(limit, 10) : 50;

      // Récupérer toutes les demandes (pas filtré par username)
      const result = await this.creditLongService.getAllRequestsForBackoffice({
        status,
        page: pageNum,
        limit: limitNum
      });

      this.logger.log(`✅ ${result.total} demandes récupérées`);

      return {
        success: true,
        ...result
      };

    } catch (error) {
      this.logger.error(`❌ Erreur récupération demandes: ${error.message}`);
      return {
        success: false,
        error: error.message,
        requests: [],
        total: 0
      };
    }
  }

  // ==========================================
  // DÉTAILS D'UNE DEMANDE
  // ==========================================

  @Get('requests/:id')
  @HttpCode(HttpStatus.OK)
  async getRequestDetails(@Param('id') id: string) {
    try {
      this.logger.log(`📄 Récupération détails demande: ${id}`);

      const request = await this.creditLongService.getRequestById(id, true);

      // Récupérer les documents
      const documents = await this.creditLongService.getRequestDocuments(id);

      // Récupérer l'historique
      const history = await this.creditLongService.getRequestHistory(id);

      return {
        success: true,
        request,
        documents,
        history
      };

    } catch (error) {
      this.logger.error(`❌ Erreur récupération détails: ${error.message}`);
      return {
        success: false,
        error: error.message
      };
    }
  }

  // ==========================================
  // METTRE À JOUR LE STATUT
  // ==========================================

  @Patch('requests/:id')
  @HttpCode(HttpStatus.OK)
  async updateRequestStatus(
    @Param('id') id: string,
    @Body() updateData: {
      status?: string;
      decisionNotes?: string;
      approvedAmount?: number;
      approvedRate?: number;
      approvedDuration?: number;
    }
  ) {
    try {
      this.logger.log(`🔄 Mise à jour demande: ${id}`);
      this.logger.log(`Nouveau statut: ${updateData.status}`);

      const updatedRequest = await this.creditLongService.updateRequest(
        id,
        updateData,
        1 // agentId - à remplacer par l'utilisateur authentifié
      );

      this.logger.log(`✅ Demande mise à jour: ${id}`);

      return {
        success: true,
        message: 'Demande mise à jour avec succès',
        request: updatedRequest
      };

    } catch (error) {
      this.logger.error(`❌ Erreur mise à jour: ${error.message}`);
      return {
        success: false,
        error: error.message
      };
    }
  }

  // ==========================================
  // APPROUVER UNE DEMANDE
  // ==========================================

  @Post('requests/:id/approve')
  @HttpCode(HttpStatus.OK)
  async approveRequest(
    @Param('id') id: string,
    @Body() approvalData: {
      approvedAmount?: number;
      approvedRate?: number;
      approvedDuration?: number;
      notes?: string;
    }
  ) {
    try {
      this.logger.log(`✅ Approbation demande: ${id}`);

      const updatedRequest = await this.creditLongService.updateRequest(
        id,
        {
          status: 'approved',
          decision: 'approved',
          decisionDate: new Date(),
          approvedAmount: approvalData.approvedAmount,
          approvedRate: approvalData.approvedRate,
          approvedDuration: approvalData.approvedDuration,
          decisionNotes: approvalData.notes || 'Demande approuvée'
        },
        1 // agentId
      );

      // Ajouter une entrée à l'historique
      await this.creditLongService.addHistoryEntry(id, {
        action: 'Demande approuvée',
        agentName: 'Agent Back-Office',
        agentId: 1,
        comment: approvalData.notes || 'Demande approuvée',
        previousStatus: 'in_review',
        newStatus: 'approved'
      });

      return {
        success: true,
        message: 'Demande approuvée avec succès',
        request: updatedRequest
      };

    } catch (error) {
      this.logger.error(`❌ Erreur approbation: ${error.message}`);
      return {
        success: false,
        error: error.message
      };
    }
  }

  // ==========================================
  // REJETER UNE DEMANDE
  // ==========================================

  @Post('requests/:id/reject')
  @HttpCode(HttpStatus.OK)
  async rejectRequest(
    @Param('id') id: string,
    @Body() rejectionData: {
      reason: string;
    }
  ) {
    try {
      this.logger.log(`❌ Rejet demande: ${id}`);

      const updatedRequest = await this.creditLongService.updateRequest(
        id,
        {
          status: 'rejected',
          decision: 'rejected',
          decisionDate: new Date(),
          decisionNotes: rejectionData.reason
        },
        1 // agentId
      );

      // Ajouter une entrée à l'historique
      await this.creditLongService.addHistoryEntry(id, {
        action: 'Demande rejetée',
        agentName: 'Agent Back-Office',
        agentId: 1,
        comment: rejectionData.reason,
        previousStatus: 'in_review',
        newStatus: 'rejected'
      });

      return {
        success: true,
        message: 'Demande rejetée',
        request: updatedRequest
      };

    } catch (error) {
      this.logger.error(`❌ Erreur rejet: ${error.message}`);
      return {
        success: false,
        error: error.message
      };
    }
  }

  // ==========================================
  // METTRE EN EXAMEN
  // ==========================================

  @Post('requests/:id/review')
  @HttpCode(HttpStatus.OK)
  async putInReview(@Param('id') id: string) {
    try {
      this.logger.log(`🔍 Mise en examen: ${id}`);

      const updatedRequest = await this.creditLongService.updateRequest(
        id,
        {
          status: 'in_review'
        },
        1 // agentId
      );

      await this.creditLongService.addHistoryEntry(id, {
        action: 'Demande mise en examen',
        agentName: 'Agent Back-Office',
        agentId: 1,
        comment: 'Début de l\'examen de la demande',
        previousStatus: 'submitted',
        newStatus: 'in_review'
      });

      return {
        success: true,
        message: 'Demande mise en examen',
        request: updatedRequest
      };

    } catch (error) {
      this.logger.error(`❌ Erreur mise en examen: ${error.message}`);
      return {
        success: false,
        error: error.message
      };
    }
  }

  // ==========================================
  // STATISTIQUES BACK-OFFICE
  // ==========================================

  @Get('statistics')
  @HttpCode(HttpStatus.OK)
  async getBackofficeStatistics() {
    try {
      this.logger.log('📊 Récupération statistiques back-office');

      const stats = await this.creditLongService.getBackofficeStatistics();

      return {
        success: true,
        statistics: stats
      };

    } catch (error) {
      this.logger.error(`❌ Erreur statistiques: ${error.message}`);
      return {
        success: false,
        error: error.message
      };
    }
  }

  // ==========================================
  // AJOUTER UN COMMENTAIRE
  // ==========================================

  @Post('requests/:id/comments')
  @HttpCode(HttpStatus.OK)
  async addComment(
    @Param('id') id: string,
    @Body() commentData: {
      comment: string;
      isPrivate?: boolean;
      commentType?: string;
    }
  ) {
    try {
      this.logger.log(`💬 Ajout commentaire sur demande: ${id}`);

      const comment = await this.creditLongService.addComment(
        id,
        commentData.comment,
        'Agent Back-Office',
        1, // agentId
        commentData.commentType || 'general',
        commentData.isPrivate || false
      );

      return {
        success: true,
        message: 'Commentaire ajouté',
        comment
      };

    } catch (error) {
      this.logger.error(`❌ Erreur ajout commentaire: ${error.message}`);
      return {
        success: false,
        error: error.message
      };
    }
  }

  // ==========================================
  // EXPORT DES DEMANDES (CSV)
  // ==========================================

  @Get('export')
  @HttpCode(HttpStatus.OK)
  async exportRequests(
    @Query('status') status?: string,
    @Query('format') format: string = 'json'
  ) {
    try {
      this.logger.log('📥 Export des demandes');

      const result = await this.creditLongService.getAllRequestsForBackoffice({
        status,
        page: 1,
        limit: 10000 // Toutes les demandes
      });

      if (format === 'csv') {
        // TODO: Implémenter export CSV
        return {
          success: true,
          message: 'Export CSV non encore implémenté',
          data: result.requests
        };
      }

      return {
        success: true,
        data: result.requests,
        total: result.total
      };

    } catch (error) {
      this.logger.error(`❌ Erreur export: ${error.message}`);
      return {
        success: false,
        error: error.message
      };
    }
  }
}

