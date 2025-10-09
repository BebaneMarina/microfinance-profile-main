// src/credit/credit.service.ts
import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { CreditRequest, RequestStatus, CreditType, RiskLevel } from './entities/credit-request.entity';
import { CreateCreditRequestDto } from './dto/create-credit-request.dto';
import { UpdateCreditRequestDto } from './dto/update-credit-request.dto';
import { ScoringService } from '../scoring/scoring.service';
import { Utilisateur } from '../app/auth/entities/user.entity';
import { CreditsEnregistres } from './entities/credit-enregistres.entity';
import { RestrictionCredit } from './entities/restriction-credit.entity';
import { HistoriquePaiements } from './entities/historique-paiement.entity';
import { HttpService } from '@nestjs/axios';
import { firstValueFrom } from 'rxjs';

@Injectable()
export class CreditService {
  private readonly flaskUrl = 'http://localhost:5000';
  logger: any;

  constructor(
    @InjectRepository(CreditRequest)
    private creditRequestRepository: Repository<CreditRequest>,
    
    @InjectRepository(Utilisateur)
    private utilisateurRepository: Repository<Utilisateur>,
    
    @InjectRepository(CreditsEnregistres)
    private creditsEnregistresRepository: Repository<CreditsEnregistres>,
    
    @InjectRepository(RestrictionCredit)
    private restrictionCreditRepository: Repository<RestrictionCredit>,
    
    @InjectRepository(HistoriquePaiements)
    private historiquePaiementsRepository: Repository<HistoriquePaiements>,
    
    private scoringService: ScoringService,
    private httpService: HttpService,
  ) {}

  // ==========================================
  // MÉTHODES EXISTANTES (conservées)
  // ==========================================

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
      credit_score: createDto.creditScore,
      risk_level: createDto.riskLevel as RiskLevel,
      probability: createDto.probability,
      decision: createDto.decision,
    });

    return await this.creditRequestRepository.save(creditRequest);
  }

  async calculateScore(data: any): Promise<any> {
    return this.scoringService.calculateScore({
      ...data,
      username: 'theobawana',
      current_date: new Date().toISOString(),
      user_id: data.userId || 1
    });
  }

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

  private calculateMaxAmount(score: number, monthlyIncome: number): number {
    let maxAmount = monthlyIncome || 0;
    
    if (score >= 800) {
      maxAmount = monthlyIncome * 0.3333;
    } else if (score >= 700) {
      maxAmount = monthlyIncome * 0.3333;
    } else if (score >= 600) {
      maxAmount = monthlyIncome * 0.3333;
    } else if (score >= 500) {
      maxAmount = monthlyIncome * 0.3333;
    } else {
      maxAmount = monthlyIncome * 0.3333;
    }
    
    return Math.min(maxAmount, 2000000);
  }

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

  // ==========================================
  // NOUVELLES MÉTHODES POSTGRESQL
  // ==========================================

  /**
   * Trouve un utilisateur par username
   */
  async findUserByUsername(username: string): Promise<Utilisateur | null> {
    return await this.utilisateurRepository.findOne({
      where: { email: username } // ou un champ username si vous en avez un
    });
  }

  /**
   * Enregistre un nouveau crédit dans PostgreSQL
   */
  async registerCredit(creditData: any): Promise<CreditsEnregistres> {
    const credit = this.creditsEnregistresRepository.create({
      utilisateur_id: creditData.utilisateur_id,
      type_credit: creditData.type_credit,
      montant_principal: creditData.montant_principal,
      montant_total: creditData.montant_total,
      montant_restant: creditData.montant_restant,
      taux_interet: creditData.taux_interet,
      duree_mois: creditData.duree_mois,
      statut: creditData.statut,
      date_approbation: creditData.date_approbation,
      date_echeance: creditData.date_echeance,
      date_prochain_paiement: creditData.date_prochain_paiement,
      montant_prochain_paiement: creditData.montant_prochain_paiement,
    });

    const savedCredit = await this.creditsEnregistresRepository.save(credit);

    // Mettre à jour les dettes de l'utilisateur
    await this.updateUserDebts(creditData.utilisateur_id);

    return savedCredit;
  }
// Remplacer getUserCompleteStats dans credit.service.ts

