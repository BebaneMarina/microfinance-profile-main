import { Controller, Get, Post, Body, Param, ParseIntPipe, Logger } from '@nestjs/common';
import { ScoringService } from './scoring.service';

@Controller('scoring')
export class ScoringController {
  private readonly logger = new Logger(ScoringController.name);

  constructor(
    private readonly scoringService: ScoringService,
  ) {}

  @Post('calculate')
  async calculateScore(@Body() data: any) {
    try {
      this.logger.log('Calcul du score de crédit demandé');
      return await this.scoringService.calculateScore(data);
    } catch (error) {
      this.logger.error(`Erreur lors du calcul du score: ${error.message}`);
      return {
        error: 'Erreur interne',
        message: 'Une erreur est survenue lors du calcul'
      };
    }
  }

  @Get('user/:userId')
  async getUserScores(@Param('userId', ParseIntPipe) userId: number) {
    try {
      return await this.scoringService.findByUserId(userId);
    } catch (error) {
      this.logger.error(`Erreur lors de la récupération des scores: ${error.message}`);
      return {
        error: 'Erreur interne',
        message: 'Impossible de récupérer les scores'
      };
    }
  }

  @Get(':id')
  async findOne(@Param('id', ParseIntPipe) id: number) {
    try {
      return await this.scoringService.findOne(id);
    } catch (error) {
      this.logger.error(`Erreur lors de la récupération du score: ${error.message}`);
      return {
        error: 'Score non trouvé',
        message: `Le score avec l'ID ${id} n'existe pas`
      };
    }
  }

  @Get()
  async findAll() {
    try {
      return await this.scoringService.findAll();
    } catch (error) {
      this.logger.error(`Erreur lors de la récupération des scores: ${error.message}`);
      return {
        error: 'Erreur interne',
        message: 'Impossible de récupérer les scores'
      };
    }
  }

  @Post('eligible-amount')
  async calculateEligibleAmount(@Body() data: {
    risk_level: any; monthly_income: number; credit_score: number 
}) {
    try {
      const amount = await this.scoringService.calculateEligibleAmount(
        data.monthly_income,
        data.credit_score,
        data.risk_level,
      );

      return {
        eligible_amount: amount,
        monthly_income: data.monthly_income,
        credit_score: data.credit_score,
        calculation_date: new Date().toISOString()
      };
    } catch (error) {
      this.logger.error(`Erreur lors du calcul du montant éligible: ${error.message}`);
      return {
        error: 'Erreur de calcul',
        message: 'Impossible de calculer le montant éligible'
      };
    }
  }
}