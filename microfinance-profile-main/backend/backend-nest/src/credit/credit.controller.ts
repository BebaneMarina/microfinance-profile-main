import { 
  Controller, 
  Get, 
  Post, 
  Body, 
  Patch, 
  Param, 
  Delete, 
  UseGuards, 
  Query,
  HttpStatus,
  HttpCode,
  Logger
} from '@nestjs/common';
import { CreditService } from './credit.service';
import { CreateCreditRequestDto } from './dto/create-credit-request.dto';
import { JwtAuthGuard } from '../app/auth/guards/jwt-auth.guard';
import { GetUser } from '../decorators/get-user.decorator';
import { RequestStatus } from './entities/credit-request.entity';
import { HttpService } from '@nestjs/axios';
import { firstValueFrom } from 'rxjs';

@Controller('api/credit')
export class CreditController {
  private readonly logger = new Logger(CreditController.name);
  private readonly flaskUrl = 'http://localhost:5000';
  
  private readonly currentDate = new Date().toISOString();
  private readonly currentUser = 'theobawana';

  constructor(
    private readonly creditService: CreditService,
    private readonly httpService: HttpService
  ) {}

  // ==========================================
  // STATS COMPLETES
  // ==========================================

  @Get('user-stats/:userId')
  async getUserStats(@Param('userId') userId: string) {
    try {
      this.logger.log(`Recuperation stats completes pour user: ${userId}`);
      
      const stats = await this.creditService.getUserCompleteStats(Number(userId));
      
      return {
        success: true,
        data: stats
      };
    } catch (error) {
      this.logger.error(`Erreur stats: ${error.message}`);
      return {
        success: false,
        error: error.message
      };
    }
  }

  @Get('user-credits-detailed/:userId')
  async getUserCreditsDetailed(@Param('userId') userId: string) {
    try {
      this.logger.log(`Recuperation credits detailles pour user: ${userId}`);
      
      const credits = await this.creditService.getUserCreditsWithPaymentStatus(Number(userId));
      
      return {
        success: true,
        data: credits,
        count: credits.length
      };
    } catch (error) {
      this.logger.error(`Erreur credits detailles: ${error.message}`);
      return {
        success: false,
        error: error.message,
        data: [],
        count: 0
      };
    }
  }

  // ==========================================
  // NOTIFICATIONS
  // ==========================================

  @Get('notifications/:userId')
  async getUserNotifications(@Param('userId') userId: string, @Query() query: any) {
    try {
      this.logger.log(`Recuperation notifications pour user: ${userId}`);
      
      const unreadOnly = query.unread_only === 'true';
      const limit = query.limit || 20;
      
      const response = await firstValueFrom(
        this.httpService.get(
          `${this.flaskUrl}/notifications/${userId}?unread_only=${unreadOnly}&limit=${limit}`
        )
      );
      
      return {
        success: true,
        data: response.data
      };
    } catch (error) {
      this.logger.error(`Erreur notifications: ${error.message}`);
      return {
        success: false,
        error: error.message,
        data: {
          notifications: [],
          total: 0,
          unread_count: 0
        }
      };
    }
  }

  @Post('notifications/:notificationId/mark-read')
  @HttpCode(HttpStatus.OK)
  async markNotificationRead(@Param('notificationId') notificationId: string) {
    try {
      const response = await firstValueFrom(
        this.httpService.post(`${this.flaskUrl}/notifications/${notificationId}/mark-read`, {})
      );
      
      return {
        success: true,
        data: response.data
      };
    } catch (error) {
      this.logger.error(`Erreur marquage notification: ${error.message}`);
      return {
        success: false,
        error: error.message
      };
    }
  }

  @Post('notifications/:userId/mark-all-read')
  @HttpCode(HttpStatus.OK)
  async markAllNotificationsRead(@Param('userId') userId: string) {
    try {
      const response = await firstValueFrom(
        this.httpService.post(`${this.flaskUrl}/notifications/${userId}/mark-all-read`, {})
      );
      
      return {
        success: true,
        data: response.data
      };
    } catch (error) {
      this.logger.error(`Erreur marquage notifications: ${error.message}`);
      return {
        success: false,
        error: error.message
      };
    }
  }