async getUserCompleteStats(userId: number): Promise<any> {
  try {
    this.logger.log(`Recuperation stats completes pour user: ${userId}`);
    
    // Recuperer l'utilisateur
    const user = await this.utilisateurRepository.findOne({
      where: { id: userId }
    });
    
    if (!user) {
      this.logger.error(`Utilisateur ${userId} non trouve`);
      return this.getDefaultStats();
    }
    
    // Recuperer les credits actifs avec paiements
    const activeCreditsWithPayments = await this.getUserCreditsWithPaymentStatus(userId);
    
    // Calculer les montants depuis les credits enregistres
    const totalBorrowed = activeCreditsWithPayments
      .reduce((sum, c) => sum + Number(c.amount), 0);
    
    const totalReimbursed = activeCreditsWithPayments
      .reduce((sum, c) => sum + Number(c.totalPaid || 0), 0);
    
    const activeCredits = activeCreditsWithPayments.filter(c => c.status === 'actif').length;
    
    // Determiner si tous les credits sont payes
    const allCreditsPaid = activeCreditsWithPayments.length > 0 && 
                           activeCreditsWithPayments.every(c => c.isPaid);
    const hasCredits = activeCreditsWithPayments.length > 0;
    
    const stats = {
      totalBorrowed,
      totalReimbursed,
      activeCredits,
      creditScore: Number(user.score_credit) || 0,
      eligibleAmount: Number(user.montant_eligible) || 0,
      totalApplications: activeCreditsWithPayments.length,
      approvedApplications: activeCreditsWithPayments.length,
      riskLevel: user.niveau_risque || 'medium',
      allCreditsPaid,
      hasCredits,
      paymentStatus: {
        totalPaid: totalReimbursed,
        totalRemaining: activeCreditsWithPayments.reduce((sum, c) => sum + Number(c.remainingAmount), 0),
        averagePaymentPercentage: activeCreditsWithPayments.length > 0 
          ? activeCreditsWithPayments.reduce((sum, c) => sum + (c.percentagePaid || 0), 0) / activeCreditsWithPayments.length
          : 0
      },
      recentRequests: []
    };
    
    this.logger.log(`Stats calculees avec succes`);
    
    return stats;
    
  } catch (error) {
    this.logger.error(`Erreur getUserCompleteStats: ${error.message}`);
    return this.getDefaultStats();
  }
}

private getDefaultStats() {
  return {
    totalBorrowed: 0,
    totalReimbursed: 0,
    activeCredits: 0,
    creditScore: 0,
    eligibleAmount: 0,
    totalApplications: 0,
    approvedApplications: 0,
    riskLevel: 'medium',
    allCreditsPaid: false,
    hasCredits: false,
    paymentStatus: {
      totalPaid: 0,
      totalRemaining: 0,
      averagePaymentPercentage: 0
    },
    recentRequests: []
  };
}


private isRequestFullyPaid(requestId: number, credits: any[]): boolean {
  const matchingCredit = credits.find(c => c.requestId === requestId);
  return matchingCredit ? matchingCredit.isPaid : false;
}


/**
 * ✅ Récupère les crédits avec statut de paiement détaillé
 */
