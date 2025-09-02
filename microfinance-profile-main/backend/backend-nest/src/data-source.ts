import { DataSource } from 'typeorm';
import { CreditApplication } from './app/auth/entities/credit-application.etity';
export const AppDataSource = new DataSource({
  type: 'postgres', // ou votre type de base de données
  host: 'localhost',
  port: 5432,
  username: 'postgres',
  password: ' admin',
  database: 'credit_scoring',
  synchronize: false,
  logging: false,
  entities: [CreditApplication
  ],
  migrations: ['src/migrations/*.{js,ts}'],
  subscribers: ['src/subscribers/*.{js,ts}'],
});