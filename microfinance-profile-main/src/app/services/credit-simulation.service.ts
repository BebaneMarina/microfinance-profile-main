import { Injectable } from '@angular/core';
import { Observable, of } from 'rxjs';
import { delay, map } from 'rxjs/operators';

export interface SimulationInput {
  clientType: 'particulier' | 'entreprise';
  fullName: string;
  monthlyIncome: number;
  creditType: string;
  requestedAmount: number;
  duration: number;
  interestRate?: number;
  amortizationType?: 'constant' | 'degressif';
}

export interface AmortizationRow {
  month: number;
  date: Date;
  startBalance: number;
  endBalance: number;
  monthlyPayment: number;
  principal: number;
  interestTTC: number;
  interestHT: number;
  tva: number;
  css: number;
  remainingBalance: number;
  cumulativePaid: number;
}

export interface SimulationResult {
  monthlyPayment: number;
  totalAmount: number;
  totalInterest: number;
  totalInterestHT: number;
  totalTVA: number;
  totalCSS: number;
  interestRate: number;
  maxBorrowingCapacity: number;
  debtRatio: number;
  isEligible: boolean;
  eligibilityReasons: string[];
  recommendations: string[];
  amortizationTable: AmortizationRow[];
  teg: number;
  amortizationType: 'constant' | 'degressif';
}

export interface MLAnalysisResult {
  riskScore: number;
  recommendations: string[];
  creditworthiness: 'excellent' | 'good' | 'fair' | 'poor';
}

@Injectable({
  providedIn: 'root'
})
export class CreditSimulationService {
  // Constantes pour les taxes
  private readonly TVA_RATE = 0.18; // 18%
  private readonly CSS_RATE = 0.01; // 1%
  private readonly TAX_RATE = 0.19; // TVA + CSS = 19%
  private readonly QUOTITE_CESSIBLE = 0.3333; // 33.33%
  
  constructor() { }

  simulateCredit(input: SimulationInput): Observable<SimulationResult> {
    return of(input).pipe(
      delay(1000), // Simuler un délai réseau
      map(data => this.calculateSimulation(data))
    );
  }

  private calculateSimulation(input: SimulationInput): SimulationResult {
    // Déterminer le taux annuel HT selon le type de client
    const annualRateHT = (input.interestRate || (input.clientType === 'entreprise' ? 24 : 18)) / 100;
    const amortizationType = input.amortizationType || 'constant';
    
    // Calcul de la capacité d'emprunt maximale avec quotité cessible
    const maxMonthlyPayment = input.monthlyIncome * this.QUOTITE_CESSIBLE;
    const maxBorrowingCapacity = this.calculateMaxBorrowingCapacity(
      maxMonthlyPayment,
      annualRateHT,
      input.duration
    );
    
    // Calcul selon le type d'amortissement
    let monthlyPayment: number;
    let amortizationTable: AmortizationRow[];
    
    if (amortizationType === 'constant') {
      // Calcul de l'échéance constante
      monthlyPayment = this.calculateConstantPayment(
        input.requestedAmount,
        annualRateHT,
        input.duration
      );
      
      // Générer le tableau d'amortissement constant
      amortizationTable = this.generateConstantAmortizationTable(
        input.requestedAmount,
        annualRateHT,
        input.duration
      );
    } else {
      // Pour le dégressif, calculer la première mensualité
      const monthlyRate = annualRateHT / 12;
      const firstMonthInterest = input.requestedAmount * monthlyRate;
      const constantPrincipal = input.requestedAmount / input.duration;
      monthlyPayment = Math.round(constantPrincipal + firstMonthInterest);
      
      // Générer le tableau d'amortissement dégressif
      amortizationTable = this.generateDegressiveAmortizationTable(
        input.requestedAmount,
        annualRateHT,
        input.duration
      );
    }
    
    // Calculer les totaux
    const totals = this.calculateTotals(amortizationTable);
    
    // Ratio d'endettement (basé sur la première mensualité)
    const debtRatio = (monthlyPayment / input.monthlyIncome) * 100;
    
    // Vérification de l'éligibilité
    const eligibilityReasons: string[] = [];
    let isEligible = true;
    
    if (debtRatio > 33.33) {
      isEligible = false;
      eligibilityReasons.push('Votre taux d\'endettement dépasse 33.33% (quotité cessible)');
    }
    
    if (input.requestedAmount > maxBorrowingCapacity) {
      isEligible = false;
      eligibilityReasons.push('Le montant demandé dépasse votre capacité d\'emprunt');
    }
    
    // Vérifier les limites spécifiques au type de crédit
    const creditLimits = this.getCreditLimits(input.creditType);
    if (creditLimits.maxAmount && input.requestedAmount > creditLimits.maxAmount) {
      isEligible = false;
      eligibilityReasons.push(`Le montant maximum pour ce type de crédit est ${this.formatCurrency(creditLimits.maxAmount)}`);
    }
    
    if (creditLimits.maxDuration && input.duration > creditLimits.maxDuration) {
      isEligible = false;
      eligibilityReasons.push(`La durée maximum pour ce type de crédit est ${creditLimits.maxDuration} mois`);
    }
    
    // Calculer le TEG
    const teg = this.calculateTEG(input.requestedAmount, totals.totalPaid, input.duration);
    
    // Recommandations
    const recommendations = this.generateRecommendations(input, debtRatio, isEligible, amortizationType);
    
    return {
      monthlyPayment,
      totalAmount: totals.totalPaid,
      totalInterest: totals.totalInterestTTC,
      totalInterestHT: totals.totalInterestHT,
      totalTVA: totals.totalTVA,
      totalCSS: totals.totalCSS,
      interestRate: annualRateHT * 100,
      maxBorrowingCapacity,
      debtRatio,
      isEligible,
      eligibilityReasons,
      recommendations,
      amortizationTable,
      teg,
      amortizationType
    };
  }

