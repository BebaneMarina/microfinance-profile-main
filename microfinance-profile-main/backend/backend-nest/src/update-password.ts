import { NestFactory } from '@nestjs/core';
import { AppModule } from '../src/app.module';
import { DataSource } from 'typeorm';
import * as bcrypt from 'bcrypt';

async function updatePasswords() {
  console.log('🔄 Updating user passwords...\n');
  
  const app = await NestFactory.createApplicationContext(AppModule);
  const dataSource = app.get(DataSource);

  try {
    // Générer les nouveaux hashs
    const marina123Hash = await bcrypt.hash('marina123', 10);
    const agent123Hash = await bcrypt.hash('agent123', 10);
    const admin123Hash = await bcrypt.hash('admin123', 10);

    console.log('📝 Generated hashes:');
    console.log(`marina123: ${marina123Hash}`);
    console.log(`agent123: ${agent123Hash}`);
    console.log(`admin123: ${admin123Hash}\n`);

    // Mettre à jour directement dans la base de données
    await dataSource.query(
      `UPDATE users SET password_hash = $1 WHERE email = $2`,
      [marina123Hash, 'marina@email.com']
    );
    console.log('✅ Updated password for marina@email.com');

    await dataSource.query(
      `UPDATE users SET password_hash = $1 WHERE email = $2`,
      [agent123Hash, 'agent@bamboo.ci']
    );
    console.log('✅ Updated password for agent@bamboo.ci');

    await dataSource.query(
      `UPDATE users SET password_hash = $1 WHERE email = $2`,
      [admin123Hash, 'admin@bamboo.ci']
    );
    console.log('✅ Updated password for admin@bamboo.ci');

    console.log('\n✨ All passwords updated successfully!');
    
    // Vérifier les mises à jour
    console.log('\n🔍 Verifying updates...');
    const users = await dataSource.query(`
      SELECT email, password_hash 
      FROM users 
      WHERE email IN ('marina@email.com', 'agent@bamboo.ci', 'admin@bamboo.ci')
    `);
    
    for (const user of users) {
      console.log(`\n${user.email}:`);
      console.log(`Hash: ${user.password_hash.substring(0, 30)}...`);
      
      // Tester le mot de passe
      let password = '';
      if (user.email === 'marina@email.com') password = 'marina123';
      else if (user.email === 'agent@bamboo.ci') password = 'agent123';
      else if (user.email === 'admin@bamboo.ci') password = 'admin123';
      
      const isValid = await bcrypt.compare(password, user.password_hash);
      console.log(`Password "${password}" is ${isValid ? '✅ VALID' : '❌ INVALID'}`);
    }

  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    await app.close();
  }
}

updatePasswords();