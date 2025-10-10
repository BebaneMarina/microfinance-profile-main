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
  // RECUPERATION STATS COMPLETES
  // ==========================================

  async getUserCompleteStats(userId: number): Promise<any> {
    try {
      this.logger?.log(`Recuperation stats completes pour user: ${userId}`);
      
      const user = await this.utilisateurRepository.findOne({
        where: { id: userId }
      });
      
      if (!user) {
        return this.getDefaultStats();
      }
      
      // Recuperer credits avec paiements
      const creditsWithPayments = await this.getUserCreditsWithPaymentStatus(userId);
      
      // Calculer totaux
      const totalBorrowed = creditsWithPayments.reduce((sum, c) => sum + Number(c.amount), 0);
      const totalReimbursed = creditsWithPayments.reduce((sum, c) => sum + Number(c.totalPaid || 0), 0);
      const activeCredits = creditsWithPayments.filter(c => c.status === 'actif').length;
      
      // Verifier si tous payes
      const allCreditsPaid = creditsWithPayments.length > 0 && 
                             creditsWithPayments.every(c => c.isPaid);
      const hasCredits = creditsWithPayments.length > 0;
      
      // Recuperer demandes recentes
      const recentRequests = await this.creditRequestRepository
        .createQueryBuilder('dcl')
        .where('dcl.utilisateur_id = :userId', { userId })
        .orderBy('dcl.date_soumission', 'DESC')
        .limit(10)
        .getMany();
      
      const stats = {
        totalBorrowed,
        totalReimbursed,
        activeCredits,
        creditScore: Number(user.score_credit) || 0,
        eligibleAmount: Number(user.montant_eligible) || 0,
        totalApplications: recentRequests.length,
        approvedApplications: recentRequests.filter(r => r.statut === 'approuvee').length,
        riskLevel: user.niveau_risque || 'medium',
        allCreditsPaid,
        hasCredits,
        paymentStatus: {
          totalPaid: totalReimbursed,
          totalRemaining: creditsWithPayments.reduce((sum, c) => sum + Number(c.remainingAmount), 0),
          averagePaymentPercentage: creditsWithPayments.length > 0 
            ? creditsWithPayments.reduce((sum, c) => sum + (c.percentagePaid || 0), 0) / creditsWithPayments.length
            : 0
        },
        recentRequests: recentRequests.map(req => ({
          id: req.id,
          requestNumber: req.numero_demande,
          type: req.credit_type,
          amount: Number(req.montant_demande),
          status: req.statut,
          submissionDate: req.date_soumission?.toISOString() ?? null,
          approvedAmount: req.montant_approuve ? Number(req.montant_approuve) : null,
          isPaid: this.isRequestFullyPaid(req.id, creditsWithPayments)
        }))
      };
      
      return stats;
      
    } catch (error) {
      this.logger?.error(`Erreur getUserCompleteStats: ${error.message}`);
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

  // ==========================================
  // CREDITS AVEC STATUT PAIEMENT
  // ==========================================

  async getUserCreditsWithPaymentStatus(userId: number): Promise<any[]> {
    const credits = await this.creditsEnregistresRepository
      .createQueryBuilder('c')
      .leftJoinAndSelect('c.paiements', 'p')
      .where('c.utilisateur_id = :userId', { userId })
      .orderBy('c.date_approbation', 'DESC')
      .getMany();
    
    return credits.map(credit => {
      const paiements = credit.paiements || [];
      const totalPaid = paiements.reduce((sum, p) => sum + Number(p.montant), 0);
      const paymentsCount = paiements.length;
      const percentagePaid = credit.montant_total > 0 
        ? (totalPaid / Number(credit.montant_total)) * 100 
        : 0;
      
      const isPaid = Number(credit.montant_restant) <= 0 || percentagePaid >= 100;
      
      const lastPayment = paiements.length > 0
        ? paiements.sort((a, b) => 
            new Date(b.date_paiement).getTime() - new Date(a.date_paiement).getTime()
          )[0]
        : null;
      
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

  // ==========================================
  // CREATION DEMANDE CREDIT
  // ==========================================

  async create(createDto: CreateCreditRequestDto, userId: number): Promise<CreditRequest> {
    const requestNumber = await this.generateRequestNumber();
    
    const creditRequest = this.creditRequestRepository.create({
      numero_demande: requestNumber,
      user_id: userId,
      credit_type: createDto.creditType as CreditType,
      montant_demande: Number(createDto.creditDetails.requestedAmount),
      duree_mois: Number(createDto.creditDetails.duration),
      objectif: createDto.creditDetails.creditPurpose,
      statut: 'soumise',
      date_soumission: new Date(),
      score_au_moment_demande: createDto.creditScore,
      niveau_risque_evaluation: createDto.riskLevel as RiskLevel,
      probability: createDto.probability,
      decision: createDto.decision,
    });

    const saved = await this.creditRequestRepository.save(creditRequest);
    
    // Declencher recalcul score apres nouvelle demande
    await this.triggerScoreRecalculation(userId);
    
    return saved;
  }

  async calculateScore(data: any): Promise<any> {
    return this.scoringService.calculateScore({
      ...data,
      username: 'theobawana',
      current_date: new Date().toISOString(),
      user_id: data.userId || 1
    });
  }

  // ==========================================
  // ENREGISTREMENT CREDIT
  // ==========================================

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

    // Mettre a jour dettes
    await this.updateUserDebts(creditData.utilisateur_id);
    
    // Mettre a jour restrictions
    await this.updateUserRestrictions(creditData.utilisateur_id);
    
    // Declencher recalcul score
    await this.triggerScoreRecalculation(creditData.utilisateur_id);

    return savedCredit;
  }

  // ==========================================
  // RESTRICTIONS
  // ==========================================

  async getUserRestrictions(userId: number): Promise<any> {
    let restriction = await this.restrictionCreditRepository.findOne({
      where: { utilisateur_id: userId }
    });

    if (!restriction) {
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

  async updateUserRestrictions(userId: number): Promise<void> {
    const activeCreditsCount = await this.creditsEnregistresRepository
      .createQueryBuilder('c')
      .where('c.utilisateur_id = :userId', { userId })
      .andWhere('c.statut = :statut', { statut: 'actif' })
      .getCount();

    const result = await this.creditsEnregistresRepository
      .createQueryBuilder('c')
      .select('SUM(c.montant_restant)', 'total')
      .where('c.utilisateur_id = :userId', { userId })
      .andWhere('c.statut = :statut', { statut: 'actif' })
      .getRawOne();

    const totalDebt = Number(result?.total || 0);

    const user = await this.utilisateurRepository.findOne({
      where: { id: userId }
    });

    const monthlyIncome = user ? Number(user.revenu_mensuel) : 1;
    const debtRatio = (totalDebt / monthlyIncome) * 100;

    const canBorrow = activeCreditsCount < 2 && debtRatio <= 70;
    let blockingReason: string | undefined;

    if (activeCreditsCount >= 2) {
      blockingReason = 'Maximum de 2 credits actifs atteint';
    } else if (debtRatio > 70) {
      blockingReason = `Ratio d'endettement trop eleve (${debtRatio.toFixed(1)}%)`;
    }

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

    if (blockingReason !== undefined) {
      restrictionValues.raison_blocage = blockingReason;
    }

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

  // ==========================================
  // PAIEMENTS
  // ==========================================

  async processPayment(paymentData: any): Promise<any> {
    const credit = await this.creditsEnregistresRepository.findOne({
      where: { id: paymentData.credit_id }
    });

    if (!credit) {
      throw new NotFoundException('Credit non trouve');
    }

    const payment = this.historiquePaiementsRepository.create({
      credit_id: credit.id,
      utilisateur_id: credit.utilisateur_id,
      montant: paymentData.payment.amount,
      date_paiement: new Date(),
      date_prevue: new Date(),
      jours_retard: 0,
      type_paiement: paymentData.payment.late ? 'en_retard' : 'a_temps',
      frais_retard: 0,
    });

    await this.historiquePaiementsRepository.save(payment);

    credit.montant_restant = paymentData.remaining_amount;
    credit.statut = paymentData.credit_status;
    await this.creditsEnregistresRepository.save(credit);

    await this.updateUserRestrictions(credit.utilisateur_id);
    
    // Declencher recalcul score apres paiement
    await this.triggerScoreRecalculation(credit.utilisateur_id);

    return {
      success: true,
      score_impact: null
    };
  }

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

  // ==========================================
  // UTILITAIRES
  // ==========================================

  async findUserByUsername(username: string): Promise<Utilisateur | null> {
    return await this.utilisateurRepository.findOne({
      where: { email: username }
    });
  }

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
      paymentsHistory: []
    }));
  }

  async triggerScoreRecalculation(userId: number): Promise<void> {
    try {
      await firstValueFrom(
        this.httpService.post(`${this.flaskUrl}/recalculate-score/${userId}`, {})
      );
    } catch (error) {
      console.error('Erreur recalcul score:', error.message);
    }
  }

  async findAll(userId?: number, filters?: any): Promise<CreditRequest[]> {
    const query = this.creditRequestRepository.createQueryBuilder('dcl');
    
    if (userId) {
      query.where('dcl.utilisateur_id = :userId', { userId });
    }
    
    if (filters?.status) {
      query.andWhere('dcl.statut = :status', { status: filters.status });
    }
    
    return query.orderBy('dcl.date_creation', 'DESC').getMany();
  }

  async findOne(id: number, userId?: number): Promise<CreditRequest> {
    const query = this.creditRequestRepository.createQueryBuilder('dcl')
      .where('dcl.id = :id', { id });
    
    if (userId) {
      query.andWhere('dcl.utilisateur_id = :userId', { userId });
    }
    
    const creditRequest = await query.getOne();
    
    if (!creditRequest) {
      throw new NotFoundException(`Demande de credit #${id} non trouvee`);
    }
    
    return creditRequest;
  }

  async generateRequestNumber(): Promise<string> {
    const date = new Date();
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    
    const lastRequest = await this.creditRequestRepository
      .createQueryBuilder('dcl')
      .select('dcl.numero_demande')
      .where('dcl.numero_demande LIKE :pattern', { pattern: `LCR-${year}${month}${day}-%` })
      .orderBy('dcl.numero_demande', 'DESC')
      .limit(1)
      .getOne();

    let sequence = 1;
    if (lastRequest && lastRequest.numero_demande) {
      const match = lastRequest.numero_demande.match(/LCR-\d{8}-(\d+)/);
      if (match) {
        sequence = parseInt(match[1]) + 1;
      }
    }

    return `LCR-${year}${month}${day}-${String(sequence).padStart(4, '0')}`;
  }

  async getCreditTypes(): Promise<any[]> {
    return [
      {
        id: 'consommation_generale',
        name: 'Credit Consommation',
        description: 'Pour vos besoins personnels',
        maxAmount: 2000000,
        duration: '1 mois',
        rate: '18%'
      },
      {
        id: 'avance_salaire',
        name: 'Avance sur Salaire',
        description: 'Jusqu\'a 70% de votre salaire',
        maxAmount: 2000000,
        duration: '1 mois',
        rate: '18%'
      },
      {
        id: 'depannage',
        name: 'Credit Depannage',
        description: 'Solution urgente',
        maxAmount: 2000000,
        duration: '1 mois',
        rate: '18%'
      }
    ];
  }

  async getStatistics(userId: number, period?: string): Promise<any> {
    const requests = await this.findAll(userId);
    
    return {
      total: requests.length,
      approved: requests.filter(r => r.statut === 'approuvee').length,
      rejected: requests.filter(r => r.statut === 'rejetee').length,
      pending: requests.filter(r => r.statut === 'en_examen').length,
      totalAmount: requests.reduce((sum, r) => sum + Number(r.montant_demande), 0),
      averageScore: requests.reduce((sum, r) => sum + (r.score_au_moment_demande || 0), 0) / (requests.length || 1)
    };
  }

  getModelInfo(): any {
    return {
      version: 'v8.0',
      lastUpdate: '2025-10-10',
      algorithm: 'Random Forest',
      features: [
        'auto_recalculation',
        'notifications',
        'payment_tracking'
      ]
    };
  }
}