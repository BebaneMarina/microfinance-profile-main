import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { UserCreditsService } from './users-credits.service';
import { UserCreditsController } from './users-credit.controller';
import { UserCredit } from './entities/users-credit.entity';
import { CreditRestriction } from './entities/credit-restriction.entity';
import { RealtimeScore } from './entities/realtime-score.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([UserCredit, CreditRestriction, RealtimeScore])
  ],
  controllers: [UserCreditsController],
  providers: [UserCreditsService],
  exports: [UserCreditsService]
})
export class UserCreditsModule {}