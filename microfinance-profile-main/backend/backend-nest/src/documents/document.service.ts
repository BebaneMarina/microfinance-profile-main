import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { DocumentStorage, DocumentStorageDocument } from '../schema/document-storage.schema';

@Injectable()
export class DocumentsService {
  private readonly logger = new Logger(DocumentsService.name);

  constructor(
    @InjectModel(DocumentStorage.name)
    private documentModel: Model<DocumentStorageDocument>,
  ) {}

  async create(createDocumentDto: any): Promise<DocumentStorageDocument> {
    const document = new this.documentModel({
      ...createDocumentDto,
      metadata: {
        uploadedBy: `user_${createDocumentDto.userId}`,
        uploadedAt: new Date(),
        source: 'api',
      },
      verificationStatus: {
        isVerified: false,
      },
    });

    return document.save();
  }

  async findByCreditRequest(creditRequestId: number): Promise<DocumentStorageDocument[]> {
    return this.documentModel.find({ 
      creditRequestId,
      status: 'active' 
    }).sort({ createdAt: -1 });
  }

  async findByUser(userId: number): Promise<DocumentStorageDocument[]> {
    return this.documentModel.find({ 
      userId,
      status: 'active' 
    }).sort({ createdAt: -1 });
  }

  async updateVerificationStatus(
    documentId: string,
    verificationData: {
      isVerified: boolean;
      verifiedBy: string;
      verificationNotes?: string;
      anomalies?: string[];
    }
  ): Promise<DocumentStorageDocument> {
    const document = await this.documentModel.findByIdAndUpdate(
      documentId,
      {
        $set: {
          'verificationStatus.isVerified': verificationData.isVerified,
          'verificationStatus.verifiedBy': verificationData.verifiedBy,
          'verificationStatus.verifiedAt': new Date(),
          'verificationStatus.verificationNotes': verificationData.verificationNotes,
          'verificationStatus.anomalies': verificationData.anomalies,
        }
      },
      { new: true }
    );

    if (!document) {
      throw new NotFoundException(`Document ${documentId} not found`);
    }

    return document;
  }

  async updateOcrData(documentId: string, ocrData: any): Promise<DocumentStorageDocument> {
    const document = await this.documentModel.findByIdAndUpdate(
      documentId,
      { $set: { ocrData } },
      { new: true }
    );

    if (!document) {
      throw new NotFoundException(`Document ${documentId} not found`);
    }

    return document;
  }

  async delete(documentId: string): Promise<void> {
    await this.documentModel.findByIdAndUpdate(
      documentId,
      { $set: { status: 'deleted' } }
    );
  }
}