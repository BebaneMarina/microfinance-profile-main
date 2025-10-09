import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { UsersService } from './user.service'; // Utiliser UsersService
import { UsersController } from './user.controller';
import { Utilisateur } from '../app/auth/entities/user.entity';

@Module({
  imports: [TypeOrmModule.forFeature([Utilisateur])],
  controllers: [UsersController],
  providers: [UsersService], // Utiliser UsersService
  exports: [UsersService],
})
export class UsersModule {}