  // ==========================================
  // ENDPOINTS PRINCIPAUX
  // ==========================================

  @Post('calculate-eligibility')
  @HttpCode(HttpStatus.OK)
  async calculateEligibility(@Body() data: any) {
    try {
      this.logger.log(`Calcul eligibilite pour ${this.currentUser}`);
      
      const enrichedData = {
        ...data,
        username: this.currentUser,
        current_date: this.currentDate,
        userId: data.userId || 1
      };
      
      const result = await this.creditService.calculateScore(enrichedData);
      
      const monthlyIncome = Number(data.monthly_income || data.financialInfo?.monthlySalary || 0);
      let eligibleAmount = monthlyIncome;
      
      if (result.risk_level === 'low' || result.risk_level === 'very_low') {
        eligibleAmount = Math.min(monthlyIncome * 0.3333, 2000000);
      } else if (result.risk_level === 'medium') {
        eligibleAmount = Math.min(monthlyIncome, 2000000);
      } else if (result.risk_level === 'high') {
        eligibleAmount = Math.min(monthlyIncome * 0.333, 2000000);
      } else {
        eligibleAmount = Math.min(monthlyIncome * 0.3333, 2000000);
      }
      
      return {
        ...result,
        eligible_amount: Math.floor(eligibleAmount),
        max_duration: 1,
        username: this.currentUser,
        timestamp: this.currentDate
      };
    } catch (error) {
      this.logger.error(`Erreur calcul eligibilite: ${error.message}`);
      throw error;
    }
  }

  @Post()
  @UseGuards(JwtAuthGuard)
  async create(@Body() createCreditRequestDto: CreateCreditRequestDto, @GetUser() user: any) {
    try {
      this.logger.log(`Nouvelle demande de credit`);
      
      const userId = user?.userId || 1;
      
      const scoringData = {
        monthly_income: Number(createCreditRequestDto.financialInfo.monthlySalary),
        other_income: Number(createCreditRequestDto.financialInfo.otherIncome || 0),
        monthly_charges: Number(createCreditRequestDto.financialInfo.monthlyCharges || 0),
        existing_debts: Number(createCreditRequestDto.financialInfo.existingDebts || 0),
        job_seniority: Number(createCreditRequestDto.financialInfo.jobSeniority || 12),
        employment_status: createCreditRequestDto.financialInfo.contractType,
        loan_amount: Number(createCreditRequestDto.creditDetails.requestedAmount),
        loan_duration: Number(createCreditRequestDto.creditDetails.duration || 1),
        credit_type: createCreditRequestDto.creditType,
        username: this.currentUser,
        current_date: this.currentDate,
        userId: userId
      };
      
      const internalScore = await this.creditService.calculateScore(scoringData);
      
      createCreditRequestDto.creditScore = internalScore.score;
      createCreditRequestDto.probability = internalScore.probability;
      createCreditRequestDto.riskLevel = internalScore.risk_level;
      createCreditRequestDto.decision = internalScore.decision || 'pending';
      createCreditRequestDto.recommendations = internalScore.recommendations;
      createCreditRequestDto.scoringFactors = internalScore.factors;
      
      const creditRequest = await this.creditService.create(createCreditRequestDto, userId);
      
      this.logger.log(`Demande creee: ${creditRequest.numero_demande}`);
      
      return {
        success: true,
        message: 'Demande de credit creee avec succes',
        data: {
          id: creditRequest.id,
          requestNumber: creditRequest.numero_demande,
          submissionDate: creditRequest.date_soumission,
          status: creditRequest.statut,
          score: creditRequest.score_au_moment_demande,
          riskLevel: creditRequest.niveau_risque_evaluation,
          decision: creditRequest.decision
        }
      };
    } catch (error) {
      this.logger.error(`Erreur creation demande: ${error.message}`);
      return {
        success: false,
        message: error.message || 'Erreur lors de la creation',
        data: null
      };
    }
  }

  // ==========================================
  // ENREGISTREMENT CREDIT
  // ==========================================

