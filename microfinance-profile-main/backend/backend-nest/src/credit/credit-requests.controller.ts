import { Body, Controller, Delete, Get, Param, Post, Put, Query } from "@nestjs/common";
import { CreditRequestsService } from "./credit-requests.service";

// credit-requests.controller.ts
@Controller('credit')
export class CreditRequestsController {
  constructor(private readonly creditRequestsService: CreditRequestsService) {}

  @Post('short')
  async createShortRequest(@Body() requestData: any) {
    return this.creditRequestsService.createShortRequest(requestData);
  }

  @Get('user/:username')
  async getUserRequests(@Param('username') username: string, @Query() filters?: any) {
    return this.creditRequestsService.getUserRequests(username, filters);
  }

  @Get('user-credits/:username')
  async getUserCredits(@Param('username') username: string) {
    return this.creditRequestsService.getShortRequests(username);
  }

  @Put('request/:id')
  async updateRequest(@Param('id') id: string, @Body() updates: any) {
    return this.creditRequestsService.updateRequest(id, updates);
  }

  @Delete('request/:id')
  async deleteRequest(@Param('id') id: string) {
    return this.creditRequestsService.deleteRequest(id);
  }

  @Post('request/:id/submit')
  async submitRequest(@Param('id') id: string) {
    return this.creditRequestsService.submitRequest(id);
  }
}

