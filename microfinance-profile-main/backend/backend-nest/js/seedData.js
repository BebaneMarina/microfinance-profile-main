const { MongoClient } = require("mongodb");

async function seedData() {
  const uri = "mongodb://localhost:27017";
  const client = new MongoClient(uri);

  try {
    await client.connect();
    const db = client.db("microfinance_db");

    // 1. Insert users
    const users = [
      {
        email: "admin@bamboo-emf.ga",
        password: "hashed_admin_password",
        role: "admin",
        firstName: "Jean",
        lastName: "Mbala",
        phone: "+24170000001",
        createdAt: new Date(),
        updatedAt: new Date(),
        status: "active",
      },
      {
        email: "agent1@bamboo-emf.ga",
        password: "hashed_agent_password",
        role: "agent",
        firstName: "Amina",
        lastName: "Ngoma",
        phone: "+24170000002",
        createdAt: new Date(),
        updatedAt: new Date(),
        status: "active",
      },
      {
        email: "client1@bamboo-emf.ga",
        password: "hashed_client_password",
        role: "client",
        firstName: "Paul",
        lastName: "Moussavou",
        phone: "+24170000003",
        createdAt: new Date(),
        updatedAt: new Date(),
        status: "active",
      },
    ];

    const usersResult = await db.collection("users").insertMany(users);
    console.log(`✅ Inséré ${usersResult.insertedCount} utilisateurs`);

    // 2. Insert client linked to the third user (client)
    const clients = [
      {
        userId: usersResult.insertedIds[2], // déjà un ObjectId
        cin: "GAB1234567",
        address: "Libreville, Gabon",
        employment: "Employé à Bamboo-EMF",
        createdAt: new Date(),
        updatedAt: new Date(),
        status: "active",
      },
    ];

    const clientsResult = await db.collection("clients").insertMany(clients);
    console.log(`✅ Inséré ${clientsResult.insertedCount} clients`);

    // 3. Insert loan products
    const loanProducts = [
      {
        name: "Microcrédit Personnel",
        interestRate: 5.5,
        minAmount: 100000,
        maxAmount: 5000000,
        description: "Crédit adapté aux petits emprunteurs individuels.",
        createdAt: new Date(),
        updatedAt: new Date(),
        status: "active",
      },
      {
        name: "Crédit Entreprise",
        interestRate: 7.0,
        minAmount: 1000000,
        maxAmount: 50000000,
        description: "Crédit pour petites et moyennes entreprises.",
        createdAt: new Date(),
        updatedAt: new Date(),
        status: "active",
      },
    ];

    const productsResult = await db.collection("loan_products").insertMany(loanProducts);
    console.log(`✅ Inséré ${productsResult.insertedCount} produits de crédit`);

    // 4. Insert a credit application linked to the inserted client
    const creditApplications = [
      {
        clientId: clientsResult.insertedIds[0], // ObjectId
        amount: 1500000,
        duration: 12,
        status: "pending",
        score: 750,
        monthlyPayment: 130000,
        createdAt: new Date(),
        updatedAt: new Date(),
      },
    ];

    const creditResult = await db.collection("credit_applications").insertMany(creditApplications);
    console.log(`✅ Inséré ${creditResult.insertedCount} demandes de crédit`);

    // 5. Insert a payment linked to the credit application
    const payments = [
      {
        applicationId: creditResult.insertedIds[0], // ObjectId
        amount: 130000,
        paymentDate: new Date(),
        createdAt: new Date(),
      },
    ];

    const paymentsResult = await db.collection("payments").insertMany(payments);
    console.log(` Inséré ${paymentsResult.insertedCount} paiements`);

  } catch (err) {
    console.error(" Erreur pendant l'insertion des données :", err);
  } finally {
    await client.close();
  }
}

seedData();
