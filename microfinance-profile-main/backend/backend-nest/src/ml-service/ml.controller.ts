// src/ml/ml.controller.ts
import { Controller, Get, Post, Body, HttpException, HttpStatus } from '@nestjs/common';
import { MlService } from './ml-service.service';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';

@ApiTags('ML Service')
@Controller('ml')
export class MlController {
  constructor(private readonly mlService: MlService) {}

  @Get('health')
  @ApiOperation({ summary: 'Vérification de l\'état du service' })
  @ApiResponse({ status: 200, description: 'Service opérationnel' })
  healthCheck() {
    return this.mlService.healthCheck();
  }

  @Post('predict')
  @ApiOperation({ summary: 'Prédiction du score de crédit' })
  @ApiResponse({ status: 200, description: 'Prédiction réussie' })
  @ApiResponse({ status: 400, description: 'Données invalides' })
  async predict(@Body() data: any) {
    try {
      if (!data) {
        throw new HttpException('Données manquantes', HttpStatus.BAD_REQUEST);
      }
      return await this.mlService.predict(data);
    } catch (error) {
      throw new HttpException(
        'Erreur lors de la prédiction',
        HttpStatus.INTERNAL_SERVER_ERROR
      );
    }
  }

  @Post('retrain')
  @ApiOperation({ summary: 'Réentraînement du modèle' })
  @ApiResponse({ status: 200, description: 'Réentraînement réussi' })
  async retrain(@Body() trainingData: any) {
    try {
      return await this.mlService.retrain(trainingData);
    } catch (error) {
      throw new HttpException(
        'Erreur lors du réentraînement',
        HttpStatus.INTERNAL_SERVER_ERROR
      );
    }
  }

  @Get('model/info')
  @ApiOperation({ summary: 'Informations sur le modèle' })
  @ApiResponse({ status: 200, description: 'Informations récupérées' })
  modelInfo() {
    return this.mlService.getModelInfo();
  }
}