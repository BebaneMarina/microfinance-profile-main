import { Entity, Column, PrimaryGeneratedColumn, OneToMany, OneToOne } from 'typeorm';
import { Credit } from './credit.entity';
import { RestrictionCredit } from './restriction-credit.entity';

export enum StatutUtilisateur {
  ACTIF = 'actif',
  INACTIF = 'inactif',
  SUSPENDU = 'suspendu',
  BLOQUE = 'bloque'
}

export enum TypeEmploi {
  CDI = 'cdi',
  CDD = 'cdd',
  INDEPENDANT = 'independant',
  FONCTIONNAIRE = 'fonctionnaire',
  AUTRE = 'autre'
}

export enum NiveauRisque {
  TRES_BAS = 'tres_bas',
  BAS = 'bas',
  MOYEN = 'moyen',
  ELEVE = 'eleve',
  TRES_ELEVE = 'tres_eleve'
}

@Entity('utilisateurs')
export class Utilisateur {
  getFullName() {
    throw new Error('Method not implemented.');
  }
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'uuid', default: () => 'uuid_generate_v4()' })
  uuid: string;

  @Column({ length: 100 })
  nom: string;

  @Column({ length: 100 })
  prenom: string;

  @Column({ unique: true, length: 255 })
  email: string;

  @Column({ unique: true, length: 20 })
  telephone: string;

  @Column({ length: 255 })
  mot_de_passe_hash: string;

  @Column({ length: 100, default: 'Libreville' })
  ville: string;

  @Column({ length: 100, nullable: true })
  quartier: string;

  @Column({ length: 50, default: 'Estuaire' })
  province: string;

  @Column({ length: 255, nullable: true })
  profession: string;

  @Column({ length: 255, nullable: true })
  employeur: string;

  @Column({ type: 'enum', enum: TypeEmploi, default: TypeEmploi.CDI })
  statut_emploi: TypeEmploi;

  @Column({ type: 'decimal', precision: 12, scale: 2 })
  revenu_mensuel: number;

  @Column({ type: 'int', default: 0 })
  anciennete_mois: number;

  @Column({ type: 'decimal', precision: 12, scale: 2, default: 0 })
  charges_mensuelles: number;

  @Column({ type: 'decimal', precision: 12, scale: 2, default: 0 })
  dettes_existantes: number;

  @Column({ type: 'decimal', precision: 3, scale: 1, default: 6.0 })
  score_credit: number;

  @Column({ type: 'int', default: 650 })
  score_850: number;

  @Column({ type: 'enum', enum: NiveauRisque, default: NiveauRisque.MOYEN })
  niveau_risque: NiveauRisque;

  @Column({ type: 'decimal', precision: 12, scale: 2, default: 0 })
  montant_eligible: number;

  @Column({ type: 'enum', enum: StatutUtilisateur, default: StatutUtilisateur.ACTIF })
  statut: StatutUtilisateur;

  @Column({ type: 'timestamp', default: () => 'CURRENT_TIMESTAMP' })
  date_creation: Date;

  @Column({ type: 'timestamp', default: () => 'CURRENT_TIMESTAMP' })
  date_modification: Date;

  @Column({ type: 'timestamp', nullable: true })
  derniere_connexion: Date;

  @OneToMany(() => Credit, credit => credit.utilisateur)
  credits: Credit[];

  @OneToOne(() => RestrictionCredit, restriction => restriction.utilisateur)
  restrictions: RestrictionCredit;
  creditRequests: any;
}