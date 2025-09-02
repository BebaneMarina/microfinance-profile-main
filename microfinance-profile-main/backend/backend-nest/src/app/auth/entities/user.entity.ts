import { Entity, Column, PrimaryGeneratedColumn, BeforeInsert, BeforeUpdate } from 'typeorm';
import * as bcrypt from 'bcrypt';

@Entity('users')
export class User {
  uuid: any;
  getFullName: any;
  monthly_income: any;
  profession: any;
  phone_number: any;
  creditRequests: any;
    username: any;
    isAdmin: any;
    creditScore: number;
    riskLevel: string;
    company: string;
  password_hash(password: string, password_hash: any) {
    throw new Error('Method not implemented.');
  }
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ unique: true })
  email: string;

  @Column({ name: 'password_hash' })
  passwordHash: string;

  @Column({ name: 'first_name' })
  firstName: string;

  @Column({ name: 'last_name' })
  lastName: string;

  @Column({ name: 'phone_number', nullable: true })
  phoneNumber: string;

  @Column({ 
    type: 'enum', 
    enum: ['admin', 'agent', 'client', 'super_admin'],
    default: 'client'
  })
  role: string;

  @Column({ 
    type: 'enum', 
    enum: ['active', 'inactive', 'suspended', 'deleted'],
    default: 'active'
  })
  status: string;

  @Column({ name: 'monthly_income', type: 'decimal', precision: 12, scale: 2, nullable: true })
  monthlyIncome: number;

  @Column({ name: 'created_at', type: 'timestamp', default: () => 'CURRENT_TIMESTAMP' })
  createdAt: Date;

  @Column({ name: 'updated_at', type: 'timestamp', default: () => 'CURRENT_TIMESTAMP' })
  updatedAt: Date;

  // Méthode pour hacher le mot de passe avant insertion/mise à jour
  @BeforeInsert()
  @BeforeUpdate()
  async hashPassword() {
    if (this.passwordHash) {
      const salt = await bcrypt.genSalt(10);
      this.passwordHash = await bcrypt.hash(this.passwordHash, salt);
    }
  }

  // Méthode pour valider le mot de passe
  async validatePassword(password: string): Promise<boolean> {
    try {
      return await bcrypt.compare(password, this.passwordHash);
    } catch (error) {
      console.error('Erreur lors de la validation du mot de passe:', error);
      return false;
    }
  }

  // Méthode pour définir le mot de passe (à utiliser lors de la création)
  async setPassword(password: string) {
    const salt = await bcrypt.genSalt(10);
    this.passwordHash = await bcrypt.hash(password, salt);
  }
  }