  private calculateConstantPayment(capital: number, annualRateHT: number, duration: number): number {
    // Taux mensuel = taux annuel HT / 12
    const monthlyRate = annualRateHT / 12;
    
    // Si taux = 0, mensualité = capital / durée
    if (monthlyRate === 0) {
      return Math.round(capital / duration);
    }
    
    // Formule: échéance = (C × i × (1+i)^n) / ((1+i)^n - 1)
    const pow = Math.pow(1 + monthlyRate, duration);
    const payment = (capital * monthlyRate * pow) / (pow - 1);
    
    return Math.round(payment);
  }

  private calculateMaxBorrowingCapacity(maxMonthlyPayment: number, annualRateHT: number, duration: number): number {
    const monthlyRate = annualRateHT / 12;
    
    if (monthlyRate === 0) {
      return Math.round(maxMonthlyPayment * duration);
    }
    
    // Formule inverse pour trouver le capital maximum
    const pow = Math.pow(1 + monthlyRate, duration);
    const capacity = (maxMonthlyPayment * (pow - 1)) / (monthlyRate * pow);
    
    return Math.round(capacity);
  }

  private generateConstantAmortizationTable(
    capital: number,
    annualRateHT: number,
    duration: number
  ): AmortizationRow[] {
    const table: AmortizationRow[] = [];
    let remainingBalance = capital;
    let cumulativePaid = 0;
    const startDate = new Date();
    
    // Calcul de l'échéance constante
    const monthlyPayment = this.calculateConstantPayment(capital, annualRateHT, duration);
    
    // Taux mensuel
    const monthlyRate = annualRateHT / 12;
    
    for (let month = 1; month <= duration; month++) {
      const startBalance = remainingBalance;
      
      // Intérêts du mois sur le capital restant dû
      const monthlyInterest = Math.round(remainingBalance * monthlyRate);
      
      // Principal = Échéance - Intérêts
      let principal = monthlyPayment - monthlyInterest;
      let currentPayment = monthlyPayment;
      
      // Ajustement pour le dernier mois si nécessaire
      if (month === duration && remainingBalance > 0) {
        principal = remainingBalance;
        currentPayment = principal + monthlyInterest;
      }
      
      // S'assurer que le principal n'est pas négatif
      if (principal < 0) {
        principal = 0;
        currentPayment = monthlyInterest;
      }
      
      // Calcul des taxes sur les intérêts
      const interestHT = Math.round(monthlyInterest / 1.19);
      const tva = Math.round(interestHT * 0.18);
      const css = Math.round(interestHT * 0.01);
      
      // Mise à jour du solde
      remainingBalance = Math.max(0, remainingBalance - principal);
      cumulativePaid += currentPayment;
      
      // Date de l'échéance
      const paymentDate = new Date(startDate);
      paymentDate.setMonth(startDate.getMonth() + month);
      
      table.push({
        month,
        date: paymentDate,
        startBalance,
        endBalance: remainingBalance,
        monthlyPayment: currentPayment,
        principal,
        interestTTC: monthlyInterest,
        interestHT,
        tva,
        css,
        remainingBalance,
        cumulativePaid
      });
    }
    
    return table;
  }

