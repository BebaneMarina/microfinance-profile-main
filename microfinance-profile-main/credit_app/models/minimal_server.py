#!/usr/bin/env python3
"""
Script de démarrage simplifié pour l'API Bamboo EMF
Résout automatiquement les problèmes de port et de dépendances
"""

import subprocess
import sys
import os
import time
import socket
from pathlib import Path

def check_port_available(port):
    """Vérifie si un port est disponible"""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.bind(('localhost', port))
            return True
    except OSError:
        return False

def kill_process_on_port(port):
    """Tue le processus utilisant un port spécifique"""
    try:
        if os.name == 'nt':  # Windows
            result = subprocess.run(['netstat', '-ano'], capture_output=True, text=True)
            lines = result.stdout.split('\n')
            for line in lines:
                if f':{port}' in line and 'LISTENING' in line:
                    parts = line.split()
                    if len(parts) >= 5:
                        pid = parts[-1]
                        print(f"🔧 Arrêt du processus {pid} sur le port {port}")
                        subprocess.run(['taskkill', '/F', '/PID', pid], capture_output=True)
                        time.sleep(2)
                        break
        else:  # Linux/Mac
            result = subprocess.run(['lsof', '-i', f':{port}'], capture_output=True, text=True)
            lines = result.stdout.split('\n')
            for line in lines[1:]:  # Skip header
                if line.strip():
                    parts = line.split()
                    if len(parts) >= 2:
                        pid = parts[1]
                        print(f"🔧 Arrêt du processus {pid} sur le port {port}")
                        subprocess.run(['kill', '-9', pid], capture_output=True)
                        time.sleep(2)
                        break
    except Exception as e:
        print(f"⚠️ Impossible d'arrêter le processus sur le port {port}: {e}")

def install_dependencies():
    """Installe les dépendances Python nécessaires"""
    dependencies = [
        'flask',
        'flask-cors', 
        'numpy',
        'pandas',
        'scikit-learn',
        'requests'
    ]
    
    print("📦 Vérification et installation des dépendances...")
    
    for dep in dependencies:
        try:
            __import__(dep.replace('-', '_'))
            print(f"   ✅ {dep} déjà installé")
        except ImportError:
            print(f"   📥 Installation de {dep}...")
            try:
                subprocess.check_call([sys.executable, '-m', 'pip', 'install', dep])
                print(f"   ✅ {dep} installé avec succès")
            except subprocess.CalledProcessError as e:
                print(f"   ❌ Erreur installation {dep}: {e}")
                return False
    
    return True

def check_files_exist():
    """Vérifie que les fichiers nécessaires existent"""
    required_files = ['app.py', 'scoring_model.py']
    missing_files = []
    
    for file in required_files:
        if not Path(file).exists():
            missing_files.append(file)
    
    if missing_files:
        print(f"❌ Fichiers manquants: {', '.join(missing_files)}")
        print("💡 Assurez-vous d'avoir les fichiers app.py et scoring_model.py dans le dossier courant")
        return False
    
    print("✅ Tous les fichiers requis sont présents")
    return True

def start_flask_server():
    """Démarre le serveur Flask"""
    print("🚀 Démarrage du serveur Flask...")
    
    # Variables d'environnement pour Flask
    env = os.environ.copy()
    env['FLASK_APP'] = 'app.py'
    env['FLASK_ENV'] = 'development'
    env['FLASK_DEBUG'] = '1'
    
    try:
        # Démarrer le serveur
        process = subprocess.Popen([
            sys.executable, 'app.py'
        ], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
        
        print("⏳ Attente du démarrage du serveur...")
        time.sleep(3)
        
        # Vérifier si le serveur fonctionne
        if process.poll() is None:  # Processus toujours en cours
            print("✅ Serveur Flask démarré avec succès!")
            print("🌐 URL: http://localhost:5000")
            print("🔗 API accessible pour Angular sur http://localhost:4200")
            print("\n📋 Endpoints disponibles:")
            print("   • GET  / - Informations de l'API")
            print("   • GET  /health - Vérification santé")
            print("   • POST /client-scoring - Scoring client")
            print("   • POST /eligible-amount - Montant éligible")
            print("   • GET  /test - Test de connectivité")
            print("\n💡 Pour arrêter le serveur: Ctrl+C")
            print("="*50)
            
            # Afficher les logs en temps réel
            try:
                for line in process.stdout:
                    print(line.strip())
            except KeyboardInterrupt:
                print("\n🛑 Arrêt du serveur demandé...")
                process.terminate()
                process.wait()
                print("✅ Serveur arrêté")
                
        else:
            print("❌ Le serveur n'a pas pu démarrer")
            # Afficher les erreurs
            stdout, stderr = process.communicate()
            if stdout:
                print("Sortie:", stdout)
            return False
            
    except Exception as e:
        print(f"❌ Erreur lors du démarrage: {e}")
        return False
    
    return True

def main():
    """Fonction principale"""
    print("🚀 DÉMARRAGE AUTOMATIQUE DU SERVEUR BAMBOO EMF")
    print("="*50)
    
    # 1. Vérifier les fichiers
    if not check_files_exist():
        return False
    
    # 2. Installer les dépendances
    if not install_dependencies():
        print("❌ Erreur lors de l'installation des dépendances")
        return False
    
    # 3. Vérifier/libérer le port 5000
    port = 5000
    if not check_port_available(port):
        print(f"⚠️ Le port {port} est occupé")
        kill_process_on_port(port)
        time.sleep(2)
        
        if not check_port_available(port):
            print(f"❌ Impossible de libérer le port {port}")
            print("💡 Essayez de redémarrer votre ordinateur ou utilisez un autre port")
            return False
    
    print(f"✅ Port {port} disponible")
    
    # 4. Démarrer le serveur
    return start_flask_server()

if __name__ == "__main__":
    try:
        success = main()
        if not success:
            print("\n❌ Le serveur n'a pas pu démarrer correctement")
            print("💡 Vérifiez les messages d'erreur ci-dessus")
            print("💡 Vous pouvez aussi essayer de démarrer manuellement: python app.py")
    except KeyboardInterrupt:
        print("\n🛑 Arrêt demandé par l'utilisateur")
    except Exception as e:
        print(f"\n❌ Erreur inattendue: {e}")
    
    input("\n📝 Appuyez sur Entrée pour fermer...")