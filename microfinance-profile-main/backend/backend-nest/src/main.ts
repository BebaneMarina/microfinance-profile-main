import { NestFactory } from '@nestjs/core';
import { ValidationPipe, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  const configService = app.get(ConfigService);
  const logger = new Logger('Bootstrap');
  
  // Validation globale
  app.useGlobalPipes(new ValidationPipe({
    whitelist: true,
    transform: true,
  }));
  
  // CORS
  app.enableCors({
    origin: '*',
    methods: 'GET,HEAD,PUT,PATCH,POST,DELETE,OPTIONS',
    credentials: true,
  });
  
  // Date et utilisateur fixe pour test
  const testDate = '2025-07-25 14:59:03';
  const testUser = 'jean';
  
  // Log des informations de test
  logger.log(`============================================`);
  logger.log(`API démarrée - Mode de test actif`);
  logger.log(`Date fixe: ${testDate}`);
  logger.log(`Utilisateur: ${testUser}`);
  logger.log(`Mot de passe: password123`);
  logger.log(`============================================`);
  
  // Démarrer le serveur
  const port = configService.get<number>('PORT', 3000);
  await app.listen(port);
  logger.log(`Application démarrée sur le port ${port}`);
}
bootstrap();