  private generateDegressiveAmortizationTable(
    capital: number,
    annualRateHT: number,
    duration: number
  ): AmortizationRow[] {
    const table: AmortizationRow[] = [];
    const constantPrincipal = Math.round(capital / duration);
    let remainingBalance = capital;
    let cumulativePaid = 0;
    const startDate = new Date();
    
    // Taux mensuel
    const monthlyRate = annualRateHT / 12;
    
    for (let month = 1; month <= duration; month++) {
      const startBalance = remainingBalance;
      
      // Intérêts du mois sur le capital restant
      const monthlyInterest = Math.round(remainingBalance * monthlyRate);
      
      // Principal constant (sauf dernier mois)
      const principal = month === duration ? remainingBalance : constantPrincipal;
      
      // Mensualité = Principal + Intérêts
      const monthlyPayment = principal + monthlyInterest;
      
      // Calcul des taxes sur les intérêts
      const interestHT = Math.round(monthlyInterest / 1.19);
      const tva = Math.round(interestHT * 0.18);
      const css = Math.round(interestHT * 0.01);
      
      // Mise à jour du solde
      remainingBalance = Math.max(0, remainingBalance - principal);
      cumulativePaid += monthlyPayment;
      
      // Date de l'échéance
      const paymentDate = new Date(startDate);
      paymentDate.setMonth(startDate.getMonth() + month);
      
      table.push({
        month,
        date: paymentDate,
        startBalance,
        endBalance: remainingBalance,
        monthlyPayment,
        principal,
        interestTTC: monthlyInterest,
        interestHT,
        tva,
        css,
        remainingBalance,
        cumulativePaid
      });
    }
    
    return table;
  }

  private calculateTotals(amortizationTable: AmortizationRow[]) {
    return amortizationTable.reduce((totals, row) => {
      return {
        totalPaid: totals.totalPaid + row.monthlyPayment,
        totalInterestTTC: totals.totalInterestTTC + row.interestTTC,
        totalInterestHT: totals.totalInterestHT + row.interestHT,
        totalTVA: totals.totalTVA + row.tva,
        totalCSS: totals.totalCSS + row.css
      };
    }, {
      totalPaid: 0,
      totalInterestTTC: 0,
      totalInterestHT: 0,
      totalTVA: 0,
      totalCSS: 0
    });
  }

  private calculateTEG(capital: number, totalPaid: number, duration: number): number {
    // TEG = ((Total payé / Capital) - 1) × (12 / durée) × 100
    const totalCost = totalPaid - capital;
    const costRate = totalCost / capital;
    const annualizedRate = costRate * (12 / duration);
    
    return Math.round(annualizedRate * 10000) / 100; // Arrondi à 2 décimales
  }

  private getCreditLimits(creditType: string): { maxAmount: number | null, maxDuration: number | null } {
    const limits: { [key: string]: { maxAmount: number | null, maxDuration: number | null } } = {
      consommation: { maxAmount: null, maxDuration: 48 },
      investissement: { maxAmount: 100000000, maxDuration: 36 },
      avance_facture: { maxAmount: 100000000, maxDuration: null },
      avance_commande: { maxAmount: 100000000, maxDuration: null },
      tontine: { maxAmount: 5000000, maxDuration: null },
      retraite: { maxAmount: 2000000, maxDuration: 12 },
      spot: { maxAmount: 100000000, maxDuration: 3 }
    };
    
    return limits[creditType] || { maxAmount: null, maxDuration: null };
  }

  private generateRecommendations(
    input: SimulationInput, 
    debtRatio: number, 
    isEligible: boolean,
    amortizationType: string
  ): string[] {
    const recommendations: string[] = [];
    
    if (!isEligible && debtRatio > 33.33) {
      const annualRateHT = (input.clientType === 'entreprise' ? 0.24 : 0.18);
      const recommendedAmount = this.calculateMaxBorrowingCapacity(
        input.monthlyIncome * this.QUOTITE_CESSIBLE,
        annualRateHT,
        input.duration
      );
      recommendations.push(`Nous vous recommandons de réduire le montant à ${this.formatCurrency(recommendedAmount)} pour respecter la quotité cessible de 33.33%`);
    }
    
    if (debtRatio > 25 && debtRatio <= 33.33) {
      recommendations.push('Votre taux d\'endettement est proche de la limite. Assurez-vous de pouvoir maintenir ce niveau de remboursement');
    }
    
    if (input.duration > 24) {
      recommendations.push('Une durée plus courte réduirait le coût total du crédit');
    }
    
    // Recommandations sur le type d'amortissement
    if (amortizationType === 'constant') {
      recommendations.push('✓ L\'amortissement constant offre des mensualités fixes, facilitant la gestion de votre budget');
    } else {
      recommendations.push('✓ L\'amortissement dégressif permet de payer moins d\'intérêts au total');
      recommendations.push('⚠️ Attention : les premières mensualités sont plus élevées avec l\'amortissement dégressif');
    }
    
    if (input.clientType === 'entreprise') {
      recommendations.push('En tant qu\'entreprise, assurez-vous d\'avoir des flux de trésorerie stables');
      recommendations.push(`Le taux annuel entreprise de 24% s'applique (taxes incluses dans les calculs)`);
      recommendations.push('Le crédit investissement est adapté pour financer vos projets de développement');
    } else {
      recommendations.push(`Le taux annuel particulier de 18% s'applique (taxes incluses dans les calculs)`);
    }
    
    // Recommandations spécifiques au type de crédit
    switch (input.creditType) {
      case 'consommation':
        recommendations.push('Le crédit consommation est idéal pour vos besoins personnels');
        break;
      case 'investissement':
        recommendations.push('Assurez-vous que l\'investissement générera des revenus suffisants');
        break;
      case 'spot':
        recommendations.push('Le crédit spot est une solution de financement court terme (3 mois max)');
        break;
      case 'retraite':
        recommendations.push('Ce crédit est adapté aux retraités CNSS/CPPF');
        break;
      case 'tontine':
        recommendations.push('Le crédit tontine est adapté aux associations et groupements');
        break;
      case 'avance_facture':
        recommendations.push('L\'avance sur facture permet d\'obtenir rapidement de la trésorerie');
        break;
      case 'avance_commande':
        recommendations.push('L\'avance sur bon de commande finance vos commandes clients');
        break;
    }
    
    return recommendations;
  }

