import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { MongooseModule } from '@nestjs/mongoose';
import { AuditLog } from '../entities/audit-log.entity';
import { AuditTrail, AuditTrailSchema } from '../schema/audit-trails.schema';
import { AuditService } from './audit.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([AuditLog]),
    MongooseModule.forFeature([
      { name: AuditTrail.name, schema: AuditTrailSchema },
    ]),
  ],
  providers: [AuditService],
  exports: [AuditService],
})
export class AuditModule {}