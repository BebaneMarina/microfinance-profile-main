import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { CreditApplicationsService } from './credit-application.service';
import { CreditApplicationsController } from './credit-application.controller';
import { CreditApplication } from './credit-application.entity';

@Module({
  imports: [TypeOrmModule.forFeature([CreditApplication])],
  controllers: [CreditApplicationsController],
  providers: [CreditApplicationsService],
})
export class CreditApplicationsModule {}