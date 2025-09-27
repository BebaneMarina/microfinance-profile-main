import { Controller, Get, Post, Body, Param, HttpCode, HttpStatus } from '@nestjs/common';
import { UserCreditsService } from './users-credits.service';

@Controller()
export class UserCreditsController {
  constructor(private readonly service: UserCreditsService) {}

  @Get('user-credits/:username')
  async getUserCredits(@Param('username') username: string) {
    return this.service.getUserCredits(username);
  }

  @Post('user-credits')
  async createCredit(@Body() creditData: any) {
    return this.service.createUserCredit(creditData);
  }

  @Get('credit-restrictions/:username')
  async getRestrictions(@Param('username') username: string) {
    return this.service.getCreditRestrictions(username);
  }

  @Post('realtime-scoring')
  @HttpCode(HttpStatus.OK)
  async calculateScore(@Body() userData: any) {
    return this.service.calculateRealtimeScore(userData);
  }

  @Post('process-payment')
  @HttpCode(HttpStatus.OK)
  async processPayment(@Body() paymentData: any) {
    return this.service.processPayment(paymentData);
  }
}