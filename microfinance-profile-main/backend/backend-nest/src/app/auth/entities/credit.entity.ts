import { Entity, Column, PrimaryGeneratedColumn, ManyToOne, JoinColumn, OneToMany } from 'typeorm';
import { Utilisateur } from './user.entity';
import { HistoriquePaiement } from './historique-paiement.entity';

export enum TypeCredit {
  CONSOMMATION_GENERALE = 'consommation_generale',
  AVANCE_SALAIRE = 'avance_salaire',
  DEPANNAGE = 'depannage',
  INVESTISSEMENT = 'investissement',
  TONTINE = 'tontine',
  RETRAITE = 'retraite'
}

export enum StatutCredit {
  ACTIF = 'actif',
  SOLDE = 'solde',
  EN_RETARD = 'en_retard',
  DEFAUT = 'defaut'
}

@Entity('credits_enregistres')
export class Credit {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  utilisateur_id: number;

  @ManyToOne(() => Utilisateur, utilisateur => utilisateur.credits)
  @JoinColumn({ name: 'utilisateur_id' })
  utilisateur: Utilisateur;

  @Column({ type: 'enum', enum: TypeCredit })
  type_credit: TypeCredit;

  @Column({ type: 'decimal', precision: 12, scale: 2 })
  montant_principal: number;

  @Column({ type: 'decimal', precision: 12, scale: 2 })
  montant_total: number;

  @Column({ type: 'decimal', precision: 12, scale: 2 })
  montant_restant: number;

  @Column({ type: 'decimal', precision: 5, scale: 2 })
  taux_interet: number;

  @Column({ type: 'int' })
  duree_mois: number;

  @Column({ type: 'enum', enum: StatutCredit, default: StatutCredit.ACTIF })
  statut: StatutCredit;

  @Column({ type: 'timestamp', default: () => 'CURRENT_TIMESTAMP' })
  date_approbation: Date;

  @Column({ type: 'timestamp' })
  date_echeance: Date;

  @Column({ type: 'timestamp', nullable: true })
  date_prochain_paiement: Date;

  @Column({ type: 'decimal', precision: 12, scale: 2, nullable: true })
  montant_prochain_paiement: number;

  @OneToMany(() => HistoriquePaiement, paiement => paiement.credit)
  paiements: HistoriquePaiement[];
}