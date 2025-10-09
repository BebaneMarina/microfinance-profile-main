import { Entity, Column, PrimaryGeneratedColumn, ManyToOne, JoinColumn } from 'typeorm';
import { Credit } from './credit.entity';

export enum TypePaiement {
  A_TEMPS = 'a_temps',
  EN_RETARD = 'en_retard',
  MANQUE = 'manque',
  ANTICIPE = 'anticipe'
}

@Entity('historique_paiements')
export class HistoriquePaiement {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  credit_id: number;

  @ManyToOne(() => Credit, credit => credit.paiements)
  @JoinColumn({ name: 'credit_id' })
  credit: Credit;

  @Column()
  utilisateur_id: number;

  @Column({ type: 'decimal', precision: 12, scale: 2 })
  montant: number;

  @Column({ type: 'timestamp', default: () => 'CURRENT_TIMESTAMP' })
  date_paiement: Date;

  @Column({ type: 'timestamp' })
  date_prevue: Date;

  @Column({ type: 'int', default: 0 })
  jours_retard: number;

  @Column({ type: 'enum', enum: TypePaiement })
  type_paiement: TypePaiement;

  @Column({ type: 'decimal', precision: 10, scale: 2, default: 0 })
  frais_retard: number;
}