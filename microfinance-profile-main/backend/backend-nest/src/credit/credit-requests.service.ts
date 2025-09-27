import { BadRequestException, Injectable } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { ShortCreditRequest } from "./entities/short-credit-request.entity";
import { CreditLongRequestEntity } from "./credit-long.dto";
import { Repository } from "typeorm";
import { HttpService } from "@nestjs/axios";

// credit-requests.service.ts (Backend)
@Injectable()
export class CreditRequestsService {
  updateRequest: any;
    deleteRequest: any;
    submitRequest: any;
    logger: any;
  getShortRequests(username: string) {
      throw new Error("Method not implemented.");
  }
  constructor(
    @InjectRepository(ShortCreditRequest)
    private shortCreditRepo: Repository<ShortCreditRequest>,
    
    @InjectRepository(CreditLongRequestEntity)
    private longCreditRepo: Repository<CreditLongRequestEntity>,
    
    private httpService: HttpService
  ) {}

  async createShortRequest(requestData: any): Promise<ShortCreditRequest> {
    const shortRequest = this.shortCreditRepo.create({
      username: requestData.username,
      creditType: requestData.type,
      amount: requestData.amount,
      totalAmount: requestData.totalAmount,
      remainingAmount: requestData.totalAmount,
      interestRate: this.getInterestRate(requestData.type),
      approvedDate: new Date(),
      dueDate: this.calculateDueDate(requestData.type),
      disbursedAmount: requestData.amount,
      status: 'active'
    });

    const saved = await this.shortCreditRepo.save(shortRequest);

    // Notification optionnelle à l'API Flask
    try {
      await this.httpService.post('http://localhost:5000/register-credit', {
        username: requestData.username,
        credit: saved,
        client_data: requestData.client_data
      }).toPromise();
    } catch (error) {
      console.warn('Flask API notification failed:', error);
    }

    return saved;
  }

  async getUserRequests(username: string, filters?: any): Promise<{
    shortRequests: ShortCreditRequest[];
    longRequests: CreditLongRequestEntity[];
    stats: any;
  }> {
    const [shortRequests, longRequests] = await Promise.all([
      this.shortCreditRepo.find({
        where: { username },
        order: { createdAt: 'DESC' }
      }),
      this.longCreditRepo.find({
        where: { username },
        order: { createdAt: 'DESC' }
      })
    ]);

    const stats = {
      total: shortRequests.length + longRequests.length,
      short: shortRequests.length,
      long: longRequests.length,
      active: shortRequests.filter(r => r.status === 'active').length +
              longRequests.filter(r => ['approved', 'submitted'].includes(r.status)).length,
      pending: longRequests.filter(r => ['submitted', 'in_review'].includes(r.status)).length,
      completed: shortRequests.filter(r => r.status === 'paid').length +
                 longRequests.filter(r => r.status === 'approved').length
    };

    return { shortRequests, longRequests, stats };
  }

  private getInterestRate(creditType: string): number {
    const rates = {
      'consommation_generale': 0.05,
      'avance_salaire': 0.03,
      'depannage': 0.04,
      'investissement': 0.08,
      'tontine': 0.06,
      'retraite': 0.04
    };
    return rates[creditType] || 0.05;
  }

  private calculateDueDate(creditType: string): Date {
    const dueDate = new Date();
    
    switch (creditType) {
      case 'avance_salaire':
        dueDate.setMonth(dueDate.getMonth() + 1);
        dueDate.setDate(new Date(dueDate.getFullYear(), dueDate.getMonth() + 1, 0).getDate());
        break;
      case 'depannage':
        dueDate.setDate(dueDate.getDate() + 30);
        break;
      case 'consommation_generale':
        dueDate.setDate(dueDate.getDate() + 45);
        break;
      default:
        dueDate.setDate(dueDate.getDate() + 30);
    }
    
    return dueDate;
  }

  
  /**
   * Crée une nouvelle demande de crédit long
   */
  async createLongRequest(requestData: any): Promise<any> {
    try {
      this.logger.log(`Creating long credit request for user: ${requestData.username}`);
      
      // Logique de création - à adapter selon votre modèle de données
      // Cette méthode devrait probablement déléguer au CreditLongRequestService
      
      // Exemple d'implémentation temporaire:
      const createdRequest = {
        id: `temp-${Date.now()}`,
        ...requestData,
        createdAt: new Date(),
        status: requestData.status || 'draft'
      };

      return createdRequest;
      
    } catch (error) {
      this.logger.error(`Error creating long request: ${error.message}`, error.stack);
      throw new BadRequestException('Impossible de créer la demande longue');
    }
  }

  /**
   * Récupère le brouillon d'une demande longue
   */
  async getLongRequestDraft(username: string): Promise<any> {
    try {
      this.logger.log(`Fetching draft for user: ${username}`);
      
      // Logique de récupération du brouillon
      // À adapter selon votre modèle de données
      
      // Retourner null si aucun brouillon trouvé
      return null;
      
    } catch (error) {
      this.logger.error(`Error fetching draft: ${error.message}`, error.stack);
      return null;
    }
  }

  /**
   * Met à jour une demande de crédit long
   */
  async updateLongRequest(id: string, updates: any): Promise<any> {
    try {
      this.logger.log(`Updating long request: ${id}`);
      
      // Validation de l'existence de la demande
      if (!id) {
        throw new BadRequestException('ID de demande requis');
      }

      // Logique de mise à jour
      // À adapter selon votre modèle de données
      
      const updatedRequest = {
        id,
        ...updates,
        updatedAt: new Date()
      };

      return updatedRequest;
      
    } catch (error) {
      this.logger.error(`Error updating long request: ${error.message}`, error.stack);
      throw new BadRequestException('Impossible de mettre à jour la demande');
    }
  }

  /**
   * Soumet une demande longue pour révision
   */
  async submitLongRequestForReview(id: string): Promise<any> {
    try {
      this.logger.log(`Submitting long request for review: ${id}`);
      
      // Validation
      if (!id) {
        throw new BadRequestException('ID de demande requis');
      }

      // Changer le statut à "submitted"
      const submittedRequest = await this.updateLongRequest(id, {
        status: 'submitted',
        submissionDate: new Date()
      });

      return submittedRequest;
      
    } catch (error) {
      this.logger.error(`Error submitting request: ${error.message}`, error.stack);
      throw new BadRequestException('Impossible de soumettre la demande');
    }
  }

  /**
   * Upload un document pour une demande longue
   */
  async uploadLongRequestDocument(
    requestId: string,
    documentType: string,
    file: any // Type temporaire - remplacer par Express.Multer.File
  ): Promise<any> {
    try {
      this.logger.log(`Uploading document for request: ${requestId}`);
      
      // Validation
      if (!requestId || !documentType || !file) {
        throw new BadRequestException('Paramètres manquants pour l\'upload');
      }

      // Logique d'upload - à adapter
      const uploadedDocument = {
        id: `doc-${Date.now()}`,
        requestId,
        documentType,
        filename: file.originalname || 'unknown',
        uploadedAt: new Date()
      };

      return uploadedDocument;
      
    } catch (error) {
      this.logger.error(`Error uploading document: ${error.message}`, error.stack);
      throw new BadRequestException('Impossible d\'uploader le document');
    }
  }
}