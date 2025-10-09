"""
Modèle de scoring Random Forest utilisant les données PostgreSQL
"""
import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, confusion_matrix
import joblib
import logging
from datetime import datetime
from typing import Dict, List, Optional
import psycopg2
from psycopg2.extras import RealDictCursor
import os

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class PostgresCreditScoringModel:
    """
    Modèle Random Forest entraîné sur les données réelles de PostgreSQL
    """
    
    def __init__(self, db_config: Dict):
        self.db_config = db_config
        self.model = None
        self.scaler = StandardScaler()
        self.model_path = 'models/rf_model_postgres.pkl'
        self.scaler_path = 'models/scaler_postgres.pkl'
        
        # Créer le dossier models s'il n'existe pas
        os.makedirs('models', exist_ok=True)
        
        # Charger ou entraîner le modèle
        if not self.load_model():
            logger.info("🤖 Aucun modèle trouvé, entraînement sur les données PostgreSQL...")
            self.train_model_from_database()
        
        self.risk_thresholds = {
            'tres_bas': 8.0,
            'bas': 7.0,
            'moyen': 5.0,
            'eleve': 3.0
        }
    
    def get_db_connection(self):
        """Connexion à PostgreSQL"""
        return psycopg2.connect(**self.db_config)
    
    # ==========================================
    # ENTRAÎNEMENT DU MODÈLE SUR DONNÉES RÉELLES
    # ==========================================
    
    def train_model_from_database(self) -> bool:
        """
        Entraîne le modèle Random Forest sur les données de la base PostgreSQL
        """
        try:
            logger.info("📊 Extraction des données depuis PostgreSQL...")
            
            with self.get_db_connection() as conn:
                # Requête complète pour récupérer toutes les données nécessaires
                query = """
                    WITH payment_stats AS (
                        SELECT 
                            utilisateur_id,
                            COUNT(*) as total_paiements,
                            COUNT(CASE WHEN type_paiement = 'a_temps' THEN 1 END) as paiements_a_temps,
                            COUNT(CASE WHEN type_paiement = 'en_retard' THEN 1 END) as paiements_en_retard,
                            COUNT(CASE WHEN type_paiement = 'manque' THEN 1 END) as paiements_manques,
                            AVG(jours_retard) as moyenne_jours_retard,
                            MAX(date_paiement) as dernier_paiement
                        FROM historique_paiements
                        GROUP BY utilisateur_id
                    )
                    SELECT 
                        u.id as utilisateur_id,
                        u.revenu_mensuel,
                        u.anciennete_mois,
                        u.charges_mensuelles,
                        u.dettes_existantes,
                        u.score_credit,
                        
                        -- Encodage statut emploi
                        CASE 
                            WHEN u.statut_emploi IN ('cdi', 'fonctionnaire') THEN 3
                            WHEN u.statut_emploi = 'cdd' THEN 2
                            WHEN u.statut_emploi = 'independant' THEN 1
                            ELSE 0
                        END as statut_emploi_encoded,
                        
                        -- Restrictions
                        COALESCE(r.credits_actifs_count, 0) as credits_actifs_count,
                        COALESCE(r.ratio_endettement, 0) as ratio_endettement,
                        
                        -- Statistiques de paiement
                        COALESCE(ps.total_paiements, 0) as total_paiements,
                        COALESCE(ps.paiements_a_temps, 0) as paiements_a_temps,
                        COALESCE(ps.paiements_en_retard, 0) as paiements_en_retard,
                        COALESCE(ps.paiements_manques, 0) as paiements_manques,
                        COALESCE(ps.moyenne_jours_retard, 0) as moyenne_jours_retard,
                        
                        -- Label cible : bon client si score >= 7 ET bon historique paiements
                        CASE 
                            WHEN u.score_credit >= 7 
                                AND COALESCE(ps.paiements_a_temps::FLOAT / NULLIF(ps.total_paiements, 0), 0) >= 0.8
                            THEN 1 
                            ELSE 0 
                        END as bon_client
                        
                    FROM utilisateurs u
                    LEFT JOIN restrictions_credit r ON u.id = r.utilisateur_id
                    LEFT JOIN payment_stats ps ON u.id = ps.utilisateur_id
                    WHERE u.statut = 'actif'
                    AND u.revenu_mensuel > 0
                """
                
                df = pd.read_sql(query, conn)
            
            logger.info(f"✅ {len(df)} utilisateurs récupérés")
            
            if len(df) < 30:
                logger.warning(f"⚠️ Pas assez de données ({len(df)} < 30), utilisation règles métier")
                return False
            
            # Afficher la distribution des classes
            class_dist = df['bon_client'].value_counts()
            logger.info(f"📊 Distribution: Bons clients={class_dist.get(1, 0)}, Mauvais={class_dist.get(0, 0)}")
            
            # Préparer les features
            feature_columns = [
                'revenu_mensuel', 'anciennete_mois', 'charges_mensuelles',
                'dettes_existantes', 'statut_emploi_encoded', 'credits_actifs_count',
                'ratio_endettement', 'total_paiements', 'paiements_a_temps',
                'paiements_en_retard', 'paiements_manques', 'moyenne_jours_retard'
            ]
            
            # Ajouter features calculées
            df['debt_to_income'] = (df['charges_mensuelles'] + df['dettes_existantes']) / df['revenu_mensuel'].replace(0, 1)
            df['capacity_ratio'] = np.maximum(0, (df['revenu_mensuel'] - df['charges_mensuelles'] - df['dettes_existantes']) / df['revenu_mensuel'].replace(0, 1))
            df['ratio_paiements_temps'] = df['paiements_a_temps'] / df['total_paiements'].replace(0, 1)
            
            feature_columns.extend(['debt_to_income', 'capacity_ratio', 'ratio_paiements_temps'])
            
            X = df[feature_columns].fillna(0).values
            y = df['bon_client'].values
            
            # Vérifier qu'on a les deux classes
            if len(np.unique(y)) < 2:
                logger.warning("⚠️ Une seule classe présente, utilisation règles métier")
                return False
            
            # Split train/test
            X_train, X_test, y_train, y_test = train_test_split(
                X, y, test_size=0.2, random_state=42, stratify=y
            )
            
            # Normalisation
            logger.info("📐 Normalisation des données...")
            X_train_scaled = self.scaler.fit_transform(X_train)
            X_test_scaled = self.scaler.transform(X_test)
            
            # Entraînement Random Forest
            logger.info("🌲 Entraînement du Random Forest...")
            self.model = RandomForestClassifier(
                n_estimators=100,
                max_depth=12,
                min_samples_split=5,
                min_samples_leaf=2,
                max_features='sqrt',
                random_state=42,
                class_weight='balanced',  # Important pour classes déséquilibrées
                n_jobs=-1
            )
            
            self.model.fit(X_train_scaled, y_train)
            
            # Évaluation
            train_score = self.model.score(X_train_scaled, y_train)
            test_score = self.model.score(X_test_scaled, y_test)
            
            logger.info(f"📈 Précision train: {train_score:.3f}")
            logger.info(f"📈 Précision test: {test_score:.3f}")
            
            # Prédictions sur test
            y_pred = self.model.predict(X_test_scaled)
            
            logger.info("\n📊 Classification Report:")
            logger.info("\n" + classification_report(y_test, y_pred, 
                                                     target_names=['Mauvais', 'Bon']))
            
            # Feature importance
            logger.info("\n🔍 Importance des features:")
            feature_names = feature_columns
            importances = self.model.feature_importances_
            
            # Trier par importance
            indices = np.argsort(importances)[::-1]
            for i in range(min(10, len(feature_names))):
                idx = indices[i]
                logger.info(f"  {i+1}. {feature_names[idx]}: {importances[idx]:.4f}")
            
            # Sauvegarder
            self.save_model()
            
            logger.info("\n✅ Modèle Random Forest entraîné et sauvegardé avec succès!")
            return True
            
        except Exception as e:
            logger.error(f"❌ Erreur lors de l'entraînement: {e}")
            import traceback
            traceback.print_exc()
            return False
    
    def save_model(self):
        """Sauvegarde le modèle et le scaler"""
        try:
            joblib.dump(self.model, self.model_path)
            joblib.dump(self.scaler, self.scaler_path)
            logger.info(f"💾 Modèle sauvegardé: {self.model_path}")
        except Exception as e:
            logger.error(f"Erreur sauvegarde modèle: {e}")
    
    def load_model(self) -> bool:
        """Charge le modèle sauvegardé"""
        try:
            if os.path.exists(self.model_path) and os.path.exists(self.scaler_path):
                self.model = joblib.load(self.model_path)
                self.scaler = joblib.load(self.scaler_path)
                logger.info("✅ Modèle Random Forest chargé depuis le fichier")
                return True
            return False
        except Exception as e:
            logger.error(f"Erreur chargement modèle: {e}")
            return False
    
    # ==========================================
    # CALCUL DU SCORE AVEC LE MODÈLE
    # ==========================================
    
    def calculate_comprehensive_score(self, user_id: int) -> Dict:
        """
        Calcule le score complet d'un utilisateur
        """
        # Récupérer toutes les données de l'utilisateur
        user_data = self._get_user_complete_data(user_id)
        
        if not user_data:
            raise ValueError(f"Utilisateur {user_id} introuvable")
        
        # Calculer le score ML
        if self.model is not None:
            ml_score = self._calculate_ml_score(user_data)
            model_type = 'random_forest'
            confidence = 0.85
        else:
            ml_score = self._calculate_rule_based_score(user_data)
            model_type = 'rule_based'
            confidence = 0.70
        
        # Normaliser entre 0 et 10
        final_score = max(0, min(10, ml_score))
        score_850 = int(300 + (final_score / 10) * 550)
        
        # Déterminer le risque
        risk_level = self._determine_risk_level(final_score)
        
        # Calculer le montant éligible
        eligible_amount = self._calculate_eligible_amount(
            final_score, 
            user_data['revenu_mensuel'],
            user_data['ratio_endettement']
        )
        
        # Générer les recommandations
        recommendations = self._generate_recommendations(final_score, user_data)
        
        return {
            'score': round(final_score, 1),
            'score_850': score_850,
            'niveau_risque': risk_level,
            'montant_eligible': eligible_amount,
            'model_type': model_type,
            'model_confidence': confidence,
            'details': {
                'payment_reliability': user_data.get('reliability', 'N/A'),
                'on_time_ratio': user_data.get('ratio_paiements_temps', 0) * 100,
                'total_payments': user_data.get('total_paiements', 0),
                'avg_delay_days': user_data.get('moyenne_jours_retard', 0),
                'debt_ratio': user_data.get('ratio_endettement', 0),
                'active_credits': user_data.get('credits_actifs_count', 0)
            },
            'recommendations': recommendations
        }
    
    def _get_user_complete_data(self, user_id: int) -> Optional[Dict]:
        """Récupère toutes les données d'un utilisateur"""
        
        with self.get_db_connection() as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute("""
                    WITH payment_stats AS (
                        SELECT 
                            utilisateur_id,
                            COUNT(*) as total_paiements,
                            COUNT(CASE WHEN type_paiement = 'a_temps' THEN 1 END) as paiements_a_temps,
                            COUNT(CASE WHEN type_paiement = 'en_retard' THEN 1 END) as paiements_en_retard,
                            COUNT(CASE WHEN type_paiement = 'manque' THEN 1 END) as paiements_manques,
                            AVG(jours_retard) as moyenne_jours_retard
                        FROM historique_paiements
                        WHERE utilisateur_id = %s
                        GROUP BY utilisateur_id
                    )
                    SELECT 
                        u.*,
                        COALESCE(r.credits_actifs_count, 0) as credits_actifs_count,
                        COALESCE(r.ratio_endettement, 0) as ratio_endettement,
                        COALESCE(r.dette_totale_active, 0) as dette_totale_active,
                        COALESCE(ps.total_paiements, 0) as total_paiements,
                        COALESCE(ps.paiements_a_temps, 0) as paiements_a_temps,
                        COALESCE(ps.paiements_en_retard, 0) as paiements_en_retard,
                        COALESCE(ps.paiements_manques, 0) as paiements_manques,
                        COALESCE(ps.moyenne_jours_retard, 0) as moyenne_jours_retard
                    FROM utilisateurs u
                    LEFT JOIN restrictions_credit r ON u.id = r.utilisateur_id
                    LEFT JOIN payment_stats ps ON u.id = ps.utilisateur_id
                    WHERE u.id = %s
                """, (user_id, user_id))
                
                result = cur.fetchone()
                
                if not result:
                    return None
                
                data = dict(result)
                
                # Calculer les features supplémentaires
                revenu = float(data.get('revenu_mensuel', 0))
                charges = float(data.get('charges_mensuelles', 0))
                dettes = float(data.get('dettes_existantes', 0))
                total_p = float(data.get('total_paiements', 0))
                
                data['debt_to_income'] = (charges + dettes) / max(revenu, 1)
                data['capacity_ratio'] = max(0, (revenu - charges - dettes) / max(revenu, 1))
                data['ratio_paiements_temps'] = data['paiements_a_temps'] / max(total_p, 1)
                
                # Déterminer la fiabilité
                if total_p == 0:
                    data['reliability'] = 'nouveau_client'
                elif data['ratio_paiements_temps'] >= 0.95:
                    data['reliability'] = 'excellent'
                elif data['ratio_paiements_temps'] >= 0.85:
                    data['reliability'] = 'tres_bon'
                elif data['ratio_paiements_temps'] >= 0.70:
                    data['reliability'] = 'bon'
                else:
                    data['reliability'] = 'moyen'
                
                return data
    
    def _calculate_ml_score(self, user_data: Dict) -> float:
        """Calcul du score avec Random Forest"""
        try:
            # Préparer les features
            employment_map = {
                'cdi': 3,
                'fonctionnaire': 3,
                'cdd': 2,
                'independant': 1,
                'autre': 0
            }
            
            features = [
                user_data.get('revenu_mensuel', 0),
                user_data.get('anciennete_mois', 0),
                user_data.get('charges_mensuelles', 0),
                user_data.get('dettes_existantes', 0),
                employment_map.get(user_data.get('statut_emploi', 'autre'), 0),
                user_data.get('credits_actifs_count', 0),
                user_data.get('ratio_endettement', 0),
                user_data.get('total_paiements', 0),
                user_data.get('paiements_a_temps', 0),
                user_data.get('paiements_en_retard', 0),
                user_data.get('paiements_manques', 0),
                user_data.get('moyenne_jours_retard', 0),
                user_data.get('debt_to_income', 0),
                user_data.get('capacity_ratio', 0),
                user_data.get('ratio_paiements_temps', 0)
            ]
            
            X = np.array([features])
            X_scaled = self.scaler.transform(X)
            
            # Prédiction
            proba = self.model.predict_proba(X_scaled)[0]
            
            # Convertir en score 0-10
            # proba[1] = probabilité d'être un bon client
            score = 3.0 + (proba[1] * 7.0)  # Score entre 3 et 10
            
            return score
            
        except Exception as e:
            logger.error(f"Erreur ML scoring: {e}")
            return self._calculate_rule_based_score(user_data)
    
    def _calculate_rule_based_score(self, user_data: Dict) -> float:
        """Score basé sur règles métier (fallback)"""
        score = 5.0
        
        # Score de revenu
        revenu = float(user_data.get('revenu_mensuel', 0))
        if revenu >= 1500000:
            score += 2.0
        elif revenu >= 1000000:
            score += 1.5
        elif revenu >= 500000:
            score += 1.0
        elif revenu < 300000:
            score -= 1.0
        
        # Score d'emploi
        statut = user_data.get('statut_emploi', 'autre')
        if statut in ['cdi', 'fonctionnaire']:
            score += 1.5
        elif statut == 'cdd':
            score += 0.5
        
        # Score d'ancienneté
        anciennete = float(user_data.get('anciennete_mois', 0))
        if anciennete >= 60:
            score += 1.0
        elif anciennete >= 24:
            score += 0.5
        elif anciennete < 12:
            score -= 0.5
        
        # Score de paiements
        ratio_temps = user_data.get('ratio_paiements_temps', 0)
        score += ratio_temps * 2.0  # +2 max
        
        # Pénalité endettement
        ratio_dette = float(user_data.get('ratio_endettement', 0))
        if ratio_dette > 70:
            score -= 3.0
        elif ratio_dette > 50:
            score -= 1.5
        elif ratio_dette <= 30:
            score += 1.0
        
        # Pénalité crédits multiples
        credits_actifs = int(user_data.get('credits_actifs_count', 0))
        if credits_actifs >= 2:
            score -= 1.5
        elif credits_actifs == 0:
            score += 0.5
        
        return max(0, min(10, score))
    
    def _determine_risk_level(self, score: float) -> str:
        """Détermine le niveau de risque"""
        if score >= 8.0:
            return 'tres_bas'
        elif score >= 7.0:
            return 'bas'
        elif score >= 5.0:
            return 'moyen'
        elif score >= 3.0:
            return 'eleve'
        else:
            return 'tres_eleve'
    
    def _calculate_eligible_amount(self, score: float, revenu: float, ratio_dette: float) -> int:
        """Calcule le montant éligible"""
        if score < 4:
            return 0
        
        # Base sur le revenu
        if score >= 8:
            multiplier = 0.8
        elif score >= 7:
            multiplier = 0.6
        elif score >= 6:
            multiplier = 0.5
        elif score >= 5:
            multiplier = 0.4
        else:
            multiplier = 0.3
        
        montant = int(revenu * multiplier)
        
        # Réduire si endettement élevé
        if ratio_dette > 50:
            montant = int(montant * 0.5)
        elif ratio_dette > 70:
            montant = int(montant * 0.3)
        
        # Plafond
        return min(montant, 2000000)
    
    def _generate_recommendations(self, score: float, user_data: Dict) -> List[str]:
        """Génère des recommandations personnalisées"""
        recommendations = []
        
        # Recommandations sur les paiements
        ratio_temps = user_data.get('ratio_paiements_temps', 0) * 100
        if ratio_temps < 80:
            recommendations.append("Améliorez votre taux de paiements à temps pour augmenter votre score")
        
        avg_delay = user_data.get('moyenne_jours_retard', 0)
        if avg_delay > 7:
            recommendations.append(f"Réduisez vos retards de paiement (moyenne actuelle: {avg_delay:.0f} jours)")
        
        # Recommandations sur l'endettement
        ratio_dette = user_data.get('ratio_endettement', 0)
        if ratio_dette > 50:
            recommendations.append(f"Votre taux d'endettement est élevé ({ratio_dette:.0f}%), remboursez vos dettes")
        
        credits_actifs = user_data.get('credits_actifs_count', 0)
        if credits_actifs >= 2:
            recommendations.append("Vous avez atteint le maximum de crédits actifs (2)")
        
        # Recommandations globales
        if score < 5:
            recommendations.append("Concentrez-vous sur les paiements à temps et la réduction des dettes")
        elif score < 7:
            recommendations.append("Continuez vos efforts, vous êtes sur la bonne voie")
        else:
            recommendations.append("Excellent profil ! Maintenez vos bonnes habitudes")
        
        return recommendations
    
    # ==========================================
    # MÉTHODES EXISTANTES (conservées)
    # ==========================================
    
    def get_or_calculate_score(self, user_id: int, force_recalculate: bool = False) -> Dict:
        """Récupère ou calcule le score"""
        if not force_recalculate:
            existing_score = self.get_user_score_from_db(user_id)
            if existing_score:
                return existing_score
        
        # Recalculer
        new_score = self.calculate_comprehensive_score(user_id)
        self.update_user_score_in_db(user_id, new_score)
        
        return new_score
    
    def get_user_score_from_db(self, user_id: int) -> Optional[Dict]:
        """Récupère le score depuis la DB"""
        with self.get_db_connection() as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute("""
                    SELECT 
                        id,
                        score_credit,
                        score_850,
                        niveau_risque,
                        montant_eligible,
                        date_modification
                    FROM utilisateurs
                    WHERE id = %s
                """, (user_id,))
                
                result = cur.fetchone()
                return dict(result) if result else None
    
    def update_user_score_in_db(self, user_id: int, score_data: Dict) -> bool:
        """Met à jour le score dans la DB"""
        try:
            with self.get_db_connection() as conn:
                with conn.cursor() as cur:
                    cur.execute("""
                        UPDATE utilisateurs
                        SET 
                            score_credit = %s,
                            score_850 = %s,
                            niveau_risque = %s,
                            montant_eligible = %s,
                            date_modification = NOW()
                        WHERE id = %s
                    """, (
                        score_data['score'],
                        score_data['score_850'],
                        score_data['niveau_risque'],
                        score_data['montant_eligible'],
                        user_id
                    ))
                    
                    # Historique
                    cur.execute("""
                        INSERT INTO historique_scores (
                            utilisateur_id,
                            score_credit,
                            score_850,
                            niveau_risque,
                            montant_eligible,
                            evenement_declencheur,
                            date_calcul
                        ) VALUES (%s, %s, %s, %s, %s, %s, NOW())
                    """, (
                        user_id,
                        score_data['score'],
                        score_data['score_850'],
                        score_data['niveau_risque'],
                        score_data['montant_eligible'],
                        'Calcul automatique ML'
                    ))
                    
                    conn.commit()
                    return True
        except Exception as e:
            logger.error(f"Erreur mise à jour score: {e}")
            return False
    
    def check_eligibility(self, user_id: int) -> Dict:
        """Vérifie l'éligibilité"""
        with self.get_db_connection() as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute("""
                    SELECT 
                        r.peut_emprunter,
                        r.credits_actifs_count,
                        r.raison_blocage,
                        u.score_credit,
                        u.montant_eligible
                    FROM restrictions_credit r
                    JOIN utilisateurs u ON r.utilisateur_id = u.id
                    WHERE r.utilisateur_id = %s
                """, (user_id,))
                
                result = cur.fetchone()
                
                if not result:
                    return {
                        'eligible': False,
                        'raison': 'Profil incomplet'
                    }
                
                eligibility = dict(result)
                
                if not eligibility['peut_emprunter']:
                    return {
                        'eligible': False,
                        'raison': eligibility.get('raison_blocage', 'Non éligible')
                    }
                
                if eligibility['score_credit'] < 5.0:
                    return {
                        'eligible': False,
                        'raison': 'Score de crédit insuffisant'
                    }
                
                return {
                    'eligible': True,
                    'montant_eligible': eligibility['montant_eligible'],
                    'score': eligibility['score_credit']
                }