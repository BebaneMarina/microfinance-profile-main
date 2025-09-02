import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ScoringService } from './scoring.service';
import { ScoringController } from './scoring.controller';
import { CreditScoring } from './entities/credit-scoring.entity';

@Module({
  imports: [
    // Enregistre l'entité CreditScoring pour créer le repository
    TypeOrmModule.forFeature([CreditScoring])
  ],
  controllers: [ScoringController],
  providers: [ScoringService],
  exports: [ScoringService] // Permet à d'autres modules d'utiliser ce service
})
export class ScoringModule {}