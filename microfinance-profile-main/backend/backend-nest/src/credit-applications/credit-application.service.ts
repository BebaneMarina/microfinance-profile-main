import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { CreditApplication } from './credit-application.entity';
import { CreateCreditApplicationDto } from './create-credit-application.dto';
import { UpdateCreditApplicationDto } from './udapte-credit-application.dto';

@Injectable()
export class CreditApplicationsService {
  constructor(
    @InjectRepository(CreditApplication)
    private creditApplicationsRepository: Repository<CreditApplication>,
  ) {}

  async create(createCreditApplicationDto: CreateCreditApplicationDto): Promise<CreditApplication> {
    const application = this.creditApplicationsRepository.create(createCreditApplicationDto);
    return await this.creditApplicationsRepository.save(application);
  }

  async findAll(): Promise<CreditApplication[]> {
    return await this.creditApplicationsRepository.find({
      order: {
        submissionDate: 'DESC',
      },
    });
  }

  async findByUserEmail(email: string): Promise<CreditApplication[]> {
    return await this.creditApplicationsRepository.find({
      where: {
        personalInfo: {
          email: email,
        } as any,
      },
      order: {
        submissionDate: 'DESC',
      },
    });
  }

  async findOne(id: number): Promise<CreditApplication> {
    const application = await this.creditApplicationsRepository.findOne({
      where: { id },
    });

    if (!application) {
      throw new NotFoundException('Demande de crédit non trouvée');
    }

    return application;
  }

  async update(id: number, updateCreditApplicationDto: UpdateCreditApplicationDto): Promise<CreditApplication> {
    const application = await this.findOne(id);
    Object.assign(application, updateCreditApplicationDto);
    return await this.creditApplicationsRepository.save(application);
  }

  async remove(id: number): Promise<void> {
    const application = await this.findOne(id);
    await this.creditApplicationsRepository.remove(application);
  }

  async getStatistics() {
    const applications = await this.findAll();
    
    return {
      total: applications.length,
      approved: applications.filter(app => app.status === 'approuvé').length,
      pending: applications.filter(app => app.status === 'en-cours').length,
      rejected: applications.filter(app => app.status === 'rejeté').length,
      totalAmount: applications.reduce((sum, app) => sum + app.creditDetails.requestedAmount, 0),
      averageScore: applications.length > 0
        ? Math.round(applications.reduce((sum, app) => sum + app.creditScore, 0) / applications.length)
        : 0,
    };
  }
}