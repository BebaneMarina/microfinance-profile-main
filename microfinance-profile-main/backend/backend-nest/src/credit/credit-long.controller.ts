// credit-long.controller.ts
import {
  Controller,
  Post,
  Get,
  Put,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
  UploadedFile,
  UseInterceptors,
  HttpStatus,
  BadRequestException,
  NotFoundException,
  InternalServerErrorException
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { JwtAuthGuard } from '../app/auth/guards/jwt-auth.guard';
import { GetUser } from '../decorators/get-user.decorator';
import { CreditLongService } from './credit-long.service';
import { 
  CreateCreditLongRequestDto, 
  UpdateCreditLongRequestDto,
  SimulateCreditDto,
  CreditLongRequestEntity,
  CreditSimulationResult 
} from './credit-long.dto';
import { User } from '../app/auth/entities/user.entity';

@Controller('api/credit-long')
@UseGuards(JwtAuthGuard)
export class CreditLongController {
  
  constructor(private readonly creditLongService: CreditLongService) {}

  // === SIMULATION ===

  @Post('simulate')
  async simulateCredit(
    @Body() simulationData: SimulateCreditDto,
    @GetUser() user: User
  ): Promise<CreditSimulationResult> {
    try {
      console.log('🔄 Simulation de crédit long pour:', user.username);
      console.log('Données:', JSON.stringify(simulationData, null, 2));

      // Enrichir les données avec les informations utilisateur
      const enrichedData = {
        ...simulationData,
        clientProfile: {
          ...simulationData.clientProfile,
          userId: user.id,
          username: user.username,
          currentScore: user.creditScore || 6.0,
          riskLevel: user.riskLevel || 'moyen'
        }
      };

      const simulation = await this.creditLongService.simulateCredit(enrichedData);
      
      console.log('✅ Simulation réalisée:', simulation.results.score);
      return simulation;

    } catch (error) {
      console.error('❌ Erreur simulation crédit long:', error);
      throw new InternalServerErrorException('Erreur lors de la simulation');
    }
  }

  @Post('quick-simulate')
  async quickSimulation(
    @Body() data: { amount: number; duration: number; username: string },
    @GetUser() user: User
  ) {
    try {
      const simulation = await this.creditLongService.quickSimulation(
        data.amount,
        data.duration,
        user
      );
      
      return {
        success: true,
        simulation,
        message: 'Simulation rapide réalisée'
      };
      
    } catch (error) {
      console.error('❌ Erreur simulation rapide:', error);
      throw new BadRequestException('Impossible de réaliser la simulation');
    }
  }

  // === GESTION DES DEMANDES ===

  @Post('create')
  async createCreditRequest(
    @Body() requestData: CreateCreditLongRequestDto,
    @GetUser() user: User
  ): Promise<CreditLongRequestEntity> {
    try {
      console.log('📝 Création demande crédit long pour:', user.username);
      
      // Vérifier que l'utilisateur peut créer une demande
      await this.creditLongService.validateUserCanCreateRequest(user);
      
      // Créer la demande
      const request = await this.creditLongService.createRequest({
        ...requestData,
        userId: user.id,
        username: user.username
      });

      console.log('✅ Demande créée avec ID:', request.id);
      
      // Notifier les agents back-office
      await this.creditLongService.notifyBackOfficeAgents(request);
      
      return request;

    } catch (error) {
      console.error('❌ Erreur création demande:', error);
      if (error instanceof BadRequestException) {
        throw error;
      }
      throw new InternalServerErrorException('Erreur lors de la création de la demande');
    }
  }

  @Get('user/:username')
  async getUserRequests(
    @Param('username') username: string,
    @GetUser() user: User,
    @Query('status') status?: string,
    @Query('page') page: number = 1,
    @Query('limit') limit: number = 10
  ): Promise<{
    requests: CreditLongRequestEntity[];
    total: number;
    page: number;
    totalPages: number;
  }> {
    try {
      // Vérifier que l'utilisateur demande ses propres données
      if (username !== user.username && !user.isAdmin) {
        throw new BadRequestException('Accès non autorisé');
      }

      const result = await this.creditLongService.getUserRequests(
        username,
        { status, page, limit }
      );

      return result;

    } catch (error) {
      console.error('❌ Erreur récupération demandes utilisateur:', error);
      throw new InternalServerErrorException('Erreur lors de la récupération des demandes');
    }
  }

  @Get(':id')
  async getRequest(
    @Param('id') id: string,
    @GetUser() user: User
  ): Promise<CreditLongRequestEntity> {
    try {
      const request = await this.creditLongService.getRequestById(id);
      
      if (!request) {
        throw new NotFoundException('Demande non trouvée');
      }

      // Vérifier les droits d'accès
      if (request.userId !== user.id && !user.isAdmin) {
        throw new BadRequestException('Accès non autorisé');
      }

      return request;

    } catch (error) {
      console.error('❌ Erreur récupération demande:', error);
      if (error instanceof NotFoundException || error instanceof BadRequestException) {
        throw error;
      }
      throw new InternalServerErrorException('Erreur lors de la récupération de la demande');
    }
  }

  @Put(':id')
  async updateRequest(
    @Param('id') id: string,
    @Body() updates: UpdateCreditLongRequestDto,
    @GetUser() user: User
  ): Promise<CreditLongRequestEntity> {
    try {
      const request = await this.creditLongService.getRequestById(id);
      
      if (!request) {
        throw new NotFoundException('Demande non trouvée');
      }

      // Vérifier les droits de modification
      if (request.userId !== user.id) {
        throw new BadRequestException('Accès non autorisé');
      }

      // Vérifier que la demande peut être modifiée
      if (!this.creditLongService.canModifyRequest(request)) {
        throw new BadRequestException('Cette demande ne peut plus être modifiée');
      }

      const updatedRequest = await this.creditLongService.updateRequest(id, updates);
      
      console.log('✅ Demande mise à jour:', id);
      return updatedRequest;

    } catch (error) {
      console.error('❌ Erreur mise à jour demande:', error);
      if (error instanceof NotFoundException || error instanceof BadRequestException) {
        throw error;
      }
      throw new InternalServerErrorException('Erreur lors de la mise à jour');
    }
  }

  @Post(':id/submit')
  async submitRequest(
    @Param('id') id: string,
    @GetUser() user: User
  ) {
    try {
      const request = await this.creditLongService.getRequestById(id);
      
      if (!request) {
        throw new NotFoundException('Demande non trouvée');
      }

      if (request.userId !== user.id) {
        throw new BadRequestException('Accès non autorisé');
      }

      if (request.status !== 'draft') {
        throw new BadRequestException('Cette demande a déjà été soumise');
      }

      // Valider la demande avant soumission
      const validation = await this.creditLongService.validateRequestForSubmission(request);
      
      if (!validation.isValid) {
        throw new BadRequestException({
          message: 'La demande ne peut pas être soumise',
          errors: validation.errors
        });
      }

      // Soumettre la demande
      const submittedRequest = await this.creditLongService.submitRequest(id);
      
      // Notifier les agents
      await this.creditLongService.notifyBackOfficeAgents(submittedRequest);
      
      console.log('✅ Demande soumise:', id);
      
      return {
        success: true,
        message: 'Demande soumise avec succès',
        request: submittedRequest
      };

    } catch (error) {
      console.error('❌ Erreur soumission demande:', error);
      if (error instanceof NotFoundException || error instanceof BadRequestException) {
        throw error;
      }
      throw new InternalServerErrorException('Erreur lors de la soumission');
    }
  }

  // === BROUILLONS ===

  @Post('draft')
  async saveDraft(
    @Body() draftData: Partial<CreateCreditLongRequestDto>,
    @GetUser() user: User
  ) {
    try {
      const draft = await this.creditLongService.saveDraft({
        ...draftData,
        userId: user.id,
        username: user.username
      });

      return {
        success: true,
        message: 'Brouillon sauvegardé',
        draftId: draft.id
      };

    } catch (error) {
      console.error('❌ Erreur sauvegarde brouillon:', error);
      throw new InternalServerErrorException('Erreur lors de la sauvegarde');
    }
  }

  @Get('draft/:username')
  async getDraft(
    @Param('username') username: string,
    @GetUser() user: User
  ) {
    try {
      if (username !== user.username) {
        throw new BadRequestException('Accès non autorisé');
      }

      const draft = await this.creditLongService.getDraft(username);
      
      return draft || null;

    } catch (error) {
      console.error('❌ Erreur récupération brouillon:', error);
      if (error instanceof BadRequestException) {
        throw error;
      }
      throw new InternalServerErrorException('Erreur lors de la récupération du brouillon');
    }
  }

  @Delete('draft/:username')
  async deleteDraft(
    @Param('username') username: string,
    @GetUser() user: User
  ) {
    try {
      if (username !== user.username) {
        throw new BadRequestException('Accès non autorisé');
      }

      await this.creditLongService.deleteDraft(username);
      
      return {
        success: true,
        message: 'Brouillon supprimé'
      };

    } catch (error) {
      console.error('❌ Erreur suppression brouillon:', error);
      throw new InternalServerErrorException('Erreur lors de la suppression');
    }
  }

  // === GESTION DES DOCUMENTS ===

  @Post(':id/documents')
  @UseInterceptors(FileInterceptor('file'))
  async uploadDocument(
    @Param('id') requestId: string,
    @UploadedFile() file: any, // Changé de Express.Multer.File à any
    @Body('type') documentType: string,
    @GetUser() user: User
  ) {
    try {
      if (!file) {
        throw new BadRequestException('Aucun fichier fourni');
      }

      if (!documentType) {
        throw new BadRequestException('Type de document requis');
      }

      // Vérifier que la demande existe et appartient à l'utilisateur
      const request = await this.creditLongService.getRequestById(requestId);
      if (!request || request.userId !== user.id) {
        throw new BadRequestException('Demande non trouvée ou accès non autorisé');
      }

      // Valider le fichier
      const validation = this.creditLongService.validateUploadedFile(file, documentType);
      if (!validation.isValid) {
        throw new BadRequestException(validation.errors.join(', '));
      }

      // Uploader le document
      const uploadResult = await this.creditLongService.uploadDocument(
        requestId,
        documentType,
        file
      );

      console.log('✅ Document uploadé:', documentType, 'pour demande:', requestId);

      return {
        success: true,
        message: 'Document téléchargé avec succès',
        document: uploadResult
      };

    } catch (error) {
      console.error('❌ Erreur upload document:', error);
      if (error instanceof BadRequestException) {
        throw error;
      }
      throw new InternalServerErrorException('Erreur lors du téléchargement');
    }
  }

  @Get(':id/documents')
  async getDocuments(
    @Param('id') requestId: string,
    @GetUser() user: User
  ) {
    try {
      const request = await this.creditLongService.getRequestById(requestId);
      if (!request || (request.userId !== user.id && !user.isAdmin)) {
        throw new BadRequestException('Demande non trouvée ou accès non autorisé');
      }

      const documents = await this.creditLongService.getRequestDocuments(requestId);
      
      return {
        success: true,
        documents
      };

    } catch (error) {
      console.error('❌ Erreur récupération documents:', error);
      if (error instanceof BadRequestException) {
        throw error;
      }
      throw new InternalServerErrorException('Erreur lors de la récupération des documents');
    }
  }

  @Delete(':id/documents/:documentId')
  async deleteDocument(
    @Param('id') requestId: string,
    @Param('documentId') documentId: string,
    @GetUser() user: User
  ) {
    try {
      const request = await this.creditLongService.getRequestById(requestId);
      if (!request || request.userId !== user.id) {
        throw new BadRequestException('Demande non trouvée ou accès non autorisé');
      }

      if (!this.creditLongService.canModifyRequest(request)) {
        throw new BadRequestException('Les documents ne peuvent plus être modifiés');
      }

      await this.creditLongService.deleteDocument(requestId, documentId);
      
      return {
        success: true,
        message: 'Document supprimé'
      };

    } catch (error) {
      console.error('❌ Erreur suppression document:', error);
      if (error instanceof BadRequestException) {
        throw error;
      }
      throw new InternalServerErrorException('Erreur lors de la suppression');
    }
  }

  // === HISTORIQUE ET COMMENTAIRES ===

  @Get(':id/history')
  async getRequestHistory(
    @Param('id') requestId: string,
    @GetUser() user: User
  ) {
    try {
      const request = await this.creditLongService.getRequestById(requestId);
      if (!request || (request.userId !== user.id && !user.isAdmin)) {
        throw new BadRequestException('Demande non trouvée ou accès non autorisé');
      }

      const history = await this.creditLongService.getRequestHistory(requestId);
      
      return {
        success: true,
        history
      };

    } catch (error) {
      console.error('❌ Erreur récupération historique:', error);
      throw new InternalServerErrorException('Erreur lors de la récupération de l\'historique');
    }
  }

  @Post(':id/comments')
  async addComment(
    @Param('id') requestId: string,
    @Body('comment') comment: string,
    @GetUser() user: User
  ) {
    try {
      if (!comment || comment.trim().length === 0) {
        throw new BadRequestException('Commentaire requis');
      }

      const request = await this.creditLongService.getRequestById(requestId);
      if (!request || request.userId !== user.id) {
        throw new BadRequestException('Demande non trouvée ou accès non autorisé');
      }

      const addedComment = await this.creditLongService.addComment(
        requestId,
        comment.trim(),
        user.username,
        'client'
      );

      return {
        success: true,
        message: 'Commentaire ajouté',
        comment: addedComment
      };

    } catch (error) {
      console.error('❌ Erreur ajout commentaire:', error);
      if (error instanceof BadRequestException) {
        throw error;
      }
      throw new InternalServerErrorException('Erreur lors de l\'ajout du commentaire');
    }
  }

  // === NOTIFICATIONS ===

  @Get('notifications/:username')
  async getNotifications(
    @Param('username') username: string,
    @GetUser() user: User,
    @Query('unread') unreadOnly: boolean = false
  ) {
    try {
      if (username !== user.username) {
        throw new BadRequestException('Accès non autorisé');
      }

      const notifications = await this.creditLongService.getUserNotifications(
        username,
        unreadOnly
      );

      return {
        success: true,
        notifications,
        unreadCount: notifications.filter(n => !n.isRead).length
      };

    } catch (error) {
      console.error('❌ Erreur récupération notifications:', error);
      throw new InternalServerErrorException('Erreur lors de la récupération des notifications');
    }
  }

  @Put('notifications/:id/read')
  async markNotificationAsRead(
    @Param('id') notificationId: string,
    @GetUser() user: User
  ) {
    try {
      await this.creditLongService.markNotificationAsRead(notificationId, user.username);
      
      return {
        success: true,
        message: 'Notification marquée comme lue'
      };

    } catch (error) {
      console.error('❌ Erreur marquage notification:', error);
      throw new InternalServerErrorException('Erreur lors du marquage');
    }
  }

  // === STATISTIQUES ET RAPPORTS ===

  @Get('stats/user/:username')
  async getUserStats(
    @Param('username') username: string,
    @GetUser() user: User
  ) {
    try {
      if (username !== user.username && !user.isAdmin) {
        throw new BadRequestException('Accès non autorisé');
      }

      const stats = await this.creditLongService.getUserStatistics(username);
      
      return {
        success: true,
        stats
      };

    } catch (error) {
      console.error('❌ Erreur récupération statistiques:', error);
      throw new InternalServerErrorException('Erreur lors de la récupération des statistiques');
    }
  }
}