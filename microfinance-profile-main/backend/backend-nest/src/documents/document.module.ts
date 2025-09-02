import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { DocumentStorage, DocumentStorageSchema } from '../schema/document-storage.schema';
import { DocumentsService } from './document.service';
import { DocumentsController } from './document.controller';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: DocumentStorage.name, schema: DocumentStorageSchema },
    ]),
  ],
  controllers: [DocumentsController],
  providers: [DocumentsService],
  exports: [DocumentsService],
})
export class DocumentsModule {}