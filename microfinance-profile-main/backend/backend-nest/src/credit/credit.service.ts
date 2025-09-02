import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { CreditRequest, RequestStatus, CreditType, RiskLevel } from './entities/credit-request.entity';
import { CreateCreditRequestDto } from './dto/create-credit-request.dto';
import { UpdateCreditRequestDto } from './dto/update-credit-request.dto';
import { ScoringService } from '../scoring/scoring.service';

@Injectable()
export class CreditService {
  constructor(
    @InjectRepository(CreditRequest)
    private creditRequestRepository: Repository<CreditRequest>,
    private scoringService: ScoringService,
  ) {}

  // Créer une nouvelle demande de crédit
  async create(createDto: CreateCreditRequestDto, userId: number): Promise<CreditRequest> {
    const requestNumber = await this.generateRequestNumber();
    
    const creditRequest = this.creditRequestRepository.create({
      request_number: requestNumber,
      user_id: userId,
      credit_type: createDto.creditType as CreditType,
      requested_amount: Number(createDto.creditDetails.requestedAmount),
      duration_months: Number(createDto.creditDetails.duration),
      purpose: createDto.creditDetails.creditPurpose,
      repayment_mode: createDto.creditDetails.repaymentMode,
      repayment_frequency: createDto.creditDetails.repaymentFrequency,
      submission_date: new Date(),
      status: RequestStatus.SUBMITTED,
      // Ajouter les scores si disponibles
      credit_score: createDto.creditScore,
      risk_level: createDto.riskLevel as RiskLevel,
      probability: createDto.probability,
      decision: createDto.decision,
    });

    return await this.creditRequestRepository.save(creditRequest);
  }

  // Calculer le score de crédit
  async calculateScore(data: any): Promise<any> {
    return this.scoringService.calculateScore({
      ...data,
      username: 'theobawana',
      current_date: '2025-07-26 10:54:55',
      user_id: data.userId || 1
    });
  }

  // Valider l'éligibilité
  async validateEligibility(data: any): Promise<any> {
    const score = await this.calculateScore(data);
    
    return {
      isEligible: score.score >= 500,
      score: score.score,
      riskLevel: score.risk_level,
      maxAmount: this.calculateMaxAmount(score.score, data.monthly_income),
      recommendations: score.recommendations || []
    };
  }

  // Calculer le montant maximum
  private calculateMaxAmount(score: number, monthlyIncome: number): number {
    let maxAmount = monthlyIncome || 0;
    
    if (score >= 800) {
      maxAmount = monthlyIncome * 0.3333; // 33.33% du revenu mensuel
    } else if (score >= 700) {
      maxAmount = monthlyIncome * 0.3333;
    } else if (score >= 600) {
      maxAmount = monthlyIncome * 0.3333;
    } else if (score >= 500) {
      maxAmount = monthlyIncome * 0.3333;
    } else {
      maxAmount = monthlyIncome * 0.3333;
    }
    
    return Math.min(maxAmount, 2000000); // Plafond à 2M
  }

  // Trouver toutes les demandes
  async findAll(userId?: number, filters?: any): Promise<CreditRequest[]> {
    const query = this.creditRequestRepository.createQueryBuilder('cr');
    
    if (userId) {
      query.where('cr.user_id = :userId', { userId });
    }
    
    if (filters?.status) {
      query.andWhere('cr.status = :status', { status: filters.status });
    }
    
    if (filters?.creditType) {
      query.andWhere('cr.credit_type = :creditType', { creditType: filters.creditType });
    }
    
    return query
      .orderBy('cr.created_at', 'DESC')
      .getMany();
  }

  // Trouver une demande spécifique
  async findOne(id: number, userId?: number): Promise<CreditRequest> {
    const query = this.creditRequestRepository.createQueryBuilder('cr')
      .where('cr.id = :id', { id });
    
    if (userId) {
      query.andWhere('cr.user_id = :userId', { userId });
    }
    
    const creditRequest = await query.getOne();
    
    if (!creditRequest) {
      throw new NotFoundException(`Demande de crédit #${id} non trouvée`);
    }
    
    return creditRequest;
  }

