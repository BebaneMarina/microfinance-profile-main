import { Injectable, HttpException, HttpStatus } from '@nestjs/common';
import axios from 'axios';

@Injectable()
export class MlService {
  private readonly flaskUrl = 'http://localhost:5000'; // adapte si ton Flask est ailleurs
  predictScore: any;

  async healthCheck(): Promise<any> {
    try {
      const response = await axios.get(`${this.flaskUrl}/health`);
      return response.data;
    } catch (error) {
      throw new HttpException(
        'Erreur lors de la vérification de l\'état du modèle',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  async predict(data: any): Promise<any> {
    try {
      const response = await axios.post(`${this.flaskUrl}/predict`, data);
      return response.data;
    } catch (error) {
      throw new HttpException(
        'Erreur lors de la prédiction',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  async retrain(trainingData: any = {}): Promise<any> {
    try {
      const response = await axios.post(`${this.flaskUrl}/retrain`, trainingData);
      return response.data;
    } catch (error) {
      throw new HttpException(
        'Erreur lors du réentraînement du modèle',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  async getModelInfo(): Promise<any> {
    try {
      const response = await axios.get(`${this.flaskUrl}/model/info`);
      return response.data;
    } catch (error) {
      throw new HttpException(
        'Erreur lors de la récupération des informations du modèle',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }
}
