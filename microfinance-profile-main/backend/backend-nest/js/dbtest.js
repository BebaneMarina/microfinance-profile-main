// import_modules.js
const fs = require('fs');
const csv = require('csv-parser');
const { MongoClient } = require('mongodb');

let client = null;
let db = null;

// Connexion MongoDB
async function connectToMongoDB(uri = 'mongodb://localhost:27017', dbName = 'bamboocredit_db') {
    if (client && client.isConnected()) return;

    client = new MongoClient(uri);
    await client.connect();
    db = client.db(dbName);
    console.log('✅ Connecté à MongoDB');
}

function getCollections() {
    if (!db) throw new Error('DB non connectée');
    return {
        credit_applications: db.collection('credit_applications'),
        scoring_data: db.collection('scoring_data'),
        users: db.collection('users'),
    };
}

async function closeConnection() {
    if (client) {
        await client.close();
        console.log('❌ Connexion MongoDB fermée');
    }
}

// Nettoyage et conversion des données CSV en format adapté
function cleanAndConvertData(row) {
    return {
        amount: parseFloat(row.amount) || 0,
        monthly_income: parseFloat(row.monthly_income) || 0,
        other_income: parseFloat(row.other_income) || 0,
        monthly_expenses: parseFloat(row.monthly_expenses) || 0,
        existing_debts: parseFloat(row.existing_debts) || 0,
        collateral_value: parseFloat(row.collateral_value) || 0,
        age: parseInt(row.age) || 25,
        employment_type: row.employment_type || 'Unknown',
        education_level: row.education_level || 'Unknown',
        marital_status: row.marital_status || 'Unknown',
        number_of_dependents: parseInt(row.number_of_dependents) || 0,
        loan_purpose: row.loan_purpose || 'Unknown',
        loan_term: parseInt(row.loan_term) || 12,
    };
}

// Conversion des documents booléens
function parseDocuments(row) {
    return {
        id_document: ['true', '1', 1].includes(row.has_id_document),
        income_proof: ['true', '1', 1].includes(row.has_income_proof),
        guarantor_id: ['true', '1', 1].includes(row.has_guarantor_id),
        proof_of_residence: ['true', '1', 1].includes(row.has_proof_of_residence),
    };
}

// Parsing du scoring avec valeurs par défaut et validation
function parseScoring(row) {
    const validRiskLevels = ['LOW', 'MEDIUM', 'HIGH', 'VERY_HIGH'];
    const validStatuses = ['PENDING', 'APPROVED', 'REJECTED', 'UNDER_REVIEW'];

    const riskLevel = (row.risk_level && validRiskLevels.includes(row.risk_level.toUpperCase()))
        ? row.risk_level.toUpperCase()
        : 'MEDIUM';

    const status = (row.status && validStatuses.includes(row.status.toUpperCase()))
        ? row.status.toUpperCase()
        : 'PENDING';

    return {
        score: row.score ? Math.min(1000, Math.max(0, parseInt(row.score))) : null,
        risk_level: riskLevel,
        status: status,
    };
}

// Validation simple des données avant insertion
function validateData(data) {
    if (!data.client_data || !data.documents || !data.scoring) return false;
    if (data.client_data.amount < 0 || data.client_data.monthly_income < 0) return false;
    if (data.client_data.age < 18 || data.client_data.age > 100) data.client_data.age = 25;
    return true;
}

// Traitement d’un batch d’insertion
async function processBatch(collection, batchData, batchNumber) {
    try {
        if (batchData.length === 0) return 0;
        const result = await collection.insertMany(batchData, { ordered: false });
        console.log(`📝 Batch #${batchNumber} inséré: ${result.insertedCount}/${batchData.length} documents`);
        return result.insertedCount;
    } catch (error) {
        console.error(`❌ Erreur insertion batch #${batchNumber}: ${error.message}`);

        // Insertion document par document pour identifier les erreurs
        if (error.name === 'MongoBulkWriteError' && batchData.length > 1) {
            let successCount = 0;
            for (let i = 0; i < batchData.length; i++) {
                try {
                    await collection.insertOne(batchData[i]);
                    successCount++;
                } catch (e) {
                    console.error(`❌ Document ${i + 1} échoué: ${e.message}`);
                }
            }
            return successCount;
        }
        return 0;
    }
}

