// credit-long-request.controller.ts
import { 
  BadRequestException, 
  Body, 
  Controller, 
  Get, 
  Param, 
  Post, 
  Put, 
  Delete,
  Query,
  UploadedFile, 
  UseInterceptors 
} from "@nestjs/common";
import { CreditLongRequestService } from "./credit-long-request.service";
import { FileInterceptor } from "@nestjs/platform-express";

@Controller('credit-long')
export class CreditLongController {
  constructor(
    private readonly creditLongRequestService: CreditLongRequestService
  ) {}

  @Post('create')
  async createLongRequest(@Body() requestData: any) {
    try {
      const validatedData = this.validateLongRequestData(requestData);
      const createdRequest = await this.creditLongRequestService.createRequest(validatedData);
      
      if (createdRequest.status === 'submitted') {
        await this.notifyBackOfficeAgents(createdRequest);
      }
      
      return {
        success: true,
        request: createdRequest,
        message: createdRequest.status === 'draft' ? 'Brouillon sauvegardé' : 'Demande soumise'
      };
    } catch (error) {
      console.error('Erreur création demande longue:', error);
      throw new BadRequestException('Impossible de créer la demande');
    }
  }

  @Get('user/:username')
  async getUserRequests(
    @Param('username') username: string,
    @Query('status') status?: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string
  ) {
    try {
      const result = await this.creditLongRequestService.getUserRequests(username, {
        status,
        page: page ? parseInt(page) : 1,
        limit: limit ? parseInt(limit) : 100,
        includeHistory: true,
        includeDocuments: true
      });

      // Enrichir avec les documents
      const requestsWithDocuments = await Promise.all(
        result.requests.map(async (request) => {
          const documents = await this.creditLongRequestService.getRequestDocuments(
            request.id.toString()
          );
          
          return {
            ...request,
            documentsCount: documents.length,
            hasAllRequiredDocuments: this.checkRequiredDocuments(documents)
          };
        })
      );
      
      return {
        success: true,
        requests: requestsWithDocuments,
        total: result.total,
        page: result.page,
        totalPages: result.totalPages
      };
    } catch (error) {
      console.error('Erreur récupération demandes:', error);
      throw new BadRequestException('Impossible de récupérer les demandes');
    }
  }

  @Get('user/:username/draft')
  async getUserDraft(@Param('username') username: string) {
    try {
      const draft = await this.creditLongRequestService.getDraft(username);
      return {
        success: true,
        request: draft
      };
    } catch (error) {
      console.error('Erreur récupération brouillon:', error);
      return { 
        success: false, 
        request: null 
      };
    }
  }

  @Get('request/:id')
  async getRequestById(@Param('id') id: string) {
    try {
      const request = await this.creditLongRequestService.getRequestById(id);
      const documents = await this.creditLongRequestService.getRequestDocuments(id);
      const history = await this.creditLongRequestService.getRequestHistory(id);
      
      return {
        success: true,
        request: {
          ...request,
          documents,
          reviewHistory: history
        }
      };
    } catch (error) {
      throw new BadRequestException('Demande non trouvée');
    }
  }

  @Put('request/:id')
  async updateLongRequest(
    @Param('id') id: string, 
    @Body() updates: any
  ) {
    try {
      const updatedRequest = await this.creditLongRequestService.updateRequest(id, updates);
      return {
        success: true,
        request: updatedRequest
      };
    } catch (error) {
      console.error('Erreur mise à jour:', error);
      throw new BadRequestException('Impossible de mettre à jour la demande');
    }
  }

  @Post('request/:id/submit')
  async submitLongRequest(@Param('id') id: string) {
    try {
      const submittedRequest = await this.creditLongRequestService.submitRequest(id);
      await this.notifyBackOfficeAgents(submittedRequest);
      
      return {
        success: true,
        request: submittedRequest,
        message: 'Demande soumise pour examen'
      };
    } catch (error) {
      console.error('Erreur soumission:', error);
      throw new BadRequestException('Impossible de soumettre la demande');
    }
  }

  @Post('request/:id/documents')
  @UseInterceptors(FileInterceptor('file'))
  async uploadDocument(
    @Param('id') id: string,
    @Body('documentType') documentType: string,
    @UploadedFile() file: Express.Multer.File
  ) {
    try {
      const uploadedDoc = await this.creditLongRequestService.uploadDocument(
        id, 
        documentType, 
        file
      );
      
      return {
        success: true,
        document: uploadedDoc
      };
    } catch (error) {
      console.error('Erreur upload document:', error);
      throw new BadRequestException('Impossible d\'uploader le document');
    }
  }

  @Delete('request/:id')
  async deleteRequest(@Param('id') id: string) {
    try {
      await this.creditLongRequestService.deleteRequest(id);
      return {
        success: true,
        message: 'Demande supprimée avec succès'
      };
    } catch (error) {
      console.error('Erreur suppression:', error);
      throw new BadRequestException('Impossible de supprimer la demande');
    }
  }

  @Post('draft')
  async saveDraft(@Body() draftData: any) {
    try {
      const savedDraft = await this.creditLongRequestService.saveDraft(draftData);
      return {
        success: true,
        request: savedDraft,
        message: 'Brouillon sauvegardé'
      };
    } catch (error) {
      console.error('Erreur sauvegarde brouillon:', error);
      throw new BadRequestException('Impossible de sauvegarder le brouillon');
    }
  }

  @Get('user/:username/stats')
  async getUserStats(@Param('username') username: string) {
    try {
      const stats = await this.creditLongRequestService.getUserStatistics(username);
      return {
        success: true,
        stats
      };
    } catch (error) {
      throw new BadRequestException('Impossible de récupérer les statistiques');
    }
  }

  // Méthodes privées
  private validateLongRequestData(data: any): any {
    if (!data.username) {
      throw new BadRequestException('Username requis');
    }
    if (!data.personalInfo && data.status !== 'draft') {
      throw new BadRequestException('Informations personnelles requises');
    }
    if (!data.creditDetails && data.status !== 'draft') {
      throw new BadRequestException('Détails du crédit requis');
    }
    return data;
  }

  private checkRequiredDocuments(documents: any[]): boolean {
    const requiredTypes = ['identityProof', 'incomeProof', 'employmentCertificate'];
    return requiredTypes.every(type => 
      documents.some(doc => doc.documentType === type)
    );
  }

  private async notifyBackOfficeAgents(request: any): Promise<void> {
    console.log('Notification envoyée pour la demande:', request.id);
  }
}