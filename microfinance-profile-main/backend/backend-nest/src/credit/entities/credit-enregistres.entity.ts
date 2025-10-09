// src/credit/entities/credit-enregistres.entity.ts
// ⚠️ REMPLACEZ TOUT LE CONTENU DU FICHIER PAR CECI

import { Entity, PrimaryGeneratedColumn, Column, OneToMany } from 'typeorm';
import { HistoriquePaiements } from './historique-paiement.entity';

@Entity('credits_enregistres')
export class CreditsEnregistres {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'utilisateur_id' })
  utilisateur_id: number;

  @Column({ name: 'type_credit', type: 'varchar', length: 100 })
  type_credit: string;

  @Column({ name: 'montant_principal', type: 'decimal', precision: 15, scale: 2 })
  montant_principal: number;

  @Column({ name: 'montant_total', type: 'decimal', precision: 15, scale: 2 })
  montant_total: number;

  @Column({ name: 'montant_restant', type: 'decimal', precision: 15, scale: 2 })
  montant_restant: number;

  @Column({ name: 'taux_interet', type: 'decimal', precision: 5, scale: 4 })
  taux_interet: number;

  @Column({ name: 'duree_mois', type: 'int' })
  duree_mois: number;

  @Column({ name: 'statut', type: 'varchar', length: 20, default: 'actif' })
  statut: string;

  @Column({ name: 'date_approbation', type: 'timestamp' })
  date_approbation: Date;

  @Column({ name: 'date_echeance', type: 'timestamp' })
  date_echeance: Date;

  @Column({ name: 'date_prochain_paiement', type: 'timestamp', nullable: true })
  date_prochain_paiement: Date;

  @Column({ name: 'montant_prochain_paiement', type: 'decimal', precision: 15, scale: 2, nullable: true })
  montant_prochain_paiement: number;

  // ✅ RELATION avec les paiements (SANS eager loading pour éviter les problèmes)
  @OneToMany(() => HistoriquePaiements, paiement => paiement.credit, {
    cascade: false
  })
  paiements: HistoriquePaiements[];
}