// Importation principale du CSV dans MongoDB
async function importCsvToMongoDB(csvFilePath = 'data/train.csv') {
    console.log('🚀 Début import CSV vers MongoDB...');

    await connectToMongoDB();
    const { credit_applications } = getCollections();

    // Vider la collection avant import (optionnel)
    await credit_applications.deleteMany({});
    console.log('🧹 Collection "credit_applications" vidée.');

    let batch = [];
    const batchSize = 50;
    let insertedCount = 0;
    let processedRows = 0;
    let errorCount = 0;

    if (!fs.existsSync(csvFilePath)) {
        console.error(`❌ Fichier CSV introuvable: ${csvFilePath}`);
        return { insertedCount: 0, errorCount: 1 };
    }

    return new Promise((resolve, reject) => {
        fs.createReadStream(csvFilePath)
            .pipe(csv())
            .on('data', async (row) => {
                processedRows++;

                const data = {
                    client_data: cleanAndConvertData(row),
                    documents: parseDocuments(row),
                    scoring: parseScoring(row),
                    created_at: new Date(),
                    updated_at: new Date(),
                };

                if (validateData(data)) {
                    batch.push(data);
                } else {
                    errorCount++;
                }

                if (batch.length >= batchSize) {
                    // Attention ici, comme on est dans un callback sync, on ne doit pas await direct
                    // On gère un batch de manière asynchrone sans bloquer la lecture
                    const currentBatch = batch;
                    batch = [];
                    processBatch(credit_applications, currentBatch, Math.ceil(processedRows / batchSize))
                        .then(count => { insertedCount += count; })
                        .catch(err => console.error(err));
                }
            })
            .on('end', async () => {
                if (batch.length > 0) {
                    insertedCount += await processBatch(credit_applications, batch, Math.ceil(processedRows / batchSize));
                }
                console.log(`✅ Import terminé. ${insertedCount} documents insérés sur ${processedRows} lignes.`);
                if (errorCount > 0) console.log(`❌ ${errorCount} erreurs détectées.`);
                resolve({ insertedCount, errorCount });
            })
            .on('error', (err) => {
                console.error('❌ Erreur lecture fichier CSV:', err);
                reject(err);
            });
    });
}

// Création d'utilisateurs de test
async function createSampleUsers() {
    await connectToMongoDB();
    const { users } = getCollections();

    await users.deleteMany({});

    const sampleUsers = [
        {
            username: 'admin',
            email: 'admin@microfinance.com',
            password: '$2b$10$hashedpassword123456789012345678901234567890', // Exemple hash bcrypt
            role: 'ADMIN',
            profile: {
                first_name: 'Admin',
                last_name: 'Principal',
                phone: '+24101234567',
                department: 'Direction',
            },
            is_active: true,
            created_at: new Date(),
            updated_at: new Date(),
            last_login: null,
        },
        {
            username: 'analyst',
            email: 'analyst@microfinance.com',
            password: '$2b$10$hashedpassword123456789012345678901234567890',
            role: 'ANALYST',
            profile: {
                first_name: 'Jean',
                last_name: 'Analyste',
                phone: '+24101234568',
                department: 'Analyse des risques',
            },
            is_active: true,
            created_at: new Date(),
            updated_at: new Date(),
            last_login: null,
        },
        {
            username: 'client',
            email: 'agent@microfinance.com',
            password: '$2b$10$N9qo8uLOickgx2ZMRZoMyeIjZGHFzXxlV3bWiAT2M81f2P9VY2xTa',
            role: 'CLIENT',
            profile: {
                first_name: 'Marie',
                last_name: 'Agent',
                phone: '+24101234569',
                department: 'Service client',
            },
            is_active: true,
            created_at: new Date(),
            updated_at: new Date(),
            last_login: null,
        },
    ];

    const result = await users.insertMany(sampleUsers);
    console.log(`✅ ${result.insertedCount} utilisateurs de test créés`);
}

// Afficher des stats simples
async function displayStats() {
    await connectToMongoDB();
    const { credit_applications, users, scoring_data } = getCollections();

    const totalApps = await credit_applications.countDocuments();
    const approvedApps = await credit_applications.countDocuments({ 'scoring.status': 'APPROVED' });
    const rejectedApps = await credit_applications.countDocuments({ 'scoring.status': 'REJECTED' });
    const pendingApps = await credit_applications.countDocuments({ 'scoring.status': 'PENDING' });

    const totalUsers = await users.countDocuments();
    const totalScoring = await scoring_data.countDocuments();

    console.log('\n📊 STATISTIQUES:');
    console.log('================');
    console.log(`Utilisateurs: ${totalUsers}`);
    console.log(`Applications totales: ${totalApps}`);
    console.log(`Applications approuvées: ${approvedApps}`);
    console.log(`Applications rejetées: ${rejectedApps}`);
    console.log(`Applications en attente: ${pendingApps}`);
    console.log(`Données de scoring: ${totalScoring}`);
    console.log('================\n');
}

// Script principal
async function main() {
    try {
        await importCsvToMongoDB('data/train.csv'); // Modifie le chemin si besoin
        await createSampleUsers();
        await displayStats();
    } catch (error) {
        console.error('Erreur dans main:', error);
    } finally {
        await closeConnection();
    }
}

// Exécution directe du script
if (require.main === module) {
    main();
}

module.exports = {
    importCsvToMongoDB,
    createSampleUsers,
    displayStats,
    connectToMongoDB,
    closeConnection,
};