async getUserCreditsWithPaymentStatus(userId: number): Promise<any[]> {
  console.log('📊 Chargement crédits avec paiements pour user:', userId);
  
  const credits = await this.creditsEnregistresRepository
    .createQueryBuilder('c')
    .leftJoinAndSelect('c.paiements', 'p')
    .where('c.utilisateur_id = :userId', { userId })
    .orderBy('c.date_approbation', 'DESC')
    .getMany();
  
  console.log('✅ Crédits récupérés:', credits.length);
  
  return credits.map(credit => {
    // Calculer les paiements effectués
    const paiements = credit.paiements || [];
    const totalPaid = paiements.reduce((sum, p) => sum + Number(p.montant), 0);
    const paymentsCount = paiements.length;
    const percentagePaid = credit.montant_total > 0 
      ? (totalPaid / Number(credit.montant_total)) * 100 
      : 0;
    
    // Déterminer si le crédit est payé
    const isPaid = Number(credit.montant_restant) <= 0 || percentagePaid >= 100;
    
    // Récupérer le dernier paiement
    const lastPayment = paiements.length > 0
      ? paiements.sort((a, b) => 
          new Date(b.date_paiement).getTime() - new Date(a.date_paiement).getTime()
        )[0]
      : null;
    
    console.log(`💰 Crédit ${credit.id}: ${paymentsCount} paiements, ${totalPaid} payé sur ${credit.montant_total}, ${percentagePaid.toFixed(1)}%`);
    
    return {
      id: credit.id.toString(),
      type: credit.type_credit,
      amount: Number(credit.montant_principal),
      totalAmount: Number(credit.montant_total),
      remainingAmount: Number(credit.montant_restant),
      interestRate: Number(credit.taux_interet),
      status: isPaid ? 'paid' : credit.statut,
      approvedDate: credit.date_approbation.toISOString(),
      dueDate: credit.date_echeance.toISOString(),
      nextPaymentDate: credit.date_prochain_paiement?.toISOString(),
      nextPaymentAmount: credit.montant_prochain_paiement ? Number(credit.montant_prochain_paiement) : 0,
      
      // ✅ Informations de paiement
      isPaid,
      totalPaid,
      percentagePaid: Math.round(percentagePaid * 10) / 10,
      paymentsCount,
      lastPaymentDate: lastPayment?.date_paiement.toISOString() || null,
      lastPaymentAmount: lastPayment ? Number(lastPayment.montant) : 0,
      
      paymentsHistory: paiements.map(p => ({
        id: p.id.toString(),
        amount: Number(p.montant),
        date: p.date_paiement.toISOString(),
        type: p.type_paiement === 'a_temps' ? 'partial' : 'late',
        late: p.type_paiement === 'en_retard',
        daysLate: p.jours_retard || 0
      }))
    };
  });
}


  /**
   * Récupère les crédits actifs d'un utilisateur
   */
  async getUserActiveCredits(userId: number): Promise<any[]> {
    const credits = await this.creditsEnregistresRepository
      .createQueryBuilder('c')
      .where('c.utilisateur_id = :userId', { userId })
      .orderBy('c.date_approbation', 'DESC')
      .getMany();

    return credits.map(credit => ({
      id: credit.id.toString(),
      type: credit.type_credit,
      amount: Number(credit.montant_principal),
      totalAmount: Number(credit.montant_total),
      remainingAmount: Number(credit.montant_restant),
      interestRate: Number(credit.taux_interet),
      status: credit.statut,
      approvedDate: credit.date_approbation.toISOString(),
      dueDate: credit.date_echeance.toISOString(),
      nextPaymentDate: credit.date_prochain_paiement?.toISOString(),
      nextPaymentAmount: credit.montant_prochain_paiement ? Number(credit.montant_prochain_paiement) : 0,
      paymentsHistory: [] // À récupérer depuis historique_paiements si besoin
    }));
  }

  /**
   * Récupère les restrictions d'un utilisateur
   */
  async getUserRestrictions(userId: number): Promise<any> {
    let restriction = await this.restrictionCreditRepository.findOne({
      where: { utilisateur_id: userId }
    });

    if (!restriction) {
      // Créer les restrictions par défaut
      restriction = await this.createDefaultRestrictions(userId);
    }

    return {
      canApplyForCredit: restriction.peut_emprunter,
      maxCreditsAllowed: restriction.credits_max_autorises,
      activeCreditCount: restriction.credits_actifs_count,
      totalActiveDebt: Number(restriction.dette_totale_active),
      debtRatio: Number(restriction.ratio_endettement),
      nextEligibleDate: restriction.date_prochaine_eligibilite?.toISOString(),
      lastApplicationDate: restriction.date_derniere_demande?.toISOString(),
      blockingReason: restriction.raison_blocage,
      daysUntilNextApplication: restriction.jours_avant_prochaine_demande
    };
  }

/**
 * Met à jour les restrictions après un nouveau crédit
 */
