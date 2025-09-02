import { Controller, Get, Param, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../app/auth/guards/jwt-auth.guard';
import { UsersService } from './user.service'; // Utiliser UsersService
import { GetUser } from '../decorators/get-user.decorator';

@Controller('api/users')
@UseGuards(JwtAuthGuard)
export class UsersController {
  constructor(private readonly usersService: UsersService) {} // Utiliser UsersService

  @Get('profile')
  async getProfile(@GetUser() user) {
    const userDetails = await this.usersService.findById(user.userId);
    return {
      id: userDetails.id,
      uuid: userDetails.uuid,
      email: userDetails.email,
      name: userDetails.getFullName(),
      role: userDetails.role,
      monthlyIncome: userDetails.monthly_income,
      profession: userDetails.profession,
      phone: userDetails.phone_number,
      currentDate: '2025-07-26 10:47:43',
      currentUser: 'theobawana'
    };
  }
}