  analyzeWithML(data: any): Observable<MLAnalysisResult> {
    // Simulation d'une analyse ML basée sur les données
    return of(data).pipe(
      delay(500),
      map(simulationData => {
        const riskScore = this.calculateRiskScore(simulationData);
        const creditworthiness = this.determineCreditworthiness(riskScore);
        const recommendations = this.generateMLRecommendations(simulationData, riskScore, creditworthiness);
        
        return {
          riskScore,
          creditworthiness,
          recommendations
        };
      })
    );
  }

  private calculateRiskScore(data: any): number {
    let score = 100;
    
    // Facteurs de risque basés sur la quotité cessible
    if (data.debtRatio > 33.33) score -= 40;
    else if (data.debtRatio > 25) score -= 20;
    else if (data.debtRatio > 20) score -= 10;
    
    // Montant du crédit par rapport au revenu
    const loanToIncomeRatio = data.requestedAmount / (data.monthlyIncome * 12);
    if (loanToIncomeRatio > 2) score -= 20;
    else if (loanToIncomeRatio > 1.5) score -= 10;
    
    // Durée du crédit
    if (data.duration > 36) score -= 10;
    else if (data.duration > 24) score -= 5;
    
    // Bonus pour les entreprises établies
    if (data.clientType === 'entreprise' && data.monthlyIncome > 5000000) {
      score += 10;
    }
    
    // Bonus pour amortissement dégressif (moins de risque)
    if (data.amortizationType === 'degressif') {
      score += 5;
    }
    
    return Math.max(0, Math.min(100, score));
  }

  private determineCreditworthiness(riskScore: number): 'excellent' | 'good' | 'fair' | 'poor' {
    if (riskScore >= 80) return 'excellent';
    if (riskScore >= 60) return 'good';
    if (riskScore >= 40) return 'fair';
    return 'poor';
  }

  private generateMLRecommendations(data: any, riskScore: number, creditworthiness: string): string[] {
    const recommendations: string[] = [];
    
    switch (creditworthiness) {
      case 'excellent':
        recommendations.push('Votre profil est excellent, vous êtes éligible aux meilleures conditions');
        recommendations.push('Vous pourriez négocier une réduction du taux d\'intérêt');
        break;
      case 'good':
        recommendations.push('Votre profil est solide, votre demande a de très bonnes chances d\'être approuvée');
        recommendations.push('Maintenez votre situation financière actuelle');
        break;
      case 'fair':
        recommendations.push('Votre profil présente quelques risques modérés');
        recommendations.push('Des garanties supplémentaires pourraient améliorer votre dossier');
        break;
      case 'poor':
        recommendations.push('Votre profil présente des risques élevés');
        recommendations.push('Envisagez un co-emprunteur ou des garanties solides');
        break;
    }
    
    // Recommandations basées sur le TEG
    if (data.teg && data.teg > 25) {
      recommendations.push('Le TEG est élevé, vérifiez si vous pouvez réduire la durée du prêt');
    }
    
    return recommendations;
  }

  formatCurrency(amount: number): string {
    return new Intl.NumberFormat('fr-FR', {
      style: 'decimal',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0
    }).format(Math.round(amount)) + ' FCFA';
  }

