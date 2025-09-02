import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { CreditController } from './credit.controller';
import { CreditService } from './credit.service';
import { CreditRequest } from './entities/credit-request.entity';
import { User } from '../app/auth/entities/user.entity';
import { ScoringModule } from '../scoring/scoring.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([CreditRequest, User]),
    ScoringModule, // Importer le ScoringModule pour avoir accès au ScoringApiService
  ],
  controllers: [CreditController],
  providers: [CreditService],
  exports: [CreditService]
})
export class CreditModule {} 