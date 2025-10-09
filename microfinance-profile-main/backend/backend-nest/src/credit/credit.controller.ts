// src/credit/credit.controller.ts
import { 
  Controller, 
  Get, 
  Post, 
  Body, 
  Patch, 
  Param, 
  Delete, 
  UseGuards, 
  Req,
  Query,
  HttpStatus,
  HttpCode,
  Logger
} from '@nestjs/common';
import { CreditService } from './credit.service';
import { CreateCreditRequestDto } from './dto/create-credit-request.dto';
import { UpdateCreditRequestDto } from './dto/update-credit-request.dto';
import { JwtAuthGuard } from '../app/auth/guards/jwt-auth.guard';
import { GetUser } from '../decorators/get-user.decorator';
import { RequestStatus } from './entities/credit-request.entity';
import { CreditStatsService } from './credit-stats.service';

@Controller('api/credit')
export class CreditController {
  private readonly logger = new Logger(CreditController.name);
  
  private readonly currentDate = new Date().toISOString();
  private readonly currentUser = 'theobawana';

  constructor(
    private readonly creditService: CreditService,
    private readonly creditStatsService: CreditStatsService
  ) {}

  // ==========================================
  // ENDPOINTS PRINCIPAUX
  // ==========================================

  /**
   * Calcule l'éligibilité d'un utilisateur
   */
  @Post('calculate-eligibility')
  @HttpCode(HttpStatus.OK)
  async calculateEligibility(@Body() data: any) {
    try {
      this.logger.log(`=== CALCUL ELIGIBILITE POUR ${this.currentUser} ===`);
      this.logger.log(`Date: ${this.currentDate}`);
      this.logger.log(`Données: ${JSON.stringify(data)}`);
      
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
      
      const response = {
        ...result,
        eligible_amount: Math.floor(eligibleAmount),
        max_duration: 1,
        username: this.currentUser,
        timestamp: this.currentDate
      };
      
      this.logger.log(`Résultat: Score=${response.score}, Montant éligible=${response.eligible_amount}`);
      
      return response;
    } catch (error) {
      this.logger.error(`Erreur calcul éligibilité: ${error.message}`);
      throw error;
    }
  }

