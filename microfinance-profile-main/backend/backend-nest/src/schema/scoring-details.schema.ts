import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type ScoringDetailsDocument = ScoringDetails & Document;

@Schema({ 
  timestamps: true,
  collection: 'scoring_details'
})
export class ScoringDetails {
  @Prop({ required: true, index: true })
  userId: number;

  @Prop({ required: true, index: true })
  creditRequestId: number;

  @Prop({ required: true })
  scoringDate: Date;

  @Prop({ type: Object, required: true })
  inputData: {
    personalInfo: Record<string, any>;
    financialInfo: Record<string, any>;
    creditInfo: Record<string, any>;
    behavioralData?: Record<string, any>;
  };

  @Prop({ type: Object, required: true })
  scoreCalculation: {
    totalScore: number;
    maxScore: number;
    scoreBreakdown: {
      income: { score: number; weight: number; details: any };
      employment: { score: number; weight: number; details: any };
      creditHistory: { score: number; weight: number; details: any };
      debtRatio: { score: number; weight: number; details: any };
      behavioral: { score: number; weight: number; details: any };
      age: { score: number; weight: number; details: any };
      collateral: { score: number; weight: number; details: any };
    };
  };

  @Prop({ type: Object })
  mlAnalysis: {
    modelVersion: string;
    modelType: string;
    predictions: {
      defaultProbability: number;
      riskScore: number;
      paymentBehavior: string;
      recommendations: string[];
    };
    features: Record<string, any>;
    confidence: number;
    processingTime: number;
  };

  @Prop({ type: [Object] })
  riskFactors: Array<{
    factor: string;
    impact: string; // 'positive', 'negative', 'neutral'
    weight: number;
    value: any;
    description: string;
  }>;

  @Prop({ type: Object })
  historicalContext: {
    previousScores: number[];
    averageScore: number;
    trend: string; // 'improving', 'stable', 'declining'
    lastDefaultDate?: Date;
    totalLoans: number;
    successfulLoans: number;
  };

  @Prop({ type: Object })
  externalData: {
    creditBureau?: Record<string, any>;
    bankingData?: Record<string, any>;
    mobileMoneyData?: Record<string, any>;
    socialData?: Record<string, any>;
  };
}

export const ScoringDetailsSchema = SchemaFactory.createForClass(ScoringDetails);