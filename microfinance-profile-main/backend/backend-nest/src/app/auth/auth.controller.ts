import { Controller, Post, Body, HttpException, HttpStatus } from '@nestjs/common';
import { AuthService } from './auth.service';

export interface LoginDto {
  email: string;
  password: string;
}

@Controller('auth') // Ceci créera les routes /api/auth/*
export class AuthController {
  constructor(private authService: AuthService) {}

  @Post('login')
  async login(@Body() loginDto: LoginDto) {
    try {
      console.log('Tentative de connexion pour:', loginDto.email);
      
      // Validation des données
      if (!loginDto.email || !loginDto.password) {
        throw new HttpException({
          success: false,
          message: 'Email et mot de passe requis'
        }, HttpStatus.BAD_REQUEST);
      }

      // Validation de l'utilisateur
      const user = await this.authService.validateUser(loginDto.email, loginDto.password);
      
      if (!user) {
        console.log('Utilisateur non trouvé ou mot de passe incorrect');
        throw new HttpException({
          success: false,
          message: 'Email ou mot de passe incorrect'
        }, HttpStatus.UNAUTHORIZED);
      }

      // Vérifier le statut de l'utilisateur
      if (user.status !== 'active') {
        throw new HttpException({
          success: false,
          message: 'Compte désactivé. Contactez l\'administrateur.'
        }, HttpStatus.FORBIDDEN);
      }

      // Génération du token et retour des données
      const result = await this.authService.login(user);
      console.log('Connexion réussie pour:', user.email);
      
      return result;

    } catch (error) {
      console.error('Erreur lors de la connexion:', error);
      
      // Si c'est déjà une HttpException, la relancer
      if (error instanceof HttpException) {
        throw error;
      }
      
      // Sinon, erreur serveur générique
      throw new HttpException({
        success: false,
        message: 'Erreur interne du serveur'
      }, HttpStatus.INTERNAL_SERVER_ERROR);
    }
  }
}