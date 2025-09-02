// test_users.js

const { MongoClient } = require('mongodb');

const MONGO_URI = process.env.MONGO_URI || 'mongodb://localhost:27017';
const DB_NAME = 'bamboocredit_db';

async function createSampleUsers() {
  const client = new MongoClient(MONGO_URI, { useUnifiedTopology: true });

  try {
    await client.connect();
    console.log('✅ Connecté à MongoDB');

    const db = client.db(DB_NAME);
    const users = db.collection('users');

    await users.deleteMany({}); // Nettoyage avant test

    const sampleUsers = [
      {
        username: 'admin',
        email: 'admin@microfinance.com',
        password: '$2b$10$hash_admin',
        role: 'ADMIN',
        profile: {
          first_name: 'Admin',
          last_name: 'Principal',
          phone: '+241 01 23 45 67',
          department: 'Direction',
        },
        is_active: true,
        created_at: new Date(),
        updated_at: new Date(),
        last_login: null,
      },
      {
        username: 'analyst',
        email: 'analyst.jean@microfinance.com',
        password: 'P@ss1234',
        role: 'ANALYST',
        profile: {
          first_name: 'Jean',
          last_name: 'Analyste',
          phone: '+241 01 23 45 68',
          department: 'Analyse des risques',
        },
        is_active: true,
        created_at: new Date(),
        updated_at: new Date(),
        last_login: null,
      },
    ];

    const result = await users.insertMany(sampleUsers);
    console.log(`✅ ${result.insertedCount} utilisateurs insérés.`);

    const allUsers = await users.find({}).toArray();
    console.log('📋 Utilisateurs insérés :');
    allUsers.forEach((u, i) => {
      console.log(`${i + 1}. ${u.username} - ${u.email}`);
    });

  } catch (error) {
    console.error('❌ Erreur :', error.message);
  } finally {
    await client.close();
    console.log('🔒 Connexion fermée');
  }
}

createSampleUsers();
