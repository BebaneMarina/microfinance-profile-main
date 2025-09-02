import { Controller, Get, Post, Body, Patch, Param, Delete, UseGuards, Request, Query } from '@nestjs/common';
import { CreditApplicationsService } from './credit-application.service';
import { CreateCreditApplicationDto } from './create-credit-application.dto';
import { UpdateCreditApplicationDto } from './udapte-credit-application.dto';
import { JwtAuthGuard } from '../app/auth/guards/jwt-auth.guard';

@Controller('credit-applications')
export class CreditApplicationsController {
  constructor(private readonly creditApplicationsService: CreditApplicationsService) {}

  @Post()
  create(@Body() createCreditApplicationDto: CreateCreditApplicationDto) {
    return this.creditApplicationsService.create(createCreditApplicationDto);
  }

  @UseGuards(JwtAuthGuard)
  @Get()
  findAll(@Request() req, @Query('userEmail') userEmail?: string) {
    // Si c'est un client, ne retourner que ses demandes
    if (req.user.role === 'client') {
      return this.creditApplicationsService.findByUserEmail(req.user.email);
    }
    
    // Si un email est spécifié, filtrer par email
    if (userEmail) {
      return this.creditApplicationsService.findByUserEmail(userEmail);
    }
    
    // Sinon, retourner toutes les demandes (pour admin/agent)
    return this.creditApplicationsService.findAll();
  }

  @UseGuards(JwtAuthGuard)
  @Get('statistics')
  getStatistics() {
    return this.creditApplicationsService.getStatistics();
  }

  @UseGuards(JwtAuthGuard)
  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.creditApplicationsService.findOne(+id);
  }

  @UseGuards(JwtAuthGuard)
  @Patch(':id')
  update(@Param('id') id: string, @Body() updateCreditApplicationDto: UpdateCreditApplicationDto) {
    return this.creditApplicationsService.update(+id, updateCreditApplicationDto);
  }

  @UseGuards(JwtAuthGuard)
  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.creditApplicationsService.remove(+id);
  }
}