  @Post('register-credit')
  @HttpCode(HttpStatus.OK)
  async registerCredit(@Body() creditData: any) {
    try {
      this.logger.log(`Enregistrement credit`);
      
      const newCredit = {
        utilisateur_id: creditData.user_id,
        type_credit: creditData.type,
        montant_principal: creditData.amount,
        montant_total: creditData.totalAmount,
        montant_restant: creditData.totalAmount,
        taux_interet: creditData.interestRate,
        duree_mois: 1,
        statut: 'actif',
        date_approbation: new Date(),
        date_echeance: this.calculateDueDate(creditData.type),
        date_prochain_paiement: this.calculateNextPayment(creditData.type),
        montant_prochain_paiement: creditData.totalAmount
      };
      
      const savedCredit = await this.creditService.registerCredit(newCredit);
      
      await this.creditService.updateUserRestrictions(creditData.user_id);
      
      return {
        success: true,
        credit: savedCredit,
        message: 'Credit enregistre avec succes'
      };
      
    } catch (error) {
      this.logger.error(`Erreur enregistrement credit: ${error.message}`);
      throw error;
    }
  }

  @Get('user-credits/:username')
  async getUserCredits(@Param('username') username: string) {
    try {
      const user = await this.creditService.findUserByUsername(username);
      
      if (!user) {
        return [];
      }
      
      const credits = await this.creditService.getUserActiveCredits(user.id);
      
      return credits;
      
    } catch (error) {
      this.logger.error(`Erreur recuperation credits: ${error.message}`);
      return [];
    }
  }

  @Get('restrictions/:username')
  async getUserRestrictions(@Param('username') username: string) {
    try {
      const user = await this.creditService.findUserByUsername(username);
      
      if (!user) {
        return this.getDefaultRestrictions();
      }
      
      const restrictions = await this.creditService.getUserRestrictions(user.id);
      
      return restrictions;
      
    } catch (error) {
      this.logger.error(`Erreur restrictions: ${error.message}`);
      return this.getDefaultRestrictions();
    }
  }

  @Post('process-payment')
  @HttpCode(HttpStatus.OK)
  async processPayment(@Body() paymentData: any) {
    try {
      this.logger.log(`Traitement paiement`);
      
      const result = await this.creditService.processPayment(paymentData);
      
      if (paymentData.user_id) {
        await this.creditService.triggerScoreRecalculation(paymentData.user_id);
      }
      
      return {
        success: true,
        message: 'Paiement traite',
        score_impact: result.score_impact
      };
      
    } catch (error) {
      this.logger.error(`Erreur paiement: ${error.message}`);
      throw error;
    }
  }

  // ==========================================
  // ENDPOINTS EXISTANTS
  // ==========================================

  @Get()
  @UseGuards(JwtAuthGuard)
  async findAll(@GetUser() user: any, @Query() filters: any) {
    const userId = user?.userId || 1;
    return this.creditService.findAll(userId, filters);
  }

  @Get(':id')
  @UseGuards(JwtAuthGuard)
  async findOne(@Param('id') id: string, @GetUser() user: any) {
    const userId = user?.userId || 1;
    return this.creditService.findOne(+id, userId);
  }

  @Get('types/list')
  async getCreditTypes() {
    return await this.creditService.getCreditTypes();
  }

  @Get('statistics/summary')
  @UseGuards(JwtAuthGuard)
  async getStatistics(@GetUser() user: any, @Query() query: any) {
    const userId = user?.userId || 1;
    return this.creditService.getStatistics(userId, query?.period);
  }

  @Get('model/info')
  getModelInfo() {
    return this.creditService.getModelInfo();
  }

  @Get('health/check')
  healthCheck() {
    return {
      status: 'ok',
      timestamp: this.currentDate,
      user: this.currentUser,
      service: 'credit-service',
      version: '8.0'
    };
  }

  // ==========================================
  // UTILITAIRES
  // ==========================================

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

  private calculateNextPayment(creditType: string): Date {
    return this.calculateDueDate(creditType);
  }

  private getDefaultRestrictions() {
    return {
      canApplyForCredit: true,
      maxCreditsAllowed: 2,
      activeCreditCount: 0,
      totalActiveDebt: 0,
      debtRatio: 0
    };
  }
}