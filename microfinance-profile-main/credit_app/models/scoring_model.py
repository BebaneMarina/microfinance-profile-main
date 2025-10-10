"""
Modele de scoring Random Forest avec recalcul automatique et notifications
"""
import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split
import joblib
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional
import psycopg2
from psycopg2.extras import RealDictCursor
from decimal import Decimal
import os

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class PostgresCreditScoringModel:
    """
    Modele Random Forest avec recalcul automatique
    """
    
    def __init__(self, db_config: Dict):
        self.db_config = db_config
        self.model = None
        self.scaler = StandardScaler()
        self.model_path = 'models/rf_model_postgres.pkl'
        self.scaler_path = 'models/scaler_postgres.pkl'
        
        os.makedirs('models', exist_ok=True)
        
        # Liste des features EXACTES utilisees pour l'entrainement
        self.feature_columns = [
            'revenu_mensuel', 'anciennete_mois', 'charges_mensuelles',
            'dettes_existantes', 'statut_emploi_encoded', 'credits_actifs_count',
            'ratio_endettement', 'total_paiements', 'paiements_a_temps',
            'paiements_en_retard', 'paiements_manques', 'moyenne_jours_retard',
            'debt_to_income', 'capacity_ratio', 'ratio_paiements_temps'
        ]
        
        if not self.load_model():
            logger.info("Entrainement du modele sur les donnees PostgreSQL...")
            self.train_model_from_database()
        
        self.risk_thresholds = {
            'tres_bas': 8.0,
            'bas': 7.0,
            'moyen': 5.0,
            'eleve': 3.0
        }
    
    def get_db_connection(self):
        """Connexion a PostgreSQL"""
        return psycopg2.connect(**self.db_config)
    
    # ==========================================
    # CONVERSION DECIMAL -> FLOAT
    # ==========================================
    
    def _convert_to_float(self, value) -> float:
        """Convertit Decimal ou autre type en float"""
        if isinstance(value, Decimal):
            return float(value)
        if value is None:
            return 0.0
        return float(value)
    
    # ==========================================
    # RECALCUL AUTOMATIQUE AU LOGIN
    # ==========================================
    
    def recalculate_on_login(self, user_id: int) -> Dict:
        """
        Recalcule automatiquement le score au login du client
        """
        try:
            logger.info(f"Recalcul automatique au login pour user {user_id}")
            
            # Verifier si besoin de recalculer
            needs_recalc = self._check_if_needs_recalculation(user_id)
            
            if needs_recalc:
                logger.info(f"Recalcul necessaire pour user {user_id}")
                
                # Recalculer le score
                new_score = self.calculate_comprehensive_score(user_id)
                
                # Mettre a jour en base
                self.update_user_score_in_db(user_id, new_score)
                
                # Creer notification si changement significatif
                self._create_score_change_notification(user_id, new_score)
                
                return new_score
            else:
                logger.info(f"Score recent, pas de recalcul pour user {user_id}")
                return self.get_user_score_from_db(user_id)
                
        except Exception as e:
            logger.error(f"Erreur recalcul login: {e}")
            return self.get_user_score_from_db(user_id)
    
    def _check_if_needs_recalculation(self, user_id: int) -> bool:
        """Verifie si le score doit etre recalcule"""
        with self.get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT 
                        date_modification,
                        EXTRACT(EPOCH FROM (NOW() - date_modification))/3600 as hours_since_update
                    FROM utilisateurs
                    WHERE id = %s
                """, (user_id,))
                
                result = cur.fetchone()
                
                if not result:
                    return True
                
                hours_since_update = result[1]
                
                # Recalculer si derniere mise a jour > 1 heure
                return hours_since_update > 1
    
    def _create_score_change_notification(self, user_id: int, new_score_data: Dict):
        """Cree une notification en cas de changement significatif"""
        try:
            with self.get_db_connection() as conn:
                with conn.cursor() as cur:
                    # Recuperer ancien score
                    cur.execute("""
                        SELECT score_credit 
                        FROM historique_scores 
                        WHERE utilisateur_id = %s 
                        ORDER BY date_calcul DESC 
                        LIMIT 1 OFFSET 1
                    """, (user_id,))
                    
                    old_score_row = cur.fetchone()
                    old_score = self._convert_to_float(old_score_row[0]) if old_score_row else 0
                    new_score = self._convert_to_float(new_score_data['score'])
                    
                    score_diff = new_score - old_score
                    
                    # Ne creer notification que si changement >= 0.5
                    if abs(score_diff) >= 0.5:
                        notification_type = 'score_improvement' if score_diff > 0 else 'score_decline'
                        
                        message = self._generate_notification_message(
                            old_score, 
                            new_score, 
                            score_diff,
                            new_score_data
                        )
                        
                        # Inserer notification
                        cur.execute("""
                            INSERT INTO notifications (
                                utilisateur_id,
                                type,
                                titre,
                                message,
                                lu,
                                date_creation
                            ) VALUES (%s, %s, %s, %s, FALSE, NOW())
                        """, (
                            user_id,
                            notification_type,
                            'Votre score a change',
                            message
                        ))
                        
                        conn.commit()
                        logger.info(f"Notification creee pour user {user_id}: {score_diff:+.1f}")
                        
        except Exception as e:
            logger.error(f"Erreur creation notification: {e}")
    
    def _generate_notification_message(self, old_score: float, new_score: float, 
                                       diff: float, score_data: Dict) -> str:
        """Genere le message de notification"""
        montant = self._convert_to_float(score_data['montant_eligible'])
        
        if diff > 0:
            message = f"Bonne nouvelle ! Votre score est passe de {old_score:.1f} a {new_score:.1f} ({diff:+.1f}). "
            message += f"Votre nouveau montant eligible est de {montant:,.0f} FCFA."
        else:
            message = f"Votre score est passe de {old_score:.1f} a {new_score:.1f} ({diff:.1f}). "
            message += "Effectuez vos paiements a temps pour ameliorer votre score."
        
        if score_data.get('recommendations'):
            message += f" Conseil: {score_data['recommendations'][0]}"
        
        return message
    
    # ==========================================
    # ENTRAINEMENT DU MODELE
    # ==========================================
    
    def train_model_from_database(self) -> bool:
        """
        Entraine le modele Random Forest sur les donnees PostgreSQL
        """
        try:
            logger.info("Extraction des donnees depuis PostgreSQL...")
            
            with self.get_db_connection() as conn:
                query = """
                    WITH payment_stats AS (
                        SELECT 
                            utilisateur_id,
                            COUNT(*) as total_paiements,
                            COUNT(CASE WHEN type_paiement = 'a_temps' THEN 1 END) as paiements_a_temps,
                            COUNT(CASE WHEN type_paiement = 'en_retard' THEN 1 END) as paiements_en_retard,
                            COUNT(CASE WHEN type_paiement = 'manque' THEN 1 END) as paiements_manques,
                            AVG(jours_retard) as moyenne_jours_retard
                        FROM historique_paiements
                        GROUP BY utilisateur_id
                    )
                    SELECT 
                        u.id as utilisateur_id,
                        u.revenu_mensuel::float,
                        u.anciennete_mois::float,
                        u.charges_mensuelles::float,
                        u.dettes_existantes::float,
                        u.score_credit::float,
                        
                        CASE 
                            WHEN u.statut_emploi IN ('cdi', 'fonctionnaire') THEN 3
                            WHEN u.statut_emploi = 'cdd' THEN 2
                            WHEN u.statut_emploi = 'independant' THEN 1
                            ELSE 0
                        END as statut_emploi_encoded,
                        
                        COALESCE(r.credits_actifs_count, 0)::float as credits_actifs_count,
                        COALESCE(r.ratio_endettement, 0)::float as ratio_endettement,
                        COALESCE(ps.total_paiements, 0)::float as total_paiements,
                        COALESCE(ps.paiements_a_temps, 0)::float as paiements_a_temps,
                        COALESCE(ps.paiements_en_retard, 0)::float as paiements_en_retard,
                        COALESCE(ps.paiements_manques, 0)::float as paiements_manques,
                        COALESCE(ps.moyenne_jours_retard, 0)::float as moyenne_jours_retard,
                        
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
            
            logger.info(f"{len(df)} utilisateurs recuperes")
            
            if len(df) < 30:
                logger.warning(f"Pas assez de donnees ({len(df)} < 30)")
                return False
            
            # Features calculees
            df['debt_to_income'] = (df['charges_mensuelles'] + df['dettes_existantes']) / df['revenu_mensuel'].replace(0, 1)
            df['capacity_ratio'] = np.maximum(0, (df['revenu_mensuel'] - df['charges_mensuelles'] - df['dettes_existantes']) / df['revenu_mensuel'].replace(0, 1))
            df['ratio_paiements_temps'] = df['paiements_a_temps'] / df['total_paiements'].replace(0, 1)
            
            # Utiliser self.feature_columns
            X = df[self.feature_columns].fillna(0).values
            y = df['bon_client'].values
            
            if len(np.unique(y)) < 2:
                logger.warning("Une seule classe presente")
                return False
            
            # Split train/test
            X_train, X_test, y_train, y_test = train_test_split(
                X, y, test_size=0.2, random_state=42, stratify=y
            )
            
            # Normalisation
            X_train_scaled = self.scaler.fit_transform(X_train)
            X_test_scaled = self.scaler.transform(X_test)
            
            # Entrainement
            logger.info("Entrainement du Random Forest...")
            self.model = RandomForestClassifier(
                n_estimators=100,
                max_depth=12,
                min_samples_split=5,
                min_samples_leaf=2,
                max_features='sqrt',
                random_state=42,
                class_weight='balanced',
                n_jobs=-1
            )
            
            self.model.fit(X_train_scaled, y_train)
            
            # Evaluation
            train_score = self.model.score(X_train_scaled, y_train)
            test_score = self.model.score(X_test_scaled, y_test)
            
            logger.info(f"Precision train: {train_score:.3f}")
            logger.info(f"Precision test: {test_score:.3f}")
            logger.info(f"Nombre de features: {len(self.feature_columns)}")
            
            # Sauvegarder
            self.save_model()
            
            logger.info("Modele Random Forest entraine avec succes")
            return True
            
        except Exception as e:
            logger.error(f"Erreur entrainement: {e}")
            import traceback
            traceback.print_exc()
            return False
    
    def save_model(self):
        """Sauvegarde le modele et le scaler"""
        try:
            joblib.dump(self.model, self.model_path)
            joblib.dump(self.scaler, self.scaler_path)
            logger.info(f"Modele sauvegarde: {self.model_path}")
        except Exception as e:
            logger.error(f"Erreur sauvegarde: {e}")
    
    def load_model(self) -> bool:
        """Charge le modele sauvegarde"""
        try:
            if os.path.exists(self.model_path) and os.path.exists(self.scaler_path):
                self.model = joblib.load(self.model_path)
                self.scaler = joblib.load(self.scaler_path)
                logger.info("Modele Random Forest charge")
                return True
            return False
        except Exception as e:
            logger.error(f"Erreur chargement: {e}")
            return False
    
    # ==========================================
    # CALCUL DU SCORE
    # ==========================================
    
    def calculate_comprehensive_score(self, user_id: int) -> Dict:
        """Calcule le score complet"""
        user_data = self._get_user_complete_data(user_id)
        
        if not user_data:
            raise ValueError(f"Utilisateur {user_id} introuvable")
        
        # Calculer score ML ou regles metier
        if self.model is not None:
            ml_score = self._calculate_ml_score(user_data)
            model_type = 'random_forest'
            confidence = 0.85
        else:
            ml_score = self._calculate_rule_based_score(user_data)
            model_type = 'rule_based'
            confidence = 0.70
        
        # Normaliser 0-10
        final_score = max(0, min(10, ml_score))
        score_850 = int(300 + (final_score / 10) * 550)
        
        # Determiner risque
        risk_level = self._determine_risk_level(final_score)
        
        # Montant eligible
        revenu = self._convert_to_float(user_data['revenu_mensuel'])
        ratio_dette = self._convert_to_float(user_data['ratio_endettement'])
        
        eligible_amount = self._calculate_eligible_amount(
            final_score, 
            revenu,
            ratio_dette
        )
        
        # Recommandations
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
                'on_time_ratio': self._convert_to_float(user_data.get('ratio_paiements_temps', 0)) * 100,
                'total_payments': int(user_data.get('total_paiements', 0)),
                'avg_delay_days': self._convert_to_float(user_data.get('moyenne_jours_retard', 0)),
                'debt_ratio': self._convert_to_float(user_data.get('ratio_endettement', 0)),
                'active_credits': int(user_data.get('credits_actifs_count', 0))
            },
            'recommendations': recommendations
        }
    
    def _get_user_complete_data(self, user_id: int) -> Optional[Dict]:
        """Recupere toutes les donnees utilisateur"""
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
                
                # Convertir tous les Decimal en float
                for key in data:
                    if isinstance(data[key], Decimal):
                        data[key] = float(data[key])
                
                # Features supplementaires
                revenu = self._convert_to_float(data.get('revenu_mensuel', 0))
                charges = self._convert_to_float(data.get('charges_mensuelles', 0))
                dettes = self._convert_to_float(data.get('dettes_existantes', 0))
                total_p = self._convert_to_float(data.get('total_paiements', 0))
                
                data['debt_to_income'] = (charges + dettes) / max(revenu, 1)
                data['capacity_ratio'] = max(0, (revenu - charges - dettes) / max(revenu, 1))
                data['ratio_paiements_temps'] = self._convert_to_float(data['paiements_a_temps']) / max(total_p, 1)
                
                # Fiabilite
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
        """Calcul score avec Random Forest"""
        try:
            employment_map = {
                'cdi': 3,
                'fonctionnaire': 3,
                'cdd': 2,
                'independant': 1,
                'autre': 0
            }
            
            # Construire les features dans l'ORDRE EXACT de self.feature_columns
            features = []
            for feature_name in self.feature_columns:
                if feature_name == 'statut_emploi_encoded':
                    value = employment_map.get(user_data.get('statut_emploi', 'autre'), 0)
                else:
                    value = self._convert_to_float(user_data.get(feature_name, 0))
                features.append(value)
            
            X = np.array([features])
            X_scaled = self.scaler.transform(X)
            
            # Prediction
            proba = self.model.predict_proba(X_scaled)[0]
            
            # Convertir en score 0-10
            score = 3.0 + (proba[1] * 7.0)
            
            return score
            
        except Exception as e:
            logger.error(f"Erreur ML scoring: {e}")
            import traceback
            traceback.print_exc()
            return self._calculate_rule_based_score(user_data)
    
    def _calculate_rule_based_score(self, user_data: Dict) -> float:
        """Score base sur regles metier"""
        score = 5.0
        
        # Convertir tous en float
        revenu = self._convert_to_float(user_data.get('revenu_mensuel', 0))
        anciennete = self._convert_to_float(user_data.get('anciennete_mois', 0))
        ratio_temps = self._convert_to_float(user_data.get('ratio_paiements_temps', 0))
        ratio_dette = self._convert_to_float(user_data.get('ratio_endettement', 0))
        credits_actifs = int(user_data.get('credits_actifs_count', 0))
        
        # Revenu
        if revenu >= 1500000:
            score += 2.0
        elif revenu >= 1000000:
            score += 1.5
        elif revenu >= 500000:
            score += 1.0
        elif revenu < 300000:
            score -= 1.0
        
        # Emploi
        statut = user_data.get('statut_emploi', 'autre')
        if statut in ['cdi', 'fonctionnaire']:
            score += 1.5
        elif statut == 'cdd':
            score += 0.5
        
        # Anciennete
        if anciennete >= 60:
            score += 1.0
        elif anciennete >= 24:
            score += 0.5
        elif anciennete < 12:
            score -= 0.5
        
        # Paiements
        score += ratio_temps * 2.0
        
        # Endettement
        if ratio_dette > 70:
            score -= 3.0
        elif ratio_dette > 50:
            score -= 1.5
        elif ratio_dette <= 30:
            score += 1.0
        
        # Credits multiples
        if credits_actifs >= 2:
            score -= 1.5
        elif credits_actifs == 0:
            score += 0.5
        
        return max(0, min(10, score))
    
    def _determine_risk_level(self, score: float) -> str:
        """Determine le niveau de risque"""
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
        """Calcule le montant eligible"""
        if score < 4:
            return 0
        
        # Base sur revenu
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
        
        # Reduire si endettement eleve
        if ratio_dette > 50:
            montant = int(montant * 0.5)
        elif ratio_dette > 70:
            montant = int(montant * 0.3)
        
        return min(montant, 2000000)
    
    def _generate_recommendations(self, score: float, user_data: Dict) -> List[str]:
        """Genere recommandations personnalisees"""
        recommendations = []
        
        ratio_temps = self._convert_to_float(user_data.get('ratio_paiements_temps', 0)) * 100
        if ratio_temps < 80:
            recommendations.append("Ameliorez votre taux de paiements a temps")
        
        avg_delay = self._convert_to_float(user_data.get('moyenne_jours_retard', 0))
        if avg_delay > 7:
            recommendations.append(f"Reduisez vos retards (moyenne: {avg_delay:.0f} jours)")
        
        ratio_dette = self._convert_to_float(user_data.get('ratio_endettement', 0))
        if ratio_dette > 50:
            recommendations.append(f"Taux d'endettement eleve ({ratio_dette:.0f}%)")
        
        credits_actifs = int(user_data.get('credits_actifs_count', 0))
        if credits_actifs >= 2:
            recommendations.append("Maximum de credits actifs atteint")
        
        if score < 5:
            recommendations.append("Concentrez-vous sur les paiements a temps")
        elif score < 7:
            recommendations.append("Bon parcours, continuez vos efforts")
        else:
            recommendations.append("Excellent profil, maintenez vos habitudes")
        
        return recommendations
    
    # ==========================================
    # METHODES EXISTANTES
    # ==========================================
    
    def get_or_calculate_score(self, user_id: int, force_recalculate: bool = False) -> Dict:
        """Recupere ou calcule le score"""
        if not force_recalculate:
            existing_score = self.get_user_score_from_db(user_id)
            if existing_score:
                return existing_score
        
        new_score = self.calculate_comprehensive_score(user_id)
        self.update_user_score_in_db(user_id, new_score)
        
        return new_score
    
    def get_user_score_from_db(self, user_id: int) -> Optional[Dict]:
        """Recupere le score depuis la DB"""
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
                
                if not result:
                    return None
                
                data = dict(result)
                
                # Convertir Decimal en float
                for key in data:
                    if isinstance(data[key], Decimal):
                        data[key] = float(data[key])
                
                return data
    
    def update_user_score_in_db(self, user_id: int, score_data: Dict) -> bool:
        """Met a jour le score en DB"""
        try:
            with self.get_db_connection() as conn:
                with conn.cursor() as cur:
                    # Convertir explicitement en types Python natifs
                    score = float(score_data['score'])
                    score_850 = int(score_data['score_850'])
                    niveau_risque = str(score_data['niveau_risque'])
                    montant_eligible = int(score_data['montant_eligible'])
                    
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
                        score,
                        score_850,
                        niveau_risque,
                        montant_eligible,
                        user_id
                    ))
        except Exception as e:
            logger.error(f"Erreur lors de la mise à jour du score en DB: {e}")
            return False
        return True
    
    def check_eligibility(self, user_id: int) -> Dict:
        """Verifie eligibilite"""
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
                
                # Convertir Decimal en float
                score_credit = self._convert_to_float(eligibility.get('score_credit', 0))
                montant_eligible = self._convert_to_float(eligibility.get('montant_eligible', 0))
                
                if not eligibility['peut_emprunter']:
                    return {
                        'eligible': False,
                        'raison': eligibility.get('raison_blocage', 'Non eligible'),
                        'montant_eligible': 0,
                        'score': score_credit
                    }
                
                if score_credit < 5.0:
                    return {
                        'eligible': False,
                        'raison': 'Score insuffisant',
                        'montant_eligible': 0,
                        'score': score_credit
                    }
                
                return {
                    'eligible': True,
                    'montant_eligible': montant_eligible,
                    'score': score_credit
                }