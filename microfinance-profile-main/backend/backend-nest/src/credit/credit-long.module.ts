
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { HttpModule } from '@nestjs/axios';

// Services
import { CreditLongRequestService } from './credit-long-request.service';

// Controllers
import { CreditLongController } from './credit-long-request.controller';
import { CreditLongBackofficeController } from '../backoffice/credit-long-backoffice.controller';  

// Entities
import { LongCreditRequestEntity } from './entities/long-credit-request.entity';
import { LongCreditDocumentEntity } from './entities/long-credit-document.entity';
import { LongCreditCommentEntity } from './entities/long-credit-comment.entity';
import { LongCreditReviewHistoryEntity } from './entities/long-credit-review-history.entity';
import { Utilisateur } from '../app/auth/entities/user.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      LongCreditRequestEntity,
      LongCreditDocumentEntity,
      LongCreditCommentEntity,
      LongCreditReviewHistoryEntity,
      Utilisateur
    ]),
    HttpModule
  ],
  controllers: [
    CreditLongController,
    CreditLongBackofficeController 
  ],
  providers: [CreditLongRequestService],
  exports: [CreditLongRequestService]
})
export class CreditLongModule {}