// Script pour créer les utilisateurs de démonstration
import * as bcrypt from 'bcrypt';

async function seedUsers() {
  const users = [
    {
      nomutilisateur: 'marina Brunelle',
      email: 'marinabrunelle@email.com',
      motdepasse: await bcrypt.hash('demo123', 10),
      role: 'client',
    },
    {
      nomutilisateur: 'Agent Dupont',
      email: 'agent@bamboo.ci',
      motdepasse: await bcrypt.hash('agent123', 10),
      role: 'agent',
    },
    {
      nomutilisateur: 'Admin System',
      email: 'admin@bamboo.ci',
      motdepasse: await bcrypt.hash('admin123', 10),
      role: 'admin',
    },
  ];

  console.log('Users to insert:', users);
  // Utilisez ces données pour insérer dans votre base de données
}

seedUsers();