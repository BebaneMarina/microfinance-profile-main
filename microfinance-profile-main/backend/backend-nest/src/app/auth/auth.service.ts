import { Injectable, UnauthorizedException, Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { UsersService } from '../../users/user.service';
import { ScoringService } from '../../scoring/scoring.service';
import * as bcrypt from 'bcrypt';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);
  private readonly currentDate = new Date().toISOString();
  private readonly currentUser = 'system';

  constructor(
    private usersService: UsersService,
    private jwtService: JwtService,
    private scoringService: ScoringService
  ) {}

  async validateUser(username: string, password: string): Promise<any> {
    try {
      const user = await this.usersService.findByUsername(username);
      
      if (!user) {
        this.logger.warn(`Utilisateur non trouvé: ${username}`);
        return null;
      }

      const isPasswordValid = bcrypt.compare(password, user.passwordHash);
      
      if (!isPasswordValid) {
        this.logger.warn(`Mot de passe invalide pour: ${username}`);
        return null;
      }

      const { password_hash, ...result } = user;
      return result;
    } catch (error) {
      this.logger.error(`Erreur lors de la validation: ${error.message}`);
      return null;
    }
  }

  async login(user: any): Promise<any> {
    try {
      this.logger.log(`=== CONNEXION UTILISATEUR ===`);
      this.logger.log(`Utilisateur: ${user.email || user.username}`);

      // Récupérer les dettes existantes depuis la base de données
      const userDebts = await this.getUserDebts(user.id);
      
      // Calculer le score avant de retourner les données
      const scoringResult = await this.calculateClientScore({
        ...user,
        monthlyIncome: user.monthly_income,
        employmentStatus: user.employment_status,
        jobSeniority: user.work_experience,
        existingDebts: userDebts.totalDebts,
        monthlyCharges: userDebts.monthlyCharges
      });

      const payload = { 
        username: user.email,
        sub: user.id,
        role: user.role,
        currentDate: this.currentDate
      };

      const token = this.jwtService.sign(payload);

      const userData = {
        id: user.id,
        uuid: user.uuid,
        email: user.email,
        name: `${user.first_name} ${user.last_name}`,
        role: user.role,
        clientId: user.uuid,
        token: token,
        profileImage: user.profile_image || '',
        monthlyIncome: user.monthly_income || 0,
        clientType: user.client_type || 'particulier',
        phone: user.phone_number,
        address: user.address,
        profession: user.profession,
        company: user.employer_name,
        birthDate: user.birth_date,
        employmentStatus: user.employment_status,
        jobSeniority: user.work_experience,
        creditScore: scoringResult.score,
        eligibleAmount: scoringResult.eligible_amount,
        riskLevel: scoringResult.risk_level,
        scoreDetails: scoringResult.scoreDetails,
        recommendations: scoringResult.recommendations
      };

      // Sauvegarder le score dans la base de données
      await this.scoringService.saveUserScore(user.id, scoringResult);

      return {
        ...userData,
        currentDate: this.currentDate,
        currentUser: this.currentUser
      };
    } catch (error) {
      this.logger.error(`Erreur lors de la connexion: ${error.message}`);
      throw new UnauthorizedException('Erreur lors de la connexion');
    }
  }

  private async getUserDebts(userId: number): Promise<any> {
    try {
      // Récupérer les crédits actifs et les paiements en retard
      const activeLoans = await this.scoringService.getUserActiveLoans(userId);
      const overduePayments = await this.scoringService.getUserOverduePayments(userId);
      
      let totalDebts = 0;
      let monthlyCharges = 0;

      // Calculer les dettes existantes (capital restant)
      for (const loan of activeLoans) {
        totalDebts += loan.remaining_balance || 0;
        monthlyCharges += loan.monthly_payment || 0;
      }

      // Ajouter les paiements en retard
      for (const payment of overduePayments) {
        totalDebts += payment.total_amount || 0;
      }

      return {
        totalDebts,
        monthlyCharges,
        activeLoansCount: activeLoans.length,
        overduePaymentsCount: overduePayments.length
      };
    } catch (error) {
      this.logger.error(`Erreur récupération dettes: ${error.message}`);
      return {
        totalDebts: 0,
        monthlyCharges: 0,
        activeLoansCount: 0,
        overduePaymentsCount: 0
      };
    }
  }

  private async calculateClientScore(user: any): Promise<any> {
    try {
      // Calculer les charges mensuelles totales
      const monthlyCharges = user.monthlyCharges || (user.monthlyIncome * 0.3);
      
      const scoringData = {
        age: this.calculateAge(user.birthDate),
        monthly_income: user.monthlyIncome || 0,
        other_income: 0,
        monthly_charges: monthlyCharges,
        existing_debts: user.existingDebts || 0,
        job_seniority: user.jobSeniority || 12,
        employment_status: user.employmentStatus || 'cdi',
        loan_amount: 0,
        loan_duration: 1,
        username: user.email,
        current_date: this.currentDate,
        user_id: user.id
      };

      // Calculer le score et le montant éligible
      const scoreResult = await this.scoringService.calculateScore(scoringData);
      const eligibleAmount = await this.scoringService.calculateEligibleAmount(
        user.monthlyIncome, 
        scoreResult.score,
        scoreResult.risk_level
      );

      // Analyser la capacité de remboursement
      const repaymentCapacity = this.calculateRepaymentCapacity(user);

      return {
        score: scoreResult.score,
        eligible_amount: eligibleAmount,
        risk_level: scoreResult.risk_level,
        scoreDetails: {
          factors: scoreResult.factors,
          model_version: scoreResult.model_version,
          probability: scoreResult.probability,
          decision: scoreResult.decision
        },
        recommendations: scoreResult.recommendations,
        repaymentCapacity: repaymentCapacity
      };
    } catch (error) {
      this.logger.error(`Erreur calcul score: ${error.message}`);
      return {
        score: 600,
        eligible_amount: 500000,
        risk_level: 'medium',
        scoreDetails: null,
        recommendations: ['Erreur lors du calcul du score'],
        repaymentCapacity: {
          monthlyCapacity: 0,
          debtRatio: 0,
          status: 'unknown'
        }
      };
    }
  }

  private calculateRepaymentCapacity(user: any): any {
    const monthlyIncome = user.monthlyIncome || 0;
    const monthlyCharges = user.monthlyCharges || 0;
    const existingDebts = user.existingDebts || 0;
    
    // Capacité de remboursement mensuelle (revenu - charges - dettes)
    const monthlyCapacity = Math.max(0, monthlyIncome - monthlyCharges - existingDebts);
    
    // Ratio d'endettement
    const debtRatio = monthlyIncome > 0 ? (monthlyCharges + existingDebts) / monthlyIncome : 1;
    
    // Statut de la capacité
    let status = 'good';
    if (debtRatio > 0.7) {
      status = 'critical';
    } else if (debtRatio > 0.5) {
      status = 'warning';
    }

    return {
      monthlyCapacity,
      debtRatio,
      status,
      maxMonthlyPayment: monthlyCapacity * 0.7 // 70% de la capacité disponible
    };
  }

  private calculateAge(birthDate?: string): number {
    if (!birthDate) return 30;
    
    const birth = new Date(birthDate);
    const today = new Date();
    let age = today.getFullYear() - birth.getFullYear();
    const monthDiff = today.getMonth() - birth.getMonth();
    
    if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birth.getDate())) {
      age--;
    }
    
    return age;
  }
}