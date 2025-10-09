import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Utilisateur } from '../app/auth/entities/user.entity';
import * as bcrypt from 'bcrypt';

@Injectable()
export class UsersService {
  updatePassword: any;
  // Chercher par email, téléphone ou nom d'utilisateur
  findByEmail(email: string) {
    throw new Error('Method not implemented.');
  }
  constructor(
    @InjectRepository(Utilisateur)
    private usersRepository: Repository<Utilisateur>,
  ) {}

  async findByUsername(username: string): Promise<Utilisateur | undefined> {
    try {
      // Chercher par email, téléphone ou nom d'utilisateur
      const user = await this.usersRepository.findOne({
        where: [
          { email: username },
          { telephone: username }
        ]
      });
      
      if (!user) {
        console.log(`Utilisateur non trouvé: ${username}`);
        return undefined;
      }
      
      console.log(`Utilisateur trouvé: ${user.email}`);
      return user;
    } catch (error) {
      console.error('Erreur lors de la recherche utilisateur:', error);
      return undefined;
    }
  }

  async findById(id: number): Promise<Utilisateur> {
    const user = await this.usersRepository.findOne({ where: { id } });
    if (!user) {
      throw new NotFoundException(`Utilisateur avec ID ${id} non trouvé`);
    }
    return user;
  }

  async findAll(): Promise<Utilisateur[]> {
    return this.usersRepository.find({
      select: ['id', 'uuid', 'email', 'prenom', 'nom', 'statut_emploi', 'revenu_mensuel']
    });
  }

  async updateUserIncome(userId: number, monthlyIncome: number): Promise<Utilisateur> {
    const user = await this.findById(userId);
    user.revenu_mensuel = monthlyIncome;
    return this.usersRepository.save(user);
  }
}