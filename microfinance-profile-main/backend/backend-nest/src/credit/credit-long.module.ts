// credit-long/credit-long.module.ts
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { HttpModule } from '@nestjs/axios';
import { CreditLongController } from './credit-long-request.controller';
import { CreditLongRequestService } from './credit-long-request.service';
import { LongCreditRequestEntity } from './entities/long-credit-request.entity';
import { LongCreditDocumentEntity } from './entities/long-credit-document.entity';
import { LongCreditCommentEntity } from './entities/long-credit-comment.entity';
import { LongCreditReviewHistoryEntity } from './entities/long-credit-review-history.entity';
import { User } from '../app/auth/entities/user.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      LongCreditRequestEntity,
      LongCreditDocumentEntity,
      LongCreditCommentEntity,
      LongCreditReviewHistoryEntity,
      User
    ]),
    HttpModule
  ],
  controllers: [CreditLongController],
  providers: [CreditLongRequestService],
  exports: [CreditLongRequestService]
})
export class CreditLongModule {}