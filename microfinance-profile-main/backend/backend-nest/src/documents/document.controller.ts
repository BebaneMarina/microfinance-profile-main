import { Controller, Get, Post, Body, Param, Patch, Delete, UseGuards } from '@nestjs/common';
import { DocumentsService } from './document.service';

@Controller('documents')
export class DocumentsController {
  constructor(private readonly documentsService: DocumentsService) {}

  @Post()
  create(@Body() createDocumentDto: any) {
    return this.documentsService.create(createDocumentDto);
  }

  @Get('credit-request/:id')
  findByCreditRequest(@Param('id') id: string) {
    return this.documentsService.findByCreditRequest(+id);
  }

  @Get('user/:id')
  findByUser(@Param('id') id: string) {
    return this.documentsService.findByUser(+id);
  }

  @Patch(':id/verify')
  verify(@Param('id') id: string, @Body() verificationData: any) {
    return this.documentsService.updateVerificationStatus(id, verificationData);
  }

  @Patch(':id/ocr')
  updateOcr(@Param('id') id: string, @Body() ocrData: any) {
    return this.documentsService.updateOcrData(id, ocrData);
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.documentsService.delete(id);
  }
}