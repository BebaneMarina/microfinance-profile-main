import * as bcrypt from 'bcrypt';

async function findPassword() {
  const hash = '$2b$10$FGdP8.kFYU3K3T2Q0Xd5AuFzZoY6DZU5dXV.N5yW6L5nQ5TQEjH3a';
  
  // Liste des mots de passe possibles à tester
  const possiblePasswords = [
    'password',
    'password123',
    'admin',
    'admin123',
    'agent',
    'agent123',
    'marina',
    'marina123',
    '123456',
    'bamboo',
    'bamboo123',
    'test',
    'test123',
    'demo',
    'demo123'
  ];

  console.log('🔍 Testing passwords against hash...\n');
  console.log(`Hash: ${hash}\n`);

  for (const password of possiblePasswords) {
    const isMatch = await bcrypt.compare(password, hash);
    if (isMatch) {
      console.log(`✅ FOUND! Password is: "${password}"`);
      return password;
    } else {
      console.log(`❌ Not: ${password}`);
    }
  }
  
  console.log('\n😞 Password not found in common passwords list');
}

findPassword();