  formatDate(date: Date): string {
    return date.toLocaleDateString('fr-FR', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric'
    });
  }

  // Convertir une image locale en base64
  async convertImageToBase64(imageFile: File): Promise<string> {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onloadend = () => resolve(reader.result as string);
      reader.onerror = reject;
      reader.readAsDataURL(imageFile);
    });
  }

    // Charger l'image depuis les assets
  async loadLogoFromAssets(): Promise<string> {
    try {
      const response = await fetch('/assets/images/bamboo-logo.png');
      const blob = await response.blob();
      return new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onloadend = () => resolve(reader.result as string);
        reader.onerror = reject;
        reader.readAsDataURL(blob);
      });
    } catch (error) {
      console.error('Erreur lors du chargement du logo:', error);
      return '';
    }
  }

  // Méthode pour sauvegarder une simulation
  saveSimulation(simulation: { input: SimulationInput, result: SimulationResult }): Observable<boolean> {
    const savedSimulations = this.getSavedSimulations();
    const newSimulation = {
      id: `SIM-${Date.now()}`,
      date: new Date().toISOString(),
      ...simulation
    };
    
    savedSimulations.push(newSimulation);
    localStorage.setItem('credit_simulations', JSON.stringify(savedSimulations));
    
    return of(true).pipe(delay(500));
  }

  // Récupérer les simulations sauvegardées
  getSavedSimulations(): any[] {
    const saved = localStorage.getItem('credit_simulations');
    return saved ? JSON.parse(saved) : [];
  }

  // Supprimer une simulation sauvegardée
  deleteSimulation(simulationId: string): Observable<boolean> {
    const savedSimulations = this.getSavedSimulations();
    const filtered = savedSimulations.filter(sim => sim.id !== simulationId);
    localStorage.setItem('credit_simulations', JSON.stringify(filtered));
    
    return of(true).pipe(delay(500));
  }

  // Exporter en PDF
  exportToPDF(simulation: SimulationResult, clientInfo: SimulationInput): string {
    const htmlContent = this.generatePDFContent(simulation, clientInfo);
    return htmlContent;
  }

  private generatePDFContent(simulation: SimulationResult, clientInfo: SimulationInput): string {
    const currentDate = new Date();
    const dateFormat = currentDate.toLocaleDateString('fr-FR', { 
      day: '2-digit', 
      month: 'long', 
      year: 'numeric' 
    });
    
    // Récupérer l'image du profil depuis le localStorage
    const profileImage = localStorage.getItem('profileImage') || '';
    
    // Récupérer le logo Bamboo en base64 depuis le localStorage
    const bambooLogo = localStorage.getItem('bamboo-logo') || '';
    
    // Calcul du mois de début
    const startMonth = currentDate.getMonth() + 1;
    const startYear = currentDate.getFullYear();
    const currentDay = currentDate.getDate();
    const currentMonth = currentDate.getMonth() + 1;
    const currentYear = currentDate.getFullYear();
    
    // Calcul du TAUX TTC (ajouter 19% de taxes au taux HT)
    const tauxTTC = simulation.interestRate * 1.19;
    
    return `
      <!DOCTYPE html>
      <html>
      <head>
        <title>Tableau d'amortissement - ${clientInfo.fullName}</title>
        <style>
          @page {
            size: A4;
            margin: 15mm;
          }
          
          * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
          }
          
          body {
            font-family: Arial, sans-serif;
            font-size: 11px;
            line-height: 1.4;
            color: #000;
            background: white;
          }
          
          /* En-tête Bamboo */
          .header {
            display: flex;
            justify-content: space-between;
            align-items: flex-start;
            margin-bottom: 20px;
            padding-bottom: 15px;
            border-bottom: 3px solid #4CAF50;
          }
          
          .logo-section {
            flex: 1;
          }
          
          .logo-img {
            height: 50px;
            width: auto;
            margin-bottom: 10px;
          }
          
          .logo-fallback {
            color: #4CAF50;
            font-size: 32px;
            font-weight: bold;
            font-family: 'Arial Black', sans-serif;
            margin-bottom: 10px;
          }
          
          .company-info {
            font-size: 10px;
            line-height: 1.3;
          }
          
          .right-info {
            text-align: right;
            font-size: 10px;
          }
          
          .right-info p {
            margin: 2px 0;
          }
          
          .right-info strong {
            color: #333;
          }
          
          /* Titre principal */
          .main-title {
            text-align: center;
            color: #4CAF50;
            font-size: 20px;
            font-weight: bold;
            margin: 25px 0;
            text-decoration: underline;
          }
          
          /* Info box */
          .info-container {
            display: table;
            width: 100%;
            margin-bottom: 20px;
          }
          
          .info-box {
            display: table-cell;
            vertical-align: top;
            background: #f5f5f5;
            border: 1px solid #ddd;
            padding: 15px;
            width: 65%;
          }
          
          .client-photo {
            display: table-cell;
            vertical-align: top;
            width: 35%;
            padding-left: 20px;
            text-align: right;
          }
          
          .client-photo img {
            width: 120px;
            height: 120px;
            border-radius: 10px;
            border: 3px solid #4CAF50;
            object-fit: cover;
          }
          
          .info-grid {
            display: table;
            width: 100%;
          }
          
          .info-row {
            display: table-row;
          }
          
          .info-label, .info-value {
            display: table-cell;
            padding: 5px 10px;
            border-bottom: 1px solid #e0e0e0;
          }
          
          .info-label {
            font-weight: bold;
            width: 40%;
            background: #eeeeee;
          }
          
          .info-value {
            width: 60%;
          }
          
          /* Summary section */
          .summary-box {
            background: #4CAF50;
            color: white;
            padding: 10px;
            margin: 15px 0;
            border-radius: 5px;
          }
          
          .summary-grid {
            display: table;
            width: 100%;
          }
          
          .summary-item {
            display: table-cell;
            text-align: center;
            padding: 5px;
          }
          
          .summary-label {
            font-size: 10px;
            opacity: 0.9;
          }
          
          .summary-value {
            font-size: 14px;
            font-weight: bold;
            margin-top: 3px;
          }
          
          /* Table */
          table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 10px;
            font-size: 9px;
          }
          
          thead {
            background: #4CAF50;
            color: white;
          }
          
          th {
            padding: 8px 3px;
            text-align: center;
            font-weight: normal;
            font-size: 9px;
            border-right: 1px solid rgba(255,255,255,0.3);
            white-space: pre-line;
          }
          
          th:last-child {
            border-right: none;
          }
          
          tbody tr {
            border-bottom: 1px solid #e0e0e0;
          }
          
          tbody tr:nth-child(even) {
            background: #f9f9f9;
          }
          
          td {
            padding: 6px 3px;
            text-align: right;
            font-size: 9px;
          }
          
          td:first-child {
            text-align: center;
            font-weight: bold;
            color: #4CAF50;
          }
          
          .total-row {
            background: #f0f0f0;
            font-weight: bold;
          }
          
          .total-row td {
            border-top: 2px solid #4CAF50;
            padding: 10px 3px;
            font-size: 10px;
          }
          
          /* Footer */
          .footer {
            margin-top: 30px;
            padding-top: 15px;
            border-top: 2px solid #4CAF50;
            text-align: center;
            font-size: 9px;
            color: #666;
          }
          
          .footer .contact-info {
            color: #4CAF50;
            margin: 5px 0;
          }
          
          .footer .website {
            color: #4CAF50;
            text-decoration: none;
          }
          
          .page-number {
            position: fixed;
            bottom: 10mm;
            right: 15mm;
            background: #4CAF50;
            color: white;
            padding: 5px 15px;
            border-radius: 3px;
            font-weight: bold;
          }
          
          @media print {
            body {
              -webkit-print-color-adjust: exact;
              print-color-adjust: exact;
            }
            
            .page-break {
              page-break-after: always;
            }
          }
        </style>
      </head>
      <body>
        <!-- En-tête Bamboo avec logo -->
        <div class="header">
          <div class="logo-section">
            ${bambooLogo ? 
              `<img src="${bambooLogo}" alt="Bamboo EMF" class="logo-img" />` :
              `<div class="logo-fallback">
               Bamboo</div>`
            }
            <div class="company-info">
              Votre partenaire financier<br>
              BP 16100 boulevard triomphal<br>
              Libreville, Gabon
            </div>
          </div>
          <div class="right-info">
            <p><strong>Edité le :</strong> ${dateFormat}</p>
            <p><strong>Utilisateur :</strong> ${clientInfo.fullName.toUpperCase()}</p>
            <p><strong>Référence :</strong> TCAL_${Date.now()}</p>
          </div>
        </div>
        
        <div class="header-note" style="text-align: center; margin-bottom: 20px; font-size: 10px; font-style: italic;">
          Veuillez trouver, ci-après, le tableau d'amortissement relatif au prêt dont les caractéristiques sont ci-dessous.
        </div>
        
        <!-- Titre principal -->
        <h1 class="main-title">TABLEAU D'AMORTISSEMENT INDICATIF</h1>
        
        <!-- Informations du prêt avec photo -->
        <div class="info-container">
          <div class="info-box">
            <div class="info-grid">
              <div class="info-row">
                <div class="info-label">Principal :</div>
                <div class="info-value">${this.formatCurrency(clientInfo.requestedAmount)}</div>
              </div>
              <div class="info-row">
                <div class="info-label">Taux Annuel HT :</div>
                <div class="info-value">${simulation.interestRate.toFixed(2)} %</div>
              </div>
              <div class="info-row">
                <div class="info-label">Durée :</div>
                <div class="info-value">${clientInfo.duration} Mois</div>
              </div>
              <div class="info-row">
                <div class="info-label">Comprenant un différé :</div>
                <div class="info-value">0 Mois</div>
              </div>
              <div class="info-row">
                <div class="info-label">TVA :</div>
                <div class="info-value">18.00 %</div>
              </div>
              <div class="info-row">
                <div class="info-label">CSS :</div>
                <div class="info-value">1.00 %</div>
              </div>
              <div class="info-row">
                <div class="info-label">TAUX TTC :</div>
                <div class="info-value">${tauxTTC.toFixed(2)} %</div>
              </div>
              <div class="info-row">
                <div class="info-label">TEG :</div>
                <div class="info-value">${simulation.teg.toFixed(2)} %</div>
              </div>
            </div>
          </div>
          <div class="client-photo">
            ${profileImage ? 
              `<img src="${profileImage}" alt="Photo du client" />` :
              `<div style="width: 120px; height: 120px; background: #f0f0f0; border: 3px solid #4CAF50; border-radius: 10px; display: inline-flex; align-items: center; justify-content: center; color: #999;">
                <span style="font-size: 48px;"></span>
              </div>`
            }
            <div style="margin-top: 10px; font-size: 10px;">
              <strong>Client :</strong><br>
              ${clientInfo.fullName.toUpperCase()}<br>
              <strong>A/C N° :</strong> ${clientInfo.clientType === 'entreprise' ? 'ENT' : 'PAR'}${Date.now().toString().slice(-8)}<br>
              <strong>Référence contrat :</strong><br>
              ${currentYear}|${(currentMonth + '').padStart(2, '0')}${currentDay}|${clientInfo.clientType === 'entreprise' ? 'E' : 'P'}|${Date.now().toString().slice(-4)}
            </div>
          </div>
        </div>
        
        <div style="margin: 15px 0;">
          <div style="display: table; width: 100%;">
            <div style="display: table-cell; width: 48%;">
              <strong>Mois début Pmt :</strong> ${(startMonth + '').padStart(2, '0')}<br>
              <strong>Année Début Pmt :</strong> ${startYear}
            </div>
            <div style="display: table-cell; width: 52%; text-align: right;">
              <!-- Espace pour info supplémentaire -->
            </div>
          </div>
        </div>
        
        <!-- Résumé des totaux -->
        <div class="summary-box">
          <div class="summary-grid">
            <div class="summary-item">
              <div class="summary-label">Paiement mensuel :</div>
              <div class="summary-value">${this.formatCurrency(simulation.monthlyPayment)}</div>
            </div>
            <div class="summary-item">
              <div class="summary-label">Total Remboursé :</div>
              <div class="summary-value">${this.formatCurrency(simulation.totalAmount)}</div>
            </div>
            <div class="summary-item">
              <div class="summary-label">Intérêt HT :</div>
              <div class="summary-value">${this.formatCurrency(simulation.totalInterestHT)}</div>
            </div>
            <div class="summary-item">
              <div class="summary-label">TVA / CSS :</div>
              <div class="summary-value">${this.formatCurrency(simulation.totalTVA + simulation.totalCSS)}</div>
            </div>
            <div class="summary-item">
              <div class="summary-label">Complément sur Intérêt :</div>
              <div class="summary-value">${this.formatCurrency(simulation.totalTVA + simulation.totalCSS)}</div>
            </div>
          </div>
        </div>
        
        <!-- Tableau d'amortissement -->
        <table>
          <thead>
            <tr>
              <th style="width: 5%;">Pmt</th>
              <th style="width: 11%;">Balance Début<br>Période</th>
              <th style="width: 11%;">Balance Fin<br>Période</th>
              <th style="width: 11%;">Principal Payé</th>
              <th style="width: 11%;">Intérêt Payé TTC</th>
              <th style="width: 11%;">Intérêt Payé HT</th>
              <th style="width: 10%;">TVA sur Intérêt</th>
              <th style="width: 10%;">CSS sur Intérêt</th>
              <th style="width: 11%;">Montant de<br>L'Échéance</th>
              <th style="width: 9%;">Date</th>
            </tr>
          </thead>
          <tbody>
            ${simulation.amortizationTable.slice(0, 20).map(row => `
              <tr>
                <td style="text-align: center; color: #4CAF50; font-weight: bold;">${row.month}</td>
                <td>${this.formatCurrency(row.startBalance)}</td>
                <td>${this.formatCurrency(row.endBalance)}</td>
                <td>${this.formatCurrency(row.principal)}</td>
                <td>${this.formatCurrency(row.interestTTC)}</td>
                <td>${this.formatCurrency(row.interestHT)}</td>
                <td>${this.formatCurrency(row.tva)}</td>
                <td>${this.formatCurrency(row.css)}</td>
                <td style="font-weight: bold;">${this.formatCurrency(row.monthlyPayment)}</td>
                <td style="text-align: center;">${this.formatDate(row.date)}</td>
              </tr>
            `).join('')}
          </tbody>
          ${simulation.amortizationTable.length <= 20 ? `
            <tfoot>
              <tr class="total-row">
                <td colspan="3" style="text-align: left;">TOTAL</td>
                <td>${this.formatCurrency(clientInfo.requestedAmount)}</td>
                <td>${this.formatCurrency(simulation.totalInterest)}</td>
                <td>${this.formatCurrency(simulation.totalInterestHT)}</td>
                <td>${this.formatCurrency(simulation.totalTVA)}</td>
                <td>${this.formatCurrency(simulation.totalCSS)}</td>
                <td>${this.formatCurrency(simulation.totalAmount)}</td>
                <td>-</td>
              </tr>
            </tfoot>
          ` : ''}
        </table>
        
        ${simulation.amortizationTable.length > 20 ? `
          <div style="margin-top: 10px; text-align: center; font-style: italic;">
            ... Suite page suivante ...
          </div>
          
          <div class="page-break"></div>
          
          <!-- Page 2 -->
          <div class="header">
            <div class="logo-section">
              ${bambooLogo ? 
                `<img src="${bambooLogo}" alt="Bamboo EMF" class="logo-img" />` :
                `<div class="logo-fallback">🎋 Bamboo</div>`
              }
            </div>
            <div class="right-info">
              <p><strong>Suite tableau d'amortissement</strong></p>
              <p><strong>Client :</strong> ${clientInfo.fullName.toUpperCase()}</p>
            </div>
          </div>
          
          <table>
            <thead>
              <tr>
                <th style="width: 5%;">Pmt</th>
                <th style="width: 11%;">Balance Début<br>Période</th>
                <th style="width: 11%;">Balance Fin<br>Période</th>
                <th style="width: 11%;">Principal Payé</th>
                <th style="width: 11%;">Intérêt Payé TTC</th>
                <th style="width: 11%;">Intérêt Payé HT</th>
                <th style="width: 10%;">TVA sur Intérêt</th>
                <th style="width: 10%;">CSS sur Intérêt</th>
                <th style="width: 11%;">Montant de<br>L'Échéance</th>
                <th style="width: 9%;">Date</th>
              </tr>
            </thead>
            <tbody>
              ${simulation.amortizationTable.slice(20).map(row => `
                <tr>
                  <td style="text-align: center; color: #4CAF50; font-weight: bold;">${row.month}</td>
                  <td>${this.formatCurrency(row.startBalance)}</td>
                  <td>${this.formatCurrency(row.endBalance)}</td>
                  <td>${this.formatCurrency(row.principal)}</td>
                  <td>${this.formatCurrency(row.interestTTC)}</td>
                  <td>${this.formatCurrency(row.interestHT)}</td>
                  <td>${this.formatCurrency(row.tva)}</td>
                  <td>${this.formatCurrency(row.css)}</td>
                  <td style="font-weight: bold;">${this.formatCurrency(row.monthlyPayment)}</td>
                  <td style="text-align: center;">${this.formatDate(row.date)}</td>
                </tr>
              `).join('')}
            </tbody>
            <tfoot>
              <tr class="total-row">
                <td colspan="3" style="text-align: left;">TOTAL</td>
                <td>${this.formatCurrency(clientInfo.requestedAmount)}</td>
                <td>${this.formatCurrency(simulation.totalInterest)}</td>
                <td>${this.formatCurrency(simulation.totalInterestHT)}</td>
                <td>${this.formatCurrency(simulation.totalTVA)}</td>
                <td>${this.formatCurrency(simulation.totalCSS)}</td>
                <td>${this.formatCurrency(simulation.totalAmount)}</td>
                <td>-</td>
              </tr>
            </tfoot>
          </table>
        ` : ''}
        
        <!-- Footer -->
        <div class="footer">
          <p class="contact-info">
            ☎️ (+241) 60 41 21 21 /77 41 21 21 service.client@bamboo-emf.com
          </p>
          <p>
            <a href="www.bamboo-emf.com" class="website">www.bamboo-emf.com</a>
          </p>
        </div>
        
      </body>
      </html>
    `;
  }
}