  // credit.controller.ts - AJOUT ENDPOINT STATS

/**
 * ✅ Récupère les statistiques complètes d'un utilisateur
 */
@Get('user-stats/:userId')
async getUserStats(@Param('userId') userId: string) {
  try {
    this.logger.log(`📊 Récupération stats complètes pour user: ${userId}`);
    
    const stats = await this.creditService.getUserCompleteStats(Number(userId));
    
    return {
      success: true,
      data: stats
    };
  } catch (error) {
    this.logger.error(`❌ Erreur stats: ${error.message}`);
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


  /**
   * Crée une nouvelle demande de crédit
   */
  @Post()
  @UseGuards(JwtAuthGuard)
  async create(@Body() createCreditRequestDto: CreateCreditRequestDto, @GetUser() user: any) {
    try {
      this.logger.log(`=== NOUVELLE DEMANDE DE CREDIT ===`);
      this.logger.log(`Utilisateur: ${this.currentUser}`);
      this.logger.log(`Date: ${this.currentDate}`);
      this.logger.log(`Type: ${createCreditRequestDto.creditType}`);
      
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
      
      this.logger.log(`Demande créée avec succès: ${creditRequest.requestNumber}`);
      
      return {
        success: true,
        message: 'Demande de crédit créée avec succès',
        data: {
          id: creditRequest.id,
          requestNumber: creditRequest.requestNumber,
          submissionDate: creditRequest.submissionDate,
          status: creditRequest.status,
          score: creditRequest.creditScore,
          riskLevel: creditRequest.riskLevel,
          decision: creditRequest.decision
        }
      };
    } catch (error) {
      this.logger.error(`Erreur création demande: ${error.message}`);
      return {
        success: false,
        message: error.message || 'Erreur lors de la création de la demande',
        data: null
      };
    }
  }

  // ==========================================
  // NOUVEAUX ENDPOINTS POSTGRESQL
  // ==========================================

  /**
   * Enregistre un crédit approuvé dans PostgreSQL
   */
  @Post('register-credit')
  @HttpCode(HttpStatus.OK)
  async registerCredit(@Body() creditData: any) {
    try {
      this.logger.log(`=== ENREGISTREMENT CRÉDIT ===`);
      this.logger.log(`Utilisateur: ${creditData.username}`);
      this.logger.log(`Type: ${creditData.type}`);
      this.logger.log(`Montant: ${creditData.amount}`);
      
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
        message: 'Crédit enregistré avec succès'
      };
      
    } catch (error) {
      this.logger.error(`Erreur enregistrement crédit: ${error.message}`);
      throw error;
    }
  }

  /**
   * Récupère les crédits d'un utilisateur
   */
  @Get('user-credits/:username')
  async getUserCredits(@Param('username') username: string) {
    try {
      this.logger.log(`Récupération crédits pour: ${username}`);
      
      const user = await this.creditService.findUserByUsername(username);
      
      if (!user) {
        return [];
      }
      
      const credits = await this.creditService.getUserActiveCredits(user.id);
      
      return credits;
      
    } catch (error) {
      this.logger.error(`Erreur récupération crédits: ${error.message}`);
      return [];
    }
  }

  /**
   * Récupère les restrictions d'un utilisateur
   */
  @Get('restrictions/:username')
  async getUserRestrictions(@Param('username') username: string) {
    try {
      this.logger.log(`Récupération restrictions pour: ${username}`);
      
      const user = await this.creditService.findUserByUsername(username);
      
      if (!user) {
        return this.getDefaultRestrictions();
      }
      
      const restrictions = await this.creditService.getUserRestrictions(user.id);
      
      return restrictions;
      
    } catch (error) {
      this.logger.error(`Erreur récupération restrictions: ${error.message}`);
      return this.getDefaultRestrictions();
    }
  }

  /**
   * Traite un paiement
   */
  @Post('process-payment')
  @HttpCode(HttpStatus.OK)
  async processPayment(@Body() paymentData: any) {
    try {
      this.logger.log(`=== TRAITEMENT PAIEMENT ===`);
      this.logger.log(`Crédit ID: ${paymentData.credit_id}`);
      this.logger.log(`Montant: ${paymentData.payment.amount}`);
      
      const result = await this.creditService.processPayment(paymentData);
      
      if (paymentData.user_id) {
        await this.creditService.triggerScoreRecalculation(paymentData.user_id);
      }
      
      return {
        success: true,
        message: 'Paiement traité',
        score_impact: result.score_impact
      };
      
    } catch (error) {
      this.logger.error(`Erreur traitement paiement: ${error.message}`);
      throw error;
    }
  }

  // ==========================================
  // ENDPOINTS EXISTANTS (conservés)
  // ==========================================

  @Post('validate-eligibility')
  @HttpCode(HttpStatus.OK)
  async validateEligibility(@Body() data: any) {
    try {
      this.logger.log(`Validation éligibilité pour ${this.currentUser}`);
      
      const enrichedData = {
        ...data,
        username: this.currentUser,
        current_date: this.currentDate
      };
      
      return await this.creditService.validateEligibility(enrichedData);
    } catch (error) {
      this.logger.error(`Erreur validation: ${error.message}`);
      throw error;
    }
  }

  @Post('calculate-score')
  @HttpCode(HttpStatus.OK)
  async calculateScore(@Body() data: any) {
    try {
      this.logger.log(`Calcul du score pour ${this.currentUser}`);
      
      const enrichedData = {
        ...data,
        username: this.currentUser,
        current_date: this.currentDate
      };
      
      return await this.creditService.calculateScore(enrichedData);
    } catch (error) {
      this.logger.error(`Erreur calcul score: ${error.message}`);
      throw error;
    }
  }

  @Get()
  @UseGuards(JwtAuthGuard)
  async findAll(@GetUser() user: any, @Query() filters: any) {
    const userId = user?.userId || 1;
    
    this.logger.log(`Récupération des demandes pour utilisateur ${userId}`);
    
    return this.creditService.findAll(userId, filters);
  }

  @Get(':id')
  @UseGuards(JwtAuthGuard)
  async findOne(@Param('id') id: string, @GetUser() user: any) {
    const userId = user?.userId || 1;
    
    this.logger.log(`Récupération de la demande ${id} pour utilisateur ${userId}`);
    
    return this.creditService.findOne(+id, userId);
  }

  @Patch(':id')
  @UseGuards(JwtAuthGuard)
  async update(@Param('id') id: string, @Body() updateCreditRequestDto: UpdateCreditRequestDto, @GetUser() user: any) {
    try {
      this.logger.log(`Mise à jour de la demande ${id} par ${this.currentUser}`);
      
      if (updateCreditRequestDto.status) {
        const status = updateCreditRequestDto.status as RequestStatus;
        const userId = user?.userId || 1;
        const notes = updateCreditRequestDto.decision_notes || '';
        
        return await this.creditService.updateStatus(+id, status, userId);
      }
      
      return await this.creditService.findOne(+id);
    } catch (error) {
      this.logger.error(`Erreur mise à jour: ${error.message}`);
      throw error;
    }
  }

  @Get('types/list')
  async getCreditTypes() {
    try {
      this.logger.log(`Récupération des types de crédit pour ${this.currentUser}`);
      
      return await this.creditService.getCreditTypes();
    } catch (error) {
      this.logger.error(`Erreur récupération types: ${error.message}`);
      throw error;
    }
  }

  @Get('statistics/summary')
  @UseGuards(JwtAuthGuard)
  async getStatistics(@GetUser() user: any, @Query() query: any) {
    const userId = user?.userId || 1;
    
    this.logger.log(`Récupération des statistiques pour utilisateur ${userId}`);
    
    return this.creditService.getStatistics(userId, query?.period);
  }

  @Get('model/info')
  getModelInfo() {
    try {
      this.logger.log(`Récupération des infos du modèle`);
      
      return this.creditService.getModelInfo();
    } catch (error) {
      this.logger.error(`Erreur info modèle: ${error.message}`);
      throw error;
    }
  }

  @Get('health/check')
  healthCheck() {
    return {
      status: 'ok',
      timestamp: this.currentDate,
      user: this.currentUser,
      service: 'credit-service',
      version: '1.0.0'
    };
  }

  @Post('test/connection')
  @HttpCode(HttpStatus.OK)
  testConnection(@Body() data: any) {
    this.logger.log(`Test de connexion reçu de ${data.username || 'anonyme'}`);
    
    return {
      success: true,
      message: 'Connexion réussie',
      timestamp: this.currentDate,
      currentUser: this.currentUser,
      receivedData: data
    };
  }

  // ==========================================
  // MÉTHODES UTILITAIRES PRIVÉES
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