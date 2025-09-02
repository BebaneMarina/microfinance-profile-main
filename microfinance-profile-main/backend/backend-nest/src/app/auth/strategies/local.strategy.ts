import { Strategy } from 'passport-local';
import { PassportStrategy } from '@nestjs/passport';
import { Injectable, UnauthorizedException, Logger } from '@nestjs/common';
import { AuthService } from '../auth.service';

@Injectable()
export class LocalStrategy extends PassportStrategy(Strategy) {
  private readonly logger = new Logger(LocalStrategy.name);
  private readonly currentDate = '2025-07-28 06:51:42';
  private readonly currentUser = 'theobawana';

  constructor(private authService: AuthService) {
    super({
      usernameField: 'username',
      passwordField: 'password',
    });
  }

  async validate(username: string, password: string): Promise<any> {
    this.logger.log(`Validation de l'utilisateur: ${username}`);
    
    const user = await this.authService.validateUser(username, password);
    
    if (!user) {
      this.logger.warn(`Échec de validation pour: ${username}`);
      throw new UnauthorizedException();
    }
    
    this.logger.log(`Validation réussie pour: ${username}`);
    return {
      ...user,
      currentDate: this.currentDate,
      currentUser: this.currentUser
    };
  }
}