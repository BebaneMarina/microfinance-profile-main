// src/credit/credit.module.ts
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { HttpModule } from '@nestjs/axios';
import { CreditController } from './credit.controller';
import { CreditService } from './credit.service';
import { CreditRequest } from './entities/credit-request.entity';
import { CreditsEnregistres } from './entities/credit-enregistres.entity';
import { RestrictionCredit } from './entities/restriction-credit.entity';
import { HistoriquePaiements } from './entities/historique-paiement.entity';
import { Utilisateur } from '../app/auth/entities/user.entity';
import { ScoringModule } from '../scoring/scoring.module';
import { CreditStatsService } from './credit-stats.service';


@Module({
  imports: [
    TypeOrmModule.forFeature([
      CreditRequest,
      CreditsEnregistres,
      RestrictionCredit,
      HistoriquePaiements,
      Utilisateur
    ]),
    HttpModule,
    ScoringModule
  ],
  controllers: [CreditController],
  providers: [CreditService, CreditStatsService],
  exports: [CreditService, CreditStatsService]
})
export class CreditModule {}