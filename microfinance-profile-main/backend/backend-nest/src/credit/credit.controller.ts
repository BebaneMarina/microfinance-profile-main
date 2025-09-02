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

@Controller('api/credit')
export class CreditController {
  private readonly logger = new Logger(CreditController.name);
  
  // Date et utilisateur courant
  private readonly currentDate = '2025-07-26 11:10:43';
  private readonly currentUser = 'theobawana';

  constructor(
    private readonly creditService: CreditService
  ) {}

  // Endpoint pour calculer le score et l'éligibilité
  @Post('calculate-eligibility')
  @HttpCode(HttpStatus.OK)
  async calculateEligibility(@Body() data: any) {
    try {
      this.logger.log(`=== CALCUL ELIGIBILITE POUR ${this.currentUser} ===`);
      this.logger.log(`Date: ${this.currentDate}`);
      this.logger.log(`Données: ${JSON.stringify(data)}`);
      
      // Ajouter les informations contextuelles
      const enrichedData = {
        ...data,
        username: this.currentUser,
        current_date: this.currentDate,
        userId: data.userId || 1
      };
      
      // Appeler directement le service de scoring
      const result = await this.creditService.calculateScore(enrichedData);
      
      // Calculer le montant éligible basé sur le score
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
        max_duration: 1, // 1 mois pour tous les crédits
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

  // Créer une nouvelle demande de crédit
  @Post()
  @UseGuards(JwtAuthGuard)
  async create(@Body() createCreditRequestDto: CreateCreditRequestDto, @GetUser() user: any) {
    try {
      this.logger.log(`=== NOUVELLE DEMANDE DE CREDIT ===`);
      this.logger.log(`Utilisateur: ${this.currentUser}`);
      this.logger.log(`Date: ${this.currentDate}`);
      this.logger.log(`Type: ${createCreditRequestDto.creditType}`);
      
      const userId = user?.userId || 1;
      
      // Calculer le score d'abord
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
      
      // Enrichir la demande avec le score
      createCreditRequestDto.creditScore = internalScore.score;
      createCreditRequestDto.probability = internalScore.probability;
      createCreditRequestDto.riskLevel = internalScore.risk_level;
      createCreditRequestDto.decision = internalScore.decision || 'pending';
      createCreditRequestDto.recommendations = internalScore.recommendations;
      createCreditRequestDto.scoringFactors = internalScore.factors;
      
      // Créer la demande
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

  // Valider l'éligibilité
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

  // Calculer le score uniquement
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

  // Obtenir toutes les demandes
  @Get()
  @UseGuards(JwtAuthGuard)
  async findAll(@GetUser() user: any, @Query() filters: any) {
    const userId = user?.userId || 1;
    
    this.logger.log(`Récupération des demandes pour utilisateur ${userId}`);
    
    return this.creditService.findAll(userId, filters);
  }

  // Obtenir une demande spécifique
  @Get(':id')
  @UseGuards(JwtAuthGuard)
  async findOne(@Param('id') id: string, @GetUser() user: any) {
    const userId = user?.userId || 1;
    
    this.logger.log(`Récupération de la demande ${id} pour utilisateur ${userId}`);
    
    return this.creditService.findOne(+id, userId);
  }

  // Mettre à jour une demande (VERSION CORRIGÉE)
  @Patch(':id')
  @UseGuards(JwtAuthGuard)
  async update(@Param('id') id: string, @Body() updateCreditRequestDto: UpdateCreditRequestDto, @GetUser() user: any) {
    try {
      this.logger.log(`Mise à jour de la demande ${id} par ${this.currentUser}`);
      
      // Si on met à jour le statut
      if (updateCreditRequestDto.status) {
        const status = updateCreditRequestDto.status as RequestStatus;
        const userId = user?.userId || 1;
        const notes = updateCreditRequestDto.decision_notes || '';
        
        return await this.creditService.updateStatus(+id, status, userId);
      }
      
      // Sinon, retourner la demande sans modification
      return await this.creditService.findOne(+id);
    } catch (error) {
      this.logger.error(`Erreur mise à jour: ${error.message}`);
      throw error;
    }
  }

  // Obtenir les types de crédit disponibles
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

  // Obtenir les statistiques
  @Get('statistics/summary')
  @UseGuards(JwtAuthGuard)
  async getStatistics(@GetUser() user: any, @Query() query: any) {
    const userId = user?.userId || 1;
    
    this.logger.log(`Récupération des statistiques pour utilisateur ${userId}`);
    
    return this.creditService.getStatistics(userId, query?.period);
  }

  // Obtenir les informations du modèle
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

  // Health check de l'API
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

  // Endpoint de test pour vérifier la connexion
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
}