async updateUserRestrictions(userId: number): Promise<void> {
  // Compter les crédits actifs
  const activeCreditsCount = await this.creditsEnregistresRepository
    .createQueryBuilder('c')
    .where('c.utilisateur_id = :userId', { userId })
    .andWhere('c.statut = :statut', { statut: 'actif' })
    .getCount();

  // Calculer la dette totale
  const result = await this.creditsEnregistresRepository
    .createQueryBuilder('c')
    .select('SUM(c.montant_restant)', 'total')
    .where('c.utilisateur_id = :userId', { userId })
    .andWhere('c.statut = :statut', { statut: 'actif' })
    .getRawOne();

  const totalDebt = Number(result?.total || 0);

  // Récupérer le revenu de l'utilisateur
  const user = await this.utilisateurRepository.findOne({
    where: { id: userId }
  });

  const monthlyIncome = user ? Number(user.revenu_mensuel) : 1;
  const debtRatio = (totalDebt / monthlyIncome) * 100;

  // Déterminer si l'utilisateur peut emprunter
  const canBorrow = activeCreditsCount < 2 && debtRatio <= 70;
  let blockingReason: string | undefined; // ✅ Pas de valeur par défaut

  if (activeCreditsCount >= 2) {
    blockingReason = 'Maximum de 2 crédits actifs atteint';
  } else if (debtRatio > 70) {
    blockingReason = `Ratio d'endettement trop élevé (${debtRatio.toFixed(1)}%)`;
  }

  // Préparer les valeurs à insérer
  const restrictionValues: any = {
    utilisateur_id: userId,
    peut_emprunter: canBorrow,
    credits_actifs_count: activeCreditsCount,
    credits_max_autorises: 2,
    dette_totale_active: totalDebt,
    ratio_endettement: debtRatio,
    date_derniere_demande: new Date(),
    date_modification: new Date()
  };

  // ✅ N'ajouter raison_blocage que si elle existe
  if (blockingReason !== undefined) {
    restrictionValues.raison_blocage = blockingReason;
  }

  // Mettre à jour ou créer les restrictions
  await this.restrictionCreditRepository
    .createQueryBuilder()
    .insert()
    .into(RestrictionCredit)
    .values(restrictionValues)
    .orUpdate(
      [
        'peut_emprunter', 
        'credits_actifs_count', 
        'dette_totale_active', 
        'ratio_endettement', 
        'date_derniere_demande', 
        'raison_blocage', 
        'date_modification'
      ], 
      ['utilisateur_id']
    )
    .execute();
}

  /**
   * Traite un paiement
   */
  async processPayment(paymentData: any): Promise<any> {
    const credit = await this.creditsEnregistresRepository.findOne({
      where: { id: paymentData.credit_id }
    });

    if (!credit) {
      throw new NotFoundException('Crédit non trouvé');
    }

    // Enregistrer le paiement
    const payment = this.historiquePaiementsRepository.create({
      credit_id: credit.id,
      utilisateur_id: credit.utilisateur_id,
      montant: paymentData.payment.amount,
      date_paiement: new Date(),
      date_prevue: new Date(), // À ajuster selon votre logique
      jours_retard: 0,
      type_paiement: paymentData.payment.late ? 'en_retard' : 'a_temps',
      frais_retard: 0,
    });

    await this.historiquePaiementsRepository.save(payment);

    // Mettre à jour le crédit
    credit.montant_restant = paymentData.remaining_amount;
    credit.statut = paymentData.credit_status;
    await this.creditsEnregistresRepository.save(credit);

    // Mettre à jour les restrictions
    await this.updateUserRestrictions(credit.utilisateur_id);

    return {
      success: true,
      score_impact: null // À calculer si nécessaire
    };
  }

  /**
   * Met à jour les dettes de l'utilisateur
   */
  private async updateUserDebts(userId: number): Promise<void> {
    const result = await this.creditsEnregistresRepository
      .createQueryBuilder('c')
      .select('SUM(c.montant_restant)', 'total')
      .where('c.utilisateur_id = :userId', { userId })
      .andWhere('c.statut = :statut', { statut: 'actif' })
      .getRawOne();

    const totalDebt = Number(result?.total || 0);

    await this.utilisateurRepository.update(userId, {
      dettes_existantes: totalDebt
    });
  }

  /**
   * Crée les restrictions par défaut
   */
  private async createDefaultRestrictions(userId: number): Promise<RestrictionCredit> {
    const restriction = this.restrictionCreditRepository.create({
      utilisateur_id: userId,
      peut_emprunter: true,
      credits_actifs_count: 0,
      credits_max_autorises: 2,
      dette_totale_active: 0,
      ratio_endettement: 0,
    });

    return await this.restrictionCreditRepository.save(restriction);
  }

  /**
   * Déclenche un recalcul du score via Flask
   */
  async triggerScoreRecalculation(userId: number): Promise<void> {
    try {
      await firstValueFrom(
        this.httpService.post(`${this.flaskUrl}/recalculate-score/${userId}`, {})
      );
    } catch (error) {
      console.error('Erreur recalcul score:', error.message);
    }
  }
}