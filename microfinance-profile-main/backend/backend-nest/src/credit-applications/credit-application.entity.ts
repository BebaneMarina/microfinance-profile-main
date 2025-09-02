import { Entity, Column, PrimaryGeneratedColumn, CreateDateColumn, UpdateDateColumn } from 'typeorm';

@Entity('credit_applications')
export class CreditApplication {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  creditType: string;

  @Column('json')
  personalInfo: {
    fullName: string;
    email: string;
    phoneNumber: string;
  };

  @Column('json')
  financialInfo: {
    monthlySalary: number;
    employerName: string;
  };

  @Column('json')
  creditDetails: {
    requestedAmount: number;
    duration: number;
    creditPurpose: string;
    repaymentMode: string;
  };

  @Column('float')
  creditScore: number;

  @Column()
  riskLevel: string;

  @Column('float')
  creditProbability: number;

  @Column({ default: 'en-cours' })
  status: string;

  @Column('json', { nullable: true })
  scoringFactors: any[];

  @CreateDateColumn()
  submissionDate: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}