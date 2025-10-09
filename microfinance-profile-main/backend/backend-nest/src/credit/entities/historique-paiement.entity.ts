// entities/historique-paiement.entity.ts - VERSION CORRIGÉE
import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn } from 'typeorm';
import { CreditsEnregistres } from './credit-enregistres.entity';

@Entity('historique_paiements')
export class HistoriquePaiements {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  credit_id: number;

  @Column()
  utilisateur_id: number;

  @Column({ type: 'decimal', precision: 15, scale: 2 })
  montant: number;

  @Column({ type: 'timestamp' })
  date_paiement: Date;

  @Column({ type: 'timestamp' })
  date_prevue: Date;

  @Column({ type: 'int', default: 0 })
  jours_retard: number;

  @Column({ type: 'varchar', length: 20, default: 'a_temps' })
  type_paiement: string; // 'a_temps' | 'en_retard'

  @Column({ type: 'decimal', precision: 15, scale: 2, default: 0 })
  frais_retard: number;

  // ✅ SUPPRIMÉ : @CreateDateColumn car la colonne n'existe probablement pas
  
  // ✅ RELATION : Un paiement appartient à un crédit
  @ManyToOne(() => CreditsEnregistres, credit => credit.paiements)
  @JoinColumn({ name: 'credit_id' })
  credit: CreditsEnregistres;
}