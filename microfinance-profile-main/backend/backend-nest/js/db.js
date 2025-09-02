const { MongoClient } = require('mongodb');

// Configuration de la base de données
const DB_URL = 'mongodb://localhost:27017';
const DB_NAME = 'bamboocredit_db';

let db;
let client;

// Connexion à MongoDB
async function connectToMongoDB() {
    try {
        client = new MongoClient(DB_URL);
        await client.connect();
        db = client.db(DB_NAME);
        console.log('✅ Connexion réussie à MongoDB');
        
        // Créer les collections sans validation stricte
        await createCollections();
        
        return db;
    } catch (error) {
        console.error('❌ Erreur de connexion à MongoDB:', error);
        process.exit(1);
    }
}

// Création des collections avec validation simplifiée
async function createCollections() {
    try {
        // Collection pour les demandes de crédit (validation minimale)
        await db.createCollection('credit_applications', {
            validator: {
                $jsonSchema: {
                    bsonType: 'object',
                    required: ['client_data', 'documents', 'scoring'],
                    properties: {
                        client_data: {
                            bsonType: 'object',
                            properties: {
                                amount: { bsonType: ['double', 'int'] },
                                monthly_income: { bsonType: ['double', 'int'] },
                                other_income: { bsonType: ['double', 'int'] },
                                monthly_expenses: { bsonType: ['double', 'int'] },
                                existing_debts: { bsonType: ['double', 'int'] },
                                collateral_value: { bsonType: ['double', 'int'] },
                                age: { bsonType: ['int', 'null'] },
                                employment_type: { bsonType: ['string', 'null'] },
                                education_level: { bsonType: ['string', 'null'] },
                                marital_status: { bsonType: ['string', 'null'] },
                                number_of_dependents: { bsonType: ['int', 'null'] },
                                loan_purpose: { bsonType: ['string', 'null'] },
                                loan_term: { bsonType: ['int', 'null'] }
                            }
                        },
                        documents: {
                            bsonType: 'object',
                            properties: {
                                id_document: { bsonType: ['bool', 'null'] },
                                income_proof: { bsonType: ['bool', 'null'] },
                                guarantor_id: { bsonType: ['bool', 'null'] },
                                proof_of_residence: { bsonType: ['bool', 'null'] }
                            }
                        },
                        scoring: {
                            bsonType: 'object',
                            properties: {
                                score: { bsonType: ['int', 'null'] },
                                risk_level: { bsonType: ['string', 'null'] },
                                status: { bsonType: ['string', 'null'] }
                            }
                        }
                    }
                }
            }
        });

        // Collection pour les données de scoring
        await db.createCollection('scoring_data');

        // Collection pour les utilisateurs
        await db.createCollection('users', {
            validator: {
                $jsonSchema: {
                    bsonType: 'object',
                    required: ['username', 'email', 'password', 'role'],
                    properties: {
                        username: { bsonType: 'string' },
                        email: { bsonType: 'string' },
                        password: { bsonType: 'string' },
                        role: { bsonType: 'string' },
                        profile: { bsonType: ['object', 'null'] },
                        is_active: { bsonType: ['bool', 'null'] },
                        created_at: { bsonType: ['date', 'null'] },
                        updated_at: { bsonType: ['date', 'null'] },
                        last_login: { bsonType: ['date', 'null'] }
                    }
                }
            }
        });

        console.log('✅ Collections créées avec succès');

        // Créer les index pour les performances
        await createIndexes();

    } catch (error) {
        if (error.code !== 48) { // Collection already exists
            console.error('❌ Erreur lors de la création des collections:', error.message);
        } else {
            console.log('ℹ️  Collections déjà existantes');
        }
    }
}

// Création des index
async function createIndexes() {
    try {
        // Index pour credit_applications
        await db.collection('credit_applications').createIndex({ 'scoring.status': 1 });
        await db.collection('credit_applications').createIndex({ 'scoring.risk_level': 1 });
        await db.collection('credit_applications').createIndex({ 'created_at': -1 });
        await db.collection('credit_applications').createIndex({ 'client_data.amount': 1 });

        // Index pour scoring_data
        await db.collection('scoring_data').createIndex({ 'application_id': 1 });
        await db.collection('scoring_data').createIndex({ 'created_at': -1 });

        // Index pour users
        await db.collection('users').createIndex({ 'email': 1 }, { unique: true });
        await db.collection('users').createIndex({ 'username': 1 }, { unique: true });
        await db.collection('users').createIndex({ 'role': 1 });

        console.log('✅ Index créés avec succès');
    } catch (error) {
        if (error.code === 11000) {
            console.log('ℹ️  Index déjà existants');
        } else {
            console.error('❌ Erreur lors de la création des index:', error.message);
        }
    }
}

// Supprimer les validations strictes (pour debug)
async function dropCollections() {
    try {
        await db.collection('credit_applications').drop();
        await db.collection('scoring_data').drop();
        await db.collection('users').drop();
        console.log('✅ Collections supprimées');
    } catch (error) {
        console.log('ℹ️  Certaines collections n\'existaient pas');
    }
}

// Recréer les collections sans validation (pour debug)
async function createSimpleCollections() {
    try {
        await dropCollections();
        
        // Créer les collections sans validation
        await db.createCollection('credit_applications');
        await db.createCollection('scoring_data');
        await db.createCollection('users');
        
        console.log('✅ Collections simples créées');
        await createIndexes();
        
    } catch (error) {
        console.error('❌ Erreur lors de la création des collections simples:', error);
    }
}

// Fermeture de la connexion
async function closeConnection() {
    if (client) {
        await client.close();
        console.log('✅ Connexion MongoDB fermée');
    }
}

// Export des collections
const getCollections = () => {
    if (!db) {
        throw new Error('Base de données non initialisée. Appelez connectToMongoDB() d\'abord.');
    }
    
    return {
        credit_applications: db.collection('credit_applications'),
        scoring_data: db.collection('scoring_data'),
        users: db.collection('users')
    };
};

module.exports = {
    connectToMongoDB,
    getCollections,
    closeConnection,
    createSimpleCollections,
    dropCollections,
    db: () => db
};