  // Obtenir les types de crédit disponibles
  async getCreditTypes(): Promise<any[]> {
    return [
      {
        id: 'consommation_generale',
        name: 'Crédit Consommation',
        description: 'Pour vos besoins personnels',
        maxAmount: 2000000,
        duration: '1 mois',
        rate: '5%'
      },
      {
        id: 'avance_salaire',
        name: 'Avance sur Salaire',
        description: 'Jusqu\'à 70% de votre salaire',
        maxAmount: 2000000,
        duration: '1 mois',
        rate: '3%'
      },
      {
        id: 'depannage',
        name: 'Crédit Dépannage',
        description: 'Solution urgente',
        maxAmount: 2000000,
        duration: '1 mois',
        rate: '4%'
      }
    ];
  }

  // Obtenir les statistiques
  async getStatistics(userId: number, period?: string): Promise<any> {
    const requests = await this.findAll(userId);
    
    const stats = {
      total: requests.length,
      approved: requests.filter(r => r.status === RequestStatus.APPROVED).length,
      rejected: requests.filter(r => r.status === RequestStatus.REJECTED).length,
      pending: requests.filter(r => r.status === RequestStatus.IN_REVIEW).length,
      totalAmount: requests.reduce((sum, r) => sum + Number(r.requested_amount), 0),
      averageScore: requests.reduce((sum, r) => sum + (r.credit_score || 0), 0) / (requests.length || 1)
    };
    
    return stats;
  }

  // Obtenir les informations du modèle
  getModelInfo(): any {
    return {
      version: 'v1.0',
      lastUpdate: '2025-07-26',
      algorithm: 'Random Forest',
      features: [
        'monthly_income',
        'employment_status',
        'job_seniority',
        'existing_debts',
        'age'
      ],
      performance: {
        accuracy: 0.85,
        precision: 0.82,
        recall: 0.88
      }
    };
  }

  // Générer un numéro de demande unique
  async generateRequestNumber(): Promise<string> {
    const date = new Date();
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    
    const lastRequest = await this.creditRequestRepository
      .createQueryBuilder('cr')
      .select('cr.request_number')
      .where('cr.request_number LIKE :pattern', { pattern: `REQ-${year}${month}${day}-%` })
      .orderBy('cr.request_number', 'DESC')
      .limit(1)
      .getOne();

    let sequence = 1;
    if (lastRequest) {
      const match = lastRequest.request_number.match(/REQ-\d{8}-(\d+)/);
      if (match) {
        sequence = parseInt(match[1]) + 1;
      }
    }

    return `REQ-${year}${month}${day}-${String(sequence).padStart(6, '0')}`;
  }

  // Méthodes existantes
  async findByRequestNumber(requestNumber: string): Promise<CreditRequest> {
    const creditRequest = await this.creditRequestRepository.findOne({
      where: { request_number: requestNumber },
      relations: ['user']
    });

    if (!creditRequest) {
      throw new NotFoundException(`Demande #${requestNumber} non trouvée`);
    }

    return creditRequest;
  }

  async updateStatus(
    creditRequestId: number, 
    status: RequestStatus, 
    userId: number, 
    notes?: string
  ): Promise<CreditRequest> {
    const creditRequest = await this.findOne(creditRequestId);

    creditRequest.status = status;
    creditRequest.decision = status;
    creditRequest.decision_notes = notes;
    creditRequest.decision_date = new Date();
    creditRequest.decision_by = userId;

    if (status === RequestStatus.APPROVED && !creditRequest.approved_amount) {
      creditRequest.approved_amount = creditRequest.requested_amount;
    }

    return this.creditRequestRepository.save(creditRequest);
  }
}