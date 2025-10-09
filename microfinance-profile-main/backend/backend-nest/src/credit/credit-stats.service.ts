// src/credit/credit-stats.service.ts
import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { CreditsEnregistres } from './entities/credit-enregistres.entity';
import { Utilisateur } from '../app/auth/entities/user.entity';
import { HistoriquePaiements } from './entities/historique-paiement.entity';

@Injectable()
export class CreditStatsService {
  constructor(
    @InjectRepository(CreditsEnregistres)
    private creditsRepository: Repository<CreditsEnregistres>,
    
    @InjectRepository(Utilisateur)
    private utilisateurRepository: Repository<Utilisateur>,
    
    @InjectRepository(HistoriquePaiements)
    private paiementsRepository: Repository<HistoriquePaiements>,
  ) {}

  /**
   * Récupère les statistiques complètes d'un utilisateur
   */
  async getUserStats(userId: number): Promise<any> {
    // 1. Récupérer l'utilisateur
    const user = await this.utilisateurRepository.findOne({
      where: { id: userId }
    });

    if (!user) {
      throw new Error('Utilisateur non trouvé');
    }

    // 2. Statistiques des crédits
    const credits = await this.creditsRepository
      .createQueryBuilder('c')
      .where('c.utilisateur_id = :userId', { userId })
      .getMany();

    // 3. Total emprunté (tous les crédits)
    const totalBorrowed = credits.reduce(
      (sum, c) => sum + Number(c.montant_principal), 
      0
    );

    // 4. Total remboursé (crédits soldés)
    const totalReimbursed = credits
      .filter(c => c.statut === 'solde')
      .reduce((sum, c) => sum + Number(c.montant_total), 0);

    // 5. Crédits actifs
    const activeCreditsCount = credits.filter(
      c => c.statut === 'actif'
    ).length;

    // 6. Dette active totale
    const activeDebt = credits
      .filter(c => c.statut === 'actif')
      .reduce((sum, c) => sum + Number(c.montant_restant), 0);

    // 7. Historique des paiements
    const payments = await this.paiementsRepository
      .createQueryBuilder('p')
      .where('p.utilisateur_id = :userId', { userId })
      .getMany();

    // 8. Ratio paiements à temps
    const totalPayments = payments.length;
    const onTimePayments = payments.filter(
      p => p.type_paiement === 'a_temps'
    ).length;
    const onTimeRatio = totalPayments > 0 
      ? (onTimePayments / totalPayments) * 100 
      : 100;

    // 9. Dernière demande
    const lastCredit = await this.creditsRepository
      .createQueryBuilder('c')
      .where('c.utilisateur_id = :userId', { userId })
      .orderBy('c.date_approbation', 'DESC')
      .limit(1)
      .getOne();

    return {
      totalBorrowed,
      totalReimbursed,
      activeCredits: activeCreditsCount,
      activeDebt,
      creditScore: Number(user.score_credit),
      eligibleAmount: Number(user.montant_eligible),
      riskLevel: user.niveau_risque,
      totalApplications: credits.length,
      approvedApplications: credits.length, // Tous les crédits enregistrés sont approuvés
      totalPayments,
      onTimePayments,
      latePayments: totalPayments - onTimePayments,
      onTimePaymentRatio: onTimeRatio,
      lastCreditRequest: lastCredit ? {
        id: lastCredit.id,
        type: lastCredit.type_credit,
        amount: Number(lastCredit.montant_principal),
        status: lastCredit.statut,
        approvedDate: lastCredit.date_approbation,
        remainingAmount: Number(lastCredit.montant_restant)
      } : null
    };
  }

  /**
   * Récupère les crédits avec détails de paiement
   */
  async getUserCreditsWithPaymentStatus(userId: number): Promise<any[]> {
    const credits = await this.creditsRepository
      .createQueryBuilder('c')
      .where('c.utilisateur_id = :userId', { userId })
      .orderBy('c.date_approbation', 'DESC')
      .getMany();

    const creditsWithStatus = await Promise.all(
      credits.map(async (credit) => {
        // Récupérer les paiements pour ce crédit
        const payments = await this.paiementsRepository
          .createQueryBuilder('p')
          .where('p.credit_id = :creditId', { creditId: credit.id })
          .orderBy('p.date_paiement', 'DESC')
          .getMany();

        // Calculer le montant total payé
        const totalPaid = payments.reduce(
          (sum, p) => sum + Number(p.montant), 
          0
        );

        // Déterminer si le crédit est payé
        const isPaid = credit.statut === 'solde' || 
                       credit.montant_restant <= 0 ||
                       totalPaid >= Number(credit.montant_total);

        // Calculer le pourcentage payé
        const percentagePaid = (totalPaid / Number(credit.montant_total)) * 100;

        return {
          id: credit.id,
          type: credit.type_credit,
          amount: Number(credit.montant_principal),
          totalAmount: Number(credit.montant_total),
          remainingAmount: Number(credit.montant_restant),
          totalPaid,
          percentagePaid: Math.min(100, percentagePaid),
          status: credit.statut,
          isPaid,
          isFullyPaid: isPaid,
          approvedDate: credit.date_approbation,
          dueDate: credit.date_echeance,
          paymentsCount: payments.length,
          lastPaymentDate: payments.length > 0 ? payments[0].date_paiement : null,
          paymentsHistory: payments.map(p => ({
            id: p.id,
            amount: Number(p.montant),
            date: p.date_paiement,
            type: p.type_paiement,
            late: p.jours_retard > 0,
            daysLate: p.jours_retard
          }))
        };
      })
    );

    return creditsWithStatus;
  }
}