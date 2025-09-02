const { connectToMongoDB, getCollections, closeConnection } = require('./db'); // modifie le chemin

async function seedData() {
  await connectToMongoDB();
  const { users, credit_applications, scoring_data } = getCollections();

  // Nettoyage des collections avant insertion
  await users.deleteMany({});
  await credit_applications.deleteMany({});
  await scoring_data.deleteMany({});

  // Données de test : utilisateurs
  await users.insertMany([
    {
      username: 'admin',
      email: 'admin@example.com',
      password: '$2b$10$hashedpassword123456789012345678901234567890', // bcrypt
      role: 'admin',
      profile: null,
      is_active: true,
      created_at: new Date(),
      updated_at: new Date(),
      last_login: new Date()
    },
    {
      username: 'user1',
      email: 'user1@example.com',
      password: '$2b$10$anotherfakehash0987654321098765432109876543210',
      role: 'customer_service',
      is_active: true,
      created_at: new Date(),
      updated_at: new Date(),
      last_login: new Date()
    }
  ]);

  // Données de test : demande de crédit
  await credit_applications.insertOne({
    client_data: {
      amount: 500000,
      monthly_income: 200000,
      other_income: 0,
      monthly_expenses: 50000,
      existing_debts: 100000,
      collateral_value: 300000,
      age: 35,
      employment_type: 'CDI',
      education_level: 'Université',
      marital_status: 'Marié',
      number_of_dependents: 2,
      loan_purpose: 'Investissement',
      loan_term: 24
    },
    documents: {
      id_document: true,
      income_proof: true,
      guarantor_id: false,
      proof_of_residence: true
    },
    scoring: {
      score: 720,
      risk_level: 'Faible',
      status: 'Accepté'
    },
    created_at: new Date()
  });

  // Données de test : scoring_data
  await scoring_data.insertOne({
    application_id: 'fake_id_1',
    score_details: {
      monthly_income: 200000,
      monthly_expenses: 50000
    },
    created_at: new Date()
  });

  console.log('✅ Données de test insérées avec succès.');
  await closeConnection();
}

seedData();
