import { Entity, Column, PrimaryGeneratedColumn, OneToOne, JoinColumn } from 'typeorm';
import { Utilisateur } from './user.entity';

@Entity('restrictions_credit')
export class RestrictionCredit {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ unique: true })
  utilisateur_id: number;

  @OneToOne(() => Utilisateur, utilisateur => utilisateur.restrictions)
  @JoinColumn({ name: 'utilisateur_id' })
  utilisateur: Utilisateur;

  @Column({ type: 'boolean', default: true })
  peut_emprunter: boolean;

  @Column({ type: 'int', default: 0 })
  credits_actifs_count: number;

  @Column({ type: 'int', default: 2 })
  credits_max_autorises: number;

  @Column({ type: 'decimal', precision: 12, scale: 2, default: 0 })
  dette_totale_active: number;

  @Column({ type: 'decimal', precision: 5, scale: 2, default: 0 })
  ratio_endettement: number;

  @Column({ type: 'timestamp', nullable: true })
  date_derniere_demande: Date;

  @Column({ type: 'timestamp', nullable: true })
  date_prochaine_eligibilite: Date;

  @Column({ type: 'int', nullable: true })
  jours_avant_prochaine_demande: number;

  @Column({ type: 'text', nullable: true })
  raison_blocage: string;
}