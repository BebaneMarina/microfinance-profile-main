import { MigrationInterface, QueryRunner } from "typeorm";

export class UpdateCreditApplicationsEntity1650000000000 implements MigrationInterface {
    name = 'UpdateCreditApplicationsEntity1650000000000';

    public async up(queryRunner: QueryRunner): Promise<void> {
        // Aucune modification nécessaire si le nom de table est correct
        // Ajoutez ici les modifications de schéma si nécessaire
        await queryRunner.query(`
            COMMENT ON TABLE "credit_applications" IS 'Table des demandes de crédit';
        `);
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        // Méthode de rollback
        await queryRunner.query(`COMMENT ON TABLE "credit_applications" IS '';`);
    }
}