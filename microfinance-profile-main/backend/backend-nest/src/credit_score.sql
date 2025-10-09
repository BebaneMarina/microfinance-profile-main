--
-- PostgreSQL database dump
--

-- Dumped from database version 17.5
-- Dumped by pg_dump version 17.5

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: niveau_risque; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.niveau_risque AS ENUM (
    'tres_bas',
    'bas',
    'moyen',
    'eleve',
    'tres_eleve'
);


ALTER TYPE public.niveau_risque OWNER TO postgres;

--
-- Name: statut_credit; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.statut_credit AS ENUM (
    'actif',
    'solde',
    'en_retard',
    'defaut'
);


ALTER TYPE public.statut_credit OWNER TO postgres;

--
-- Name: statut_utilisateur; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.statut_utilisateur AS ENUM (
    'actif',
    'inactif',
    'suspendu',
    'bloque'
);


ALTER TYPE public.statut_utilisateur OWNER TO postgres;

--
-- Name: type_credit; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.type_credit AS ENUM (
    'consommation_generale',
    'avance_salaire',
    'depannage',
    'investissement',
    'tontine',
    'retraite'
);


ALTER TYPE public.type_credit OWNER TO postgres;

--
-- Name: type_emploi; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.type_emploi AS ENUM (
    'cdi',
    'cdd',
    'independant',
    'fonctionnaire',
    'autre'
);


ALTER TYPE public.type_emploi OWNER TO postgres;

--
-- Name: type_paiement; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.type_paiement AS ENUM (
    'a_temps',
    'en_retard',
    'manque',
    'anticipe'
);


ALTER TYPE public.type_paiement OWNER TO postgres;

--
-- Name: calculer_ratio_endettement(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.calculer_ratio_endettement(p_utilisateur_id integer) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_revenu DECIMAL(12,2);
    v_dette_totale DECIMAL(12,2);
    v_ratio DECIMAL(5,2);
BEGIN
    SELECT revenu_mensuel INTO v_revenu 
    FROM utilisateurs 
    WHERE id = p_utilisateur_id;
    
    SELECT COALESCE(SUM(montant_restant), 0) INTO v_dette_totale
    FROM credits_enregistres
    WHERE utilisateur_id = p_utilisateur_id AND statut = 'actif';
    
    IF v_revenu > 0 THEN
        v_ratio := (v_dette_totale / v_revenu) * 100;
    ELSE
        v_ratio := 0;
    END IF;
    
    RETURN v_ratio;
END;
$$;


ALTER FUNCTION public.calculer_ratio_endettement(p_utilisateur_id integer) OWNER TO postgres;

--
-- Name: FUNCTION calculer_ratio_endettement(p_utilisateur_id integer); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.calculer_ratio_endettement(p_utilisateur_id integer) IS 'Calcule le ratio dette/revenu en pourcentage';


--
-- Name: date_aleatoire_passe(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.date_aleatoire_passe(jours_max integer) RETURNS timestamp without time zone
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN NOW() - (RANDOM() * jours_max || ' days')::INTERVAL;
END;
$$;


ALTER FUNCTION public.date_aleatoire_passe(jours_max integer) OWNER TO postgres;

--
-- Name: generer_historique_score_utilisateur(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.generer_historique_score_utilisateur(p_utilisateur_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_user RECORD;
    v_nb_entrees INTEGER;
    v_i INTEGER;
    v_date TIMESTAMP;
    v_score DECIMAL(3,1);
    v_score_precedent DECIMAL(3,1);
    v_evenement TEXT;
BEGIN
    SELECT * INTO v_user FROM utilisateurs WHERE id = p_utilisateur_id;
    
    v_nb_entrees := FLOOR(RANDOM() * 8 + 3);
    v_score := v_user.score_credit - (RANDOM() * 2 + 1);
    
    FOR v_i IN 1..v_nb_entrees LOOP
        v_score_precedent := v_score;
        v_date := NOW() - ((v_nb_entrees - v_i) * 45 || ' days')::INTERVAL;
        
        v_score := v_score + (v_user.score_credit - v_score) / (v_nb_entrees - v_i + 1) + (RANDOM() - 0.5) * 0.3;
        v_score := GREATEST(0, LEAST(10, v_score));
        
        v_evenement := CASE 
            WHEN RANDOM() < 0.4 THEN 'Paiement Ã  temps'
            WHEN RANDOM() < 0.6 THEN 'Nouveau crÃ©dit accordÃ©'
            WHEN RANDOM() < 0.8 THEN 'CrÃ©dit remboursÃ© intÃ©gralement'
            WHEN RANDOM() < 0.9 THEN 'Paiement en retard'
            ELSE 'Mise Ã  jour automatique'
        END;
        
        INSERT INTO historique_scores (
            utilisateur_id,
            score_credit,
            score_850,
            score_precedent,
            changement,
            niveau_risque,
            montant_eligible,
            evenement_declencheur,
            ratio_paiements_temps,
            tendance,
            date_calcul
        ) VALUES (
            p_utilisateur_id,
            ROUND(v_score, 1),
            300 + FLOOR(v_score * 55),
            ROUND(v_score_precedent, 1),
            ROUND(v_score - v_score_precedent, 1),
            CASE 
                WHEN v_score >= 8 THEN 'bas'::niveau_risque
                WHEN v_score >= 6 THEN 'moyen'::niveau_risque
                WHEN v_score >= 4 THEN 'eleve'::niveau_risque
                ELSE 'tres_eleve'::niveau_risque
            END,
            CASE 
                WHEN v_score >= 8 THEN v_user.revenu_mensuel * 0.7
                WHEN v_score >= 6 THEN v_user.revenu_mensuel * 0.5
                WHEN v_score >= 4 THEN v_user.revenu_mensuel * 0.3
                ELSE 0
            END,
            v_evenement,
            0.65 + v_score * 0.03,
            CASE 
                WHEN v_score > v_score_precedent + 0.2 THEN 'amelioration'
                WHEN v_score < v_score_precedent - 0.2 THEN 'degradation'
                ELSE 'stable'
            END,
            v_date
        );
    END LOOP;
END;
$$;


ALTER FUNCTION public.generer_historique_score_utilisateur(p_utilisateur_id integer) OWNER TO postgres;

--
-- Name: generer_numero_demande(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.generer_numero_demande() RETURNS character varying
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN 'LCR-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || 
           LPAD(FLOOR(RANDOM() * 9999 + 1)::TEXT, 4, '0');
END;
$$;


ALTER FUNCTION public.generer_numero_demande() OWNER TO postgres;

--
-- Name: generer_paiements_credit(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.generer_paiements_credit(p_credit_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_credit RECORD;
    v_date_paiement TIMESTAMP;
    v_montant_paiement DECIMAL(12,2);
    v_nb_paiements INTEGER;
    v_i INTEGER;
    v_jours_retard INTEGER;
    v_type_paiement type_paiement;
BEGIN
    SELECT * INTO v_credit FROM credits_enregistres WHERE id = p_credit_id;
    
    v_nb_paiements := CASE 
        WHEN v_credit.statut = 'solde' THEN v_credit.duree_mois
        WHEN v_credit.statut = 'actif' THEN FLOOR(v_credit.duree_mois * (0.3 + RANDOM() * 0.5))
        WHEN v_credit.statut = 'en_retard' THEN FLOOR(v_credit.duree_mois * (0.2 + RANDOM() * 0.4))
        ELSE FLOOR(v_credit.duree_mois * (0.1 + RANDOM() * 0.3))
    END;
    
    v_montant_paiement := v_credit.montant_total / v_credit.duree_mois;
    
    FOR v_i IN 1..v_nb_paiements LOOP
        v_date_paiement := v_credit.date_approbation + (v_i * 30 || ' days')::INTERVAL;
        
        IF v_credit.statut = 'solde' OR (v_credit.statut = 'actif' AND RANDOM() > 0.2) THEN
            v_jours_retard := 0;
            v_type_paiement := 'a_temps'::type_paiement;
        ELSIF RANDOM() > 0.5 THEN
            v_jours_retard := FLOOR(RANDOM() * 15 + 1);
            v_type_paiement := 'en_retard'::type_paiement;
            v_date_paiement := v_date_paiement + (v_jours_retard || ' days')::INTERVAL;
        ELSE
            v_jours_retard := FLOOR(RANDOM() * 45 + 15);
            v_type_paiement := 'en_retard'::type_paiement;
            v_date_paiement := v_date_paiement + (v_jours_retard || ' days')::INTERVAL;
        END IF;
        
        INSERT INTO historique_paiements (
            credit_id, 
            utilisateur_id, 
            montant, 
            date_paiement, 
            date_prevue,
            jours_retard, 
            type_paiement,
            frais_retard
        ) VALUES (
            p_credit_id,
            v_credit.utilisateur_id,
            v_montant_paiement * (0.9 + RANDOM() * 0.2),
            v_date_paiement,
            v_credit.date_approbation + (v_i * 30 || ' days')::INTERVAL,
            v_jours_retard,
            v_type_paiement,
            CASE WHEN v_jours_retard > 0 THEN v_jours_retard * 500 ELSE 0 END
        );
    END LOOP;
    
    IF v_credit.statut IN ('en_retard', 'defaut') THEN
        FOR v_i IN 1..FLOOR(RANDOM() * 3 + 1) LOOP
            INSERT INTO historique_paiements (
                credit_id, 
                utilisateur_id, 
                montant, 
                date_paiement, 
                date_prevue,
                jours_retard, 
                type_paiement,
                frais_retard
            ) VALUES (
                p_credit_id,
                v_credit.utilisateur_id,
                0,
                v_credit.date_approbation + ((v_nb_paiements + v_i) * 30 || ' days')::INTERVAL,
                v_credit.date_approbation + ((v_nb_paiements + v_i) * 30 || ' days')::INTERVAL,
                FLOOR(RANDOM() * 60 + 30),
                'manque'::type_paiement,
                FLOOR(RANDOM() * 60 + 30) * 500
            );
        END LOOP;
    END IF;
END;
$$;


ALTER FUNCTION public.generer_paiements_credit(p_credit_id integer) OWNER TO postgres;

--
-- Name: maj_date_modification(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.maj_date_modification() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.date_modification = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.maj_date_modification() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: credits_enregistres; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.credits_enregistres (
    id integer NOT NULL,
    utilisateur_id integer NOT NULL,
    type_credit public.type_credit NOT NULL,
    montant_principal numeric(12,2) NOT NULL,
    montant_total numeric(12,2) NOT NULL,
    montant_restant numeric(12,2) NOT NULL,
    taux_interet numeric(5,2) NOT NULL,
    duree_mois integer NOT NULL,
    statut public.statut_credit DEFAULT 'actif'::public.statut_credit,
    date_approbation timestamp without time zone DEFAULT now() NOT NULL,
    date_echeance timestamp without time zone NOT NULL,
    date_prochain_paiement timestamp without time zone,
    montant_prochain_paiement numeric(12,2),
    date_creation timestamp without time zone DEFAULT now(),
    date_modification timestamp without time zone DEFAULT now(),
    CONSTRAINT credits_enregistres_duree_mois_check CHECK ((duree_mois > 0)),
    CONSTRAINT credits_enregistres_montant_principal_check CHECK ((montant_principal > (0)::numeric)),
    CONSTRAINT credits_enregistres_montant_restant_check CHECK ((montant_restant >= (0)::numeric)),
    CONSTRAINT credits_enregistres_montant_total_check CHECK ((montant_total >= (0)::numeric)),
    CONSTRAINT credits_enregistres_taux_interet_check CHECK ((taux_interet >= (0)::numeric)),
    CONSTRAINT montant_restant_coherent CHECK (((montant_restant <= montant_total) OR (montant_total = (0)::numeric)))
);


ALTER TABLE public.credits_enregistres OWNER TO postgres;

--
-- Name: TABLE credits_enregistres; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.credits_enregistres IS 'Tous les crÃ©dits accordÃ©s - historique complet';


--
-- Name: COLUMN credits_enregistres.montant_restant; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.credits_enregistres.montant_restant IS 'Solde restant Ã  rembourser';


--
-- Name: credits_enregistres_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.credits_enregistres_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.credits_enregistres_id_seq OWNER TO postgres;

--
-- Name: credits_enregistres_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.credits_enregistres_id_seq OWNED BY public.credits_enregistres.id;


--
-- Name: demandes_credit_longues; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.demandes_credit_longues (
    id integer NOT NULL,
    numero_demande character varying(50) NOT NULL,
    utilisateur_id integer NOT NULL,
    type_credit public.type_credit NOT NULL,
    montant_demande numeric(12,2) NOT NULL,
    duree_mois integer NOT NULL,
    objectif text NOT NULL,
    statut character varying(50) DEFAULT 'soumise'::character varying,
    date_soumission timestamp without time zone DEFAULT now(),
    date_decision timestamp without time zone,
    decideur_id integer,
    montant_approuve numeric(12,2),
    taux_approuve numeric(5,2),
    notes_decision text,
    score_au_moment_demande numeric(3,1),
    niveau_risque_evaluation public.niveau_risque,
    date_creation timestamp without time zone DEFAULT now(),
    date_modification timestamp without time zone DEFAULT now()
);


ALTER TABLE public.demandes_credit_longues OWNER TO postgres;

--
-- Name: TABLE demandes_credit_longues; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.demandes_credit_longues IS 'Demandes de crÃ©dit complexes avec workflow back-office';


--
-- Name: demandes_credit_longues_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.demandes_credit_longues_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.demandes_credit_longues_id_seq OWNER TO postgres;

--
-- Name: demandes_credit_longues_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.demandes_credit_longues_id_seq OWNED BY public.demandes_credit_longues.id;


--
-- Name: historique_paiements; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.historique_paiements (
    id integer NOT NULL,
    credit_id integer NOT NULL,
    utilisateur_id integer NOT NULL,
    montant numeric(12,2) NOT NULL,
    date_paiement timestamp without time zone DEFAULT now() NOT NULL,
    date_prevue timestamp without time zone NOT NULL,
    jours_retard integer DEFAULT 0,
    type_paiement public.type_paiement NOT NULL,
    frais_retard numeric(10,2) DEFAULT 0,
    date_creation timestamp without time zone DEFAULT now(),
    CONSTRAINT historique_paiements_jours_retard_check CHECK ((jours_retard >= 0)),
    CONSTRAINT historique_paiements_montant_check CHECK ((montant >= (0)::numeric))
);


ALTER TABLE public.historique_paiements OWNER TO postgres;

--
-- Name: TABLE historique_paiements; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.historique_paiements IS 'Historique complet des paiements - donnÃ©es ML';


--
-- Name: COLUMN historique_paiements.jours_retard; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.historique_paiements.jours_retard IS 'Nombre de jours de retard (0 = Ã  temps)';


--
-- Name: historique_paiements_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.historique_paiements_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.historique_paiements_id_seq OWNER TO postgres;

--
-- Name: historique_paiements_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.historique_paiements_id_seq OWNED BY public.historique_paiements.id;


--
-- Name: historique_scores; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.historique_scores (
    id integer NOT NULL,
    utilisateur_id integer NOT NULL,
    score_credit numeric(3,1) NOT NULL,
    score_850 integer NOT NULL,
    score_precedent numeric(3,1),
    changement numeric(3,1),
    niveau_risque public.niveau_risque NOT NULL,
    montant_eligible numeric(12,2),
    evenement_declencheur character varying(200),
    ratio_paiements_temps numeric(5,2),
    tendance character varying(20),
    date_calcul timestamp without time zone DEFAULT now()
);


ALTER TABLE public.historique_scores OWNER TO postgres;

--
-- Name: TABLE historique_scores; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.historique_scores IS 'Ã‰volution temporelle des scores de crÃ©dit';


--
-- Name: COLUMN historique_scores.evenement_declencheur; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.historique_scores.evenement_declencheur IS 'Ce qui a causÃ© le recalcul (paiement, nouveau crÃ©dit, etc.)';


--
-- Name: historique_scores_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.historique_scores_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.historique_scores_id_seq OWNER TO postgres;

--
-- Name: historique_scores_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.historique_scores_id_seq OWNED BY public.historique_scores.id;


--
-- Name: restrictions_credit; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.restrictions_credit (
    id integer NOT NULL,
    utilisateur_id integer NOT NULL,
    peut_emprunter boolean DEFAULT true,
    credits_actifs_count integer DEFAULT 0,
    credits_max_autorises integer DEFAULT 2,
    dette_totale_active numeric(12,2) DEFAULT 0,
    ratio_endettement numeric(5,2) DEFAULT 0,
    date_derniere_demande timestamp without time zone,
    date_prochaine_eligibilite timestamp without time zone,
    jours_avant_prochaine_demande integer,
    raison_blocage text,
    date_creation timestamp without time zone DEFAULT now(),
    date_modification timestamp without time zone DEFAULT now()
);


ALTER TABLE public.restrictions_credit OWNER TO postgres;

--
-- Name: TABLE restrictions_credit; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.restrictions_credit IS 'Gestion des rÃ¨gles et restrictions de crÃ©dit par client';


--
-- Name: restrictions_credit_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.restrictions_credit_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.restrictions_credit_id_seq OWNER TO postgres;

--
-- Name: restrictions_credit_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.restrictions_credit_id_seq OWNED BY public.restrictions_credit.id;


--
-- Name: utilisateurs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.utilisateurs (
    id integer NOT NULL,
    uuid uuid DEFAULT public.uuid_generate_v4(),
    nom character varying(100) NOT NULL,
    prenom character varying(100) NOT NULL,
    email character varying(255) NOT NULL,
    telephone character varying(20) NOT NULL,
    mot_de_passe_hash character varying(255) NOT NULL,
    ville character varying(100) DEFAULT 'Libreville'::character varying,
    quartier character varying(100),
    province character varying(50) DEFAULT 'Estuaire'::character varying,
    profession character varying(255),
    employeur character varying(255),
    statut_emploi public.type_emploi DEFAULT 'cdi'::public.type_emploi,
    revenu_mensuel numeric(12,2) NOT NULL,
    anciennete_mois integer DEFAULT 0,
    charges_mensuelles numeric(12,2) DEFAULT 0,
    dettes_existantes numeric(12,2) DEFAULT 0,
    score_credit numeric(3,1) DEFAULT 6.0,
    score_850 integer DEFAULT 650,
    niveau_risque public.niveau_risque DEFAULT 'moyen'::public.niveau_risque,
    montant_eligible numeric(12,2) DEFAULT 0,
    statut public.statut_utilisateur DEFAULT 'actif'::public.statut_utilisateur,
    date_creation timestamp without time zone DEFAULT now(),
    date_modification timestamp without time zone DEFAULT now(),
    derniere_connexion timestamp without time zone,
    CONSTRAINT revenu_positif CHECK ((revenu_mensuel > (0)::numeric)),
    CONSTRAINT utilisateurs_anciennete_mois_check CHECK ((anciennete_mois >= 0)),
    CONSTRAINT utilisateurs_revenu_mensuel_check CHECK ((revenu_mensuel >= (0)::numeric)),
    CONSTRAINT utilisateurs_score_850_check CHECK (((score_850 >= 300) AND (score_850 <= 850))),
    CONSTRAINT utilisateurs_score_credit_check CHECK (((score_credit >= (0)::numeric) AND (score_credit <= (10)::numeric)))
);


ALTER TABLE public.utilisateurs OWNER TO postgres;

--
-- Name: TABLE utilisateurs; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.utilisateurs IS 'Table principale des clients avec informations personnelles et scoring';


--
-- Name: COLUMN utilisateurs.score_credit; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.utilisateurs.score_credit IS 'Score sur 10 calculÃ© par le modÃ¨le ML';


--
-- Name: COLUMN utilisateurs.score_850; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.utilisateurs.score_850 IS 'Score traditionnel FICO-like (300-850)';


--
-- Name: COLUMN utilisateurs.montant_eligible; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.utilisateurs.montant_eligible IS 'Montant maximum empruntable selon le profil';


--
-- Name: utilisateurs_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.utilisateurs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.utilisateurs_id_seq OWNER TO postgres;

--
-- Name: utilisateurs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.utilisateurs_id_seq OWNED BY public.utilisateurs.id;


--
-- Name: v_analyse_paiements; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_analyse_paiements AS
 SELECT u.id AS utilisateur_id,
    u.nom,
    u.prenom,
    count(hp.id) AS total_paiements,
    count(hp.id) FILTER (WHERE (hp.type_paiement = 'a_temps'::public.type_paiement)) AS paiements_a_temps,
    count(hp.id) FILTER (WHERE (hp.type_paiement = 'en_retard'::public.type_paiement)) AS paiements_en_retard,
    count(hp.id) FILTER (WHERE (hp.type_paiement = 'manque'::public.type_paiement)) AS paiements_manques,
    round((((count(hp.id) FILTER (WHERE (hp.type_paiement = 'a_temps'::public.type_paiement)))::numeric / (NULLIF(count(hp.id), 0))::numeric) * (100)::numeric), 2) AS taux_paiements_temps,
    round(avg(hp.jours_retard), 1) AS moyenne_jours_retard,
    sum(hp.montant) AS total_paye,
    sum(hp.frais_retard) AS total_frais_retard
   FROM (public.utilisateurs u
     LEFT JOIN public.historique_paiements hp ON ((u.id = hp.utilisateur_id)))
  GROUP BY u.id, u.nom, u.prenom;


ALTER VIEW public.v_analyse_paiements OWNER TO postgres;

--
-- Name: VIEW v_analyse_paiements; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON VIEW public.v_analyse_paiements IS 'Statistiques de paiement par utilisateur pour ML';


--
-- Name: v_dashboard_utilisateurs; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_dashboard_utilisateurs AS
SELECT
    NULL::integer AS id,
    NULL::character varying(100) AS nom,
    NULL::character varying(100) AS prenom,
    NULL::character varying(255) AS email,
    NULL::character varying(20) AS telephone,
    NULL::character varying(100) AS ville,
    NULL::character varying(255) AS profession,
    NULL::public.type_emploi AS statut_emploi,
    NULL::numeric(12,2) AS revenu_mensuel,
    NULL::numeric(3,1) AS score_credit,
    NULL::public.niveau_risque AS niveau_risque,
    NULL::numeric(12,2) AS montant_eligible,
    NULL::boolean AS peut_emprunter,
    NULL::integer AS credits_actifs_count,
    NULL::numeric(12,2) AS dette_totale_active,
    NULL::numeric(5,2) AS ratio_endettement,
    NULL::text AS raison_blocage,
    NULL::bigint AS credits_actifs,
    NULL::bigint AS credits_soldes,
    NULL::bigint AS credits_en_retard,
    NULL::numeric AS total_dette_active;


ALTER VIEW public.v_dashboard_utilisateurs OWNER TO postgres;

--
-- Name: VIEW v_dashboard_utilisateurs; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON VIEW public.v_dashboard_utilisateurs IS 'Vue complÃ¨te de la situation de chaque utilisateur';


--
-- Name: v_evolution_scores; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_evolution_scores AS
 SELECT u.id AS utilisateur_id,
    u.nom,
    u.prenom,
    u.score_credit AS score_actuel,
    hs.score_credit AS score_historique,
    hs.changement,
    hs.tendance,
    hs.evenement_declencheur,
    hs.date_calcul,
    row_number() OVER (PARTITION BY u.id ORDER BY hs.date_calcul DESC) AS rang
   FROM (public.utilisateurs u
     LEFT JOIN public.historique_scores hs ON ((u.id = hs.utilisateur_id)))
  ORDER BY u.id, hs.date_calcul DESC;


ALTER VIEW public.v_evolution_scores OWNER TO postgres;

--
-- Name: VIEW v_evolution_scores; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON VIEW public.v_evolution_scores IS 'Historique de l''Ã©volution des scores par utilisateur';


--
-- Name: v_statistiques_globales; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_statistiques_globales AS
 SELECT ( SELECT count(*) AS count
           FROM public.utilisateurs) AS total_utilisateurs,
    ( SELECT count(*) AS count
           FROM public.credits_enregistres) AS total_credits,
    ( SELECT count(*) AS count
           FROM public.historique_paiements) AS total_paiements,
    ( SELECT count(*) AS count
           FROM public.historique_scores) AS total_entrees_score,
    ( SELECT count(*) AS count
           FROM public.demandes_credit_longues) AS total_demandes_longues,
    ( SELECT count(*) AS count
           FROM public.utilisateurs
          WHERE (utilisateurs.score_credit >= (8)::numeric)) AS utilisateurs_excellents,
    ( SELECT count(*) AS count
           FROM public.utilisateurs
          WHERE ((utilisateurs.score_credit >= (6)::numeric) AND (utilisateurs.score_credit <= 7.9))) AS utilisateurs_bons,
    ( SELECT count(*) AS count
           FROM public.utilisateurs
          WHERE ((utilisateurs.score_credit >= (4)::numeric) AND (utilisateurs.score_credit <= 5.9))) AS utilisateurs_moyens,
    ( SELECT count(*) AS count
           FROM public.utilisateurs
          WHERE (utilisateurs.score_credit < (4)::numeric)) AS utilisateurs_risque,
    ( SELECT count(*) AS count
           FROM public.credits_enregistres
          WHERE (credits_enregistres.statut = 'actif'::public.statut_credit)) AS credits_actifs,
    ( SELECT count(*) AS count
           FROM public.credits_enregistres
          WHERE (credits_enregistres.statut = 'solde'::public.statut_credit)) AS credits_soldes,
    ( SELECT count(*) AS count
           FROM public.credits_enregistres
          WHERE (credits_enregistres.statut = 'en_retard'::public.statut_credit)) AS credits_en_retard,
    ( SELECT sum(credits_enregistres.montant_restant) AS sum
           FROM public.credits_enregistres
          WHERE (credits_enregistres.statut = 'actif'::public.statut_credit)) AS encours_total,
    ( SELECT round(avg(utilisateurs.score_credit), 2) AS round
           FROM public.utilisateurs) AS score_moyen,
    ( SELECT round(avg(restrictions_credit.ratio_endettement), 2) AS round
           FROM public.restrictions_credit) AS ratio_endettement_moyen;


ALTER VIEW public.v_statistiques_globales OWNER TO postgres;

--
-- Name: credits_enregistres id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.credits_enregistres ALTER COLUMN id SET DEFAULT nextval('public.credits_enregistres_id_seq'::regclass);


--
-- Name: demandes_credit_longues id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.demandes_credit_longues ALTER COLUMN id SET DEFAULT nextval('public.demandes_credit_longues_id_seq'::regclass);


--
-- Name: historique_paiements id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.historique_paiements ALTER COLUMN id SET DEFAULT nextval('public.historique_paiements_id_seq'::regclass);


--
-- Name: historique_scores id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.historique_scores ALTER COLUMN id SET DEFAULT nextval('public.historique_scores_id_seq'::regclass);


--
-- Name: restrictions_credit id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.restrictions_credit ALTER COLUMN id SET DEFAULT nextval('public.restrictions_credit_id_seq'::regclass);


--
-- Name: utilisateurs id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.utilisateurs ALTER COLUMN id SET DEFAULT nextval('public.utilisateurs_id_seq'::regclass);


--
-- Data for Name: credits_enregistres; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.credits_enregistres (id, utilisateur_id, type_credit, montant_principal, montant_total, montant_restant, taux_interet, duree_mois, statut, date_approbation, date_echeance, date_prochain_paiement, montant_prochain_paiement, date_creation, date_modification) FROM stdin;
1	1	avance_salaire	1702897.00	1788041.85	837780.98	0.05	1	actif	2025-08-12 12:35:24.69028	2026-01-24 00:40:06.895716	2025-10-23 06:25:44.054027	732338.36	2025-10-02 08:01:52.812279	2025-10-02 08:01:52.830408
2	2	consommation_generale	1500038.00	1575039.90	0.00	0.05	1	solde	2025-04-21 11:11:10.958657	2025-12-22 23:13:44.568865	2025-10-18 20:24:58.473252	\N	2025-10-02 08:01:52.812279	2025-10-02 08:01:52.830408
3	3	consommation_generale	1568993.00	1647442.65	408085.76	0.05	1	actif	2025-09-01 09:41:11.068607	2026-01-29 01:34:44.552626	2025-10-31 17:18:59.889086	529790.32	2025-10-02 08:01:52.812279	2025-10-02 08:01:52.830408
4	4	avance_salaire	1995162.00	2294436.30	1463287.90	0.05	3	actif	2025-09-11 22:37:27.230529	2026-03-12 03:39:18.853111	2025-10-02 22:56:31.731955	854420.99	2025-10-02 08:01:52.812279	2025-10-02 08:01:52.830408
5	5	avance_salaire	1199534.00	1235520.02	0.00	0.03	1	solde	2025-01-27 20:09:49.416982	2026-01-01 22:41:47.387285	2025-10-09 12:43:56.66629	\N	2025-10-02 08:01:52.812279	2025-10-02 08:01:52.830408
6	6	avance_salaire	540057.00	567059.85	140792.50	0.05	1	actif	2025-03-26 09:13:41.796546	2026-01-09 03:36:59.659844	2025-10-18 15:06:48.412712	238386.44	2025-10-02 08:01:52.812279	2025-10-02 08:01:52.830408
7	7	consommation_generale	724806.00	746550.18	130775.08	0.03	1	actif	2025-09-01 23:33:43.249668	2026-02-03 19:54:00.107214	2025-10-29 00:58:40.734938	257934.42	2025-10-02 08:01:52.812279	2025-10-02 08:01:52.830408
8	8	avance_salaire	756776.00	779479.28	0.00	0.03	1	solde	2025-05-21 22:49:13.906371	2026-03-12 18:03:38.464748	2025-10-09 06:35:30.380215	\N	2025-10-02 08:01:52.812279	2025-10-02 08:01:52.830408
9	9	avance_salaire	570346.00	627380.60	321479.78	0.05	2	actif	2025-03-27 13:31:05.74943	2026-01-02 08:09:33.844343	2025-10-15 08:38:18.219736	255393.75	2025-10-02 08:01:52.812279	2025-10-02 08:01:52.830408
10	10	consommation_generale	1647545.00	1729922.25	1019515.84	0.05	1	actif	2025-02-17 03:57:28.443867	2025-11-07 19:29:58.507149	2025-10-09 21:38:13.74587	597094.28	2025-10-02 08:01:52.812279	2025-10-02 08:01:52.830408
11	11	avance_salaire	548828.00	576269.40	0.00	0.05	1	solde	2024-11-06 09:34:24.688008	2025-11-24 18:35:12.804195	2025-10-21 23:35:37.141808	\N	2025-10-02 08:01:52.812279	2025-10-02 08:01:52.830408
12	12	avance_salaire	1016782.00	1047285.46	71713.65	0.03	1	actif	2025-05-23 03:28:16.687905	2025-12-26 15:51:53.686139	2025-10-23 13:14:11.703262	452194.55	2025-10-02 08:01:52.812279	2025-10-02 08:01:52.830408
13	13	consommation_generale	1959769.00	2253734.35	0.00	0.05	3	solde	2025-03-22 16:20:04.641186	2025-11-14 07:24:12.106444	2025-10-24 11:36:24.812387	\N	2025-10-02 08:01:52.812279	2025-10-02 08:01:52.830408
14	14	avance_salaire	1795726.00	1957341.34	0.00	0.03	3	solde	2025-06-11 18:38:40.037667	2026-03-29 20:57:02.925977	2025-10-19 18:26:05.605879	\N	2025-10-02 08:01:52.812279	2025-10-02 08:01:52.830408
15	15	consommation_generale	1136189.00	1170274.67	0.00	0.03	1	solde	2025-06-06 11:34:28.679069	2026-01-15 10:59:59.902812	2025-10-27 12:07:15.16402	\N	2025-10-02 08:01:52.812279	2025-10-02 08:01:52.830408
16	16	avance_salaire	1194653.00	1254385.65	0.00	0.05	1	solde	2025-03-29 15:43:21.25365	2025-12-16 07:14:03.805262	2025-10-18 16:06:40.963585	\N	2025-10-02 08:01:52.812279	2025-10-02 08:01:52.830408
17	17	consommation_generale	1518364.00	1594282.20	0.00	0.05	1	solde	2025-09-11 23:24:56.371407	2025-10-24 20:54:57.604172	2025-10-31 04:00:52.548599	\N	2025-10-02 08:01:52.812279	2025-10-02 08:01:52.830408
18	18	consommation_generale	1223276.00	1259974.28	409245.28	0.03	1	actif	2025-03-12 11:49:05.173728	2025-11-26 11:37:32.289426	2025-10-25 08:53:44.337081	509105.67	2025-10-02 08:01:52.812279	2025-10-02 08:01:52.830408
19	19	consommation_generale	722736.00	831146.40	0.00	0.05	3	solde	2025-08-09 02:56:52.774093	2025-11-13 04:43:10.166827	2025-10-25 05:58:15.641482	\N	2025-10-02 08:01:52.812279	2025-10-02 08:01:52.830408
20	20	avance_salaire	1829797.00	1921286.85	0.00	0.05	1	solde	2025-09-27 18:53:28.85246	2026-01-16 17:23:10.244243	2025-10-12 22:04:56.429964	\N	2025-10-02 08:01:52.812279	2025-10-02 08:01:52.830408
21	21	consommation_generale	906941.00	988565.69	269373.91	0.03	3	actif	2025-09-26 22:38:47.838063	2025-12-01 08:18:53.021142	2025-10-10 02:04:48.784381	296361.57	2025-10-02 08:01:52.812279	2025-10-02 08:01:52.830408
22	22	consommation_generale	1378031.00	1446932.55	0.00	0.05	1	solde	2024-10-13 17:49:08.792501	2025-12-19 14:16:38.923271	2025-10-29 02:31:19.580003	\N	2025-10-02 08:01:52.812279	2025-10-02 08:01:52.830408
23	23	avance_salaire	745219.00	767575.57	0.00	0.03	1	solde	2025-02-09 20:42:38.659398	2026-01-14 03:41:29.47759	2025-10-31 11:08:24.575265	\N	2025-10-02 08:01:52.812279	2025-10-02 08:01:52.830408
24	24	consommation_generale	1309368.00	1374836.40	79202.35	0.05	1	actif	2025-03-20 03:38:13.961761	2026-01-24 05:11:02.698519	2025-10-06 23:31:02.833316	490701.90	2025-10-02 08:01:52.812279	2025-10-02 08:01:52.830408
25	25	consommation_generale	1258330.00	1296079.90	0.00	0.03	1	solde	2024-12-15 23:16:49.089899	2025-10-20 21:03:10.626432	2025-10-17 21:26:43.771971	\N	2025-10-02 08:01:52.812279	2025-10-02 08:01:52.830408
26	26	consommation_generale	641480.00	673554.00	455302.75	0.05	1	actif	2025-02-26 09:26:18.932755	2026-03-04 19:19:19.387969	2025-10-18 00:20:35.415937	219210.83	2025-10-02 08:01:52.812279	2025-10-02 08:01:52.830408
27	27	avance_salaire	597300.00	627165.00	0.00	0.05	1	solde	2025-02-13 01:12:03.980074	2026-03-28 21:36:47.103833	2025-10-12 18:26:39.94956	\N	2025-10-02 08:01:52.812279	2025-10-02 08:01:52.830408
28	28	consommation_generale	1814149.00	1868573.47	763503.08	0.03	1	actif	2025-01-16 09:00:10.429065	2026-01-19 10:40:14.885833	2025-10-08 16:33:59.129666	742361.07	2025-10-02 08:01:52.812279	2025-10-02 08:01:52.830408
29	29	consommation_generale	1521512.00	1749738.80	676200.93	0.05	3	actif	2025-02-23 11:48:49.360185	2025-10-18 15:52:10.795783	2025-10-15 07:17:57.710289	482605.88	2025-10-02 08:01:52.812279	2025-10-02 08:01:52.830408
30	30	avance_salaire	901605.00	928653.15	512008.48	0.03	1	actif	2025-05-21 18:39:27.302804	2025-12-10 07:21:20.790895	2025-10-18 02:47:58.674821	401813.46	2025-10-02 08:01:52.812279	2025-10-02 08:01:52.830408
31	1	depannage	519555.00	540337.20	237735.35	0.04	1	actif	2025-08-14 22:56:19.298062	2025-10-12 19:20:16.444264	2025-10-09 03:20:53.358874	190770.04	2025-10-02 08:01:52.820859	2025-10-02 08:01:52.830408
32	2	depannage	718955.00	747713.20	136699.86	0.04	1	actif	2025-08-30 10:12:32.596334	2025-11-06 07:29:08.098655	2025-10-09 20:37:44.600391	216062.07	2025-10-02 08:01:52.820859	2025-10-02 08:01:52.830408
33	3	depannage	306655.00	318921.20	223093.41	0.04	1	actif	2025-09-18 13:13:00.159178	2025-11-11 18:56:01.542709	2025-10-15 16:39:24.168484	104003.50	2025-10-02 08:01:52.820859	2025-10-02 08:01:52.830408
34	4	depannage	781361.00	812615.44	430232.68	0.04	1	actif	2025-07-29 19:13:03.010394	2025-10-05 07:15:55.371229	2025-10-16 21:24:01.525379	257472.63	2025-10-02 08:01:52.820859	2025-10-02 08:01:52.830408
35	5	depannage	803750.00	835900.00	192233.84	0.04	1	actif	2025-09-05 18:31:54.933348	2025-10-21 10:06:20.315264	2025-10-14 03:29:57.122955	246196.29	2025-10-02 08:01:52.820859	2025-10-02 08:01:52.830408
36	6	depannage	536091.00	557534.64	172818.31	0.04	1	actif	2025-07-26 09:42:27.683278	2025-10-11 06:11:36.613255	2025-10-16 12:15:36.073693	194045.42	2025-10-02 08:01:52.820859	2025-10-02 08:01:52.830408
37	7	depannage	734192.00	763559.68	481025.07	0.04	1	actif	2025-09-20 23:14:47.590063	2025-10-19 12:17:04.818241	2025-10-07 12:51:30.633819	247808.53	2025-10-02 08:01:52.820859	2025-10-02 08:01:52.830408
38	8	depannage	943712.00	981460.48	385129.15	0.04	1	actif	2025-09-15 13:27:54.349741	2025-11-24 23:50:27.697502	2025-10-06 15:00:39.973172	414011.04	2025-10-02 08:01:52.820859	2025-10-02 08:01:52.830408
39	9	depannage	709507.00	737887.28	369441.87	0.04	1	actif	2025-09-19 23:07:37.698149	2025-11-29 16:38:29.695926	2025-10-09 19:15:01.003534	230991.39	2025-10-02 08:01:52.820859	2025-10-02 08:01:52.830408
40	10	depannage	205237.00	213446.48	104673.64	0.04	1	actif	2025-09-22 20:46:11.845911	2025-11-18 20:20:17.923511	2025-10-06 16:24:01.838213	81333.91	2025-10-02 08:01:52.820859	2025-10-02 08:01:52.830408
41	11	depannage	337776.00	351287.04	234002.52	0.04	1	actif	2025-08-10 14:20:21.557645	2025-11-03 05:45:39.383953	2025-10-13 03:31:22.803872	111466.92	2025-10-02 08:01:52.820859	2025-10-02 08:01:52.830408
42	12	depannage	238218.00	247746.72	49726.19	0.04	1	actif	2025-07-26 11:50:57.314813	2025-11-24 22:01:30.332088	2025-10-05 12:43:02.252729	83996.65	2025-10-02 08:01:52.820859	2025-10-02 08:01:52.830408
43	13	depannage	481594.00	500857.76	124844.23	0.04	1	actif	2025-08-18 11:17:21.964639	2025-10-15 16:14:24.494268	2025-10-03 08:41:34.104483	158857.12	2025-10-02 08:01:52.820859	2025-10-02 08:01:52.830408
44	14	depannage	478658.00	497804.32	84164.45	0.04	1	actif	2025-09-08 01:42:08.236614	2025-11-30 12:21:40.205547	2025-10-14 16:14:44.236656	206582.87	2025-10-02 08:01:52.820859	2025-10-02 08:01:52.830408
45	15	depannage	880347.00	915560.88	435992.25	0.04	1	actif	2025-07-13 04:47:06.937192	2025-11-19 15:39:01.192944	2025-10-10 22:47:29.896077	358062.16	2025-10-02 08:01:52.820859	2025-10-02 08:01:52.830408
46	31	avance_salaire	440018.00	484019.80	0.00	0.05	2	solde	2025-09-16 10:37:59.911985	2026-01-09 15:14:13.788685	2025-10-16 12:21:21.536917	\N	2025-10-02 08:01:52.821778	2025-10-02 08:01:52.830408
47	32	depannage	529115.00	571444.20	0.00	0.04	2	solde	2025-09-17 00:08:00.483171	2025-12-05 12:32:10.018461	2025-10-22 17:56:06.507266	\N	2025-10-02 08:01:52.821778	2025-10-02 08:01:52.830408
48	33	depannage	783636.00	814981.44	424024.30	0.04	1	en_retard	2025-02-26 17:10:17.617682	2025-10-30 21:05:34.47875	2025-10-18 23:33:58.734542	253994.17	2025-10-02 08:01:52.821778	2025-10-02 08:01:52.830408
49	34	avance_salaire	539011.00	571351.66	0.00	0.03	2	solde	2025-01-07 20:04:53.324022	2026-01-10 09:41:40.298091	2025-10-23 09:08:23.412608	\N	2025-10-02 08:01:52.821778	2025-10-02 08:01:52.830408
50	35	consommation_generale	360459.00	396504.90	220262.57	0.05	2	en_retard	2025-09-26 00:36:31.17746	2025-10-06 13:57:23.722872	2025-10-24 03:42:38.530671	119683.17	2025-10-02 08:01:52.821778	2025-10-02 08:01:52.830408
51	36	avance_salaire	679998.00	707197.92	0.00	0.04	1	solde	2025-02-09 15:55:56.901817	2025-10-20 17:12:53.427563	2025-10-03 00:46:26.775398	\N	2025-10-02 08:01:52.821778	2025-10-02 08:01:52.830408
52	37	avance_salaire	688225.00	708871.75	31194.49	0.03	1	actif	2025-06-14 11:54:46.080651	2025-10-05 13:04:56.830084	2025-10-17 04:57:46.507705	278484.13	2025-10-02 08:01:52.821778	2025-10-02 08:01:52.830408
53	38	depannage	770784.00	793907.52	65620.38	0.03	1	actif	2025-09-04 21:30:04.334728	2025-10-23 03:43:14.774418	2025-10-19 01:36:32.544428	257578.25	2025-10-02 08:01:52.821778	2025-10-02 08:01:52.830408
54	39	consommation_generale	461583.00	484662.15	94356.62	0.05	1	actif	2025-01-30 21:21:18.709234	2025-11-27 03:09:58.380185	2025-10-27 03:09:28.774311	178854.98	2025-10-02 08:01:52.821778	2025-10-02 08:01:52.830408
55	40	avance_salaire	539252.00	571607.12	0.00	0.03	2	solde	2025-08-20 10:54:15.038803	2025-11-26 05:43:13.651539	2025-10-08 18:43:26.005637	\N	2025-10-02 08:01:52.821778	2025-10-02 08:01:52.830408
56	41	avance_salaire	433944.00	455641.20	0.00	0.05	1	solde	2025-02-23 18:35:10.193316	2025-11-01 10:16:47.593182	2025-10-13 04:22:13.516766	\N	2025-10-02 08:01:52.821778	2025-10-02 08:01:52.830408
57	42	avance_salaire	479939.00	518334.12	0.00	0.04	2	solde	2025-02-18 01:13:00.04763	2026-01-20 08:26:33.552591	2025-10-22 00:01:25.5118	\N	2025-10-02 08:01:52.821778	2025-10-02 08:01:52.830408
58	43	avance_salaire	609074.00	645618.44	402566.77	0.03	2	actif	2025-09-04 22:38:02.02038	2025-10-23 17:58:54.955882	2025-10-20 21:10:23.999851	268987.29	2025-10-02 08:01:52.821778	2025-10-02 08:01:52.830408
59	44	consommation_generale	488203.00	512613.15	149564.58	0.05	1	actif	2025-01-25 06:43:49.050915	2025-12-10 11:34:06.523811	2025-10-19 06:03:35.014773	163362.04	2025-10-02 08:01:52.821778	2025-10-02 08:01:52.830408
60	45	consommation_generale	406403.00	430787.18	0.00	0.03	2	solde	2025-08-23 04:47:51.503472	2025-10-27 13:09:36.023722	2025-10-05 17:35:44.457323	\N	2025-10-02 08:01:52.821778	2025-10-02 08:01:52.830408
61	46	avance_salaire	624059.00	661502.54	0.00	0.03	2	solde	2025-03-04 22:04:03.690437	2026-01-25 16:21:28.525878	2025-10-22 00:50:54.875568	\N	2025-10-02 08:01:52.821778	2025-10-02 08:01:52.830408
62	47	consommation_generale	409745.00	430232.25	0.00	0.05	1	solde	2025-02-25 05:45:20.949243	2025-12-15 09:25:02.323807	2025-10-06 07:43:27.062351	\N	2025-10-02 08:01:52.821778	2025-10-02 08:01:52.830408
63	48	depannage	531747.00	558334.35	259780.78	0.05	1	actif	2025-07-05 14:47:43.03935	2025-10-05 08:01:11.2065	2025-10-26 04:32:51.493419	169652.95	2025-10-02 08:01:52.821778	2025-10-02 08:01:52.830408
64	49	consommation_generale	371533.00	386394.32	0.00	0.04	1	solde	2025-01-26 08:38:00.742785	2026-01-05 08:59:59.002137	2025-10-04 21:31:39.143541	\N	2025-10-02 08:01:52.821778	2025-10-02 08:01:52.830408
65	50	consommation_generale	284417.00	292949.51	0.00	0.03	1	solde	2025-01-29 08:34:46.822178	2025-12-20 11:22:39.501083	2025-10-09 14:24:21.384905	\N	2025-10-02 08:01:52.821778	2025-10-02 08:01:52.830408
66	51	consommation_generale	305119.00	323426.14	0.00	0.03	2	solde	2025-01-28 11:35:45.589659	2025-12-22 16:25:14.578875	2025-10-24 04:00:51.098246	\N	2025-10-02 08:01:52.821778	2025-10-02 08:01:52.830408
67	52	avance_salaire	474827.00	522309.70	123919.54	0.05	2	actif	2025-08-29 02:01:20.405515	2025-12-02 14:51:30.461116	2025-10-09 23:00:17.164894	185149.77	2025-10-02 08:01:52.821778	2025-10-02 08:01:52.830408
68	53	consommation_generale	266390.00	287701.20	0.00	0.04	2	solde	2025-06-05 05:23:01.251111	2025-11-08 21:20:41.578292	2025-10-14 06:33:45.844252	\N	2025-10-02 08:01:52.821778	2025-10-02 08:01:52.830408
69	54	avance_salaire	472684.00	519952.40	13164.87	0.05	2	actif	2025-09-06 22:11:07.667394	2025-11-23 14:32:25.035414	2025-10-03 15:41:13.946511	157459.73	2025-10-02 08:01:52.821778	2025-10-02 08:01:52.830408
70	55	consommation_generale	213623.00	226440.38	151212.80	0.03	2	actif	2025-02-28 04:50:27.497469	2026-01-17 19:44:18.076605	2025-10-19 07:51:35.574915	75214.41	2025-10-02 08:01:52.821778	2025-10-02 08:01:52.830408
71	56	consommation_generale	642984.00	707282.40	0.00	0.05	2	solde	2025-06-13 21:28:20.935285	2025-12-09 00:44:54.876838	2025-10-07 22:27:34.638523	\N	2025-10-02 08:01:52.821778	2025-10-02 08:01:52.830408
72	57	avance_salaire	453049.00	480231.94	0.00	0.03	2	solde	2025-02-15 22:58:40.401315	2025-10-29 23:03:15.607535	2025-10-17 03:32:47.153503	\N	2025-10-02 08:01:52.821778	2025-10-02 08:01:52.830408
73	58	consommation_generale	302816.00	311900.48	74274.13	0.03	1	actif	2025-03-15 20:45:08.480088	2025-12-30 15:56:35.009705	2025-10-03 22:49:26.751185	105687.43	2025-10-02 08:01:52.821778	2025-10-02 08:01:52.830408
74	59	consommation_generale	444860.00	489346.00	0.00	0.05	2	solde	2025-04-03 18:28:26.822464	2026-01-09 20:24:12.180729	2025-10-03 15:06:48.919068	\N	2025-10-02 08:01:52.821778	2025-10-02 08:01:52.830408
75	60	depannage	549380.00	565861.40	343199.06	0.03	1	actif	2025-04-16 08:28:08.122468	2025-12-18 15:46:35.776617	2025-10-06 13:48:15.187309	218412.09	2025-10-02 08:01:52.821778	2025-10-02 08:01:52.830408
76	61	avance_salaire	406712.00	418913.36	196280.99	0.03	1	actif	2025-02-15 00:50:33.738758	2025-11-11 07:06:10.291729	2025-10-19 04:45:46.235179	157612.47	2025-10-02 08:01:52.821778	2025-10-02 08:01:52.830408
77	62	consommation_generale	652759.00	704979.72	480201.52	0.04	2	actif	2025-04-19 18:47:48.088537	2025-10-20 20:16:16.033409	2025-10-08 09:04:27.455314	272172.22	2025-10-02 08:01:52.821778	2025-10-02 08:01:52.830408
78	63	depannage	519111.00	550257.66	0.00	0.03	2	solde	2025-02-16 19:38:57.467382	2026-01-07 02:23:41.951301	2025-10-21 00:25:41.756273	\N	2025-10-02 08:01:52.821778	2025-10-02 08:01:52.830408
79	64	avance_salaire	762974.00	785863.22	266211.55	0.03	1	actif	2025-05-30 00:57:53.455338	2025-12-02 19:22:07.89877	2025-10-06 21:40:46.37558	249104.90	2025-10-02 08:01:52.821778	2025-10-02 08:01:52.830408
80	65	avance_salaire	765919.00	827192.52	0.00	0.04	2	solde	2025-04-20 21:18:32.629696	2025-11-12 03:33:05.413851	2025-10-04 23:12:10.659629	\N	2025-10-02 08:01:52.821778	2025-10-02 08:01:52.830408
81	66	avance_salaire	239373.00	253735.38	23972.86	0.03	2	actif	2025-05-16 17:56:25.393843	2026-01-15 07:22:19.302006	2025-10-03 20:40:32.879221	96721.97	2025-10-02 08:01:52.821778	2025-10-02 08:01:52.830408
82	67	depannage	727353.00	800088.30	0.00	0.05	2	solde	2025-07-05 00:42:51.038809	2025-12-18 17:38:41.599811	2025-10-23 16:55:29.271362	\N	2025-10-02 08:01:52.821778	2025-10-02 08:01:52.830408
83	68	depannage	371911.00	383068.33	129923.94	0.03	1	actif	2025-09-26 00:41:05.896386	2025-10-02 21:00:19.852574	2025-10-21 19:29:07.478141	129094.82	2025-10-02 08:01:52.821778	2025-10-02 08:01:52.830408
84	69	consommation_generale	695869.00	716745.07	0.00	0.03	1	solde	2025-07-13 21:34:22.504549	2025-10-07 03:40:52.160828	2025-10-03 19:24:07.815478	\N	2025-10-02 08:01:52.821778	2025-10-02 08:01:52.830408
85	70	avance_salaire	640621.00	679058.26	0.00	0.03	2	solde	2025-02-22 10:32:22.278869	2025-11-21 02:10:39.51127	2025-10-07 01:52:13.075589	\N	2025-10-02 08:01:52.821778	2025-10-02 08:01:52.830408
86	31	depannage	258501.00	268841.04	141078.49	0.04	1	en_retard	2025-08-04 07:05:38.262677	2025-10-31 20:04:53.789638	2025-10-04 01:55:56.590467	85374.85	2025-10-02 08:01:52.823873	2025-10-02 08:01:52.830408
87	32	depannage	523110.00	544034.40	373456.35	0.04	1	actif	2025-08-04 15:07:00.636131	2025-11-11 17:50:27.892024	2025-10-19 03:49:23.636324	224466.37	2025-10-02 08:01:52.823873	2025-10-02 08:01:52.830408
88	33	depannage	239556.00	249138.24	55773.35	0.04	1	actif	2025-09-20 01:37:38.677166	2025-10-22 03:05:18.567732	2025-10-19 21:01:01.267071	97007.74	2025-10-02 08:01:52.823873	2025-10-02 08:01:52.830408
89	34	depannage	401147.00	417192.88	281507.63	0.04	1	en_retard	2025-09-30 13:23:31.605617	2025-10-03 10:16:28.00669	2025-10-16 13:05:50.914015	124405.07	2025-10-02 08:01:52.823873	2025-10-02 08:01:52.830408
90	35	depannage	339176.00	352743.04	261787.61	0.04	1	en_retard	2025-06-08 21:34:27.390891	2025-10-25 09:52:52.796748	2025-10-07 05:20:01.309525	131652.63	2025-10-02 08:01:52.823873	2025-10-02 08:01:52.830408
91	36	depannage	265326.00	275939.04	133068.70	0.04	1	actif	2025-06-15 00:55:52.749634	2025-10-06 10:39:44.17518	2025-10-22 00:25:10.04617	111006.69	2025-10-02 08:01:52.823873	2025-10-02 08:01:52.830408
92	37	depannage	277189.00	288276.56	87455.02	0.04	1	actif	2025-08-15 12:55:09.512317	2025-10-19 15:58:50.100102	2025-10-04 23:42:03.476099	107762.54	2025-10-02 08:01:52.823873	2025-10-02 08:01:52.830408
93	38	depannage	428112.00	445236.48	98208.30	0.04	1	actif	2025-07-30 15:10:19.584172	2025-10-30 06:43:17.758558	2025-10-10 22:09:01.656594	158295.68	2025-10-02 08:01:52.823873	2025-10-02 08:01:52.830408
94	39	depannage	444836.00	462629.44	310724.78	0.04	1	actif	2025-07-10 13:03:03.369047	2025-11-13 02:42:45.097156	2025-10-21 15:37:15.20928	148824.77	2025-10-02 08:01:52.823873	2025-10-02 08:01:52.830408
95	40	depannage	512074.00	532556.96	336149.64	0.04	1	en_retard	2025-09-17 16:04:54.002176	2025-10-20 14:44:36.367408	2025-10-19 21:04:25.805659	166427.85	2025-10-02 08:01:52.823873	2025-10-02 08:01:52.830408
96	41	depannage	290245.00	301854.80	31113.69	0.04	1	actif	2025-07-08 20:46:12.278269	2025-10-07 15:19:57.874286	2025-10-11 20:39:51.74981	127822.48	2025-10-02 08:01:52.823873	2025-10-02 08:01:52.830408
97	42	depannage	268522.00	279262.88	195066.34	0.04	1	en_retard	2025-06-17 08:39:51.394881	2025-10-30 22:46:06.505758	2025-10-08 10:04:06.346709	86170.04	2025-10-02 08:01:52.823873	2025-10-02 08:01:52.830408
98	43	depannage	487193.00	506680.72	76085.31	0.04	1	actif	2025-06-17 13:38:43.054947	2025-10-24 15:51:33.54732	2025-10-08 21:31:29.42414	147113.78	2025-10-02 08:01:52.823873	2025-10-02 08:01:52.830408
99	44	depannage	494504.00	514284.16	269035.68	0.04	1	actif	2025-08-09 21:58:30.720428	2025-11-16 00:52:50.397576	2025-10-09 00:53:26.152799	179193.04	2025-10-02 08:01:52.823873	2025-10-02 08:01:52.830408
100	45	depannage	212996.00	221515.84	57109.81	0.04	1	actif	2025-06-28 09:30:59.284392	2025-10-20 08:37:12.513882	2025-10-06 07:18:43.544081	73807.60	2025-10-02 08:01:52.823873	2025-10-02 08:01:52.830408
101	46	depannage	454798.00	472989.92	250208.01	0.04	1	en_retard	2025-07-13 18:20:11.759923	2025-11-12 16:42:09.376986	2025-10-04 00:43:06.116376	166450.82	2025-10-02 08:01:52.823873	2025-10-02 08:01:52.830408
102	47	depannage	201240.00	209289.60	34150.77	0.04	1	actif	2025-07-28 04:30:12.70999	2025-11-16 05:26:07.68894	2025-10-14 12:53:43.501264	68286.82	2025-10-02 08:01:52.823873	2025-10-02 08:01:52.830408
103	48	depannage	503188.00	523315.52	272597.78	0.04	1	actif	2025-07-08 12:29:40.462174	2025-11-02 18:33:33.92239	2025-10-06 09:36:00.575393	204797.34	2025-10-02 08:01:52.823873	2025-10-02 08:01:52.830408
104	49	depannage	185675.00	193102.00	115594.63	0.04	1	actif	2025-07-16 12:52:11.881984	2025-10-21 18:00:37.810652	2025-10-08 00:48:23.256196	77381.68	2025-10-02 08:01:52.823873	2025-10-02 08:01:52.830408
105	50	depannage	297083.00	308966.32	115761.34	0.04	1	actif	2025-06-21 06:17:11.987134	2025-10-16 15:49:34.849148	2025-10-20 19:40:31.719617	126290.04	2025-10-02 08:01:52.823873	2025-10-02 08:01:52.830408
106	71	consommation_generale	196385.00	206204.25	0.00	0.05	1	solde	2025-04-20 19:44:47.071897	2025-12-16 16:00:04.659628	2025-10-31 06:14:51.823478	\N	2025-10-02 08:01:52.824924	2025-10-02 08:01:52.830408
107	72	avance_salaire	180759.00	186181.77	46154.94	0.03	1	actif	2025-05-04 09:27:47.003317	2025-11-13 18:36:51.653868	2025-10-05 07:57:20.317706	59151.00	2025-10-02 08:01:52.824924	2025-10-02 08:01:52.830408
108	73	consommation_generale	398196.00	418105.80	9105.88	0.05	1	actif	2025-05-02 00:27:21.341766	2025-10-06 16:47:20.839919	2025-10-16 21:51:43.526345	130101.77	2025-10-02 08:01:52.824924	2025-10-02 08:01:52.830408
109	74	avance_salaire	292387.00	301158.61	0.00	0.03	1	solde	2025-05-20 17:04:13.519471	2025-10-09 09:31:02.705386	2025-10-08 19:56:26.760207	\N	2025-10-02 08:01:52.824924	2025-10-02 08:01:52.830408
110	75	avance_salaire	313863.00	323278.89	289531.18	0.03	1	en_retard	2025-09-03 09:56:08.78283	2025-10-23 13:01:12.911615	2025-10-07 09:09:13.927097	116641.27	2025-10-02 08:01:52.824924	2025-10-02 08:01:52.830408
111	76	consommation_generale	277996.00	286335.88	94106.36	0.03	1	actif	2025-08-23 07:07:40.219977	2025-11-17 13:49:08.284715	2025-10-15 21:10:24.088592	118958.60	2025-10-02 08:01:52.824924	2025-10-02 08:01:52.830408
112	77	consommation_generale	251122.00	258655.66	7976.65	0.03	1	actif	2025-05-25 09:54:58.35277	2025-10-21 17:25:48.540371	2025-10-31 12:38:05.180427	76790.00	2025-10-02 08:01:52.824924	2025-10-02 08:01:52.830408
113	78	avance_salaire	426595.00	447924.75	0.00	0.05	1	solde	2025-04-09 09:17:22.129783	2025-11-28 01:16:18.993391	2025-10-27 21:57:11.167211	\N	2025-10-02 08:01:52.824924	2025-10-02 08:01:52.830408
114	79	avance_salaire	395333.00	411146.32	50207.66	0.04	1	actif	2025-06-04 20:36:34.705203	2025-12-14 02:35:54.359225	2025-10-13 19:52:05.681291	142658.40	2025-10-02 08:01:52.824924	2025-10-02 08:01:52.830408
115	80	avance_salaire	395529.00	407394.87	111126.15	0.03	1	actif	2025-08-26 20:07:40.207554	2025-12-07 13:45:55.189172	2025-10-11 20:38:21.363988	141132.86	2025-10-02 08:01:52.824924	2025-10-02 08:01:52.830408
116	81	depannage	333888.00	347243.52	29909.64	0.04	1	actif	2025-08-04 21:03:29.360159	2025-12-03 10:19:07.471419	2025-10-21 01:51:12.094342	122797.90	2025-10-02 08:01:52.824924	2025-10-02 08:01:52.830408
117	82	consommation_generale	217146.00	228003.30	0.00	0.05	1	solde	2025-09-06 17:40:29.815255	2025-10-17 08:21:48.323528	2025-10-13 00:48:32.232687	\N	2025-10-02 08:01:52.824924	2025-10-02 08:01:52.830408
118	83	consommation_generale	234133.00	243498.32	141644.62	0.04	1	en_retard	2025-04-06 01:54:51.113866	2025-11-16 12:32:13.8225	2025-10-24 06:13:18.343898	88914.02	2025-10-02 08:01:52.824924	2025-10-02 08:01:52.830408
119	84	consommation_generale	400879.00	420922.95	349219.25	0.05	1	en_retard	2025-09-06 23:50:07.204611	2025-10-25 11:25:35.648963	2025-10-27 10:05:07.334947	150252.76	2025-10-02 08:01:52.824924	2025-10-02 08:01:52.830408
120	85	depannage	130166.00	134070.98	105136.27	0.03	1	en_retard	2025-06-10 00:34:19.986358	2025-10-30 21:03:46.134336	2025-10-20 22:32:59.14118	58516.73	2025-10-02 08:01:52.824924	2025-10-02 08:01:52.830408
121	86	avance_salaire	138503.00	142658.09	0.00	0.03	1	solde	2025-04-26 20:28:22.712225	2025-10-15 07:18:27.220301	2025-10-08 01:30:43.358383	\N	2025-10-02 08:01:52.824924	2025-10-02 08:01:52.830408
122	87	avance_salaire	440710.00	462745.50	197610.18	0.05	1	actif	2025-09-05 06:13:31.515649	2025-12-03 04:42:51.871747	2025-10-30 09:13:38.999279	183407.98	2025-10-02 08:01:52.824924	2025-10-02 08:01:52.830408
123	88	consommation_generale	325555.00	335321.65	0.00	0.03	1	solde	2025-04-29 16:15:26.080859	2025-10-30 23:28:31.799812	2025-10-12 09:17:57.062514	\N	2025-10-02 08:01:52.824924	2025-10-02 08:01:52.830408
124	89	avance_salaire	114230.00	118799.20	10037.04	0.04	1	actif	2025-09-21 13:02:40.679109	2025-10-05 01:26:06.284735	2025-10-18 04:39:40.853021	45836.56	2025-10-02 08:01:52.824924	2025-10-02 08:01:52.830408
125	90	consommation_generale	268377.00	281795.85	153680.95	0.05	1	actif	2025-07-04 09:59:49.714522	2025-12-15 13:52:40.261311	2025-10-31 02:15:40.97981	111077.17	2025-10-02 08:01:52.824924	2025-10-02 08:01:52.830408
126	75	depannage	106251.00	110501.04	68344.32	0.04	1	en_retard	2025-09-16 01:17:08.112315	2025-09-30 04:40:45.019755	2025-09-26 01:51:14.905822	34382.83	2025-10-02 08:01:52.827134	2025-10-02 08:01:52.830408
127	76	depannage	216373.00	225027.92	147945.37	0.04	1	en_retard	2025-08-15 20:57:07.072737	2025-09-30 17:07:41.226246	2025-09-22 23:40:02.754602	92893.16	2025-10-02 08:01:52.827134	2025-10-02 08:01:52.830408
128	77	depannage	285530.00	296951.20	252698.81	0.04	1	en_retard	2025-10-01 10:04:35.604583	2025-09-21 21:46:03.908998	2025-09-26 22:18:58.589031	88318.04	2025-10-02 08:01:52.827134	2025-10-02 08:01:52.830408
129	78	depannage	108233.00	112562.32	85992.49	0.04	1	en_retard	2025-09-08 10:24:50.127478	2025-10-01 12:35:08.961862	2025-09-27 14:41:39.514937	34076.03	2025-10-02 08:01:52.827134	2025-10-02 08:01:52.830408
130	79	depannage	279193.00	290360.72	220115.69	0.04	1	en_retard	2025-10-01 08:22:32.000441	2025-09-21 20:49:51.279864	2025-09-26 03:56:44.058565	110064.49	2025-10-02 08:01:52.827134	2025-10-02 08:01:52.830408
131	80	depannage	326273.00	339323.92	197682.81	0.04	1	en_retard	2025-09-19 18:58:47.02583	2025-09-18 02:45:39.422616	2025-09-30 12:57:15.395877	111622.56	2025-10-02 08:01:52.827134	2025-10-02 08:01:52.830408
132	81	depannage	264312.00	274884.48	196901.61	0.04	1	en_retard	2025-09-14 06:52:39.689084	2025-09-19 10:35:45.644056	2025-09-28 06:14:45.990496	112594.29	2025-10-02 08:01:52.827134	2025-10-02 08:01:52.830408
133	82	depannage	111994.00	116473.76	69654.91	0.04	1	en_retard	2025-08-13 19:28:30.662871	2025-09-26 00:05:42.17219	2025-09-29 06:52:30.405517	37976.57	2025-10-02 08:01:52.827134	2025-10-02 08:01:52.830408
134	83	depannage	128269.00	133399.76	73199.15	0.04	1	en_retard	2025-09-14 09:20:08.408359	2025-09-28 22:09:00.781374	2025-09-28 12:34:12.455782	45945.02	2025-10-02 08:01:52.827134	2025-10-02 08:01:52.830408
135	84	depannage	178717.00	185865.68	134139.57	0.04	1	en_retard	2025-08-28 07:20:12.841113	2025-09-30 04:12:42.622003	2025-09-25 23:54:16.777714	62609.13	2025-10-02 08:01:52.827134	2025-10-02 08:01:52.830408
136	85	depannage	206345.00	214598.80	128306.27	0.04	1	en_retard	2025-08-13 04:20:37.16385	2025-09-25 00:45:52.496592	2025-09-26 19:22:24.362463	65260.20	2025-10-02 08:01:52.827134	2025-10-02 08:01:52.830408
137	91	depannage	125448.00	129211.44	129211.44	0.03	1	defaut	2025-09-26 18:13:25.415486	2025-09-02 02:17:06.964939	2025-09-14 14:16:40.106171	\N	2025-10-02 08:01:52.828743	2025-10-02 08:01:52.830408
138	92	depannage	246269.00	253657.07	226903.27	0.03	1	en_retard	2025-07-04 01:19:54.583987	2025-09-15 10:13:04.453217	2025-09-30 00:27:23.387704	95463.03	2025-10-02 08:01:52.828743	2025-10-02 08:01:52.830408
139	93	depannage	94413.00	97245.39	82460.81	0.03	1	en_retard	2025-07-09 04:12:41.469997	2025-09-18 05:38:01.881725	2025-09-15 09:20:04.241411	40652.03	2025-10-02 08:01:52.828743	2025-10-02 08:01:52.830408
140	94	depannage	230329.00	239542.16	193275.25	0.04	1	en_retard	2025-09-28 06:19:44.735625	2025-08-26 06:24:38.452614	2025-09-10 05:49:25.930447	98205.68	2025-10-02 08:01:52.828743	2025-10-02 08:01:52.830408
141	95	depannage	125826.00	130859.04	67130.44	0.04	1	en_retard	2025-05-05 21:48:14.128286	2025-09-11 17:52:26.043167	2025-09-04 05:42:57.687551	40031.73	2025-10-02 08:01:52.828743	2025-10-02 08:01:52.830408
142	96	depannage	171432.00	178289.28	95151.91	0.04	1	en_retard	2025-06-25 05:53:19.60818	2025-09-16 01:49:31.083535	2025-10-01 05:10:36.719172	59468.99	2025-10-02 08:01:52.828743	2025-10-02 08:01:52.830408
143	97	avance_salaire	272974.00	281163.22	250963.59	0.03	1	en_retard	2025-05-18 13:10:01.589228	2025-09-20 07:36:08.328073	2025-09-11 02:41:25.624532	101310.64	2025-10-02 08:01:52.828743	2025-10-02 08:01:52.830408
144	98	avance_salaire	272776.00	280959.28	203491.44	0.03	1	en_retard	2025-08-12 16:59:35.541902	2025-08-28 14:38:19.813629	2025-09-22 19:45:56.589763	120257.41	2025-10-02 08:01:52.828743	2025-10-02 08:01:52.830408
145	99	depannage	215264.00	221721.92	221721.92	0.03	1	defaut	2025-09-08 14:57:39.559141	2025-08-22 23:22:31.610556	2025-09-22 01:44:58.439321	\N	2025-10-02 08:01:52.828743	2025-10-02 08:01:52.830408
146	91	depannage	181274.00	188524.96	188524.96	0.04	1	defaut	2025-09-17 18:09:25.729052	2025-09-30 06:09:20.185871	2025-09-24 11:13:56.704175	\N	2025-10-02 08:01:52.829713	2025-10-02 08:01:52.830408
147	92	depannage	87836.00	91349.44	91349.44	0.04	1	defaut	2025-09-15 14:44:24.718995	2025-08-09 18:40:55.402578	2025-09-24 07:11:42.193941	\N	2025-10-02 08:01:52.829713	2025-10-02 08:01:52.830408
148	93	depannage	105672.00	109898.88	109898.88	0.04	1	defaut	2025-09-12 23:18:48.980555	2025-08-18 05:29:54.214783	2025-08-27 20:36:18.169902	\N	2025-10-02 08:01:52.829713	2025-10-02 08:01:52.830408
149	94	depannage	89016.00	92576.64	92576.64	0.04	1	defaut	2025-09-06 16:06:12.807148	2025-08-27 08:35:50.44413	2025-08-29 19:11:07.292564	\N	2025-10-02 08:01:52.829713	2025-10-02 08:01:52.830408
150	95	depannage	184221.00	191589.84	191589.84	0.04	1	defaut	2025-08-25 23:38:18.149877	2025-08-14 23:29:49.820225	2025-09-19 00:54:05.807319	\N	2025-10-02 08:01:52.829713	2025-10-02 08:01:52.830408
\.


--
-- Data for Name: demandes_credit_longues; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.demandes_credit_longues (id, numero_demande, utilisateur_id, type_credit, montant_demande, duree_mois, objectif, statut, date_soumission, date_decision, decideur_id, montant_approuve, taux_approuve, notes_decision, score_au_moment_demande, niveau_risque_evaluation, date_creation, date_modification) FROM stdin;
1	LCR-20251002-5038	1	investissement	2076643.00	24	Achat de vÃ©hicule professionnel	soumise	2025-09-24 11:05:22.652533	2025-08-23 04:33:14.44043	\N	1810600.00	0.08	Revenus insuffisants pour le montant demandÃ©	9.2	tres_bas	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978
2	LCR-20251002-5564	2	consommation_generale	3152160.00	25	DÃ©veloppement d'activitÃ© commerciale	soumise	2025-06-19 06:58:35.753698	2025-09-10 09:42:25.813432	2	\N	0.10	En cours d'analyse par le comitÃ©	8.9	tres_bas	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978
3	LCR-20251002-8526	4	consommation_generale	2161474.00	21	Travaux de rÃ©novation immobiliÃ¨re	en_examen	2025-09-21 03:56:15.818959	2025-08-10 11:16:48.225331	\N	1267353.00	0.09	Dossier complet - Approbation accordÃ©e	8.7	tres_bas	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978
4	LCR-20251002-2432	5	investissement	3528556.00	24	DÃ©veloppement d'activitÃ© commerciale	soumise	2025-08-09 11:16:29.738186	\N	\N	\N	\N	Documents complÃ©mentaires requis	8.3	bas	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978
5	LCR-20251002-1737	8	consommation_generale	2110375.00	25	Achat de vÃ©hicule professionnel	en_examen	2025-07-04 18:57:38.967167	2025-09-28 21:29:08.697724	2	\N	0.07	Revenus insuffisants pour le montant demandÃ©	8.4	bas	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978
6	LCR-20251002-8379	12	consommation_generale	3653378.00	24	Achat de vÃ©hicule professionnel	en_examen	2025-07-12 21:14:12.076735	2025-08-26 23:08:10.287799	\N	\N	\N	Revenus insuffisants pour le montant demandÃ©	8.1	bas	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978
7	LCR-20251002-5895	13	consommation_generale	1986301.00	30	Achat de vÃ©hicule professionnel	en_examen	2025-06-19 13:41:09.040968	2025-09-17 08:23:40.378878	2	1014427.00	0.08	En cours d'analyse par le comitÃ©	8.0	bas	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978
8	LCR-20251002-1064	16	investissement	3342408.00	30	Achat de vÃ©hicule professionnel	en_examen	2025-06-24 03:37:42.157471	\N	2	2303128.00	0.08	Revenus insuffisants pour le montant demandÃ©	8.2	bas	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978
9	LCR-20251002-7046	21	consommation_generale	2632677.00	18	Travaux de rÃ©novation immobiliÃ¨re	soumise	2025-07-17 12:34:44.249581	2025-08-13 23:25:05.764421	2	\N	0.08	En cours d'analyse par le comitÃ©	8.4	bas	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978
10	LCR-20251002-2697	24	consommation_generale	1283881.00	18	DÃ©veloppement d'activitÃ© commerciale	soumise	2025-06-12 05:13:10.570338	2025-09-03 21:58:47.062608	2	\N	\N	Dossier complet - Approbation accordÃ©e	8.6	bas	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978
11	LCR-20251002-4575	26	consommation_generale	2497720.00	26	DÃ©veloppement d'activitÃ© commerciale	rejetee	2025-08-19 05:45:32.346574	2025-08-29 02:14:22.341604	2	1490881.00	0.06	Dossier complet - Approbation accordÃ©e	8.2	bas	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978
12	LCR-20251002-9459	28	consommation_generale	3236778.00	30	Investissement dans Ã©quipements professionnels	en_examen	2025-06-08 14:49:23.576799	2025-08-07 10:20:45.860141	2	978118.00	0.09	Dossier complet - Approbation accordÃ©e	8.7	tres_bas	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978
13	LCR-20251002-4502	31	investissement	3979871.00	19	Travaux de rÃ©novation immobiliÃ¨re	rejetee	2025-08-27 12:52:44.578988	2025-09-24 19:53:05.682008	\N	2239694.00	0.09	Documents complÃ©mentaires requis	7.2	moyen	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978
14	LCR-20251002-0391	33	investissement	3722818.00	31	Travaux de rÃ©novation immobiliÃ¨re	en_examen	2025-08-16 17:35:24.996418	\N	\N	\N	\N	Documents complÃ©mentaires requis	7.0	moyen	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978
15	LCR-20251002-2030	35	consommation_generale	1652047.00	21	Achat de vÃ©hicule professionnel	en_examen	2025-09-27 08:08:29.024662	2025-08-28 07:45:25.388919	\N	\N	\N	Revenus insuffisants pour le montant demandÃ©	7.1	moyen	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978
16	LCR-20251002-4047	36	investissement	1666072.00	35	DÃ©veloppement d'activitÃ© commerciale	en_examen	2025-07-01 09:45:08.354801	\N	2	\N	\N	Revenus insuffisants pour le montant demandÃ©	6.9	moyen	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978
17	LCR-20251002-1305	37	consommation_generale	3038096.00	26	DÃ©veloppement d'activitÃ© commerciale	soumise	2025-07-06 13:13:57.151956	\N	2	\N	\N	En cours d'analyse par le comitÃ©	6.7	moyen	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978
18	LCR-20251002-5093	40	consommation_generale	2344485.00	17	Travaux de rÃ©novation immobiliÃ¨re	soumise	2025-06-15 00:33:43.382378	\N	2	\N	\N	Revenus insuffisants pour le montant demandÃ©	7.0	moyen	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978
19	LCR-20251002-1144	43	consommation_generale	2126928.00	25	Achat de vÃ©hicule professionnel	approuvee	2025-06-12 04:25:24.727717	2025-09-06 03:44:50.636074	2	1762261.00	\N	Revenus insuffisants pour le montant demandÃ©	6.5	moyen	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978
20	LCR-20251002-3670	49	consommation_generale	3124246.00	26	DÃ©veloppement d'activitÃ© commerciale	soumise	2025-06-12 19:24:50.002033	\N	2	\N	\N	Dossier complet - Approbation accordÃ©e	6.2	moyen	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978
21	LCR-20251002-8352	50	consommation_generale	2006786.00	16	Achat de vÃ©hicule professionnel	en_examen	2025-06-21 05:59:32.398228	\N	\N	2844953.00	0.09	Dossier complet - Approbation accordÃ©e	6.6	moyen	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978
22	LCR-20251002-1439	51	consommation_generale	3585207.00	32	Achat de vÃ©hicule professionnel	en_examen	2025-07-31 01:05:55.448039	2025-08-16 16:36:18.166181	\N	\N	0.08	Revenus insuffisants pour le montant demandÃ©	6.9	moyen	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978
23	LCR-20251002-5664	52	consommation_generale	3656640.00	24	Achat de vÃ©hicule professionnel	approuvee	2025-09-24 01:51:06.12193	2025-09-12 18:08:58.423044	2	1629329.00	\N	Documents complÃ©mentaires requis	6.3	moyen	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978
24	LCR-20251002-5948	56	investissement	1606552.00	26	DÃ©veloppement d'activitÃ© commerciale	soumise	2025-07-23 15:53:11.749871	2025-10-02 06:46:28.08739	\N	\N	0.07	Revenus insuffisants pour le montant demandÃ©	7.0	moyen	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978
25	LCR-20251002-5055	63	investissement	3639865.00	17	Travaux de rÃ©novation immobiliÃ¨re	soumise	2025-08-07 12:25:49.166388	2025-09-02 18:29:01.242301	\N	1600244.00	0.07	Documents complÃ©mentaires requis	7.0	moyen	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978
26	LCR-20251002-9659	66	investissement	1590400.00	34	Achat de vÃ©hicule professionnel	en_examen	2025-07-27 02:36:34.25995	\N	2	\N	0.06	Dossier complet - Approbation accordÃ©e	7.1	moyen	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978
27	LCR-20251002-9829	68	consommation_generale	2610680.00	16	DÃ©veloppement d'activitÃ© commerciale	soumise	2025-08-20 15:24:46.962512	2025-09-06 02:13:20.95794	2	1896679.00	\N	Revenus insuffisants pour le montant demandÃ©	6.3	moyen	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978
28	LCR-20251002-2608	69	investissement	1207517.00	29	Achat de vÃ©hicule professionnel	rejetee	2025-08-08 23:14:05.513904	2025-09-29 10:26:45.56466	\N	\N	\N	Dossier complet - Approbation accordÃ©e	6.7	moyen	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978
29	LCR-20251002-7314	70	consommation_generale	1333737.00	20	Investissement dans Ã©quipements professionnels	en_examen	2025-06-07 07:37:15.038013	\N	2	\N	\N	Revenus insuffisants pour le montant demandÃ©	5.2	moyen	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978
30	LCR-20251002-3920	81	consommation_generale	1537120.00	27	Travaux de rÃ©novation immobiliÃ¨re	soumise	2025-07-27 07:03:21.41427	\N	\N	\N	0.09	Dossier complet - Approbation accordÃ©e	5.3	moyen	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978
\.


--
-- Data for Name: historique_paiements; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.historique_paiements (id, credit_id, utilisateur_id, montant, date_paiement, date_prevue, jours_retard, type_paiement, frais_retard, date_creation) FROM stdin;
1	2	2	1656134.36	2025-05-21 11:11:10.958657	2025-05-21 11:11:10.958657	0	a_temps	0.00	2025-10-02 08:01:52.834391
2	4	4	741956.69	2025-10-11 22:37:27.230529	2025-10-11 22:37:27.230529	0	a_temps	0.00	2025-10-02 08:01:52.834391
3	4	4	776174.22	2025-11-10 22:37:27.230529	2025-11-10 22:37:27.230529	0	a_temps	0.00	2025-10-02 08:01:52.834391
4	5	5	1232544.87	2025-02-26 20:09:49.416982	2025-02-26 20:09:49.416982	0	a_temps	0.00	2025-10-02 08:01:52.834391
5	8	8	807085.72	2025-06-20 22:49:13.906371	2025-06-20 22:49:13.906371	0	a_temps	0.00	2025-10-02 08:01:52.834391
6	9	9	320861.11	2025-04-26 13:31:05.74943	2025-04-26 13:31:05.74943	0	a_temps	0.00	2025-10-02 08:01:52.834391
7	11	11	562657.69	2024-12-06 09:34:24.688008	2024-12-06 09:34:24.688008	0	a_temps	0.00	2025-10-02 08:01:52.834391
8	13	13	806488.35	2025-04-21 16:20:04.641186	2025-04-21 16:20:04.641186	0	a_temps	0.00	2025-10-02 08:01:52.834391
9	13	13	733434.25	2025-05-21 16:20:04.641186	2025-05-21 16:20:04.641186	0	a_temps	0.00	2025-10-02 08:01:52.834391
10	13	13	682603.26	2025-06-20 16:20:04.641186	2025-06-20 16:20:04.641186	0	a_temps	0.00	2025-10-02 08:01:52.834391
11	14	14	637696.22	2025-07-11 18:38:40.037667	2025-07-11 18:38:40.037667	0	a_temps	0.00	2025-10-02 08:01:52.834391
12	14	14	688262.66	2025-08-10 18:38:40.037667	2025-08-10 18:38:40.037667	0	a_temps	0.00	2025-10-02 08:01:52.834391
13	14	14	632683.14	2025-09-09 18:38:40.037667	2025-09-09 18:38:40.037667	0	a_temps	0.00	2025-10-02 08:01:52.834391
14	15	15	1121707.37	2025-07-06 11:34:28.679069	2025-07-06 11:34:28.679069	0	a_temps	0.00	2025-10-02 08:01:52.834391
15	16	16	1359380.46	2025-04-28 15:43:21.25365	2025-04-28 15:43:21.25365	0	a_temps	0.00	2025-10-02 08:01:52.834391
16	17	17	1569121.53	2025-10-11 23:24:56.371407	2025-10-11 23:24:56.371407	0	a_temps	0.00	2025-10-02 08:01:52.834391
17	19	19	277420.21	2025-09-08 02:56:52.774093	2025-09-08 02:56:52.774093	0	a_temps	0.00	2025-10-02 08:01:52.834391
18	19	19	256903.98	2025-10-08 02:56:52.774093	2025-10-08 02:56:52.774093	0	a_temps	0.00	2025-10-02 08:01:52.834391
19	19	19	266357.91	2025-11-07 02:56:52.774093	2025-11-07 02:56:52.774093	0	a_temps	0.00	2025-10-02 08:01:52.834391
20	20	20	1761839.46	2025-10-27 18:53:28.85246	2025-10-27 18:53:28.85246	0	a_temps	0.00	2025-10-02 08:01:52.834391
21	22	22	1422745.67	2024-11-12 17:49:08.792501	2024-11-12 17:49:08.792501	0	a_temps	0.00	2025-10-02 08:01:52.834391
22	23	23	694574.10	2025-03-11 20:42:38.659398	2025-03-11 20:42:38.659398	0	a_temps	0.00	2025-10-02 08:01:52.834391
23	25	25	1201898.53	2025-01-14 23:16:49.089899	2025-01-14 23:16:49.089899	0	a_temps	0.00	2025-10-02 08:01:52.834391
24	27	27	585402.95	2025-03-15 01:12:03.980074	2025-03-15 01:12:03.980074	0	a_temps	0.00	2025-10-02 08:01:52.834391
25	29	29	615017.21	2025-03-25 11:48:49.360185	2025-03-25 11:48:49.360185	0	a_temps	0.00	2025-10-02 08:01:52.834391
26	46	31	219601.67	2025-10-16 10:37:59.911985	2025-10-16 10:37:59.911985	0	a_temps	0.00	2025-10-02 08:01:52.834391
27	46	31	264023.20	2025-11-15 10:37:59.911985	2025-11-15 10:37:59.911985	0	a_temps	0.00	2025-10-02 08:01:52.834391
28	47	32	282415.29	2025-10-17 00:08:00.483171	2025-10-17 00:08:00.483171	0	a_temps	0.00	2025-10-02 08:01:52.834391
29	47	32	313681.15	2025-11-16 00:08:00.483171	2025-11-16 00:08:00.483171	0	a_temps	0.00	2025-10-02 08:01:52.834391
30	48	33	0.00	2025-03-28 17:10:17.617682	2025-03-28 17:10:17.617682	52	manque	29000.00	2025-10-02 08:01:52.834391
31	48	33	0.00	2025-04-27 17:10:17.617682	2025-04-27 17:10:17.617682	81	manque	29500.00	2025-10-02 08:01:52.834391
32	48	33	0.00	2025-05-27 17:10:17.617682	2025-05-27 17:10:17.617682	41	manque	24500.00	2025-10-02 08:01:52.834391
33	49	34	266318.49	2025-02-06 20:04:53.324022	2025-02-06 20:04:53.324022	0	a_temps	0.00	2025-10-02 08:01:52.834391
34	49	34	289614.71	2025-03-08 20:04:53.324022	2025-03-08 20:04:53.324022	0	a_temps	0.00	2025-10-02 08:01:52.834391
35	50	35	0.00	2025-10-26 00:36:31.17746	2025-10-26 00:36:31.17746	44	manque	28000.00	2025-10-02 08:01:52.834391
36	50	35	0.00	2025-11-25 00:36:31.17746	2025-11-25 00:36:31.17746	53	manque	21000.00	2025-10-02 08:01:52.834391
37	51	36	725314.38	2025-03-11 15:55:56.901817	2025-03-11 15:55:56.901817	0	a_temps	0.00	2025-10-02 08:01:52.834391
38	55	40	290204.98	2025-09-19 10:54:15.038803	2025-09-19 10:54:15.038803	0	a_temps	0.00	2025-10-02 08:01:52.834391
39	55	40	303858.94	2025-10-19 10:54:15.038803	2025-10-19 10:54:15.038803	0	a_temps	0.00	2025-10-02 08:01:52.834391
40	56	41	474352.78	2025-03-25 18:35:10.193316	2025-03-25 18:35:10.193316	0	a_temps	0.00	2025-10-02 08:01:52.834391
41	57	42	242675.62	2025-03-20 01:13:00.04763	2025-03-20 01:13:00.04763	0	a_temps	0.00	2025-10-02 08:01:52.834391
42	57	42	236675.83	2025-04-19 01:13:00.04763	2025-04-19 01:13:00.04763	0	a_temps	0.00	2025-10-02 08:01:52.834391
43	58	43	302868.58	2025-10-04 22:38:02.02038	2025-10-04 22:38:02.02038	0	a_temps	0.00	2025-10-02 08:01:52.834391
44	60	45	232057.10	2025-09-22 04:47:51.503472	2025-09-22 04:47:51.503472	0	a_temps	0.00	2025-10-02 08:01:52.834391
45	60	45	198343.01	2025-10-22 04:47:51.503472	2025-10-22 04:47:51.503472	0	a_temps	0.00	2025-10-02 08:01:52.834391
46	61	46	331556.32	2025-04-03 22:04:03.690437	2025-04-03 22:04:03.690437	0	a_temps	0.00	2025-10-02 08:01:52.834391
47	61	46	299971.48	2025-05-03 22:04:03.690437	2025-05-03 22:04:03.690437	0	a_temps	0.00	2025-10-02 08:01:52.834391
48	62	47	454148.40	2025-03-27 05:45:20.949243	2025-03-27 05:45:20.949243	0	a_temps	0.00	2025-10-02 08:01:52.834391
49	64	49	366460.09	2025-02-25 08:38:00.742785	2025-02-25 08:38:00.742785	0	a_temps	0.00	2025-10-02 08:01:52.834391
50	65	50	281647.96	2025-02-28 08:34:46.822178	2025-02-28 08:34:46.822178	0	a_temps	0.00	2025-10-02 08:01:52.834391
51	66	51	167133.87	2025-02-27 11:35:45.589659	2025-02-27 11:35:45.589659	0	a_temps	0.00	2025-10-02 08:01:52.834391
52	66	51	161264.50	2025-03-29 11:35:45.589659	2025-03-29 11:35:45.589659	0	a_temps	0.00	2025-10-02 08:01:52.834391
53	67	52	278624.93	2025-10-01 02:01:20.405515	2025-09-28 02:01:20.405515	3	en_retard	1500.00	2025-10-02 08:01:52.834391
54	68	53	140989.61	2025-07-05 05:23:01.251111	2025-07-05 05:23:01.251111	0	a_temps	0.00	2025-10-02 08:01:52.834391
55	68	53	140110.20	2025-08-04 05:23:01.251111	2025-08-04 05:23:01.251111	0	a_temps	0.00	2025-10-02 08:01:52.834391
56	69	54	245957.67	2025-10-06 22:11:07.667394	2025-10-06 22:11:07.667394	0	a_temps	0.00	2025-10-02 08:01:52.834391
57	71	56	372810.99	2025-07-13 21:28:20.935285	2025-07-13 21:28:20.935285	0	a_temps	0.00	2025-10-02 08:01:52.834391
58	71	56	340789.53	2025-08-12 21:28:20.935285	2025-08-12 21:28:20.935285	0	a_temps	0.00	2025-10-02 08:01:52.834391
59	72	57	258440.99	2025-03-17 22:58:40.401315	2025-03-17 22:58:40.401315	0	a_temps	0.00	2025-10-02 08:01:52.834391
60	72	57	223207.23	2025-04-16 22:58:40.401315	2025-04-16 22:58:40.401315	0	a_temps	0.00	2025-10-02 08:01:52.834391
61	74	59	250810.82	2025-05-03 18:28:26.822464	2025-05-03 18:28:26.822464	0	a_temps	0.00	2025-10-02 08:01:52.834391
62	74	59	220784.06	2025-06-02 18:28:26.822464	2025-06-02 18:28:26.822464	0	a_temps	0.00	2025-10-02 08:01:52.834391
63	77	62	370762.42	2025-05-19 18:47:48.088537	2025-05-19 18:47:48.088537	0	a_temps	0.00	2025-10-02 08:01:52.834391
64	78	63	265505.88	2025-03-18 19:38:57.467382	2025-03-18 19:38:57.467382	0	a_temps	0.00	2025-10-02 08:01:52.834391
65	78	63	268367.44	2025-04-17 19:38:57.467382	2025-04-17 19:38:57.467382	0	a_temps	0.00	2025-10-02 08:01:52.834391
66	80	65	410329.58	2025-05-20 21:18:32.629696	2025-05-20 21:18:32.629696	0	a_temps	0.00	2025-10-02 08:01:52.834391
67	80	65	372264.66	2025-06-19 21:18:32.629696	2025-06-19 21:18:32.629696	0	a_temps	0.00	2025-10-02 08:01:52.834391
68	82	67	386437.42	2025-08-04 00:42:51.038809	2025-08-04 00:42:51.038809	0	a_temps	0.00	2025-10-02 08:01:52.834391
69	82	67	412990.89	2025-09-03 00:42:51.038809	2025-09-03 00:42:51.038809	0	a_temps	0.00	2025-10-02 08:01:52.834391
70	84	69	756509.18	2025-08-12 21:34:22.504549	2025-08-12 21:34:22.504549	0	a_temps	0.00	2025-10-02 08:01:52.834391
71	85	70	327637.92	2025-03-24 10:32:22.278869	2025-03-24 10:32:22.278869	0	a_temps	0.00	2025-10-02 08:01:52.834391
72	85	70	358475.37	2025-04-23 10:32:22.278869	2025-04-23 10:32:22.278869	0	a_temps	0.00	2025-10-02 08:01:52.834391
73	86	31	0.00	2025-09-03 07:05:38.262677	2025-09-03 07:05:38.262677	39	manque	40500.00	2025-10-02 08:01:52.834391
74	86	31	0.00	2025-10-03 07:05:38.262677	2025-10-03 07:05:38.262677	37	manque	23000.00	2025-10-02 08:01:52.834391
75	86	31	0.00	2025-11-02 07:05:38.262677	2025-11-02 07:05:38.262677	48	manque	20500.00	2025-10-02 08:01:52.834391
76	89	34	0.00	2025-10-30 13:23:31.605617	2025-10-30 13:23:31.605617	31	manque	16000.00	2025-10-02 08:01:52.834391
77	89	34	0.00	2025-11-29 13:23:31.605617	2025-11-29 13:23:31.605617	72	manque	37000.00	2025-10-02 08:01:52.834391
78	89	34	0.00	2025-12-29 13:23:31.605617	2025-12-29 13:23:31.605617	77	manque	32500.00	2025-10-02 08:01:52.834391
79	90	35	0.00	2025-07-08 21:34:27.390891	2025-07-08 21:34:27.390891	74	manque	36500.00	2025-10-02 08:01:52.834391
80	95	40	0.00	2025-10-17 16:04:54.002176	2025-10-17 16:04:54.002176	44	manque	40500.00	2025-10-02 08:01:52.834391
81	95	40	0.00	2025-11-16 16:04:54.002176	2025-11-16 16:04:54.002176	62	manque	27500.00	2025-10-02 08:01:52.834391
82	97	42	0.00	2025-07-17 08:39:51.394881	2025-07-17 08:39:51.394881	85	manque	26000.00	2025-10-02 08:01:52.834391
83	97	42	0.00	2025-08-16 08:39:51.394881	2025-08-16 08:39:51.394881	88	manque	24000.00	2025-10-02 08:01:52.834391
84	97	42	0.00	2025-09-15 08:39:51.394881	2025-09-15 08:39:51.394881	57	manque	26500.00	2025-10-02 08:01:52.834391
85	101	46	0.00	2025-08-12 18:20:11.759923	2025-08-12 18:20:11.759923	58	manque	36000.00	2025-10-02 08:01:52.834391
86	106	71	224327.82	2025-05-20 19:44:47.071897	2025-05-20 19:44:47.071897	0	a_temps	0.00	2025-10-02 08:01:52.834391
87	109	74	302961.31	2025-06-19 17:04:13.519471	2025-06-19 17:04:13.519471	0	a_temps	0.00	2025-10-02 08:01:52.834391
88	110	75	0.00	2025-10-03 09:56:08.78283	2025-10-03 09:56:08.78283	71	manque	32000.00	2025-10-02 08:01:52.834391
89	110	75	0.00	2025-11-02 09:56:08.78283	2025-11-02 09:56:08.78283	35	manque	21000.00	2025-10-02 08:01:52.834391
90	113	78	449519.09	2025-05-09 09:17:22.129783	2025-05-09 09:17:22.129783	0	a_temps	0.00	2025-10-02 08:01:52.834391
91	117	82	246394.74	2025-10-06 17:40:29.815255	2025-10-06 17:40:29.815255	0	a_temps	0.00	2025-10-02 08:01:52.834391
92	118	83	0.00	2025-05-06 01:54:51.113866	2025-05-06 01:54:51.113866	53	manque	31500.00	2025-10-02 08:01:52.834391
93	119	84	0.00	2025-10-06 23:50:07.204611	2025-10-06 23:50:07.204611	33	manque	34500.00	2025-10-02 08:01:52.834391
94	120	85	0.00	2025-07-10 00:34:19.986358	2025-07-10 00:34:19.986358	71	manque	17500.00	2025-10-02 08:01:52.834391
95	121	86	145491.94	2025-05-26 20:28:22.712225	2025-05-26 20:28:22.712225	0	a_temps	0.00	2025-10-02 08:01:52.834391
96	123	88	357451.58	2025-05-29 16:15:26.080859	2025-05-29 16:15:26.080859	0	a_temps	0.00	2025-10-02 08:01:52.834391
97	126	75	0.00	2025-10-16 01:17:08.112315	2025-10-16 01:17:08.112315	54	manque	43000.00	2025-10-02 08:01:52.834391
98	127	76	0.00	2025-09-14 20:57:07.072737	2025-09-14 20:57:07.072737	88	manque	21000.00	2025-10-02 08:01:52.834391
99	128	77	0.00	2025-10-31 10:04:35.604583	2025-10-31 10:04:35.604583	48	manque	36500.00	2025-10-02 08:01:52.834391
100	129	78	0.00	2025-10-08 10:24:50.127478	2025-10-08 10:24:50.127478	42	manque	38500.00	2025-10-02 08:01:52.834391
101	130	79	0.00	2025-10-31 08:22:32.000441	2025-10-31 08:22:32.000441	66	manque	37500.00	2025-10-02 08:01:52.834391
102	131	80	0.00	2025-10-19 18:58:47.02583	2025-10-19 18:58:47.02583	87	manque	22000.00	2025-10-02 08:01:52.834391
103	132	81	0.00	2025-10-14 06:52:39.689084	2025-10-14 06:52:39.689084	86	manque	25500.00	2025-10-02 08:01:52.834391
104	133	82	0.00	2025-09-12 19:28:30.662871	2025-09-12 19:28:30.662871	60	manque	19000.00	2025-10-02 08:01:52.834391
105	133	82	0.00	2025-10-12 19:28:30.662871	2025-10-12 19:28:30.662871	59	manque	39000.00	2025-10-02 08:01:52.834391
106	134	83	0.00	2025-10-14 09:20:08.408359	2025-10-14 09:20:08.408359	46	manque	17500.00	2025-10-02 08:01:52.834391
107	134	83	0.00	2025-11-13 09:20:08.408359	2025-11-13 09:20:08.408359	55	manque	25500.00	2025-10-02 08:01:52.834391
108	134	83	0.00	2025-12-13 09:20:08.408359	2025-12-13 09:20:08.408359	89	manque	17500.00	2025-10-02 08:01:52.834391
109	135	84	0.00	2025-09-27 07:20:12.841113	2025-09-27 07:20:12.841113	88	manque	19500.00	2025-10-02 08:01:52.834391
110	136	85	0.00	2025-09-12 04:20:37.16385	2025-09-12 04:20:37.16385	36	manque	17000.00	2025-10-02 08:01:52.834391
111	137	91	0.00	2025-10-26 18:13:25.415486	2025-10-26 18:13:25.415486	59	manque	26000.00	2025-10-02 08:01:52.834391
112	137	91	0.00	2025-11-25 18:13:25.415486	2025-11-25 18:13:25.415486	56	manque	23000.00	2025-10-02 08:01:52.834391
113	138	92	0.00	2025-08-03 01:19:54.583987	2025-08-03 01:19:54.583987	77	manque	36500.00	2025-10-02 08:01:52.834391
114	138	92	0.00	2025-09-02 01:19:54.583987	2025-09-02 01:19:54.583987	45	manque	16500.00	2025-10-02 08:01:52.834391
115	138	92	0.00	2025-10-02 01:19:54.583987	2025-10-02 01:19:54.583987	40	manque	25000.00	2025-10-02 08:01:52.834391
116	139	93	0.00	2025-08-08 04:12:41.469997	2025-08-08 04:12:41.469997	40	manque	40000.00	2025-10-02 08:01:52.834391
117	140	94	0.00	2025-10-28 06:19:44.735625	2025-10-28 06:19:44.735625	40	manque	24000.00	2025-10-02 08:01:52.834391
118	141	95	0.00	2025-06-04 21:48:14.128286	2025-06-04 21:48:14.128286	75	manque	16500.00	2025-10-02 08:01:52.834391
119	142	96	0.00	2025-07-25 05:53:19.60818	2025-07-25 05:53:19.60818	78	manque	29500.00	2025-10-02 08:01:52.834391
120	142	96	0.00	2025-08-24 05:53:19.60818	2025-08-24 05:53:19.60818	70	manque	26000.00	2025-10-02 08:01:52.834391
121	142	96	0.00	2025-09-23 05:53:19.60818	2025-09-23 05:53:19.60818	38	manque	17000.00	2025-10-02 08:01:52.834391
122	143	97	0.00	2025-06-17 13:10:01.589228	2025-06-17 13:10:01.589228	82	manque	34000.00	2025-10-02 08:01:52.834391
123	143	97	0.00	2025-07-17 13:10:01.589228	2025-07-17 13:10:01.589228	63	manque	16500.00	2025-10-02 08:01:52.834391
124	144	98	0.00	2025-09-11 16:59:35.541902	2025-09-11 16:59:35.541902	32	manque	31000.00	2025-10-02 08:01:52.834391
125	144	98	0.00	2025-10-11 16:59:35.541902	2025-10-11 16:59:35.541902	37	manque	19000.00	2025-10-02 08:01:52.834391
126	145	99	0.00	2025-10-08 14:57:39.559141	2025-10-08 14:57:39.559141	77	manque	26500.00	2025-10-02 08:01:52.834391
127	145	99	0.00	2025-11-07 14:57:39.559141	2025-11-07 14:57:39.559141	39	manque	17500.00	2025-10-02 08:01:52.834391
128	146	91	0.00	2025-10-17 18:09:25.729052	2025-10-17 18:09:25.729052	62	manque	34000.00	2025-10-02 08:01:52.834391
129	146	91	0.00	2025-11-16 18:09:25.729052	2025-11-16 18:09:25.729052	34	manque	24000.00	2025-10-02 08:01:52.834391
130	146	91	0.00	2025-12-16 18:09:25.729052	2025-12-16 18:09:25.729052	58	manque	19000.00	2025-10-02 08:01:52.834391
131	147	92	0.00	2025-10-15 14:44:24.718995	2025-10-15 14:44:24.718995	65	manque	18000.00	2025-10-02 08:01:52.834391
132	148	93	0.00	2025-10-12 23:18:48.980555	2025-10-12 23:18:48.980555	84	manque	35000.00	2025-10-02 08:01:52.834391
133	149	94	0.00	2025-10-06 16:06:12.807148	2025-10-06 16:06:12.807148	86	manque	42000.00	2025-10-02 08:01:52.834391
134	149	94	0.00	2025-11-05 16:06:12.807148	2025-11-05 16:06:12.807148	37	manque	18500.00	2025-10-02 08:01:52.834391
135	150	95	0.00	2025-09-24 23:38:18.149877	2025-09-24 23:38:18.149877	59	manque	31000.00	2025-10-02 08:01:52.834391
\.


--
-- Data for Name: historique_scores; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.historique_scores (id, utilisateur_id, score_credit, score_850, score_precedent, changement, niveau_risque, montant_eligible, evenement_declencheur, ratio_paiements_temps, tendance, date_calcul) FROM stdin;
1	1	7.9	734	7.6	0.3	moyen	1250000.00	Paiement Ã  temps	0.89	amelioration	2025-02-19 08:01:52.856086
2	1	8.3	756	7.9	0.4	bas	1750000.00	Nouveau crÃ©dit accordÃ©	0.90	amelioration	2025-04-05 08:01:52.856086
3	1	8.6	773	8.3	0.3	bas	1750000.00	Paiement Ã  temps	0.91	amelioration	2025-05-20 08:01:52.856086
4	1	8.7	778	8.6	0.1	bas	1750000.00	Paiement en retard	0.91	stable	2025-07-04 08:01:52.856086
5	1	9.0	795	8.7	0.3	bas	1750000.00	Paiement Ã  temps	0.92	amelioration	2025-08-18 08:01:52.856086
6	1	9.1	800	9.0	0.1	bas	1750000.00	Paiement Ã  temps	0.92	stable	2025-10-02 08:01:52.856086
7	2	6.7	668	6.1	0.6	moyen	900000.00	Nouveau crÃ©dit accordÃ©	0.85	amelioration	2025-05-20 08:01:52.856086
8	2	7.5	712	6.7	0.8	moyen	900000.00	Nouveau crÃ©dit accordÃ©	0.88	amelioration	2025-07-04 08:01:52.856086
9	2	8.2	751	7.5	0.7	bas	1260000.00	Paiement Ã  temps	0.90	amelioration	2025-08-18 08:01:52.856086
10	2	8.9	789	8.2	0.7	bas	1260000.00	Paiement Ã  temps	0.92	amelioration	2025-10-02 08:01:52.856086
11	3	6.5	657	6.2	0.3	moyen	750000.00	Paiement Ã  temps	0.85	amelioration	2024-08-23 08:01:52.856086
12	3	6.9	679	6.5	0.4	moyen	750000.00	Nouveau crÃ©dit accordÃ©	0.86	amelioration	2024-10-07 08:01:52.856086
13	3	7.0	685	6.9	0.1	moyen	750000.00	Paiement Ã  temps	0.86	stable	2024-11-21 08:01:52.856086
14	3	7.1	690	7.0	0.1	moyen	750000.00	Paiement Ã  temps	0.86	stable	2025-01-05 08:01:52.856086
15	3	7.5	712	7.1	0.4	moyen	750000.00	Nouveau crÃ©dit accordÃ©	0.88	amelioration	2025-02-19 08:01:52.856086
16	3	7.6	718	7.5	0.1	moyen	750000.00	Paiement Ã  temps	0.88	stable	2025-04-05 08:01:52.856086
17	3	7.9	734	7.6	0.3	moyen	750000.00	Nouveau crÃ©dit accordÃ©	0.89	amelioration	2025-05-20 08:01:52.856086
18	3	8.0	740	7.9	0.1	bas	1050000.00	Nouveau crÃ©dit accordÃ©	0.89	stable	2025-07-04 08:01:52.856086
19	3	8.2	751	8.0	0.2	bas	1050000.00	Paiement Ã  temps	0.90	stable	2025-08-18 08:01:52.856086
20	3	8.6	773	8.2	0.4	bas	1050000.00	Paiement Ã  temps	0.91	amelioration	2025-10-02 08:01:52.856086
21	4	7.1	690	6.2	0.9	moyen	600000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.86	amelioration	2025-07-04 08:01:52.856086
22	4	7.9	734	7.1	0.8	moyen	600000.00	Paiement Ã  temps	0.89	amelioration	2025-08-18 08:01:52.856086
23	4	8.6	773	7.9	0.7	bas	840000.00	Paiement en retard	0.91	amelioration	2025-10-02 08:01:52.856086
24	5	7.4	707	6.8	0.6	moyen	1000000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.87	amelioration	2025-07-04 08:01:52.856086
25	5	7.7	723	7.4	0.3	moyen	1000000.00	Nouveau crÃ©dit accordÃ©	0.88	amelioration	2025-08-18 08:01:52.856086
26	5	8.3	756	7.7	0.6	bas	1400000.00	Nouveau crÃ©dit accordÃ©	0.90	amelioration	2025-10-02 08:01:52.856086
27	6	6.5	657	6.1	0.4	moyen	700000.00	Paiement Ã  temps	0.85	amelioration	2025-01-05 08:01:52.856086
28	6	6.7	668	6.5	0.2	moyen	700000.00	Paiement Ã  temps	0.85	stable	2025-02-19 08:01:52.856086
29	6	7.0	685	6.7	0.3	moyen	700000.00	Nouveau crÃ©dit accordÃ©	0.86	amelioration	2025-04-05 08:01:52.856086
30	6	7.4	707	7.0	0.4	moyen	700000.00	Paiement Ã  temps	0.87	amelioration	2025-05-20 08:01:52.856086
31	6	7.8	729	7.4	0.4	moyen	700000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.88	amelioration	2025-07-04 08:01:52.856086
32	6	8.1	745	7.8	0.3	bas	980000.00	Nouveau crÃ©dit accordÃ©	0.89	amelioration	2025-08-18 08:01:52.856086
33	6	8.6	773	8.1	0.5	bas	980000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.91	amelioration	2025-10-02 08:01:52.856086
34	7	7.4	707	7.2	0.2	moyen	950000.00	Paiement Ã  temps	0.87	stable	2024-08-23 08:01:52.856086
35	7	7.5	712	7.4	0.1	moyen	950000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.88	stable	2024-10-07 08:01:52.856086
36	7	7.6	718	7.5	0.1	moyen	950000.00	Paiement Ã  temps	0.88	stable	2024-11-21 08:01:52.856086
37	7	7.9	734	7.6	0.3	moyen	950000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.89	amelioration	2025-01-05 08:01:52.856086
38	7	8.0	740	7.9	0.1	bas	1330000.00	Paiement Ã  temps	0.89	stable	2025-02-19 08:01:52.856086
39	7	8.0	740	8.0	0.0	bas	1330000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.89	stable	2025-04-05 08:01:52.856086
40	7	8.3	756	8.0	0.3	bas	1330000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.90	amelioration	2025-05-20 08:01:52.856086
41	7	8.4	762	8.3	0.1	bas	1330000.00	Paiement en retard	0.90	stable	2025-07-04 08:01:52.856086
42	7	8.6	773	8.4	0.2	bas	1330000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.91	stable	2025-08-18 08:01:52.856086
43	7	8.9	789	8.6	0.3	bas	1330000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.92	amelioration	2025-10-02 08:01:52.856086
44	8	7.1	690	6.9	0.2	moyen	550000.00	Paiement Ã  temps	0.86	stable	2025-01-05 08:01:52.856086
45	8	7.2	696	7.1	0.1	moyen	550000.00	Paiement Ã  temps	0.87	stable	2025-02-19 08:01:52.856086
46	8	7.4	707	7.2	0.2	moyen	550000.00	Nouveau crÃ©dit accordÃ©	0.87	stable	2025-04-05 08:01:52.856086
47	8	7.7	723	7.4	0.3	moyen	550000.00	Paiement Ã  temps	0.88	amelioration	2025-05-20 08:01:52.856086
48	8	7.9	734	7.7	0.2	moyen	550000.00	Paiement Ã  temps	0.89	stable	2025-07-04 08:01:52.856086
49	8	8.2	751	7.9	0.3	bas	770000.00	Paiement Ã  temps	0.90	amelioration	2025-08-18 08:01:52.856086
50	8	8.5	767	8.2	0.3	bas	770000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.91	amelioration	2025-10-02 08:01:52.856086
51	9	6.4	652	5.3	1.1	moyen	800000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.84	amelioration	2025-07-04 08:01:52.856086
52	9	7.4	707	6.4	1.0	moyen	800000.00	Paiement Ã  temps	0.87	amelioration	2025-08-18 08:01:52.856086
53	9	8.3	756	7.4	0.9	bas	1120000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.90	amelioration	2025-10-02 08:01:52.856086
54	10	7.7	723	7.7	0.0	moyen	675000.00	Nouveau crÃ©dit accordÃ©	0.88	stable	2024-10-07 08:01:52.856086
55	10	7.9	734	7.7	0.2	moyen	675000.00	Nouveau crÃ©dit accordÃ©	0.89	stable	2024-11-21 08:01:52.856086
56	10	8.0	740	7.9	0.1	bas	945000.00	Nouveau crÃ©dit accordÃ©	0.89	stable	2025-01-05 08:01:52.856086
57	10	8.0	740	8.0	0.0	bas	945000.00	Nouveau crÃ©dit accordÃ©	0.89	stable	2025-02-19 08:01:52.856086
58	10	8.2	751	8.0	0.2	bas	945000.00	Nouveau crÃ©dit accordÃ©	0.90	stable	2025-04-05 08:01:52.856086
59	10	8.4	762	8.2	0.2	bas	945000.00	Paiement Ã  temps	0.90	stable	2025-05-20 08:01:52.856086
60	10	8.4	762	8.4	0.0	bas	945000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.90	stable	2025-07-04 08:01:52.856086
61	10	8.5	767	8.4	0.1	bas	945000.00	Paiement Ã  temps	0.91	stable	2025-08-18 08:01:52.856086
62	10	8.6	773	8.5	0.1	bas	945000.00	Paiement Ã  temps	0.91	stable	2025-10-02 08:01:52.856086
63	11	6.7	668	6.4	0.3	moyen	725000.00	Paiement Ã  temps	0.85	amelioration	2025-02-19 08:01:52.856086
64	11	7.2	696	6.7	0.5	moyen	725000.00	Paiement Ã  temps	0.87	amelioration	2025-04-05 08:01:52.856086
65	11	7.6	718	7.2	0.4	moyen	725000.00	Mise Ã  jour automatique	0.88	amelioration	2025-05-20 08:01:52.856086
66	11	7.9	734	7.6	0.3	moyen	725000.00	Nouveau crÃ©dit accordÃ©	0.89	amelioration	2025-07-04 08:01:52.856086
67	11	8.3	756	7.9	0.4	bas	1015000.00	Paiement Ã  temps	0.90	amelioration	2025-08-18 08:01:52.856086
68	11	9.0	795	8.3	0.7	bas	1015000.00	Paiement Ã  temps	0.92	amelioration	2025-10-02 08:01:52.856086
69	12	5.4	597	5.1	0.3	eleve	285000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.81	amelioration	2024-08-23 08:01:52.856086
70	12	5.8	619	5.4	0.4	eleve	285000.00	Paiement Ã  temps	0.82	amelioration	2024-10-07 08:01:52.856086
71	12	6.1	635	5.8	0.3	moyen	475000.00	Nouveau crÃ©dit accordÃ©	0.83	amelioration	2024-11-21 08:01:52.856086
72	12	6.5	657	6.1	0.4	moyen	475000.00	Nouveau crÃ©dit accordÃ©	0.85	amelioration	2025-01-05 08:01:52.856086
73	12	6.8	674	6.5	0.3	moyen	475000.00	Paiement en retard	0.85	amelioration	2025-02-19 08:01:52.856086
74	12	7.0	685	6.8	0.2	moyen	475000.00	Nouveau crÃ©dit accordÃ©	0.86	stable	2025-04-05 08:01:52.856086
75	12	7.4	707	7.0	0.4	moyen	475000.00	Nouveau crÃ©dit accordÃ©	0.87	amelioration	2025-05-20 08:01:52.856086
76	12	7.5	712	7.4	0.1	moyen	475000.00	Paiement Ã  temps	0.88	stable	2025-07-04 08:01:52.856086
77	12	7.9	734	7.5	0.4	moyen	475000.00	Paiement Ã  temps	0.89	amelioration	2025-08-18 08:01:52.856086
78	12	8.0	740	7.9	0.1	bas	665000.00	Paiement Ã  temps	0.89	stable	2025-10-02 08:01:52.856086
79	13	7.0	685	6.5	0.5	moyen	425000.00	Paiement Ã  temps	0.86	amelioration	2025-07-04 08:01:52.856086
80	13	7.5	712	7.0	0.5	moyen	425000.00	Paiement Ã  temps	0.88	amelioration	2025-08-18 08:01:52.856086
81	13	7.9	734	7.5	0.4	moyen	425000.00	Paiement Ã  temps	0.89	amelioration	2025-10-02 08:01:52.856086
82	14	7.2	696	6.9	0.3	moyen	640000.00	Nouveau crÃ©dit accordÃ©	0.87	amelioration	2025-05-20 08:01:52.856086
83	14	7.5	712	7.2	0.3	moyen	640000.00	Paiement Ã  temps	0.88	amelioration	2025-07-04 08:01:52.856086
84	14	8.0	740	7.5	0.5	bas	896000.00	Paiement Ã  temps	0.89	amelioration	2025-08-18 08:01:52.856086
85	14	8.2	751	8.0	0.2	bas	896000.00	Paiement Ã  temps	0.90	stable	2025-10-02 08:01:52.856086
86	15	7.4	707	7.0	0.4	moyen	775000.00	Nouveau crÃ©dit accordÃ©	0.87	amelioration	2025-04-05 08:01:52.856086
87	15	7.6	718	7.4	0.2	moyen	775000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.88	stable	2025-05-20 08:01:52.856086
88	15	7.8	729	7.6	0.2	moyen	775000.00	Paiement Ã  temps	0.88	stable	2025-07-04 08:01:52.856086
89	15	8.1	745	7.8	0.3	bas	1085000.00	Paiement Ã  temps	0.89	amelioration	2025-08-18 08:01:52.856086
90	15	8.7	778	8.1	0.6	bas	1085000.00	Nouveau crÃ©dit accordÃ©	0.91	amelioration	2025-10-02 08:01:52.856086
91	16	6.7	668	6.4	0.3	moyen	575000.00	Paiement Ã  temps	0.85	amelioration	2025-04-05 08:01:52.856086
92	16	6.9	679	6.7	0.2	moyen	575000.00	Paiement Ã  temps	0.86	stable	2025-05-20 08:01:52.856086
93	16	7.4	707	6.9	0.5	moyen	575000.00	Paiement Ã  temps	0.87	amelioration	2025-07-04 08:01:52.856086
94	16	7.7	723	7.4	0.3	moyen	575000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.88	amelioration	2025-08-18 08:01:52.856086
95	16	8.3	756	7.7	0.6	bas	805000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.90	amelioration	2025-10-02 08:01:52.856086
96	17	6.5	657	6.5	0.0	moyen	840000.00	Nouveau crÃ©dit accordÃ©	0.85	stable	2024-08-23 08:01:52.856086
97	17	6.8	674	6.5	0.3	moyen	840000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.85	amelioration	2024-10-07 08:01:52.856086
98	17	6.9	679	6.8	0.1	moyen	840000.00	Nouveau crÃ©dit accordÃ©	0.86	stable	2024-11-21 08:01:52.856086
99	17	6.9	679	6.9	0.0	moyen	840000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.86	stable	2025-01-05 08:01:52.856086
100	17	7.2	696	6.9	0.3	moyen	840000.00	Nouveau crÃ©dit accordÃ©	0.87	amelioration	2025-02-19 08:01:52.856086
101	17	7.4	707	7.2	0.2	moyen	840000.00	Nouveau crÃ©dit accordÃ©	0.87	stable	2025-04-05 08:01:52.856086
102	17	7.6	718	7.4	0.2	moyen	840000.00	Paiement en retard	0.88	stable	2025-05-20 08:01:52.856086
103	17	7.7	723	7.6	0.1	moyen	840000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.88	stable	2025-07-04 08:01:52.856086
104	17	7.7	723	7.7	0.0	moyen	840000.00	Paiement Ã  temps	0.88	stable	2025-08-18 08:01:52.856086
105	17	8.1	745	7.7	0.4	bas	1176000.00	Paiement Ã  temps	0.89	amelioration	2025-10-02 08:01:52.856086
106	18	7.2	696	7.1	0.1	moyen	710000.00	Nouveau crÃ©dit accordÃ©	0.87	stable	2024-10-07 08:01:52.856086
107	18	7.5	712	7.2	0.3	moyen	710000.00	Nouveau crÃ©dit accordÃ©	0.88	amelioration	2024-11-21 08:01:52.856086
108	18	7.8	729	7.5	0.3	moyen	710000.00	Paiement Ã  temps	0.88	amelioration	2025-01-05 08:01:52.856086
109	18	8.0	740	7.8	0.2	bas	994000.00	Paiement Ã  temps	0.89	stable	2025-02-19 08:01:52.856086
110	18	8.0	740	8.0	0.0	bas	994000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.89	stable	2025-04-05 08:01:52.856086
111	18	8.1	745	8.0	0.1	bas	994000.00	Paiement Ã  temps	0.89	stable	2025-05-20 08:01:52.856086
112	18	8.3	756	8.1	0.2	bas	994000.00	Paiement Ã  temps	0.90	stable	2025-07-04 08:01:52.856086
113	18	8.3	756	8.3	0.0	bas	994000.00	Paiement Ã  temps	0.90	stable	2025-08-18 08:01:52.856086
114	18	8.5	767	8.3	0.2	bas	994000.00	Paiement en retard	0.91	stable	2025-10-02 08:01:52.856086
115	19	6.8	674	6.6	0.2	moyen	1050000.00	Paiement Ã  temps	0.85	stable	2025-04-05 08:01:52.856086
116	19	7.0	685	6.8	0.2	moyen	1050000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.86	stable	2025-05-20 08:01:52.856086
117	19	7.4	707	7.0	0.4	moyen	1050000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.87	amelioration	2025-07-04 08:01:52.856086
118	19	7.7	723	7.4	0.3	moyen	1050000.00	Paiement Ã  temps	0.88	amelioration	2025-08-18 08:01:52.856086
119	19	8.0	740	7.7	0.3	bas	1470000.00	Nouveau crÃ©dit accordÃ©	0.89	amelioration	2025-10-02 08:01:52.856086
120	20	7.1	690	7.0	0.1	moyen	875000.00	Paiement Ã  temps	0.86	stable	2024-08-23 08:01:52.856086
121	20	7.4	707	7.1	0.3	moyen	875000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.87	amelioration	2024-10-07 08:01:52.856086
122	20	7.4	707	7.4	0.0	moyen	875000.00	Nouveau crÃ©dit accordÃ©	0.87	stable	2024-11-21 08:01:52.856086
123	20	7.6	718	7.4	0.2	moyen	875000.00	Paiement Ã  temps	0.88	stable	2025-01-05 08:01:52.856086
124	20	7.7	723	7.6	0.1	moyen	875000.00	Nouveau crÃ©dit accordÃ©	0.88	stable	2025-02-19 08:01:52.856086
125	20	7.8	729	7.7	0.1	moyen	875000.00	Nouveau crÃ©dit accordÃ©	0.88	stable	2025-04-05 08:01:52.856086
126	20	8.0	740	7.8	0.2	bas	1225000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.89	stable	2025-05-20 08:01:52.856086
127	20	8.3	756	8.0	0.3	bas	1225000.00	Paiement Ã  temps	0.90	amelioration	2025-07-04 08:01:52.856086
128	20	8.6	773	8.3	0.3	bas	1225000.00	Nouveau crÃ©dit accordÃ©	0.91	amelioration	2025-08-18 08:01:52.856086
129	20	8.7	778	8.6	0.1	bas	1225000.00	Paiement Ã  temps	0.91	stable	2025-10-02 08:01:52.856086
130	21	6.3	646	5.9	0.4	moyen	940000.00	Nouveau crÃ©dit accordÃ©	0.84	amelioration	2025-02-19 08:01:52.856086
131	21	6.9	679	6.3	0.6	moyen	940000.00	Nouveau crÃ©dit accordÃ©	0.86	amelioration	2025-04-05 08:01:52.856086
132	21	7.2	696	6.9	0.3	moyen	940000.00	Paiement Ã  temps	0.87	amelioration	2025-05-20 08:01:52.856086
133	21	7.6	718	7.2	0.4	moyen	940000.00	Paiement Ã  temps	0.88	amelioration	2025-07-04 08:01:52.856086
134	21	8.0	740	7.6	0.4	bas	1316000.00	Nouveau crÃ©dit accordÃ©	0.89	amelioration	2025-08-18 08:01:52.856086
135	21	8.3	756	8.0	0.3	bas	1316000.00	Paiement Ã  temps	0.90	amelioration	2025-10-02 08:01:52.856086
136	22	5.9	624	5.8	0.1	eleve	396000.00	Paiement Ã  temps	0.83	stable	2024-08-23 08:01:52.856086
137	22	6.1	635	5.9	0.2	moyen	660000.00	Paiement Ã  temps	0.83	stable	2024-10-07 08:01:52.856086
138	22	6.4	652	6.1	0.3	moyen	660000.00	Mise Ã  jour automatique	0.84	amelioration	2024-11-21 08:01:52.856086
139	22	6.8	674	6.4	0.4	moyen	660000.00	Paiement Ã  temps	0.85	amelioration	2025-01-05 08:01:52.856086
140	22	7.0	685	6.8	0.2	moyen	660000.00	Nouveau crÃ©dit accordÃ©	0.86	stable	2025-02-19 08:01:52.856086
141	22	7.4	707	7.0	0.4	moyen	660000.00	Nouveau crÃ©dit accordÃ©	0.87	amelioration	2025-04-05 08:01:52.856086
142	22	7.7	723	7.4	0.3	moyen	660000.00	Paiement Ã  temps	0.88	amelioration	2025-05-20 08:01:52.856086
143	22	7.8	729	7.7	0.1	moyen	660000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.88	stable	2025-07-04 08:01:52.856086
144	22	7.9	734	7.8	0.1	moyen	660000.00	Nouveau crÃ©dit accordÃ©	0.89	stable	2025-08-18 08:01:52.856086
145	22	8.3	756	7.9	0.4	bas	924000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.90	amelioration	2025-10-02 08:01:52.856086
146	23	6.6	663	6.2	0.4	moyen	740000.00	Paiement Ã  temps	0.85	amelioration	2025-04-05 08:01:52.856086
147	23	7.2	696	6.6	0.6	moyen	740000.00	Paiement Ã  temps	0.87	amelioration	2025-05-20 08:01:52.856086
148	23	7.8	729	7.2	0.6	moyen	740000.00	Nouveau crÃ©dit accordÃ©	0.88	amelioration	2025-07-04 08:01:52.856086
149	23	8.0	740	7.8	0.2	bas	1036000.00	Paiement Ã  temps	0.89	stable	2025-08-18 08:01:52.856086
150	23	8.5	767	8.0	0.5	bas	1036000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.91	amelioration	2025-10-02 08:01:52.856086
151	24	5.9	624	5.6	0.3	eleve	486000.00	Paiement Ã  temps	0.83	amelioration	2024-08-23 08:01:52.856086
152	24	6.1	635	5.9	0.2	moyen	810000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.83	stable	2024-10-07 08:01:52.856086
153	24	6.5	657	6.1	0.4	moyen	810000.00	Nouveau crÃ©dit accordÃ©	0.85	amelioration	2024-11-21 08:01:52.856086
154	24	6.9	679	6.5	0.4	moyen	810000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.86	amelioration	2025-01-05 08:01:52.856086
155	24	7.2	696	6.9	0.3	moyen	810000.00	Nouveau crÃ©dit accordÃ©	0.87	amelioration	2025-02-19 08:01:52.856086
156	24	7.5	712	7.2	0.3	moyen	810000.00	Paiement Ã  temps	0.88	amelioration	2025-04-05 08:01:52.856086
157	24	7.9	734	7.5	0.4	moyen	810000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.89	amelioration	2025-05-20 08:01:52.856086
158	24	8.2	751	7.9	0.3	bas	1134000.00	Nouveau crÃ©dit accordÃ©	0.90	amelioration	2025-07-04 08:01:52.856086
159	24	8.3	756	8.2	0.1	bas	1134000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.90	stable	2025-08-18 08:01:52.856086
160	24	8.7	778	8.3	0.4	bas	1134000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.91	amelioration	2025-10-02 08:01:52.856086
161	25	7.1	690	6.6	0.5	moyen	595000.00	Nouveau crÃ©dit accordÃ©	0.86	amelioration	2025-07-04 08:01:52.856086
162	25	7.7	723	7.1	0.6	moyen	595000.00	Paiement Ã  temps	0.88	amelioration	2025-08-18 08:01:52.856086
163	25	8.4	762	7.7	0.7	bas	833000.00	Nouveau crÃ©dit accordÃ©	0.90	amelioration	2025-10-02 08:01:52.856086
164	26	7.4	707	7.1	0.3	moyen	525000.00	Paiement Ã  temps	0.87	amelioration	2025-02-19 08:01:52.856086
165	26	7.5	712	7.4	0.1	moyen	525000.00	Paiement Ã  temps	0.88	stable	2025-04-05 08:01:52.856086
166	26	7.6	718	7.5	0.1	moyen	525000.00	Nouveau crÃ©dit accordÃ©	0.88	stable	2025-05-20 08:01:52.856086
167	26	7.8	729	7.6	0.2	moyen	525000.00	Nouveau crÃ©dit accordÃ©	0.88	stable	2025-07-04 08:01:52.856086
168	26	8.1	745	7.8	0.3	bas	735000.00	Nouveau crÃ©dit accordÃ©	0.89	amelioration	2025-08-18 08:01:52.856086
169	26	8.1	745	8.1	0.0	bas	735000.00	Nouveau crÃ©dit accordÃ©	0.89	stable	2025-10-02 08:01:52.856086
170	27	6.1	635	5.5	0.6	moyen	675000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.83	amelioration	2025-02-19 08:01:52.856086
171	27	6.6	663	6.1	0.5	moyen	675000.00	Paiement Ã  temps	0.85	amelioration	2025-04-05 08:01:52.856086
172	27	6.8	674	6.6	0.2	moyen	675000.00	Paiement Ã  temps	0.85	stable	2025-05-20 08:01:52.856086
173	27	7.4	707	6.8	0.6	moyen	675000.00	Paiement en retard	0.87	amelioration	2025-07-04 08:01:52.856086
174	27	7.8	729	7.4	0.4	moyen	675000.00	Nouveau crÃ©dit accordÃ©	0.88	amelioration	2025-08-18 08:01:52.856086
175	27	8.2	751	7.8	0.4	bas	945000.00	Nouveau crÃ©dit accordÃ©	0.90	amelioration	2025-10-02 08:01:52.856086
176	28	7.8	729	7.6	0.2	moyen	790000.00	Nouveau crÃ©dit accordÃ©	0.88	stable	2024-11-21 08:01:52.856086
177	28	7.9	734	7.8	0.1	moyen	790000.00	Nouveau crÃ©dit accordÃ©	0.89	stable	2025-01-05 08:01:52.856086
178	28	8.0	740	7.9	0.1	bas	1106000.00	Paiement Ã  temps	0.89	stable	2025-02-19 08:01:52.856086
179	28	8.1	745	8.0	0.1	bas	1106000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.89	stable	2025-04-05 08:01:52.856086
180	28	8.3	756	8.1	0.2	bas	1106000.00	Paiement Ã  temps	0.90	stable	2025-05-20 08:01:52.856086
181	28	8.5	767	8.3	0.2	bas	1106000.00	Paiement Ã  temps	0.91	stable	2025-07-04 08:01:52.856086
182	28	8.7	778	8.5	0.2	bas	1106000.00	Nouveau crÃ©dit accordÃ©	0.91	stable	2025-08-18 08:01:52.856086
183	28	8.6	773	8.7	-0.1	bas	1106000.00	Nouveau crÃ©dit accordÃ©	0.91	stable	2025-10-02 08:01:52.856086
184	29	7.2	696	7.0	0.2	moyen	710000.00	Nouveau crÃ©dit accordÃ©	0.87	stable	2024-10-07 08:01:52.856086
185	29	7.4	707	7.2	0.2	moyen	710000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.87	stable	2024-11-21 08:01:52.856086
186	29	7.7	723	7.4	0.3	moyen	710000.00	Paiement Ã  temps	0.88	amelioration	2025-01-05 08:01:52.856086
187	29	7.7	723	7.7	0.0	moyen	710000.00	Paiement Ã  temps	0.88	stable	2025-02-19 08:01:52.856086
188	29	8.0	740	7.7	0.3	bas	994000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.89	amelioration	2025-04-05 08:01:52.856086
189	29	8.0	740	8.0	0.0	bas	994000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.89	stable	2025-05-20 08:01:52.856086
190	29	8.2	751	8.0	0.2	bas	994000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.90	stable	2025-07-04 08:01:52.856086
191	29	8.3	756	8.2	0.1	bas	994000.00	Paiement Ã  temps	0.90	stable	2025-08-18 08:01:52.856086
192	29	8.3	756	8.3	0.0	bas	994000.00	Nouveau crÃ©dit accordÃ©	0.90	stable	2025-10-02 08:01:52.856086
193	30	7.2	696	7.1	0.1	moyen	640000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.87	stable	2024-08-23 08:01:52.856086
194	30	7.2	696	7.2	0.0	moyen	640000.00	Paiement Ã  temps	0.87	stable	2024-10-07 08:01:52.856086
195	30	7.3	701	7.2	0.1	moyen	640000.00	Paiement Ã  temps	0.87	stable	2024-11-21 08:01:52.856086
196	30	7.4	707	7.3	0.1	moyen	640000.00	Nouveau crÃ©dit accordÃ©	0.87	stable	2025-01-05 08:01:52.856086
197	30	7.6	718	7.4	0.2	moyen	640000.00	Paiement Ã  temps	0.88	stable	2025-02-19 08:01:52.856086
198	30	7.8	729	7.6	0.2	moyen	640000.00	Paiement Ã  temps	0.88	stable	2025-04-05 08:01:52.856086
199	30	8.0	740	7.8	0.2	bas	896000.00	Nouveau crÃ©dit accordÃ©	0.89	stable	2025-05-20 08:01:52.856086
200	30	8.1	745	8.0	0.1	bas	896000.00	Paiement Ã  temps	0.89	stable	2025-07-04 08:01:52.856086
201	30	8.2	751	8.1	0.1	bas	896000.00	Paiement Ã  temps	0.90	stable	2025-08-18 08:01:52.856086
202	30	8.7	778	8.2	0.5	bas	896000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.91	amelioration	2025-10-02 08:01:52.856086
203	31	5.3	591	5.0	0.3	eleve	204000.00	Nouveau crÃ©dit accordÃ©	0.81	amelioration	2024-10-07 08:01:52.856086
204	31	5.6	608	5.3	0.3	eleve	204000.00	Paiement Ã  temps	0.82	amelioration	2024-11-21 08:01:52.856086
205	31	5.9	624	5.6	0.3	eleve	204000.00	Nouveau crÃ©dit accordÃ©	0.83	amelioration	2025-01-05 08:01:52.856086
206	31	6.0	630	5.9	0.1	moyen	340000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.83	stable	2025-02-19 08:01:52.856086
207	31	6.3	646	6.0	0.3	moyen	340000.00	Paiement Ã  temps	0.84	amelioration	2025-04-05 08:01:52.856086
208	31	6.5	657	6.3	0.2	moyen	340000.00	Paiement Ã  temps	0.85	stable	2025-05-20 08:01:52.856086
209	31	6.7	668	6.5	0.2	moyen	340000.00	Paiement Ã  temps	0.85	stable	2025-07-04 08:01:52.856086
210	31	6.9	679	6.7	0.2	moyen	340000.00	Paiement Ã  temps	0.86	stable	2025-08-18 08:01:52.856086
211	31	7.1	690	6.9	0.2	moyen	340000.00	Paiement Ã  temps	0.86	stable	2025-10-02 08:01:52.856086
212	32	5.2	586	5.1	0.1	eleve	156000.00	Nouveau crÃ©dit accordÃ©	0.81	stable	2024-08-23 08:01:52.856086
213	32	5.3	591	5.2	0.1	eleve	156000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.81	stable	2024-10-07 08:01:52.856086
214	32	5.5	602	5.3	0.2	eleve	156000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.82	stable	2024-11-21 08:01:52.856086
215	32	5.5	602	5.5	0.0	eleve	156000.00	Paiement Ã  temps	0.82	stable	2025-01-05 08:01:52.856086
216	32	5.8	619	5.5	0.3	eleve	156000.00	Paiement Ã  temps	0.82	amelioration	2025-02-19 08:01:52.856086
217	32	5.9	624	5.8	0.1	eleve	156000.00	Paiement Ã  temps	0.83	stable	2025-04-05 08:01:52.856086
218	32	6.0	630	5.9	0.1	moyen	260000.00	Nouveau crÃ©dit accordÃ©	0.83	stable	2025-05-20 08:01:52.856086
219	32	6.4	652	6.0	0.4	moyen	260000.00	Paiement Ã  temps	0.84	amelioration	2025-07-04 08:01:52.856086
220	32	6.7	668	6.4	0.3	moyen	260000.00	Nouveau crÃ©dit accordÃ©	0.85	amelioration	2025-08-18 08:01:52.856086
221	32	6.7	668	6.7	0.0	moyen	260000.00	Nouveau crÃ©dit accordÃ©	0.85	stable	2025-10-02 08:01:52.856086
222	33	5.3	591	4.6	0.7	eleve	225000.00	Nouveau crÃ©dit accordÃ©	0.81	amelioration	2025-07-04 08:01:52.856086
223	33	6.2	641	5.3	0.9	moyen	375000.00	Paiement Ã  temps	0.84	amelioration	2025-08-18 08:01:52.856086
224	33	7.0	685	6.2	0.8	moyen	375000.00	Nouveau crÃ©dit accordÃ©	0.86	amelioration	2025-10-02 08:01:52.856086
225	34	4.9	569	4.5	0.4	eleve	144000.00	Nouveau crÃ©dit accordÃ©	0.80	amelioration	2025-04-05 08:01:52.856086
226	34	5.5	602	4.9	0.6	eleve	144000.00	Paiement Ã  temps	0.82	amelioration	2025-05-20 08:01:52.856086
227	34	5.8	619	5.5	0.3	eleve	144000.00	Paiement Ã  temps	0.82	amelioration	2025-07-04 08:01:52.856086
228	34	6.3	646	5.8	0.5	moyen	240000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.84	amelioration	2025-08-18 08:01:52.856086
229	34	7.0	685	6.3	0.7	moyen	240000.00	Paiement Ã  temps	0.86	amelioration	2025-10-02 08:01:52.856086
230	35	4.6	553	4.3	0.3	eleve	186000.00	Paiement Ã  temps	0.79	amelioration	2024-08-23 08:01:52.856086
231	35	5.0	575	4.6	0.4	eleve	186000.00	Paiement Ã  temps	0.80	amelioration	2024-10-07 08:01:52.856086
232	35	5.2	586	5.0	0.2	eleve	186000.00	Nouveau crÃ©dit accordÃ©	0.81	stable	2024-11-21 08:01:52.856086
233	35	5.5	602	5.2	0.3	eleve	186000.00	Paiement Ã  temps	0.82	amelioration	2025-01-05 08:01:52.856086
234	35	5.8	619	5.5	0.3	eleve	186000.00	Nouveau crÃ©dit accordÃ©	0.82	amelioration	2025-02-19 08:01:52.856086
235	35	5.9	624	5.8	0.1	eleve	186000.00	Nouveau crÃ©dit accordÃ©	0.83	stable	2025-04-05 08:01:52.856086
236	35	6.1	635	5.9	0.2	moyen	310000.00	Nouveau crÃ©dit accordÃ©	0.83	stable	2025-05-20 08:01:52.856086
237	35	6.3	646	6.1	0.2	moyen	310000.00	Nouveau crÃ©dit accordÃ©	0.84	stable	2025-07-04 08:01:52.856086
238	35	6.6	663	6.3	0.3	moyen	310000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.85	amelioration	2025-08-18 08:01:52.856086
239	35	7.2	696	6.6	0.6	moyen	310000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.87	amelioration	2025-10-02 08:01:52.856086
240	36	6.1	635	5.6	0.5	moyen	320000.00	Nouveau crÃ©dit accordÃ©	0.83	amelioration	2025-07-04 08:01:52.856086
241	36	6.5	657	6.1	0.4	moyen	320000.00	Nouveau crÃ©dit accordÃ©	0.85	amelioration	2025-08-18 08:01:52.856086
242	36	6.9	679	6.5	0.4	moyen	320000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.86	amelioration	2025-10-02 08:01:52.856086
243	37	5.2	586	5.1	0.1	eleve	165000.00	Paiement Ã  temps	0.81	stable	2025-02-19 08:01:52.856086
244	37	5.5	602	5.2	0.3	eleve	165000.00	Paiement Ã  temps	0.82	amelioration	2025-04-05 08:01:52.856086
245	37	5.9	624	5.5	0.4	eleve	165000.00	Nouveau crÃ©dit accordÃ©	0.83	amelioration	2025-05-20 08:01:52.856086
246	37	6.0	630	5.9	0.1	moyen	275000.00	Paiement Ã  temps	0.83	stable	2025-07-04 08:01:52.856086
247	37	6.4	652	6.0	0.4	moyen	275000.00	Nouveau crÃ©dit accordÃ©	0.84	amelioration	2025-08-18 08:01:52.856086
248	37	6.8	674	6.4	0.4	moyen	275000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.85	amelioration	2025-10-02 08:01:52.856086
249	38	6.4	652	6.0	0.4	moyen	360000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.84	amelioration	2025-07-04 08:01:52.856086
250	38	6.7	668	6.4	0.3	moyen	360000.00	Nouveau crÃ©dit accordÃ©	0.85	amelioration	2025-08-18 08:01:52.856086
251	38	7.1	690	6.7	0.4	moyen	360000.00	Paiement Ã  temps	0.86	amelioration	2025-10-02 08:01:52.856086
252	39	4.5	547	3.7	0.8	eleve	144000.00	Nouveau crÃ©dit accordÃ©	0.79	amelioration	2025-07-04 08:01:52.856086
253	39	5.5	602	4.5	1.0	eleve	144000.00	Nouveau crÃ©dit accordÃ©	0.82	amelioration	2025-08-18 08:01:52.856086
254	39	6.5	657	5.5	1.0	moyen	240000.00	Paiement Ã  temps	0.85	amelioration	2025-10-02 08:01:52.856086
255	40	6.2	641	5.6	0.6	moyen	295000.00	Nouveau crÃ©dit accordÃ©	0.84	amelioration	2025-07-04 08:01:52.856086
256	40	6.7	668	6.2	0.5	moyen	295000.00	Nouveau crÃ©dit accordÃ©	0.85	amelioration	2025-08-18 08:01:52.856086
257	40	6.9	679	6.7	0.2	moyen	295000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.86	stable	2025-10-02 08:01:52.856086
258	41	6.1	635	5.7	0.4	moyen	325000.00	Nouveau crÃ©dit accordÃ©	0.83	amelioration	2025-02-19 08:01:52.856086
259	41	6.2	641	6.1	0.1	moyen	325000.00	Nouveau crÃ©dit accordÃ©	0.84	stable	2025-04-05 08:01:52.856086
260	41	6.6	663	6.2	0.4	moyen	325000.00	Paiement en retard	0.85	amelioration	2025-05-20 08:01:52.856086
261	41	6.8	674	6.6	0.2	moyen	325000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.85	stable	2025-07-04 08:01:52.856086
262	41	7.1	690	6.8	0.3	moyen	325000.00	Paiement en retard	0.86	amelioration	2025-08-18 08:01:52.856086
263	41	7.2	696	7.1	0.1	moyen	325000.00	Paiement en retard	0.87	stable	2025-10-02 08:01:52.856086
264	42	5.0	575	4.7	0.3	eleve	168000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.80	amelioration	2024-10-07 08:01:52.856086
265	42	5.2	586	5.0	0.2	eleve	168000.00	Paiement Ã  temps	0.81	stable	2024-11-21 08:01:52.856086
266	42	5.4	597	5.2	0.2	eleve	168000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.81	stable	2025-01-05 08:01:52.856086
267	42	5.6	608	5.4	0.2	eleve	168000.00	Nouveau crÃ©dit accordÃ©	0.82	stable	2025-02-19 08:01:52.856086
268	42	5.7	613	5.6	0.1	eleve	168000.00	Nouveau crÃ©dit accordÃ©	0.82	stable	2025-04-05 08:01:52.856086
269	42	5.9	624	5.7	0.2	eleve	168000.00	Nouveau crÃ©dit accordÃ©	0.83	stable	2025-05-20 08:01:52.856086
270	42	6.3	646	5.9	0.4	moyen	280000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.84	amelioration	2025-07-04 08:01:52.856086
271	42	6.6	663	6.3	0.3	moyen	280000.00	Paiement Ã  temps	0.85	amelioration	2025-08-18 08:01:52.856086
272	42	6.8	674	6.6	0.2	moyen	280000.00	Nouveau crÃ©dit accordÃ©	0.85	stable	2025-10-02 08:01:52.856086
273	43	4.1	525	4.0	0.1	eleve	126000.00	Paiement Ã  temps	0.77	stable	2024-08-23 08:01:52.856086
274	43	4.2	531	4.1	0.1	eleve	126000.00	Nouveau crÃ©dit accordÃ©	0.78	stable	2024-10-07 08:01:52.856086
275	43	4.3	536	4.2	0.1	eleve	126000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.78	stable	2024-11-21 08:01:52.856086
276	43	4.7	558	4.3	0.4	eleve	126000.00	Nouveau crÃ©dit accordÃ©	0.79	amelioration	2025-01-05 08:01:52.856086
277	43	4.9	569	4.7	0.2	eleve	126000.00	Nouveau crÃ©dit accordÃ©	0.80	stable	2025-02-19 08:01:52.856086
278	43	5.2	586	4.9	0.3	eleve	126000.00	Paiement Ã  temps	0.81	amelioration	2025-04-05 08:01:52.856086
279	43	5.6	608	5.2	0.4	eleve	126000.00	Paiement Ã  temps	0.82	amelioration	2025-05-20 08:01:52.856086
280	43	6.0	630	5.6	0.4	moyen	210000.00	Nouveau crÃ©dit accordÃ©	0.83	amelioration	2025-07-04 08:01:52.856086
281	43	6.2	641	6.0	0.2	moyen	210000.00	Paiement Ã  temps	0.84	stable	2025-08-18 08:01:52.856086
282	43	6.6	663	6.2	0.4	moyen	210000.00	Paiement Ã  temps	0.85	amelioration	2025-10-02 08:01:52.856086
283	44	4.1	525	3.7	0.4	eleve	135000.00	Paiement Ã  temps	0.77	amelioration	2024-11-21 08:01:52.856086
284	44	4.4	542	4.1	0.3	eleve	135000.00	Nouveau crÃ©dit accordÃ©	0.78	amelioration	2025-01-05 08:01:52.856086
285	44	4.7	558	4.4	0.3	eleve	135000.00	Nouveau crÃ©dit accordÃ©	0.79	amelioration	2025-02-19 08:01:52.856086
286	44	5.2	586	4.7	0.5	eleve	135000.00	Paiement Ã  temps	0.81	amelioration	2025-04-05 08:01:52.856086
287	44	5.4	597	5.2	0.2	eleve	135000.00	Paiement Ã  temps	0.81	stable	2025-05-20 08:01:52.856086
288	44	5.8	619	5.4	0.4	eleve	135000.00	Nouveau crÃ©dit accordÃ©	0.82	amelioration	2025-07-04 08:01:52.856086
289	44	6.3	646	5.8	0.5	moyen	225000.00	Paiement Ã  temps	0.84	amelioration	2025-08-18 08:01:52.856086
290	44	6.6	663	6.3	0.3	moyen	225000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.85	amelioration	2025-10-02 08:01:52.856086
291	45	5.3	591	4.9	0.4	eleve	114000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.81	amelioration	2025-04-05 08:01:52.856086
292	45	5.6	608	5.3	0.3	eleve	114000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.82	amelioration	2025-05-20 08:01:52.856086
293	45	6.0	630	5.6	0.4	moyen	190000.00	Nouveau crÃ©dit accordÃ©	0.83	amelioration	2025-07-04 08:01:52.856086
294	45	6.3	646	6.0	0.3	moyen	190000.00	Paiement Ã  temps	0.84	amelioration	2025-08-18 08:01:52.856086
295	45	6.3	646	6.3	0.0	moyen	190000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.84	stable	2025-10-02 08:01:52.856086
296	46	6.1	635	5.9	0.2	moyen	335000.00	Paiement Ã  temps	0.83	stable	2024-11-21 08:01:52.856086
297	46	6.3	646	6.1	0.2	moyen	335000.00	Paiement en retard	0.84	stable	2025-01-05 08:01:52.856086
298	46	6.4	652	6.3	0.1	moyen	335000.00	Paiement Ã  temps	0.84	stable	2025-02-19 08:01:52.856086
299	46	6.6	663	6.4	0.2	moyen	335000.00	Paiement Ã  temps	0.85	stable	2025-04-05 08:01:52.856086
300	46	6.9	679	6.6	0.3	moyen	335000.00	Nouveau crÃ©dit accordÃ©	0.86	amelioration	2025-05-20 08:01:52.856086
301	46	7.0	685	6.9	0.1	moyen	335000.00	Mise Ã  jour automatique	0.86	stable	2025-07-04 08:01:52.856086
302	46	6.9	679	7.0	-0.1	moyen	335000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.86	stable	2025-08-18 08:01:52.856086
303	46	7.2	696	6.9	0.3	moyen	335000.00	Paiement Ã  temps	0.87	amelioration	2025-10-02 08:01:52.856086
304	47	4.2	531	3.7	0.5	eleve	138000.00	Nouveau crÃ©dit accordÃ©	0.78	amelioration	2025-02-19 08:01:52.856086
305	47	4.6	553	4.2	0.4	eleve	138000.00	Paiement Ã  temps	0.79	amelioration	2025-04-05 08:01:52.856086
306	47	5.0	575	4.6	0.4	eleve	138000.00	Paiement Ã  temps	0.80	amelioration	2025-05-20 08:01:52.856086
307	47	5.5	602	5.0	0.5	eleve	138000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.82	amelioration	2025-07-04 08:01:52.856086
308	47	6.0	630	5.5	0.5	moyen	230000.00	Paiement Ã  temps	0.83	amelioration	2025-08-18 08:01:52.856086
309	47	6.6	663	6.0	0.6	moyen	230000.00	Nouveau crÃ©dit accordÃ©	0.85	amelioration	2025-10-02 08:01:52.856086
310	48	4.7	558	4.2	0.5	eleve	156000.00	Nouveau crÃ©dit accordÃ©	0.79	amelioration	2025-02-19 08:01:52.856086
311	48	5.2	586	4.7	0.5	eleve	156000.00	Nouveau crÃ©dit accordÃ©	0.81	amelioration	2025-04-05 08:01:52.856086
312	48	5.7	613	5.2	0.5	eleve	156000.00	Paiement Ã  temps	0.82	amelioration	2025-05-20 08:01:52.856086
313	48	6.0	630	5.7	0.3	moyen	260000.00	Nouveau crÃ©dit accordÃ©	0.83	amelioration	2025-07-04 08:01:52.856086
314	48	6.3	646	6.0	0.3	moyen	260000.00	Nouveau crÃ©dit accordÃ©	0.84	amelioration	2025-08-18 08:01:52.856086
315	48	6.9	679	6.3	0.6	moyen	260000.00	Paiement Ã  temps	0.86	amelioration	2025-10-02 08:01:52.856086
316	49	4.3	536	4.0	0.3	eleve	102000.00	Paiement Ã  temps	0.78	amelioration	2024-08-23 08:01:52.856086
317	49	4.5	547	4.3	0.2	eleve	102000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.79	stable	2024-10-07 08:01:52.856086
318	49	4.8	564	4.5	0.3	eleve	102000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.79	amelioration	2024-11-21 08:01:52.856086
319	49	4.9	569	4.8	0.1	eleve	102000.00	Paiement Ã  temps	0.80	stable	2025-01-05 08:01:52.856086
320	49	5.1	580	4.9	0.2	eleve	102000.00	Nouveau crÃ©dit accordÃ©	0.80	stable	2025-02-19 08:01:52.856086
321	49	5.4	597	5.1	0.3	eleve	102000.00	Paiement Ã  temps	0.81	amelioration	2025-04-05 08:01:52.856086
322	49	5.7	613	5.4	0.3	eleve	102000.00	Paiement Ã  temps	0.82	amelioration	2025-05-20 08:01:52.856086
323	49	5.7	613	5.7	0.0	eleve	102000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.82	stable	2025-07-04 08:01:52.856086
324	49	5.9	624	5.7	0.2	eleve	102000.00	Paiement Ã  temps	0.83	stable	2025-08-18 08:01:52.856086
325	49	6.3	646	5.9	0.4	moyen	170000.00	Paiement Ã  temps	0.84	amelioration	2025-10-02 08:01:52.856086
326	50	5.6	608	5.4	0.2	eleve	147000.00	Nouveau crÃ©dit accordÃ©	0.82	stable	2025-04-05 08:01:52.856086
327	50	5.9	624	5.6	0.3	eleve	147000.00	Nouveau crÃ©dit accordÃ©	0.83	amelioration	2025-05-20 08:01:52.856086
328	50	6.1	635	5.9	0.2	moyen	245000.00	Paiement Ã  temps	0.83	stable	2025-07-04 08:01:52.856086
329	50	6.3	646	6.1	0.2	moyen	245000.00	Paiement Ã  temps	0.84	stable	2025-08-18 08:01:52.856086
330	50	6.7	668	6.3	0.4	moyen	245000.00	Paiement Ã  temps	0.85	amelioration	2025-10-02 08:01:52.856086
331	51	6.0	630	5.8	0.2	moyen	270000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.83	stable	2025-04-05 08:01:52.856086
332	51	6.1	635	6.0	0.1	moyen	270000.00	Nouveau crÃ©dit accordÃ©	0.83	stable	2025-05-20 08:01:52.856086
333	51	6.5	657	6.1	0.4	moyen	270000.00	Nouveau crÃ©dit accordÃ©	0.85	amelioration	2025-07-04 08:01:52.856086
334	51	6.8	674	6.5	0.3	moyen	270000.00	Nouveau crÃ©dit accordÃ©	0.85	amelioration	2025-08-18 08:01:52.856086
335	51	6.9	679	6.8	0.1	moyen	270000.00	Paiement Ã  temps	0.86	stable	2025-10-02 08:01:52.856086
336	52	4.7	558	4.4	0.3	eleve	108000.00	Paiement Ã  temps	0.79	amelioration	2024-11-21 08:01:52.856086
337	52	5.0	575	4.7	0.3	eleve	108000.00	Nouveau crÃ©dit accordÃ©	0.80	amelioration	2025-01-05 08:01:52.856086
338	52	5.2	586	5.0	0.2	eleve	108000.00	Nouveau crÃ©dit accordÃ©	0.81	stable	2025-02-19 08:01:52.856086
339	52	5.5	602	5.2	0.3	eleve	108000.00	Paiement Ã  temps	0.82	amelioration	2025-04-05 08:01:52.856086
340	52	5.7	613	5.5	0.2	eleve	108000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.82	stable	2025-05-20 08:01:52.856086
341	52	6.0	630	5.7	0.3	moyen	180000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.83	amelioration	2025-07-04 08:01:52.856086
342	52	6.2	641	6.0	0.2	moyen	180000.00	Paiement Ã  temps	0.84	stable	2025-08-18 08:01:52.856086
343	52	6.2	641	6.2	0.0	moyen	180000.00	Paiement Ã  temps	0.84	stable	2025-10-02 08:01:52.856086
344	53	5.8	619	5.5	0.3	eleve	141000.00	Paiement Ã  temps	0.82	amelioration	2025-01-05 08:01:52.856086
345	53	5.8	619	5.8	0.0	eleve	141000.00	Paiement Ã  temps	0.82	stable	2025-02-19 08:01:52.856086
346	53	5.9	624	5.8	0.1	eleve	141000.00	Paiement Ã  temps	0.83	stable	2025-04-05 08:01:52.856086
347	53	6.1	635	5.9	0.2	moyen	235000.00	Nouveau crÃ©dit accordÃ©	0.83	stable	2025-05-20 08:01:52.856086
348	53	6.4	652	6.1	0.3	moyen	235000.00	Paiement Ã  temps	0.84	amelioration	2025-07-04 08:01:52.856086
349	53	6.6	663	6.4	0.2	moyen	235000.00	Nouveau crÃ©dit accordÃ©	0.85	stable	2025-08-18 08:01:52.856086
350	53	6.6	663	6.6	0.0	moyen	235000.00	Nouveau crÃ©dit accordÃ©	0.85	stable	2025-10-02 08:01:52.856086
351	54	5.0	575	4.6	0.4	eleve	165000.00	Nouveau crÃ©dit accordÃ©	0.80	amelioration	2025-04-05 08:01:52.856086
352	54	5.5	602	5.0	0.5	eleve	165000.00	Nouveau crÃ©dit accordÃ©	0.82	amelioration	2025-05-20 08:01:52.856086
353	54	6.1	635	5.5	0.6	moyen	275000.00	Paiement Ã  temps	0.83	amelioration	2025-07-04 08:01:52.856086
354	54	6.6	663	6.1	0.5	moyen	275000.00	Nouveau crÃ©dit accordÃ©	0.85	amelioration	2025-08-18 08:01:52.856086
355	54	6.9	679	6.6	0.3	moyen	275000.00	Nouveau crÃ©dit accordÃ©	0.86	amelioration	2025-10-02 08:01:52.856086
356	55	5.0	575	4.8	0.2	eleve	105000.00	Paiement Ã  temps	0.80	stable	2025-01-05 08:01:52.856086
357	55	5.1	580	5.0	0.1	eleve	105000.00	Paiement Ã  temps	0.80	stable	2025-02-19 08:01:52.856086
358	55	5.3	591	5.1	0.2	eleve	105000.00	Nouveau crÃ©dit accordÃ©	0.81	stable	2025-04-05 08:01:52.856086
359	55	5.6	608	5.3	0.3	eleve	105000.00	Paiement Ã  temps	0.82	amelioration	2025-05-20 08:01:52.856086
360	55	5.7	613	5.6	0.1	eleve	105000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.82	stable	2025-07-04 08:01:52.856086
361	55	6.1	635	5.7	0.4	moyen	175000.00	Paiement Ã  temps	0.83	amelioration	2025-08-18 08:01:52.856086
362	55	6.2	641	6.1	0.1	moyen	175000.00	Nouveau crÃ©dit accordÃ©	0.84	stable	2025-10-02 08:01:52.856086
363	56	5.9	624	5.5	0.4	eleve	174000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.83	amelioration	2025-07-04 08:01:52.856086
364	56	6.5	657	5.9	0.6	moyen	290000.00	Nouveau crÃ©dit accordÃ©	0.85	amelioration	2025-08-18 08:01:52.856086
365	56	6.9	679	6.5	0.4	moyen	290000.00	Nouveau crÃ©dit accordÃ©	0.86	amelioration	2025-10-02 08:01:52.856086
366	57	5.1	580	5.0	0.1	eleve	126000.00	Paiement Ã  temps	0.80	stable	2025-01-05 08:01:52.856086
367	57	5.4	597	5.1	0.3	eleve	126000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.81	amelioration	2025-02-19 08:01:52.856086
368	57	5.6	608	5.4	0.2	eleve	126000.00	Nouveau crÃ©dit accordÃ©	0.82	stable	2025-04-05 08:01:52.856086
369	57	5.7	613	5.6	0.1	eleve	126000.00	Nouveau crÃ©dit accordÃ©	0.82	stable	2025-05-20 08:01:52.856086
370	57	6.0	630	5.7	0.3	moyen	210000.00	Nouveau crÃ©dit accordÃ©	0.83	amelioration	2025-07-04 08:01:52.856086
371	57	6.1	635	6.0	0.1	moyen	210000.00	Paiement Ã  temps	0.83	stable	2025-08-18 08:01:52.856086
372	57	6.4	652	6.1	0.3	moyen	210000.00	Nouveau crÃ©dit accordÃ©	0.84	amelioration	2025-10-02 08:01:52.856086
373	58	5.9	624	5.3	0.6	eleve	153000.00	Nouveau crÃ©dit accordÃ©	0.83	amelioration	2025-07-04 08:01:52.856086
374	58	6.2	641	5.9	0.3	moyen	255000.00	Paiement Ã  temps	0.84	amelioration	2025-08-18 08:01:52.856086
375	58	6.7	668	6.2	0.5	moyen	255000.00	Paiement Ã  temps	0.85	amelioration	2025-10-02 08:01:52.856086
376	59	3.7	503	3.4	0.3	tres_eleve	0.00	Paiement Ã  temps	0.76	amelioration	2024-10-07 08:01:52.856086
377	59	3.9	514	3.7	0.2	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.77	stable	2024-11-21 08:01:52.856086
378	59	4.2	531	3.9	0.3	eleve	117000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.78	amelioration	2025-01-05 08:01:52.856086
379	59	4.5	547	4.2	0.3	eleve	117000.00	Nouveau crÃ©dit accordÃ©	0.79	amelioration	2025-02-19 08:01:52.856086
380	59	4.8	564	4.5	0.3	eleve	117000.00	Paiement Ã  temps	0.79	amelioration	2025-04-05 08:01:52.856086
381	59	5.3	591	4.8	0.5	eleve	117000.00	Nouveau crÃ©dit accordÃ©	0.81	amelioration	2025-05-20 08:01:52.856086
382	59	5.6	608	5.3	0.3	eleve	117000.00	Paiement Ã  temps	0.82	amelioration	2025-07-04 08:01:52.856086
383	59	6.1	635	5.6	0.5	moyen	195000.00	Nouveau crÃ©dit accordÃ©	0.83	amelioration	2025-08-18 08:01:52.856086
384	59	6.4	652	6.1	0.3	moyen	195000.00	Paiement en retard	0.84	amelioration	2025-10-02 08:01:52.856086
385	60	5.2	586	4.6	0.6	eleve	156000.00	Paiement Ã  temps	0.81	amelioration	2025-07-04 08:01:52.856086
386	60	6.1	635	5.2	0.9	moyen	260000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.83	amelioration	2025-08-18 08:01:52.856086
387	60	6.8	674	6.1	0.7	moyen	260000.00	Paiement Ã  temps	0.85	amelioration	2025-10-02 08:01:52.856086
388	61	6.0	630	5.7	0.3	moyen	300000.00	Mise Ã  jour automatique	0.83	amelioration	2025-04-05 08:01:52.856086
389	61	6.2	641	6.0	0.2	moyen	300000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.84	stable	2025-05-20 08:01:52.856086
390	61	6.6	663	6.2	0.4	moyen	300000.00	Nouveau crÃ©dit accordÃ©	0.85	amelioration	2025-07-04 08:01:52.856086
391	61	6.9	679	6.6	0.3	moyen	300000.00	Paiement Ã  temps	0.86	amelioration	2025-08-18 08:01:52.856086
392	61	7.0	685	6.9	0.1	moyen	300000.00	Paiement Ã  temps	0.86	stable	2025-10-02 08:01:52.856086
393	62	5.7	613	4.8	0.9	eleve	204000.00	Paiement Ã  temps	0.82	amelioration	2025-07-04 08:01:52.856086
394	62	6.4	652	5.7	0.7	moyen	340000.00	Nouveau crÃ©dit accordÃ©	0.84	amelioration	2025-08-18 08:01:52.856086
395	62	7.1	690	6.4	0.7	moyen	340000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.86	amelioration	2025-10-02 08:01:52.856086
396	63	5.7	613	5.6	0.1	eleve	186000.00	Nouveau crÃ©dit accordÃ©	0.82	stable	2024-11-21 08:01:52.856086
397	63	6.0	630	5.7	0.3	moyen	310000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.83	amelioration	2025-01-05 08:01:52.856086
398	63	6.1	635	6.0	0.1	moyen	310000.00	Paiement Ã  temps	0.83	stable	2025-02-19 08:01:52.856086
399	63	6.2	641	6.1	0.1	moyen	310000.00	Paiement Ã  temps	0.84	stable	2025-04-05 08:01:52.856086
400	63	6.3	646	6.2	0.1	moyen	310000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.84	stable	2025-05-20 08:01:52.856086
401	63	6.4	652	6.3	0.1	moyen	310000.00	Paiement Ã  temps	0.84	stable	2025-07-04 08:01:52.856086
402	63	6.6	663	6.4	0.2	moyen	310000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.85	stable	2025-08-18 08:01:52.856086
403	63	6.9	679	6.6	0.3	moyen	310000.00	Nouveau crÃ©dit accordÃ©	0.86	amelioration	2025-10-02 08:01:52.856086
404	64	5.6	608	5.5	0.1	eleve	132000.00	Nouveau crÃ©dit accordÃ©	0.82	stable	2024-11-21 08:01:52.856086
405	64	5.7	613	5.6	0.1	eleve	132000.00	Nouveau crÃ©dit accordÃ©	0.82	stable	2025-01-05 08:01:52.856086
406	64	5.8	619	5.7	0.1	eleve	132000.00	Nouveau crÃ©dit accordÃ©	0.82	stable	2025-02-19 08:01:52.856086
407	64	6.1	635	5.8	0.3	moyen	220000.00	Paiement Ã  temps	0.83	amelioration	2025-04-05 08:01:52.856086
408	64	6.4	652	6.1	0.3	moyen	220000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.84	amelioration	2025-05-20 08:01:52.856086
409	64	6.6	663	6.4	0.2	moyen	220000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.85	stable	2025-07-04 08:01:52.856086
410	64	6.7	668	6.6	0.1	moyen	220000.00	Paiement Ã  temps	0.85	stable	2025-08-18 08:01:52.856086
411	64	6.5	657	6.7	-0.2	moyen	220000.00	Nouveau crÃ©dit accordÃ©	0.85	stable	2025-10-02 08:01:52.856086
412	65	5.0	575	4.8	0.2	eleve	150000.00	Paiement Ã  temps	0.80	stable	2024-11-21 08:01:52.856086
413	65	5.4	597	5.0	0.4	eleve	150000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.81	amelioration	2025-01-05 08:01:52.856086
414	65	5.6	608	5.4	0.2	eleve	150000.00	Paiement Ã  temps	0.82	stable	2025-02-19 08:01:52.856086
415	65	5.8	619	5.6	0.2	eleve	150000.00	Nouveau crÃ©dit accordÃ©	0.82	stable	2025-04-05 08:01:52.856086
416	65	6.1	635	5.8	0.3	moyen	250000.00	Nouveau crÃ©dit accordÃ©	0.83	amelioration	2025-05-20 08:01:52.856086
417	65	6.3	646	6.1	0.2	moyen	250000.00	Paiement Ã  temps	0.84	stable	2025-07-04 08:01:52.856086
418	65	6.5	657	6.3	0.2	moyen	250000.00	Paiement en retard	0.85	stable	2025-08-18 08:01:52.856086
419	65	6.8	674	6.5	0.3	moyen	250000.00	Paiement Ã  temps	0.85	amelioration	2025-10-02 08:01:52.856086
420	66	5.3	591	4.6	0.7	eleve	186000.00	Nouveau crÃ©dit accordÃ©	0.81	amelioration	2025-07-04 08:01:52.856086
421	66	6.2	641	5.3	0.9	moyen	310000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.84	amelioration	2025-08-18 08:01:52.856086
422	66	7.1	690	6.2	0.9	moyen	310000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.86	amelioration	2025-10-02 08:01:52.856086
423	67	5.0	575	4.0	1.0	eleve	165000.00	Paiement en retard	0.80	amelioration	2025-07-04 08:01:52.856086
424	67	6.0	630	5.0	1.0	moyen	275000.00	Nouveau crÃ©dit accordÃ©	0.83	amelioration	2025-08-18 08:01:52.856086
425	67	6.9	679	6.0	0.9	moyen	275000.00	Paiement Ã  temps	0.86	amelioration	2025-10-02 08:01:52.856086
426	68	3.5	492	3.3	0.2	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.76	stable	2024-11-21 08:01:52.856086
427	68	4.0	520	3.5	0.5	eleve	114000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.77	amelioration	2025-01-05 08:01:52.856086
428	68	4.3	536	4.0	0.3	eleve	114000.00	Paiement Ã  temps	0.78	amelioration	2025-02-19 08:01:52.856086
429	68	4.8	564	4.3	0.5	eleve	114000.00	Nouveau crÃ©dit accordÃ©	0.79	amelioration	2025-04-05 08:01:52.856086
430	68	5.1	580	4.8	0.3	eleve	114000.00	Nouveau crÃ©dit accordÃ©	0.80	amelioration	2025-05-20 08:01:52.856086
431	68	5.4	597	5.1	0.3	eleve	114000.00	Paiement Ã  temps	0.81	amelioration	2025-07-04 08:01:52.856086
432	68	5.8	619	5.4	0.4	eleve	114000.00	Nouveau crÃ©dit accordÃ©	0.82	amelioration	2025-08-18 08:01:52.856086
433	68	6.4	652	5.8	0.6	moyen	190000.00	Paiement Ã  temps	0.84	amelioration	2025-10-02 08:01:52.856086
434	69	5.7	613	5.6	0.1	eleve	138000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.82	stable	2025-01-05 08:01:52.856086
435	69	5.9	624	5.7	0.2	eleve	138000.00	Paiement Ã  temps	0.83	stable	2025-02-19 08:01:52.856086
436	69	6.0	630	5.9	0.1	moyen	230000.00	Paiement Ã  temps	0.83	stable	2025-04-05 08:01:52.856086
437	69	6.1	635	6.0	0.1	moyen	230000.00	Paiement Ã  temps	0.83	stable	2025-05-20 08:01:52.856086
438	69	6.4	652	6.1	0.3	moyen	230000.00	Paiement Ã  temps	0.84	amelioration	2025-07-04 08:01:52.856086
439	69	6.4	652	6.4	0.0	moyen	230000.00	Nouveau crÃ©dit accordÃ©	0.84	stable	2025-08-18 08:01:52.856086
440	69	6.7	668	6.4	0.3	moyen	230000.00	Nouveau crÃ©dit accordÃ©	0.85	amelioration	2025-10-02 08:01:52.856086
441	70	3.4	487	3.2	0.2	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.75	stable	2025-01-05 08:01:52.856086
442	70	3.8	509	3.4	0.4	tres_eleve	0.00	Paiement Ã  temps	0.76	amelioration	2025-02-19 08:01:52.856086
443	70	4.1	525	3.8	0.3	eleve	84000.00	Paiement Ã  temps	0.77	amelioration	2025-04-05 08:01:52.856086
444	70	4.4	542	4.1	0.3	eleve	84000.00	Nouveau crÃ©dit accordÃ©	0.78	amelioration	2025-05-20 08:01:52.856086
445	70	4.8	564	4.4	0.4	eleve	84000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.79	amelioration	2025-07-04 08:01:52.856086
446	70	4.9	569	4.8	0.1	eleve	84000.00	Paiement Ã  temps	0.80	stable	2025-08-18 08:01:52.856086
447	70	5.2	586	4.9	0.3	eleve	84000.00	Nouveau crÃ©dit accordÃ©	0.81	amelioration	2025-10-02 08:01:52.856086
448	71	3.9	514	3.5	0.4	tres_eleve	0.00	Paiement Ã  temps	0.77	amelioration	2025-02-19 08:01:52.856086
449	71	4.2	531	3.9	0.3	eleve	54000.00	Nouveau crÃ©dit accordÃ©	0.78	amelioration	2025-04-05 08:01:52.856086
450	71	4.3	536	4.2	0.1	eleve	54000.00	Paiement Ã  temps	0.78	stable	2025-05-20 08:01:52.856086
451	71	4.5	547	4.3	0.2	eleve	54000.00	Paiement Ã  temps	0.79	stable	2025-07-04 08:01:52.856086
452	71	4.8	564	4.5	0.3	eleve	54000.00	Nouveau crÃ©dit accordÃ©	0.79	amelioration	2025-08-18 08:01:52.856086
453	71	4.9	569	4.8	0.1	eleve	54000.00	Nouveau crÃ©dit accordÃ©	0.80	stable	2025-10-02 08:01:52.856086
454	72	2.2	421	2.0	0.2	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.72	stable	2024-08-23 08:01:52.856086
455	72	2.4	432	2.2	0.2	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.72	stable	2024-10-07 08:01:52.856086
456	72	2.8	454	2.4	0.4	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.73	amelioration	2024-11-21 08:01:52.856086
457	72	2.9	459	2.8	0.1	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.74	stable	2025-01-05 08:01:52.856086
458	72	3.0	465	2.9	0.1	tres_eleve	0.00	Paiement Ã  temps	0.74	stable	2025-02-19 08:01:52.856086
459	72	3.2	476	3.0	0.2	tres_eleve	0.00	Paiement Ã  temps	0.75	stable	2025-04-05 08:01:52.856086
460	72	3.4	487	3.2	0.2	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.75	stable	2025-05-20 08:01:52.856086
461	72	3.6	498	3.4	0.2	tres_eleve	0.00	Paiement Ã  temps	0.76	stable	2025-07-04 08:01:52.856086
462	72	4.0	520	3.6	0.4	eleve	66000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.77	amelioration	2025-08-18 08:01:52.856086
463	72	4.5	547	4.0	0.5	eleve	66000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.79	amelioration	2025-10-02 08:01:52.856086
464	73	3.1	470	3.0	0.1	tres_eleve	0.00	Paiement Ã  temps	0.74	stable	2024-08-23 08:01:52.856086
465	73	3.3	481	3.1	0.2	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.75	stable	2024-10-07 08:01:52.856086
466	73	3.5	492	3.3	0.2	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.76	stable	2024-11-21 08:01:52.856086
467	73	3.6	498	3.5	0.1	tres_eleve	0.00	Paiement Ã  temps	0.76	stable	2025-01-05 08:01:52.856086
468	73	3.6	498	3.6	0.0	tres_eleve	0.00	Paiement Ã  temps	0.76	stable	2025-02-19 08:01:52.856086
469	73	3.8	509	3.6	0.2	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.76	stable	2025-04-05 08:01:52.856086
470	73	3.9	514	3.8	0.1	tres_eleve	0.00	Paiement Ã  temps	0.77	stable	2025-05-20 08:01:52.856086
471	73	4.3	536	3.9	0.4	eleve	57000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.78	amelioration	2025-07-04 08:01:52.856086
472	73	4.6	553	4.3	0.3	eleve	57000.00	Nouveau crÃ©dit accordÃ©	0.79	amelioration	2025-08-18 08:01:52.856086
473	73	4.5	547	4.6	-0.1	eleve	57000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.79	stable	2025-10-02 08:01:52.856086
474	74	3.1	470	2.3	0.8	tres_eleve	0.00	Paiement Ã  temps	0.74	amelioration	2025-07-04 08:01:52.856086
475	74	4.0	520	3.1	0.9	eleve	72000.00	Nouveau crÃ©dit accordÃ©	0.77	amelioration	2025-08-18 08:01:52.856086
476	74	4.9	569	4.0	0.9	eleve	72000.00	Nouveau crÃ©dit accordÃ©	0.80	amelioration	2025-10-02 08:01:52.856086
477	75	3.8	509	3.5	0.3	tres_eleve	0.00	Paiement Ã  temps	0.76	amelioration	2025-04-05 08:01:52.856086
478	75	4.2	531	3.8	0.4	eleve	63000.00	Paiement Ã  temps	0.78	amelioration	2025-05-20 08:01:52.856086
479	75	4.6	553	4.2	0.4	eleve	63000.00	Paiement Ã  temps	0.79	amelioration	2025-07-04 08:01:52.856086
480	75	4.7	558	4.6	0.1	eleve	63000.00	Nouveau crÃ©dit accordÃ©	0.79	stable	2025-08-18 08:01:52.856086
481	75	4.9	569	4.7	0.2	eleve	63000.00	Nouveau crÃ©dit accordÃ©	0.80	stable	2025-10-02 08:01:52.856086
482	76	2.6	443	2.1	0.5	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.73	amelioration	2025-02-19 08:01:52.856086
483	76	2.9	459	2.6	0.3	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.74	amelioration	2025-04-05 08:01:52.856086
484	76	3.3	481	2.9	0.4	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.75	amelioration	2025-05-20 08:01:52.856086
485	76	3.7	503	3.3	0.4	tres_eleve	0.00	Paiement en retard	0.76	amelioration	2025-07-04 08:01:52.856086
486	76	3.9	514	3.7	0.2	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.77	stable	2025-08-18 08:01:52.856086
487	76	4.3	536	3.9	0.4	eleve	48000.00	Nouveau crÃ©dit accordÃ©	0.78	amelioration	2025-10-02 08:01:52.856086
488	77	2.7	448	2.1	0.6	tres_eleve	0.00	Paiement Ã  temps	0.73	amelioration	2025-02-19 08:01:52.856086
489	77	3.2	476	2.7	0.5	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.75	amelioration	2025-04-05 08:01:52.856086
490	77	3.6	498	3.2	0.4	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.76	amelioration	2025-05-20 08:01:52.856086
491	77	4.1	525	3.6	0.5	eleve	60000.00	Nouveau crÃ©dit accordÃ©	0.77	amelioration	2025-07-04 08:01:52.856086
492	77	4.5	547	4.1	0.4	eleve	60000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.79	amelioration	2025-08-18 08:01:52.856086
493	77	4.6	553	4.5	0.1	eleve	60000.00	Nouveau crÃ©dit accordÃ©	0.79	stable	2025-10-02 08:01:52.856086
494	78	2.8	454	2.2	0.6	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.73	amelioration	2025-04-05 08:01:52.856086
495	78	3.4	487	2.8	0.6	tres_eleve	0.00	Paiement Ã  temps	0.75	amelioration	2025-05-20 08:01:52.856086
496	78	4.0	520	3.4	0.6	eleve	75000.00	Nouveau crÃ©dit accordÃ©	0.77	amelioration	2025-07-04 08:01:52.856086
497	78	4.5	547	4.0	0.5	eleve	75000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.79	amelioration	2025-08-18 08:01:52.856086
498	78	5.0	575	4.5	0.5	eleve	75000.00	Nouveau crÃ©dit accordÃ©	0.80	amelioration	2025-10-02 08:01:52.856086
499	79	2.9	459	2.6	0.3	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.74	amelioration	2025-01-05 08:01:52.856086
500	79	3.2	476	2.9	0.3	tres_eleve	0.00	Paiement Ã  temps	0.75	amelioration	2025-02-19 08:01:52.856086
501	79	3.7	503	3.2	0.5	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.76	amelioration	2025-04-05 08:01:52.856086
502	79	4.1	525	3.7	0.4	eleve	69000.00	Paiement Ã  temps	0.77	amelioration	2025-05-20 08:01:52.856086
503	79	4.4	542	4.1	0.3	eleve	69000.00	Paiement Ã  temps	0.78	amelioration	2025-07-04 08:01:52.856086
504	79	4.7	558	4.4	0.3	eleve	69000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.79	amelioration	2025-08-18 08:01:52.856086
505	79	5.1	580	4.7	0.4	eleve	69000.00	Paiement Ã  temps	0.80	amelioration	2025-10-02 08:01:52.856086
506	80	2.1	415	1.7	0.4	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.71	amelioration	2024-10-07 08:01:52.856086
507	80	2.3	426	2.1	0.2	tres_eleve	0.00	Paiement en retard	0.72	stable	2024-11-21 08:01:52.856086
508	80	2.6	443	2.3	0.3	tres_eleve	0.00	Paiement Ã  temps	0.73	amelioration	2025-01-05 08:01:52.856086
509	80	3.0	465	2.6	0.4	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.74	amelioration	2025-02-19 08:01:52.856086
510	80	3.2	476	3.0	0.2	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.75	stable	2025-04-05 08:01:52.856086
511	80	3.5	492	3.2	0.3	tres_eleve	0.00	Paiement Ã  temps	0.76	amelioration	2025-05-20 08:01:52.856086
512	80	3.9	514	3.5	0.4	tres_eleve	0.00	Paiement en retard	0.77	amelioration	2025-07-04 08:01:52.856086
513	80	4.0	520	3.9	0.1	eleve	51000.00	Paiement Ã  temps	0.77	stable	2025-08-18 08:01:52.856086
514	80	4.4	542	4.0	0.4	eleve	51000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.78	amelioration	2025-10-02 08:01:52.856086
515	81	4.3	536	4.1	0.2	eleve	78000.00	Nouveau crÃ©dit accordÃ©	0.78	stable	2025-04-05 08:01:52.856086
516	81	4.5	547	4.3	0.2	eleve	78000.00	Nouveau crÃ©dit accordÃ©	0.79	stable	2025-05-20 08:01:52.856086
517	81	4.8	564	4.5	0.3	eleve	78000.00	Nouveau crÃ©dit accordÃ©	0.79	amelioration	2025-07-04 08:01:52.856086
518	81	5.0	575	4.8	0.2	eleve	78000.00	Paiement Ã  temps	0.80	stable	2025-08-18 08:01:52.856086
519	81	5.4	597	5.0	0.4	eleve	78000.00	Paiement Ã  temps	0.81	amelioration	2025-10-02 08:01:52.856086
520	82	2.8	454	2.3	0.5	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.73	amelioration	2025-02-19 08:01:52.856086
521	82	3.2	476	2.8	0.4	tres_eleve	0.00	Paiement Ã  temps	0.75	amelioration	2025-04-05 08:01:52.856086
522	82	3.4	487	3.2	0.2	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.75	stable	2025-05-20 08:01:52.856086
523	82	3.9	514	3.4	0.5	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.77	amelioration	2025-07-04 08:01:52.856086
524	82	4.4	542	3.9	0.5	eleve	55500.00	Nouveau crÃ©dit accordÃ©	0.78	amelioration	2025-08-18 08:01:52.856086
525	82	4.5	547	4.4	0.1	eleve	55500.00	Nouveau crÃ©dit accordÃ©	0.79	stable	2025-10-02 08:01:52.856086
526	83	2.4	432	1.9	0.5	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.72	amelioration	2024-11-21 08:01:52.856086
527	83	2.7	448	2.4	0.3	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.73	amelioration	2025-01-05 08:01:52.856086
528	83	3.0	465	2.7	0.3	tres_eleve	0.00	Paiement Ã  temps	0.74	amelioration	2025-02-19 08:01:52.856086
529	83	3.4	487	3.0	0.4	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.75	amelioration	2025-04-05 08:01:52.856086
530	83	3.8	509	3.4	0.4	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.76	amelioration	2025-05-20 08:01:52.856086
531	83	4.0	520	3.8	0.2	eleve	58500.00	Nouveau crÃ©dit accordÃ©	0.77	stable	2025-07-04 08:01:52.856086
532	83	4.4	542	4.0	0.4	eleve	58500.00	Paiement Ã  temps	0.78	amelioration	2025-08-18 08:01:52.856086
533	83	4.7	558	4.4	0.3	eleve	58500.00	Nouveau crÃ©dit accordÃ©	0.79	amelioration	2025-10-02 08:01:52.856086
534	84	3.4	487	3.0	0.4	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.75	amelioration	2024-11-21 08:01:52.856086
535	84	3.8	509	3.4	0.4	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.76	amelioration	2025-01-05 08:01:52.856086
536	84	4.0	520	3.8	0.2	eleve	81000.00	Nouveau crÃ©dit accordÃ©	0.77	stable	2025-02-19 08:01:52.856086
537	84	4.4	542	4.0	0.4	eleve	81000.00	Nouveau crÃ©dit accordÃ©	0.78	amelioration	2025-04-05 08:01:52.856086
538	84	4.8	564	4.4	0.4	eleve	81000.00	Paiement Ã  temps	0.79	amelioration	2025-05-20 08:01:52.856086
539	84	5.1	580	4.8	0.3	eleve	81000.00	Paiement Ã  temps	0.80	amelioration	2025-07-04 08:01:52.856086
540	84	5.2	586	5.1	0.1	eleve	81000.00	Nouveau crÃ©dit accordÃ©	0.81	stable	2025-08-18 08:01:52.856086
541	84	5.5	602	5.2	0.3	eleve	81000.00	Paiement Ã  temps	0.82	amelioration	2025-10-02 08:01:52.856086
542	85	2.6	443	2.3	0.3	tres_eleve	0.00	Paiement Ã  temps	0.73	amelioration	2025-01-05 08:01:52.856086
543	85	2.9	459	2.6	0.3	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.74	amelioration	2025-02-19 08:01:52.856086
544	85	3.1	470	2.9	0.2	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.74	stable	2025-04-05 08:01:52.856086
545	85	3.5	492	3.1	0.4	tres_eleve	0.00	Paiement Ã  temps	0.76	amelioration	2025-05-20 08:01:52.856086
546	85	4.0	520	3.5	0.5	eleve	52500.00	Nouveau crÃ©dit accordÃ©	0.77	amelioration	2025-07-04 08:01:52.856086
547	85	4.3	536	4.0	0.3	eleve	52500.00	Paiement Ã  temps	0.78	amelioration	2025-08-18 08:01:52.856086
548	85	4.5	547	4.3	0.2	eleve	52500.00	CrÃ©dit remboursÃ© intÃ©gralement	0.79	stable	2025-10-02 08:01:52.856086
549	86	2.0	410	1.6	0.4	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.71	amelioration	2024-11-21 08:01:52.856086
550	86	2.2	421	2.0	0.2	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.72	stable	2025-01-05 08:01:52.856086
551	86	2.4	432	2.2	0.2	tres_eleve	0.00	Paiement Ã  temps	0.72	stable	2025-02-19 08:01:52.856086
552	86	2.9	459	2.4	0.5	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.74	amelioration	2025-04-05 08:01:52.856086
553	86	3.2	476	2.9	0.3	tres_eleve	0.00	Paiement Ã  temps	0.75	amelioration	2025-05-20 08:01:52.856086
554	86	3.4	487	3.2	0.2	tres_eleve	0.00	Paiement Ã  temps	0.75	stable	2025-07-04 08:01:52.856086
555	86	3.7	503	3.4	0.3	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.76	amelioration	2025-08-18 08:01:52.856086
556	86	4.3	536	3.7	0.6	eleve	46500.00	Nouveau crÃ©dit accordÃ©	0.78	amelioration	2025-10-02 08:01:52.856086
557	87	3.0	465	2.2	0.8	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.74	amelioration	2025-07-04 08:01:52.856086
558	87	4.0	520	3.0	1.0	eleve	61500.00	Nouveau crÃ©dit accordÃ©	0.77	amelioration	2025-08-18 08:01:52.856086
559	87	4.9	569	4.0	0.9	eleve	61500.00	Nouveau crÃ©dit accordÃ©	0.80	amelioration	2025-10-02 08:01:52.856086
560	88	3.1	470	2.9	0.2	tres_eleve	0.00	Paiement Ã  temps	0.74	stable	2024-11-21 08:01:52.856086
561	88	3.3	481	3.1	0.2	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.75	stable	2025-01-05 08:01:52.856086
562	88	3.6	498	3.3	0.3	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.76	amelioration	2025-02-19 08:01:52.856086
563	88	4.0	520	3.6	0.4	eleve	87000.00	Nouveau crÃ©dit accordÃ©	0.77	amelioration	2025-04-05 08:01:52.856086
564	88	4.2	531	4.0	0.2	eleve	87000.00	Nouveau crÃ©dit accordÃ©	0.78	stable	2025-05-20 08:01:52.856086
565	88	4.7	558	4.2	0.5	eleve	87000.00	Paiement Ã  temps	0.79	amelioration	2025-07-04 08:01:52.856086
566	88	5.0	575	4.7	0.3	eleve	87000.00	Paiement Ã  temps	0.80	amelioration	2025-08-18 08:01:52.856086
567	88	5.4	597	5.0	0.4	eleve	87000.00	Paiement Ã  temps	0.81	amelioration	2025-10-02 08:01:52.856086
568	89	3.6	498	3.0	0.6	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.76	amelioration	2025-05-20 08:01:52.856086
569	89	4.2	531	3.6	0.6	eleve	66000.00	Paiement Ã  temps	0.78	amelioration	2025-07-04 08:01:52.856086
570	89	4.6	553	4.2	0.4	eleve	66000.00	Nouveau crÃ©dit accordÃ©	0.79	amelioration	2025-08-18 08:01:52.856086
571	89	5.0	575	4.6	0.4	eleve	66000.00	Nouveau crÃ©dit accordÃ©	0.80	amelioration	2025-10-02 08:01:52.856086
572	90	2.4	432	2.1	0.3	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.72	amelioration	2024-08-23 08:01:52.856086
573	90	2.4	432	2.4	0.0	tres_eleve	0.00	Paiement Ã  temps	0.72	stable	2024-10-07 08:01:52.856086
574	90	2.4	432	2.4	0.0	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.72	stable	2024-11-21 08:01:52.856086
575	90	2.4	432	2.4	0.0	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.72	stable	2025-01-05 08:01:52.856086
576	90	2.6	443	2.4	0.2	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.73	stable	2025-02-19 08:01:52.856086
577	90	2.8	454	2.6	0.2	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.73	stable	2025-04-05 08:01:52.856086
578	90	2.9	459	2.8	0.1	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.74	stable	2025-05-20 08:01:52.856086
579	90	2.9	459	2.9	0.0	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.74	stable	2025-07-04 08:01:52.856086
580	90	3.0	465	2.9	0.1	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.74	stable	2025-08-18 08:01:52.856086
581	90	3.3	481	3.0	0.3	tres_eleve	0.00	Paiement Ã  temps	0.75	amelioration	2025-10-02 08:01:52.856086
582	91	0.8	344	0.5	0.3	tres_eleve	0.00	Paiement Ã  temps	0.67	amelioration	2024-11-21 08:01:52.856086
583	91	1.2	366	0.8	0.4	tres_eleve	0.00	Paiement en retard	0.69	amelioration	2025-01-05 08:01:52.856086
584	91	1.6	388	1.2	0.4	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.70	amelioration	2025-02-19 08:01:52.856086
585	91	1.8	399	1.6	0.2	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.70	stable	2025-04-05 08:01:52.856086
586	91	2.1	415	1.8	0.3	tres_eleve	0.00	Paiement en retard	0.71	amelioration	2025-05-20 08:01:52.856086
587	91	2.4	432	2.1	0.3	tres_eleve	0.00	Paiement Ã  temps	0.72	amelioration	2025-07-04 08:01:52.856086
588	91	2.5	437	2.4	0.1	tres_eleve	0.00	Paiement Ã  temps	0.73	stable	2025-08-18 08:01:52.856086
589	91	2.9	459	2.5	0.4	tres_eleve	0.00	Paiement Ã  temps	0.74	amelioration	2025-10-02 08:01:52.856086
590	92	0.2	311	-0.1	0.3	tres_eleve	0.00	Paiement Ã  temps	0.66	amelioration	2025-02-19 08:01:52.856086
591	92	0.7	338	0.2	0.5	tres_eleve	0.00	Paiement Ã  temps	0.67	amelioration	2025-04-05 08:01:52.856086
592	92	1.2	366	0.7	0.5	tres_eleve	0.00	Paiement Ã  temps	0.69	amelioration	2025-05-20 08:01:52.856086
593	92	1.7	393	1.2	0.5	tres_eleve	0.00	Paiement Ã  temps	0.70	amelioration	2025-07-04 08:01:52.856086
594	92	2.0	410	1.7	0.3	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.71	amelioration	2025-08-18 08:01:52.856086
595	92	2.6	443	2.0	0.6	tres_eleve	0.00	Paiement Ã  temps	0.73	amelioration	2025-10-02 08:01:52.856086
596	93	1.5	382	0.8	0.7	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.70	amelioration	2025-07-04 08:01:52.856086
597	93	2.3	426	1.5	0.8	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.72	amelioration	2025-08-18 08:01:52.856086
598	93	2.9	459	2.3	0.6	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.74	amelioration	2025-10-02 08:01:52.856086
599	94	1.1	360	0.7	0.4	tres_eleve	0.00	Paiement Ã  temps	0.68	amelioration	2024-10-07 08:01:52.856086
600	94	1.5	382	1.1	0.4	tres_eleve	0.00	Paiement en retard	0.70	amelioration	2024-11-21 08:01:52.856086
601	94	1.7	393	1.5	0.2	tres_eleve	0.00	Paiement Ã  temps	0.70	stable	2025-01-05 08:01:52.856086
602	94	2.0	410	1.7	0.3	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.71	amelioration	2025-02-19 08:01:52.856086
603	94	2.2	421	2.0	0.2	tres_eleve	0.00	Paiement Ã  temps	0.72	stable	2025-04-05 08:01:52.856086
604	94	2.5	437	2.2	0.3	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.73	amelioration	2025-05-20 08:01:52.856086
605	94	2.8	454	2.5	0.3	tres_eleve	0.00	Paiement Ã  temps	0.73	amelioration	2025-07-04 08:01:52.856086
606	94	3.2	476	2.8	0.4	tres_eleve	0.00	Paiement Ã  temps	0.75	amelioration	2025-08-18 08:01:52.856086
607	94	3.5	492	3.2	0.3	tres_eleve	0.00	Paiement Ã  temps	0.76	amelioration	2025-10-02 08:01:52.856086
608	95	1.4	377	0.8	0.6	tres_eleve	0.00	Paiement Ã  temps	0.69	amelioration	2025-05-20 08:01:52.856086
609	95	1.9	404	1.4	0.5	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.71	amelioration	2025-07-04 08:01:52.856086
610	95	2.2	421	1.9	0.3	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.72	amelioration	2025-08-18 08:01:52.856086
611	95	2.8	454	2.2	0.6	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.73	amelioration	2025-10-02 08:01:52.856086
612	96	0.8	344	0.5	0.3	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.67	amelioration	2024-08-23 08:01:52.856086
613	96	1.1	360	0.8	0.3	tres_eleve	0.00	Paiement Ã  temps	0.68	amelioration	2024-10-07 08:01:52.856086
614	96	1.5	382	1.1	0.4	tres_eleve	0.00	Paiement Ã  temps	0.70	amelioration	2024-11-21 08:01:52.856086
615	96	1.8	399	1.5	0.3	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.70	amelioration	2025-01-05 08:01:52.856086
616	96	2.1	415	1.8	0.3	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.71	amelioration	2025-02-19 08:01:52.856086
617	96	2.2	421	2.1	0.1	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.72	stable	2025-04-05 08:01:52.856086
618	96	2.7	448	2.2	0.5	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.73	amelioration	2025-05-20 08:01:52.856086
619	96	3.1	470	2.7	0.4	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.74	amelioration	2025-07-04 08:01:52.856086
620	96	3.2	476	3.1	0.1	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.75	stable	2025-08-18 08:01:52.856086
621	96	3.4	487	3.2	0.2	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.75	stable	2025-10-02 08:01:52.856086
622	97	1.8	399	1.6	0.2	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.70	stable	2025-01-05 08:01:52.856086
623	97	2.1	415	1.8	0.3	tres_eleve	0.00	Paiement Ã  temps	0.71	amelioration	2025-02-19 08:01:52.856086
624	97	2.4	432	2.1	0.3	tres_eleve	0.00	Paiement Ã  temps	0.72	amelioration	2025-04-05 08:01:52.856086
625	97	2.5	437	2.4	0.1	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.73	stable	2025-05-20 08:01:52.856086
626	97	2.8	454	2.5	0.3	tres_eleve	0.00	Paiement Ã  temps	0.73	amelioration	2025-07-04 08:01:52.856086
627	97	2.9	459	2.8	0.1	tres_eleve	0.00	Paiement en retard	0.74	stable	2025-08-18 08:01:52.856086
628	97	3.0	465	2.9	0.1	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.74	stable	2025-10-02 08:01:52.856086
629	98	0.7	338	-0.2	0.9	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.67	amelioration	2025-07-04 08:01:52.856086
630	98	1.5	382	0.7	0.8	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.70	amelioration	2025-08-18 08:01:52.856086
631	98	2.2	421	1.5	0.7	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.72	amelioration	2025-10-02 08:01:52.856086
632	99	1.2	366	1.1	0.1	tres_eleve	0.00	Paiement Ã  temps	0.69	stable	2024-10-07 08:01:52.856086
633	99	1.4	377	1.2	0.2	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.69	stable	2024-11-21 08:01:52.856086
634	99	1.7	393	1.4	0.3	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.70	amelioration	2025-01-05 08:01:52.856086
635	99	1.9	404	1.7	0.2	tres_eleve	0.00	Paiement Ã  temps	0.71	stable	2025-02-19 08:01:52.856086
636	99	2.1	415	1.9	0.2	tres_eleve	0.00	Paiement en retard	0.71	stable	2025-04-05 08:01:52.856086
637	99	2.3	426	2.1	0.2	tres_eleve	0.00	Paiement Ã  temps	0.72	stable	2025-05-20 08:01:52.856086
638	99	2.5	437	2.3	0.2	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.73	stable	2025-07-04 08:01:52.856086
639	99	2.4	432	2.5	-0.1	tres_eleve	0.00	Paiement Ã  temps	0.72	stable	2025-08-18 08:01:52.856086
640	99	2.6	443	2.4	0.2	tres_eleve	0.00	Paiement Ã  temps	0.73	stable	2025-10-02 08:01:52.856086
\.


--
-- Data for Name: restrictions_credit; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.restrictions_credit (id, utilisateur_id, peut_emprunter, credits_actifs_count, credits_max_autorises, dette_totale_active, ratio_endettement, date_derniere_demande, date_prochaine_eligibilite, jours_avant_prochaine_demande, raison_blocage, date_creation, date_modification) FROM stdin;
1	55	t	1	2	151212.80	43.20	2025-02-28 04:50:27.497469	2025-03-30 04:50:27.497469	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
2	27	t	0	2	0.00	0.00	2025-02-13 01:12:03.980074	2025-03-15 01:12:03.980074	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
3	23	t	0	2	0.00	0.00	2025-02-09 20:42:38.659398	2025-03-11 20:42:38.659398	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
4	56	t	0	2	0.00	0.00	2025-06-13 21:28:20.935285	2025-07-13 21:28:20.935285	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
5	91	f	0	2	0.00	0.00	2025-09-26 18:13:25.415486	2025-10-26 18:13:25.415486	25	Score de crÃ©dit insuffisant	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
6	58	t	1	2	74274.13	14.56	2025-03-15 20:45:08.480088	2025-04-14 20:45:08.480088	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
7	8	t	1	2	385129.15	35.01	2025-09-15 13:27:54.349741	2025-10-15 13:27:54.349741	14	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
8	87	f	1	2	197610.18	96.40	2025-09-05 06:13:31.515649	2025-10-05 06:13:31.515649	3	Ratio d'endettement trop Ã©levÃ© (>70%)	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
9	74	t	0	2	0.00	0.00	2025-05-20 17:04:13.519471	2025-06-19 17:04:13.519471	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
10	54	t	1	2	13164.87	2.39	2025-09-06 22:11:07.667394	2025-10-06 22:11:07.667394	5	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
11	29	t	1	2	676200.93	47.62	2025-02-23 11:48:49.360185	2025-03-25 11:48:49.360185	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
12	71	t	0	2	0.00	0.00	2025-04-20 19:44:47.071897	2025-05-20 19:44:47.071897	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
13	68	t	1	2	129923.94	34.19	2025-09-26 00:41:05.896386	2025-10-26 00:41:05.896386	24	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
14	4	f	2	2	1893520.58	157.79	2025-09-11 22:37:27.230529	\N	10	Maximum de 2 crÃ©dits actifs atteint	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
15	34	t	0	2	0.00	0.00	2025-09-30 13:23:31.605617	2025-10-30 13:23:31.605617	29	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
16	51	t	0	2	0.00	0.00	2025-01-28 11:35:45.589659	2025-02-27 11:35:45.589659	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
17	96	f	0	2	0.00	0.00	2025-06-25 05:53:19.60818	2025-07-25 05:53:19.60818	0	Score de crÃ©dit insuffisant	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
18	80	t	1	2	111126.15	65.37	2025-09-19 18:58:47.02583	2025-10-19 18:58:47.02583	18	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
19	70	t	0	2	0.00	0.00	2025-02-22 10:32:22.278869	2025-03-24 10:32:22.278869	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
20	52	t	1	2	123919.54	34.42	2025-08-29 02:01:20.405515	2025-09-28 02:01:20.405515	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
21	83	t	0	2	0.00	0.00	2025-09-14 09:20:08.408359	2025-10-14 09:20:08.408359	13	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
22	67	t	0	2	0.00	0.00	2025-07-05 00:42:51.038809	2025-08-04 00:42:51.038809	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
23	63	t	0	2	0.00	0.00	2025-02-16 19:38:57.467382	2025-03-18 19:38:57.467382	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
24	90	f	1	2	153680.95	128.07	2025-07-04 09:59:49.714522	2025-08-03 09:59:49.714522	0	Score de crÃ©dit insuffisant	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
25	10	f	2	2	1124189.48	83.27	2025-09-22 20:46:11.845911	\N	21	Maximum de 2 crÃ©dits actifs atteint	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
26	35	t	0	2	0.00	0.00	2025-09-26 00:36:31.17746	2025-10-26 00:36:31.17746	24	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
27	45	t	1	2	57109.81	15.03	2025-08-23 04:47:51.503472	2025-09-22 04:47:51.503472	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
28	6	f	2	2	313610.81	22.40	2025-07-26 09:42:27.683278	\N	0	Maximum de 2 crÃ©dits actifs atteint	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
29	86	t	0	2	0.00	0.00	2025-04-26 20:28:22.712225	2025-05-26 20:28:22.712225	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
30	84	t	0	2	0.00	0.00	2025-09-06 23:50:07.204611	2025-10-06 23:50:07.204611	5	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
31	39	f	2	2	405081.40	84.39	2025-07-10 13:03:03.369047	\N	0	Maximum de 2 crÃ©dits actifs atteint	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
32	92	f	0	2	0.00	0.00	2025-09-15 14:44:24.718995	2025-10-15 14:44:24.718995	14	Score de crÃ©dit insuffisant	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
33	93	f	0	2	0.00	0.00	2025-09-12 23:18:48.980555	2025-10-12 23:18:48.980555	11	Score de crÃ©dit insuffisant	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
34	89	t	1	2	10037.04	4.56	2025-09-21 13:02:40.679109	2025-10-21 13:02:40.679109	20	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
35	69	t	0	2	0.00	0.00	2025-07-13 21:34:22.504549	2025-08-12 21:34:22.504549	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
36	36	t	1	2	133068.70	20.79	2025-06-15 00:55:52.749634	2025-07-15 00:55:52.749634	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
37	31	t	0	2	0.00	0.00	2025-09-16 10:37:59.911985	2025-10-16 10:37:59.911985	15	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
38	50	t	1	2	115761.34	23.62	2025-06-21 06:17:11.987134	2025-07-21 06:17:11.987134	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
39	60	t	1	2	343199.06	66.00	2025-04-16 08:28:08.122468	2025-05-16 08:28:08.122468	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
40	97	f	0	2	0.00	0.00	2025-05-18 13:10:01.589228	2025-06-17 13:10:01.589228	0	Score de crÃ©dit insuffisant	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
41	14	t	1	2	84164.45	6.58	2025-09-08 01:42:08.236614	2025-10-08 01:42:08.236614	6	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
42	66	t	1	2	23972.86	3.87	2025-05-16 17:56:25.393843	2025-06-15 17:56:25.393843	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
43	22	t	0	2	0.00	0.00	2024-10-13 17:49:08.792501	2024-11-12 17:49:08.792501	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
44	59	t	0	2	0.00	0.00	2025-04-03 18:28:26.822464	2025-05-03 18:28:26.822464	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
45	13	t	1	2	124844.23	14.69	2025-08-18 11:17:21.964639	2025-09-17 11:17:21.964639	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
46	65	t	0	2	0.00	0.00	2025-04-20 21:18:32.629696	2025-05-20 21:18:32.629696	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
47	2	t	1	2	136699.86	7.59	2025-08-30 10:12:32.596334	2025-09-29 10:12:32.596334	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
48	16	t	0	2	0.00	0.00	2025-03-29 15:43:21.25365	2025-04-28 15:43:21.25365	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
49	62	f	1	2	480201.52	70.62	2025-04-19 18:47:48.088537	2025-05-19 18:47:48.088537	0	Ratio d'endettement trop Ã©levÃ© (>70%)	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
50	75	t	0	2	0.00	0.00	2025-09-16 01:17:08.112315	2025-10-16 01:17:08.112315	14	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
51	98	f	0	2	0.00	0.00	2025-08-12 16:59:35.541902	2025-09-11 16:59:35.541902	0	Score de crÃ©dit insuffisant	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
52	73	t	1	2	9105.88	4.79	2025-05-02 00:27:21.341766	2025-06-01 00:27:21.341766	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
53	44	f	2	2	418600.26	93.02	2025-08-09 21:58:30.720428	\N	0	Maximum de 2 crÃ©dits actifs atteint	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
54	11	t	1	2	234002.52	16.14	2025-08-10 14:20:21.557645	2025-09-09 14:20:21.557645	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
55	99	f	0	2	0.00	0.00	2025-09-08 14:57:39.559141	2025-10-08 14:57:39.559141	7	Score de crÃ©dit insuffisant	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
56	42	t	0	2	0.00	0.00	2025-06-17 08:39:51.394881	2025-07-17 08:39:51.394881	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
57	88	t	0	2	0.00	0.00	2025-04-29 16:15:26.080859	2025-05-29 16:15:26.080859	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
58	82	t	0	2	0.00	0.00	2025-09-06 17:40:29.815255	2025-10-06 17:40:29.815255	5	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
59	41	t	1	2	31113.69	4.79	2025-07-08 20:46:12.278269	2025-08-07 20:46:12.278269	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
60	46	t	0	2	0.00	0.00	2025-07-13 18:20:11.759923	2025-08-12 18:20:11.759923	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
61	40	t	0	2	0.00	0.00	2025-09-17 16:04:54.002176	2025-10-17 16:04:54.002176	16	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
62	43	f	2	2	478652.08	113.96	2025-09-04 22:38:02.02038	\N	3	Maximum de 2 crÃ©dits actifs atteint	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
63	53	t	0	2	0.00	0.00	2025-06-05 05:23:01.251111	2025-07-05 05:23:01.251111	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
64	32	f	1	2	373456.35	71.82	2025-09-17 00:08:00.483171	2025-10-17 00:08:00.483171	15	Ratio d'endettement trop Ã©levÃ© (>70%)	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
65	9	f	2	2	690921.65	43.18	2025-09-19 23:07:37.698149	\N	18	Maximum de 2 crÃ©dits actifs atteint	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
66	7	f	2	2	611800.15	32.20	2025-09-20 23:14:47.590063	\N	19	Maximum de 2 crÃ©dits actifs atteint	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
67	38	f	2	2	163828.68	22.75	2025-09-04 21:30:04.334728	\N	3	Maximum de 2 crÃ©dits actifs atteint	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
68	15	t	1	2	435992.25	28.13	2025-07-13 04:47:06.937192	2025-08-12 04:47:06.937192	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
69	79	t	1	2	50207.66	21.83	2025-10-01 08:22:32.000441	2025-10-31 08:22:32.000441	30	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
70	48	f	2	2	532378.56	102.38	2025-07-08 12:29:40.462174	\N	0	Maximum de 2 crÃ©dits actifs atteint	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
71	26	t	1	2	455302.75	43.36	2025-02-26 09:26:18.932755	2025-03-28 09:26:18.932755	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
72	12	f	2	2	121439.84	12.78	2025-07-26 11:50:57.314813	\N	0	Maximum de 2 crÃ©dits actifs atteint	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
73	85	t	0	2	0.00	0.00	2025-08-13 04:20:37.16385	2025-09-12 04:20:37.16385	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
74	72	t	1	2	46154.94	20.98	2025-05-04 09:27:47.003317	2025-06-03 09:27:47.003317	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
75	95	f	0	2	0.00	0.00	2025-08-25 23:38:18.149877	2025-09-24 23:38:18.149877	0	Score de crÃ©dit insuffisant	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
76	78	t	0	2	0.00	0.00	2025-09-08 10:24:50.127478	2025-10-08 10:24:50.127478	7	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
77	57	t	0	2	0.00	0.00	2025-02-15 22:58:40.401315	2025-03-17 22:58:40.401315	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
78	24	t	1	2	79202.35	4.89	2025-03-20 03:38:13.961761	2025-04-19 03:38:13.961761	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
79	81	t	1	2	29909.64	11.50	2025-09-14 06:52:39.689084	2025-10-14 06:52:39.689084	12	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
80	61	t	1	2	196280.99	32.71	2025-02-15 00:50:33.738758	2025-03-17 00:50:33.738758	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
81	19	t	0	2	0.00	0.00	2025-08-09 02:56:52.774093	2025-09-08 02:56:52.774093	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
82	77	t	1	2	7976.65	3.99	2025-10-01 10:04:35.604583	2025-10-31 10:04:35.604583	30	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
83	25	t	0	2	0.00	0.00	2024-12-15 23:16:49.089899	2025-01-14 23:16:49.089899	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
84	94	f	0	2	0.00	0.00	2025-09-28 06:19:44.735625	2025-10-28 06:19:44.735625	26	Score de crÃ©dit insuffisant	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
85	30	t	1	2	512008.48	40.00	2025-05-21 18:39:27.302804	2025-06-20 18:39:27.302804	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
86	21	t	1	2	269373.91	14.33	2025-09-26 22:38:47.838063	2025-10-26 22:38:47.838063	25	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
87	49	t	1	2	115594.63	34.00	2025-07-16 12:52:11.881984	2025-08-15 12:52:11.881984	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
88	47	t	1	2	34150.77	7.42	2025-07-28 04:30:12.70999	2025-08-27 04:30:12.70999	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
89	3	f	2	2	631179.17	42.08	2025-09-18 13:13:00.159178	\N	17	Maximum de 2 crÃ©dits actifs atteint	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
90	17	t	0	2	0.00	0.00	2025-09-11 23:24:56.371407	2025-10-11 23:24:56.371407	10	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
91	37	f	2	2	118649.51	21.57	2025-08-15 12:55:09.512317	\N	0	Maximum de 2 crÃ©dits actifs atteint	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
92	28	t	1	2	763503.08	48.32	2025-01-16 09:00:10.429065	2025-02-15 09:00:10.429065	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
93	20	t	0	2	0.00	0.00	2025-09-27 18:53:28.85246	2025-10-27 18:53:28.85246	26	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
94	33	t	1	2	55773.35	7.44	2025-09-20 01:37:38.677166	2025-10-20 01:37:38.677166	18	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
95	1	f	2	2	1075516.33	43.02	2025-08-14 22:56:19.298062	\N	0	Maximum de 2 crÃ©dits actifs atteint	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
96	76	t	1	2	94106.36	58.82	2025-08-23 07:07:40.219977	2025-09-22 07:07:40.219977	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
97	5	t	1	2	192233.84	9.61	2025-09-05 18:31:54.933348	2025-10-05 18:31:54.933348	4	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
98	18	t	1	2	409245.28	28.82	2025-03-12 11:49:05.173728	2025-04-11 11:49:05.173728	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
99	64	t	1	2	266211.55	60.50	2025-05-30 00:57:53.455338	2025-06-29 00:57:53.455338	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
\.


--
-- Data for Name: utilisateurs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.utilisateurs (id, uuid, nom, prenom, email, telephone, mot_de_passe_hash, ville, quartier, province, profession, employeur, statut_emploi, revenu_mensuel, anciennete_mois, charges_mensuelles, dettes_existantes, score_credit, score_850, niveau_risque, montant_eligible, statut, date_creation, date_modification, derniere_connexion) FROM stdin;
1	8eea411c-d0aa-4528-b3c7-6bcf21378f0a	OBAME	Jean-Pierre	jp.obame@email.ga	077111001	$2b$10$hash1	Libreville	Glass	Estuaire	IngÃ©nieur PÃ©trole	Total Gabon	cdi	2500000.00	72	800000.00	0.00	9.2	780	tres_bas	2000000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
2	aa9b39ba-405d-42ac-b504-cdff5b697ced	NGUEMA	Marie-Claire	mc.nguema@email.ga	077111002	$2b$10$hash2	Libreville	NombakÃ©LÃ©	Estuaire	Directrice RH	Banque Gabonaise	cdi	1800000.00	96	600000.00	0.00	8.9	750	tres_bas	1500000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
3	5afcfa17-1b47-4cdc-b99b-317c548bfcd0	MBOUMBA	Patrick	p.mboumba@email.ga	077111003	$2b$10$hash3	Libreville	Batterie IV	Estuaire	Manager IT	Gabon Telecom	cdi	1500000.00	60	500000.00	200000.00	8.5	720	bas	1200000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
4	434fc68d-b4ba-415e-a357-b2831d4cdc3a	MINTSA	Sylvie	s.mintsa@email.ga	077111004	$2b$10$hash4	Port-Gentil	CitÃ©	OgoouÃ©-Maritime	Comptable Senior	Perenco	cdi	1200000.00	84	400000.00	0.00	8.7	740	tres_bas	1000000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
5	c87286b2-bbb4-475b-91e3-8d206dfb270a	ONDO	FranÃ§ois	f.ondo@email.ga	077111005	$2b$10$hash5	Libreville	Lalala	Estuaire	MÃ©decin	Centre Hospitalier	fonctionnaire	2000000.00	120	700000.00	300000.00	8.3	710	bas	1600000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
6	deaf0d6c-d2ae-46dc-bfca-e80038b79a42	MOUSSAVOU	Georgette	g.moussavou@email.ga	077111006	$2b$10$hash6	Franceville	Potos	Haut-OgoouÃ©	Pharmacienne	Pharmacie Centrale	independant	1400000.00	48	450000.00	150000.00	8.6	730	bas	1100000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
7	4689618f-5f91-4b45-8f94-5a529706b185	BOULINGUI	Marcel	m.boulingui@email.ga	077111007	$2b$10$hash7	Libreville	Akanda	Estuaire	Avocat	Cabinet Juridique	independant	1900000.00	60	650000.00	0.00	8.8	745	tres_bas	1550000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
8	495650e4-a831-443e-a4f0-bd2e5385faf3	NZAMBA	Christelle	c.nzamba@email.ga	077111008	$2b$10$hash8	Libreville	Mont-BouÃ«t	Estuaire	Chef de Projet	MinistÃ¨re Ã‰conomie	fonctionnaire	1100000.00	72	380000.00	100000.00	8.4	715	bas	900000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
9	202759cd-28f9-40a2-8397-43b654235e88	EYEGHE	Antoine	a.eyeghe@email.ga	077111009	$2b$10$hash9	Libreville	Okala	Estuaire	Architecte	Bureau Ã‰tudes	cdi	1600000.00	54	520000.00	250000.00	8.2	705	bas	1300000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
10	41b10cfc-e34d-4539-909c-ff2ab60e89f3	NDONG BEKALE	Pauline	p.ndongbekale@email.ga	077111010	$2b$10$hash10	Port-Gentil	Quartier Basse	OgoouÃ©-Maritime	IngÃ©nieur Logistique	BollorÃ©	cdi	1350000.00	66	440000.00	0.00	8.7	738	tres_bas	1080000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
11	327e4b62-8190-42d3-bebd-4aba3e5b84e7	IVANGA	Rodrigue	r.ivanga@email.ga	077111011	$2b$10$hash11	Libreville	Nzeng-Ayong	Estuaire	ContrÃ´leur Financier	Assala Energy	cdi	1450000.00	78	480000.00	0.00	8.9	752	tres_bas	1160000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
12	c8e0f660-b369-4796-87bb-9fa6903ff8c2	MASSALA	Henriette	h.massala@email.ga	077111012	$2b$10$hash12	Libreville	Alibandeng	Estuaire	Professeur UniversitÃ©	UniversitÃ© Omar Bongo	fonctionnaire	950000.00	144	320000.00	0.00	8.1	698	bas	760000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
13	b40bc845-2b44-4820-8b95-e1677b99af1c	KOMBILA	Serge	s.kombila@email.ga	077111013	$2b$10$hash13	Oyem	Centre-Ville	Woleu-Ntem	Directeur Ã‰cole	Ã‰ducation Nationale	fonctionnaire	850000.00	108	290000.00	50000.00	8.0	690	bas	680000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
14	507bf1f0-e825-43cb-be26-d51193adeb2c	BOUNDA	Jacqueline	j.bounda@email.ga	077111014	$2b$10$hash14	Libreville	AkÃ©bÃ©	Estuaire	Responsable Achats	BGFI Bank	cdi	1280000.00	60	420000.00	180000.00	8.3	708	bas	1020000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
15	4900b124-e873-40c9-8bcc-990da98fc811	KOUMBA	Ernest	e.koumba@email.ga	077111015	$2b$10$hash15	Libreville	PK9	Estuaire	Chef de Service	Gabon Oil	cdi	1550000.00	90	510000.00	0.00	8.6	733	tres_bas	1240000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
16	b562730b-045a-46b9-a1af-e31f168f3f0d	LEKOGO	Sandrine	s.lekogo@email.ga	077111016	$2b$10$hash16	Libreville	Oloumi	Estuaire	Analyste CrÃ©dit	UGB Gabon	cdi	1150000.00	48	380000.00	120000.00	8.2	703	bas	920000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
17	0f41941e-b303-48ce-a233-95e5f57f892a	MOUNDOUNGA	Victor	v.moundounga@email.ga	077111017	$2b$10$hash17	Mouila	Sangatanga	NgouniÃ©	Entrepreneur BTP	Auto-entrepreneur	independant	1680000.00	72	560000.00	400000.00	8.0	692	bas	1340000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
18	4f7ba791-b2d9-4df0-a178-c29e179fdc91	NZIENGUI	Diane	d.nziengui@email.ga	077111018	$2b$10$hash18	Libreville	Louis	Estuaire	DRH Adjointe	BGFIBank	cdi	1420000.00	66	470000.00	0.00	8.5	725	bas	1140000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
19	f33d5621-abc2-4d26-8044-16318b6755cc	MAGANGA	Jules	j.maganga@email.ga	077111019	$2b$10$hash19	Libreville	Charbonnages	Estuaire	Pilote HÃ©licoptÃ¨re	Air Services	cdi	2100000.00	84	700000.00	500000.00	8.1	695	bas	1680000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
20	0a1469a4-d13d-46db-a289-9f7bed82e37b	OVONO	Laurence	l.ovono@email.ga	077111020	$2b$10$hash20	Libreville	Centre-Ville	Estuaire	Notaire	Ã‰tude Notariale	independant	1750000.00	96	580000.00	0.00	8.8	748	tres_bas	1400000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
21	19013eda-1a4e-47a0-bc4f-c3ad58eafb07	BOUASSA	Raymond	r.bouassa@email.ga	077111021	$2b$10$hash21	Port-Gentil	Nouveau Port	OgoouÃ©-Maritime	Superviseur Offshore	Schlumberger	cdi	1880000.00	72	620000.00	280000.00	8.4	718	bas	1500000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
22	7c52a721-210c-4450-872a-672c4f785f87	LENDOYE	Odette	o.lendoye@email.ga	077111022	$2b$10$hash22	Libreville	Atong Abe	Estuaire	Responsable Marketing	Total Gabon	cdi	1320000.00	54	440000.00	0.00	8.3	710	bas	1060000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
23	11e6fd36-0b76-46b5-b242-e846667c5fca	NGOMA	Thierry	t.ngoma@email.ga	077111023	$2b$10$hash23	Libreville	Sotega	Estuaire	IngÃ©nieur RÃ©seau	Airtel Gabon	cdi	1480000.00	60	490000.00	150000.00	8.5	728	bas	1180000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
24	d084c834-b19a-436d-9e14-492238601dfd	OKOMO	VÃ©ronique	v.okomo@email.ga	077111024	$2b$10$hash24	Libreville	Nzeng-Ayong	Estuaire	Consultante Finance	Cabinet Conseil	independant	1620000.00	48	540000.00	0.00	8.6	735	bas	1300000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
25	34f86d3d-b287-4061-813c-8b3462efeae4	PAMBOU	GÃ©rard	g.pambou@email.ga	077111025	$2b$10$hash25	Franceville	BangombÃ©	Haut-OgoouÃ©	Chef Comptable	Comilog	cdi	1190000.00	90	390000.00	100000.00	8.3	712	bas	950000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
26	81408af2-6458-44c2-a7d7-b3315b583ddf	TCHOUMBA	AgnÃ¨s	a.tchoumba@email.ga	077111026	$2b$10$hash26	Libreville	Toulon	Estuaire	Responsable Formation	CNSS	fonctionnaire	1050000.00	84	350000.00	0.00	8.2	705	bas	840000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
27	ee4e17d5-fe6a-4c53-a2a6-c1b5f2e07baf	YEMBIT	Daniel	d.yembit@email.ga	077111027	$2b$10$hash27	Libreville	Bellevue	Estuaire	GÃ©rant Restaurant	Auto-entrepreneur	independant	1350000.00	60	450000.00	200000.00	8.1	698	bas	1080000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
28	5bc7c195-2f71-45fa-a90f-57aea22a430b	ZOMO	Mireille	m.zomo@email.ga	077111028	$2b$10$hash28	Libreville	Akanda II	Estuaire	Chef de Mission Audit	KPMG Gabon	cdi	1580000.00	66	520000.00	0.00	8.7	740	tres_bas	1260000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
29	a26a8ee8-a61a-4132-a680-12c2358e6595	BEKALE	Olivier	o.bekale@email.ga	077111029	$2b$10$hash29	Port-Gentil	Cap Lopez	OgoouÃ©-Maritime	Cadre Bancaire	BICIG	cdi	1420000.00	78	470000.00	120000.00	8.4	720	bas	1140000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
30	64118787-0217-4a2c-9de8-72f505465fe0	NDEMBI	Clarisse	c.ndembi@email.ga	077111030	$2b$10$hash30	Libreville	SabliÃ¨re	Estuaire	Responsable QualitÃ©	Ceca-Gadis	cdi	1280000.00	54	420000.00	0.00	8.6	733	bas	1020000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
31	5516e7ff-5006-4118-a034-d2abca25f2c9	BOUYOU	Michel	m.bouyou@email.ga	077222001	$2b$10$hash31	Libreville	Lalala	Estuaire	Technicien Informatique	SOBRAGA	cdi	680000.00	36	250000.00	180000.00	7.2	640	moyen	550000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
32	9aef0417-ebef-4980-99d3-678d80dfc4a6	DITEEKE	Albertine	a.diteeke@email.ga	077222002	$2b$10$hash32	Libreville	PK8	Estuaire	SecrÃ©taire Direction	MinistÃ¨re SantÃ©	fonctionnaire	520000.00	48	200000.00	100000.00	6.8	610	moyen	420000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
33	189444ee-debe-4784-bdae-af2de06d7518	ENGONE	LÃ©on	l.engone@email.ga	077222003	$2b$10$hash33	Libreville	Mont-BouÃ«t	Estuaire	Commercial	Orange Gabon	cdi	750000.00	30	280000.00	220000.00	7.0	625	moyen	600000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
34	0acf9a99-9efc-4a1b-9793-e825b20272f6	FOGUE	Roseline	r.fogue@email.ga	077222004	$2b$10$hash34	Port-Gentil	Madagascar	OgoouÃ©-Maritime	Agent Administratif	Mairie Port-Gentil	fonctionnaire	480000.00	60	190000.00	120000.00	6.9	618	moyen	380000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
35	024a91ca-1be3-4848-873e-6b15bc44375d	GANDZIAMI	Prosper	p.gandziami@email.ga	077222005	$2b$10$hash35	Libreville	Sibang	Estuaire	Chauffeur Poids Lourds	SETRAG	cdi	620000.00	42	240000.00	150000.00	7.1	632	moyen	500000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
36	6a828c4e-2475-416b-a5da-84d511456e71	IKAPI	Blaise	b.ikapi@email.ga	077222007	$2b$10$hash37	Libreville	Okala	Estuaire	Ã‰lectricien	Gabon Ã‰lectricitÃ©	cdi	640000.00	36	240000.00	160000.00	6.9	620	moyen	510000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
37	c2500423-12e8-43a7-aba4-b22dbc4de280	KAYA	Ã‰lise	e.kaya@email.ga	077222008	$2b$10$hash38	Libreville	NombakÃ©LÃ©	Estuaire	Assistante Comptable	PME Locale	cdd	550000.00	24	210000.00	130000.00	6.7	605	moyen	440000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
38	4d971ae3-3510-495c-9b4d-43c2bc173c33	LEBIGUI	ArsÃ¨ne	a.lebigui@email.ga	077222009	$2b$10$hash39	Franceville	Ogoua	Haut-OgoouÃ©	Agent de MaÃ®trise	Comilog	cdi	720000.00	48	270000.00	190000.00	7.2	638	moyen	580000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
39	f9535327-658b-426c-aa0b-2f266f856a8d	MAKOSSO	JosÃ©phine	j.makosso@email.ga	077222010	$2b$10$hash40	Libreville	Batterie IV	Estuaire	Vendeuse	SupermarchÃ© Score	cdi	480000.00	30	190000.00	110000.00	6.6	598	moyen	380000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
40	84f80da2-c509-4609-aa7e-ead6f06272e4	NANG	Bernard	b.nang@email.ga	077222011	$2b$10$hash41	Libreville	AwendjÃ©	Estuaire	Plombier	Auto-entrepreneur	independant	590000.00	60	230000.00	150000.00	7.0	628	moyen	470000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
41	10f26ff8-56ce-4c52-b66b-9a2b58d42e08	OBIANG	Fernande	f.obiang@email.ga	077222012	$2b$10$hash42	Libreville	Glass	Estuaire	Enseignante Primaire	Ã‰ducation Nationale	fonctionnaire	650000.00	72	250000.00	170000.00	7.3	642	moyen	520000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
42	2aab8e7f-cd10-4c3a-8638-a41923b3aeec	PAMBOU	Christian	c.pambou@email.ga	077222013	$2b$10$hash43	Port-Gentil	Boulingui	OgoouÃ©-Maritime	MÃ©canicien Auto	Garage PrivÃ©	cdi	560000.00	42	220000.00	140000.00	6.8	612	moyen	450000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
43	dbfd2839-8ce0-47b3-b049-7f90b7ab90ad	QUEMBO	AngÃ©lique	a.quembo@email.ga	077222014	$2b$10$hash44	Libreville	PK5	Estuaire	Coiffeuse	Salon de BeautÃ©	independant	420000.00	36	170000.00	90000.00	6.5	590	moyen	340000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
44	2ce57a7b-d93d-481f-baa2-6e97e492633d	RETENO	Faustin	f.reteno@email.ga	077222015	$2b$10$hash45	Libreville	Ancien Chantier	Estuaire	Agent de SÃ©curitÃ©	SociÃ©tÃ© SÃ©curitÃ©	cdi	450000.00	48	180000.00	100000.00	6.7	608	moyen	360000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
45	1ebb9341-e528-476d-97c7-3726f41ddb91	SAMBA	GisÃ¨le	g.samba@email.ga	077222016	$2b$10$hash46	Libreville	Nzeng-Ayong	Estuaire	CaissiÃ¨re	Station Service	cdi	380000.00	24	160000.00	80000.00	6.4	585	moyen	300000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
46	b3759999-ee18-41b4-9a14-492d8ec15ee3	TCHIBINTA	Armand	a.tchibinta@email.ga	077222017	$2b$10$hash47	Libreville	Akanda	Estuaire	Technicien Maintenance	SEEG	cdi	670000.00	54	260000.00	180000.00	7.1	635	moyen	540000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
47	c34ec8c3-7c91-4985-92e3-19d2f429e453	UROBO	ValÃ©rie	v.urobo@email.ga	077222018	$2b$10$hash48	Libreville	Alibandeng	Estuaire	Aide-Soignante	Clinique PrivÃ©e	cdd	460000.00	18	185000.00	105000.00	6.5	592	moyen	370000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
48	3e5f44d4-e112-41a6-82a9-e5900af2c308	VIDJABO	Paul	p.vidjabo@email.ga	077222019	$2b$10$hash49	Oyem	Centre	Woleu-Ntem	Chauffeur Taxi	Auto-entrepreneur	independant	520000.00	48	210000.00	130000.00	6.8	615	moyen	420000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
49	aa98cf82-5eba-4d59-8353-f2c6149509e6	WORA	Brigitte	b.wora@email.ga	077222020	$2b$10$hash50	Libreville	Sibang	Estuaire	Serveuse Restaurant	Restaurant Local	autre	340000.00	12	150000.00	70000.00	6.2	575	moyen	270000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
50	f570916b-84e9-4c76-b2d8-4c0f6f3df559	YEMBA	Gilbert	g.yemba@email.ga	077222021	$2b$10$hash51	Libreville	Charbonnages	Estuaire	Ouvrier BTP	Entreprise Construction	cdd	490000.00	30	200000.00	120000.00	6.6	600	moyen	390000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
51	7ff37ae1-b16e-4119-9e12-6751a6f6cf59	ZINGA	Martine	m.zinga@email.ga	077222022	$2b$10$hash52	Libreville	AkÃ©bÃ©	Estuaire	EmployÃ©e Bureau	Cabinet Avocat	cdi	540000.00	36	215000.00	135000.00	6.9	622	moyen	430000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
52	6fcc6b63-0f71-40b7-8b76-3966975c0397	ALLOGO	HervÃ©	h.allogo@email.ga	077222023	$2b$10$hash53	Libreville	Atong Abe	Estuaire	Gardien Immeuble	CopropriÃ©tÃ©	cdi	360000.00	60	155000.00	75000.00	6.3	580	moyen	290000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
53	d33081f1-f410-427a-a839-d726cc2b9954	BINET	StÃ©phanie	s.binet@email.ga	077222024	$2b$10$hash54	Port-Gentil	Grand Village	OgoouÃ©-Maritime	RÃ©ceptionniste	HÃ´tel Atlantique	cdi	470000.00	42	190000.00	110000.00	6.7	610	moyen	380000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
54	fd646a76-6253-4e20-8922-87f406c3a176	COMBO	Ã‰douard	e.combo@email.ga	077222025	$2b$10$hash55	Libreville	Oloumi	Estuaire	MaÃ§on	Auto-entrepreneur	independant	550000.00	48	220000.00	145000.00	6.9	618	moyen	440000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
55	3989a64f-bc83-4601-b23c-d4aeec9754b4	DIKAMONA	Lydie	l.dikamona@email.ga	077222026	$2b$10$hash56	Libreville	Louis	Estuaire	Agent Entretien	Entreprise Nettoyage	cdi	350000.00	36	150000.00	72000.00	6.2	578	moyen	280000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
56	1c60bf24-b2d4-43c9-884e-c7d73d67e429	EBANG	Robert	r.ebang@email.ga	077222027	$2b$10$hash57	Libreville	PK9	Estuaire	Menuisier	Atelier PrivÃ©	independant	580000.00	54	230000.00	155000.00	7.0	625	moyen	460000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
57	d8e6ebba-0446-4a83-8296-bd1e431a2f26	FILA	Annette	a.fila@email.ga	077222028	$2b$10$hash58	Libreville	Nzeng-Ayong	Estuaire	Standardiste	SociÃ©tÃ© PrivÃ©e	cdi	420000.00	30	175000.00	95000.00	6.5	595	moyen	340000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
58	b7a9d400-8647-4068-b23f-c0eda90c5dd4	GASSAMA	LÃ©onard	l.gassama@email.ga	077222029	$2b$10$hash59	Libreville	Batterie IV	Estuaire	Cuisinier	Restaurant Touristique	cdi	510000.00	36	205000.00	125000.00	6.8	612	moyen	410000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
59	b5dba3b0-c8ba-4dc4-ac81-871a26663e0d	HONGUI	Sophie	s.hongui@email.ga	077222030	$2b$10$hash60	Libreville	Sotega	Estuaire	Vendeuse Boutique	Commerce Local	cdi	390000.00	24	165000.00	85000.00	6.4	588	moyen	310000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
60	5aa235dd-d828-40a6-b159-a88a9f1d8323	ITSOUA	Maxime	m.itsoua@email.ga	077222031	$2b$10$hash61	Libreville	Akanda II	Estuaire	Magasinier	SociÃ©tÃ© Import	cdi	520000.00	48	210000.00	130000.00	6.9	620	moyen	420000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
61	225a7f0e-d4b9-479b-91b4-8348ac383a34	JIBIA	Rachel	r.jibia@email.ga	077222032	$2b$10$hash62	Libreville	Bellevue	Estuaire	Animatrice Radio	Radio Locale	cdd	600000.00	30	240000.00	160000.00	7.1	630	moyen	480000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
62	b2ccbad8-20fa-48ec-ac1b-bb1be79c5c3e	KOUMOU	Alphonse	a.koumou@email.ga	077222033	$2b$10$hash63	Franceville	Bel-Air	Haut-OgoouÃ©	Agent Logistique	SociÃ©tÃ© MiniÃ¨re	cdi	680000.00	42	265000.00	185000.00	7.2	640	moyen	540000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
63	0e199d4c-9b0d-4279-90b1-deeba53a3b35	LIBALA	Martine	m.libala@email.ga	077222034	$2b$10$hash64	Libreville	Toulon	Estuaire	Agent Commercial	Assurance GAB	cdi	620000.00	36	245000.00	155000.00	7.0	628	moyen	500000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
64	75f390e2-820c-4d99-bc91-84d3e4818400	MABIALA	Jacques	j.mabiala@email.ga	077222035	$2b$10$hash65	Port-Gentil	Aviation	OgoouÃ©-Maritime	ContrÃ´leur Bus	SociÃ©tÃ© Transport	cdi	440000.00	48	180000.00	100000.00	6.6	602	moyen	350000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
65	beead6a7-37b7-4ae1-b82e-272892d00c3e	NDAMBA	CÃ©cile	c.ndamba@email.ga	077222036	$2b$10$hash66	Libreville	AkÃ©bÃ© Plaine	Estuaire	SecrÃ©taire MÃ©dicale	Cabinet MÃ©dical	cdi	500000.00	42	200000.00	120000.00	6.8	615	moyen	400000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
66	a21752f1-74b5-4e5d-b569-038ac592a2ed	OBANDA	Justin	j.obanda@email.ga	077222037	$2b$10$hash67	Libreville	SabliÃ¨re	Estuaire	Technicien Froid	SociÃ©tÃ© Climatisation	independant	620000.00	54	245000.00	165000.00	7.1	632	moyen	500000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
67	393a0528-d6d7-42f1-9c94-5d79ee7cb30c	PAMBOU	Delphine	d.pambou2@email.ga	077222038	$2b$10$hash68	Libreville	Mont-BouÃ«t	Estuaire	GÃ©rante Boutique	Auto-entrepreneur	independant	550000.00	36	225000.00	140000.00	6.9	620	moyen	440000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
68	83ac54eb-9f61-4475-b2b5-0a07dd074637	QUILLARD	Thomas	t.quillard@email.ga	077222039	$2b$10$hash69	Libreville	Lalala	Estuaire	Livreur	SociÃ©tÃ© Livraison	cdd	380000.00	18	160000.00	80000.00	6.3	582	moyen	300000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
69	5faa61e8-00a3-4e54-8ece-b6336b8ca27a	ROGOMBE	Jeanne	j.rogombe@email.ga	077222040	$2b$10$hash70	Libreville	PK12	Estuaire	Agent Accueil	Clinique PrivÃ©e	cdi	460000.00	30	185000.00	105000.00	6.7	608	moyen	370000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
70	7ee1f98a-98d7-4757-9c4d-6d9eccad2e85	SAMBA BIYO	AndrÃ©	a.sambabiyo@email.ga	077333001	$2b$10$hash71	Libreville	AwendjÃ©	Estuaire	Vendeur MarchÃ©	Auto-entrepreneur	independant	280000.00	24	140000.00	120000.00	5.2	480	moyen	220000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
71	7296a9cc-08d1-4249-b819-628159ef093a	TCHOUMBA	Marie	m.tchoumba@email.ga	077333002	$2b$10$hash72	Libreville	Nzeng-Ayong	Estuaire	MÃ©nagÃ¨re	Particuliers	autre	180000.00	12	95000.00	60000.00	4.8	450	eleve	140000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
72	888fde5c-470e-4af4-b46f-456613ff4660	UROBO	Francis	f.urobo@email.ga	077333003	$2b$10$hash73	Libreville	PK8	Estuaire	Aide MaÃ§on	Chantiers	autre	220000.00	18	115000.00	85000.00	4.5	430	eleve	180000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
73	1613cbb6-d2fa-42d4-ae1e-80dae4b134de	VIEIRA	Lucie	l.vieira@email.ga	077333004	$2b$10$hash74	Port-Gentil	CitÃ© Nouvelle	OgoouÃ©-Maritime	Vendeuse Ambulante	Auto-entrepreneur	independant	190000.00	36	100000.00	70000.00	4.6	435	eleve	150000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
74	d51f218a-ad0d-48b9-a7fa-345a5a8f6a61	WAMBA	Pierre	p.wamba@email.ga	077333005	$2b$10$hash75	Libreville	Okala	Estuaire	Gardien	Immeuble PrivÃ©	autre	240000.00	30	125000.00	95000.00	4.9	455	eleve	190000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
75	de498184-e122-4a6a-b57d-69bef906179c	YAYI	Georgette	g.yayi@email.ga	077333006	$2b$10$hash76	Libreville	Alibandeng	Estuaire	Vendeuse Poisson	MarchÃ© Local	independant	210000.00	48	110000.00	80000.00	5.0	460	moyen	170000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
76	0a99aff2-11b8-475d-b4a2-34de12b18d1c	ZIGHA	Samuel	s.zigha@email.ga	077333007	$2b$10$hash77	Libreville	Sibang	Estuaire	Apprenti Ã‰lectricien	Formation	autre	160000.00	6	90000.00	50000.00	4.3	415	eleve	130000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
77	8a2a8760-3f88-40d4-b9c1-7d8450288440	ABAGA	Solange	s.abaga@email.ga	077333008	$2b$10$hash78	Libreville	Ancien Chantier	Estuaire	Revendeuse	Commerce Informel	independant	200000.00	24	105000.00	75000.00	4.7	440	eleve	160000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
78	f6e15fef-c385-43e6-b942-2c96093faae1	BIVIGOU	Ã‰tienne	e.bivigou@email.ga	077333009	$2b$10$hash79	Libreville	Charbonnages	Estuaire	ManÅ“uvre	SociÃ©tÃ© BTP	cdd	250000.00	12	130000.00	100000.00	5.1	470	moyen	200000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
79	0528ce7e-bf0b-487d-a21e-1874b338eebd	COMLAN	Ã‰milienne	e.comlan@email.ga	077333010	$2b$10$hash80	Libreville	Batterie IV	Estuaire	CouturiÃ¨re	Atelier Couture	independant	230000.00	36	120000.00	90000.00	5.0	465	moyen	180000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
80	0d95cb46-35cb-4854-a26a-7409c8e15bc2	DEMBA	Julien	j.demba@email.ga	077333011	$2b$10$hash81	Libreville	AkÃ©bÃ©	Estuaire	Apprenti MÃ©canicien	Garage Local	autre	170000.00	8	92000.00	55000.00	4.4	420	eleve	140000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
81	bb786a4e-d216-4797-8f27-94b730ca0523	ESSONE	Paulette	p.essone@email.ga	077333012	$2b$10$hash82	Libreville	Oloumi	Estuaire	Agent Entretien	SociÃ©tÃ© Nettoyage	cdd	260000.00	18	135000.00	105000.00	5.3	485	moyen	210000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
82	0b1588d4-5120-46e5-b431-81cec7ddc905	FOUNDOU	CÃ©sar	c.foundou@email.ga	077333013	$2b$10$hash83	Libreville	Louis	Estuaire	Laveur Voitures	Auto-entrepreneur	independant	185000.00	30	98000.00	68000.00	4.6	438	eleve	150000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
83	f861daed-bae7-4b05-89db-6c5b51115eed	GOMA	Sylvie	s.goma@email.ga	077333014	$2b$10$hash84	Libreville	Sotega	Estuaire	Aide CuisiniÃ¨re	Restaurant	autre	195000.00	12	102000.00	72000.00	4.7	442	eleve	155000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
84	a12dd9fb-69c0-4565-a960-3d4a1e639205	HOUSSOU	Raoul	r.houssou@email.ga	077333015	$2b$10$hash85	Port-Gentil	Basse-Pointe	OgoouÃ©-Maritime	PÃªcheur	Auto-entrepreneur	independant	270000.00	48	140000.00	110000.00	5.4	495	moyen	220000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
85	1d8d2f75-f3d6-4096-9fcc-62fcf9d579dc	IBAKA	Nadine	n.ibaka@email.ga	077333016	$2b$10$hash86	Libreville	Akanda	Estuaire	CaissiÃ¨re Buvette	Petit Commerce	autre	175000.00	18	93000.00	58000.00	4.5	428	eleve	140000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
86	009b9b4e-0ab9-4b3d-ba21-6f6d1a06246e	JOCKTANE	Albert	a.jocktane@email.ga	077333017	$2b$10$hash87	Libreville	PK5	Estuaire	Plongeur Restaurant	Restaurant Local	autre	155000.00	10	88000.00	48000.00	4.2	410	eleve	125000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
87	495d0b46-9f60-4de1-95b0-1513d5840eb5	KOUMBA	Hortense	h.koumba@email.ga	077333018	$2b$10$hash88	Libreville	Nzeng-Ayong	Estuaire	Repasseuse	Pressing Quartier	independant	205000.00	24	108000.00	78000.00	4.8	448	eleve	165000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
88	6050a3b4-0bdc-4c9a-8f83-67149678b0c8	LOUBAKI	Norbert	n.loubaki@email.ga	077333019	$2b$10$hash89	Libreville	Mont-BouÃ«t	Estuaire	Chauffeur Moto-Taxi	Auto-entrepreneur	independant	290000.00	36	150000.00	125000.00	5.5	500	moyen	230000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
89	3595035e-f82a-4642-9302-5bb369dcaa79	MABIKA	Colette	c.mabika@email.ga	077333020	$2b$10$hash90	Libreville	Bellevue	Estuaire	Vendeuse Tissu	MarchÃ©	independant	220000.00	42	115000.00	88000.00	5.1	472	moyen	175000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
90	7f2d2604-4149-426d-a751-c7424dacbdd2	NDOUMBA	Jacques	j.ndoumba@email.ga	077444001	$2b$10$hash91	Libreville	Nzeng-Ayong	Estuaire	Sans Emploi	Aucun	autre	120000.00	0	75000.00	95000.00	3.2	350	tres_eleve	0.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
91	af9d28ce-4959-47b7-9142-370625fd580e	OBAME	Marguerite	m.obame2@email.ga	077444002	$2b$10$hash92	Libreville	AwendjÃ©	Estuaire	Petits Boulots	Occasionnel	autre	95000.00	3	65000.00	110000.00	2.8	320	tres_eleve	0.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
92	0a26149f-8c29-43b3-84df-d9526766e336	PAMBOU	ThÃ©odore	t.pambou@email.ga	077444003	$2b$10$hash93	Libreville	PK8	Estuaire	Aide Familial	Sans Revenu Fixe	autre	80000.00	6	55000.00	75000.00	2.5	305	tres_eleve	0.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
93	25316627-304c-48eb-b55f-903224741d65	QUEMBO	IrÃ¨ne	i.quembo@email.ga	077444004	$2b$10$hash94	Port-Gentil	Quartier	OgoouÃ©-Maritime	Vendeuse Rue	Informel	independant	105000.00	12	70000.00	90000.00	3.0	330	tres_eleve	0.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
94	2035721a-b3bb-4198-8ab0-737087dee45c	RETENO	Bruno	b.reteno@email.ga	077444005	$2b$10$hash95	Libreville	Okala	Estuaire	Apprenti	Sans Contrat	autre	130000.00	4	80000.00	105000.00	3.4	365	tres_eleve	100000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
95	95efd385-5e1c-40dc-a967-dc78de328199	SAMBA	FÃ©licitÃ©	f.samba@email.ga	077444006	$2b$10$hash96	Libreville	Sibang	Estuaire	Aide MÃ©nagÃ¨re	Occasionnel	autre	90000.00	8	62000.00	85000.00	2.7	315	tres_eleve	0.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
96	ef7e57b3-45b0-4a7c-8c0d-fd559f12f56f	TCHIBINTA	Gaston	g.tchibinta@email.ga	077444007	$2b$10$hash97	Libreville	Alibandeng	Estuaire	Gardien Nuit	Sans Contrat	autre	140000.00	10	85000.00	115000.00	3.5	370	tres_eleve	110000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
97	933cbc6a-c91d-4725-87c3-d2e78d62a160	UROBO	Denise	d.urobo@email.ga	077444008	$2b$10$hash98	Libreville	Ancien Chantier	Estuaire	Revendeuse	Informel	independant	110000.00	15	72000.00	95000.00	3.1	340	tres_eleve	90000.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
98	f3c23690-214c-41a4-b05e-f5f0483a415d	VIDJABO	Firmin	f.vidjabo@email.ga	077444009	$2b$10$hash99	Libreville	Charbonnages	Estuaire	ChÃ´meur	Sans Emploi	autre	75000.00	0	50000.00	80000.00	2.3	300	tres_eleve	0.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
99	fab13cf6-dae0-48cb-8ed7-0e09a8764e05	WORA	Lucie	l.wora@email.ga	077444010	$2b$10$hash100	Libreville	Batterie IV	Estuaire	Aide Occasionnelle	Sans Revenu	autre	85000.00	5	58000.00	88000.00	2.6	310	tres_eleve	0.00	actif	2025-10-02 08:01:52.723422	2025-10-02 08:01:52.723422	\N
\.


--
-- Name: credits_enregistres_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.credits_enregistres_id_seq', 150, true);


--
-- Name: demandes_credit_longues_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.demandes_credit_longues_id_seq', 30, true);


--
-- Name: historique_paiements_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.historique_paiements_id_seq', 135, true);


--
-- Name: historique_scores_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.historique_scores_id_seq', 640, true);


--
-- Name: restrictions_credit_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.restrictions_credit_id_seq', 99, true);


--
-- Name: utilisateurs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.utilisateurs_id_seq', 99, true);


--
-- Name: credits_enregistres credits_enregistres_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.credits_enregistres
    ADD CONSTRAINT credits_enregistres_pkey PRIMARY KEY (id);


--
-- Name: demandes_credit_longues demandes_credit_longues_numero_demande_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.demandes_credit_longues
    ADD CONSTRAINT demandes_credit_longues_numero_demande_key UNIQUE (numero_demande);


--
-- Name: demandes_credit_longues demandes_credit_longues_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.demandes_credit_longues
    ADD CONSTRAINT demandes_credit_longues_pkey PRIMARY KEY (id);


--
-- Name: historique_paiements historique_paiements_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.historique_paiements
    ADD CONSTRAINT historique_paiements_pkey PRIMARY KEY (id);


--
-- Name: historique_scores historique_scores_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.historique_scores
    ADD CONSTRAINT historique_scores_pkey PRIMARY KEY (id);


--
-- Name: restrictions_credit restrictions_credit_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.restrictions_credit
    ADD CONSTRAINT restrictions_credit_pkey PRIMARY KEY (id);


--
-- Name: restrictions_credit restrictions_credit_utilisateur_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.restrictions_credit
    ADD CONSTRAINT restrictions_credit_utilisateur_id_key UNIQUE (utilisateur_id);


--
-- Name: utilisateurs utilisateurs_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.utilisateurs
    ADD CONSTRAINT utilisateurs_email_key UNIQUE (email);


--
-- Name: utilisateurs utilisateurs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.utilisateurs
    ADD CONSTRAINT utilisateurs_pkey PRIMARY KEY (id);


--
-- Name: utilisateurs utilisateurs_telephone_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.utilisateurs
    ADD CONSTRAINT utilisateurs_telephone_key UNIQUE (telephone);


--
-- Name: utilisateurs utilisateurs_uuid_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.utilisateurs
    ADD CONSTRAINT utilisateurs_uuid_key UNIQUE (uuid);


--
-- Name: idx_credits_date_echeance; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_credits_date_echeance ON public.credits_enregistres USING btree (date_echeance);


--
-- Name: idx_credits_statut; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_credits_statut ON public.credits_enregistres USING btree (statut);


--
-- Name: idx_credits_utilisateur; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_credits_utilisateur ON public.credits_enregistres USING btree (utilisateur_id);


--
-- Name: idx_demandes_longues_statut; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_demandes_longues_statut ON public.demandes_credit_longues USING btree (statut);


--
-- Name: idx_demandes_longues_utilisateur; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_demandes_longues_utilisateur ON public.demandes_credit_longues USING btree (utilisateur_id);


--
-- Name: idx_paiements_credit; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_paiements_credit ON public.historique_paiements USING btree (credit_id);


--
-- Name: idx_paiements_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_paiements_date ON public.historique_paiements USING btree (date_paiement DESC);


--
-- Name: idx_paiements_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_paiements_type ON public.historique_paiements USING btree (type_paiement);


--
-- Name: idx_paiements_utilisateur; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_paiements_utilisateur ON public.historique_paiements USING btree (utilisateur_id);


--
-- Name: idx_restrictions_peut_emprunter; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_restrictions_peut_emprunter ON public.restrictions_credit USING btree (peut_emprunter);


--
-- Name: idx_restrictions_utilisateur; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_restrictions_utilisateur ON public.restrictions_credit USING btree (utilisateur_id);


--
-- Name: idx_scores_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_scores_date ON public.historique_scores USING btree (date_calcul DESC);


--
-- Name: idx_scores_utilisateur; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_scores_utilisateur ON public.historique_scores USING btree (utilisateur_id);


--
-- Name: idx_utilisateurs_email; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_utilisateurs_email ON public.utilisateurs USING btree (email);


--
-- Name: idx_utilisateurs_score; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_utilisateurs_score ON public.utilisateurs USING btree (score_credit DESC);


--
-- Name: idx_utilisateurs_statut; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_utilisateurs_statut ON public.utilisateurs USING btree (statut);


--
-- Name: idx_utilisateurs_telephone; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_utilisateurs_telephone ON public.utilisateurs USING btree (telephone);


--
-- Name: v_dashboard_utilisateurs _RETURN; Type: RULE; Schema: public; Owner: postgres
--

CREATE OR REPLACE VIEW public.v_dashboard_utilisateurs AS
 SELECT u.id,
    u.nom,
    u.prenom,
    u.email,
    u.telephone,
    u.ville,
    u.profession,
    u.statut_emploi,
    u.revenu_mensuel,
    u.score_credit,
    u.niveau_risque,
    u.montant_eligible,
    r.peut_emprunter,
    r.credits_actifs_count,
    r.dette_totale_active,
    r.ratio_endettement,
    r.raison_blocage,
    count(DISTINCT c.id) FILTER (WHERE (c.statut = 'actif'::public.statut_credit)) AS credits_actifs,
    count(DISTINCT c.id) FILTER (WHERE (c.statut = 'solde'::public.statut_credit)) AS credits_soldes,
    count(DISTINCT c.id) FILTER (WHERE (c.statut = 'en_retard'::public.statut_credit)) AS credits_en_retard,
    COALESCE(sum(c.montant_restant) FILTER (WHERE (c.statut = 'actif'::public.statut_credit)), (0)::numeric) AS total_dette_active
   FROM ((public.utilisateurs u
     LEFT JOIN public.restrictions_credit r ON ((u.id = r.utilisateur_id)))
     LEFT JOIN public.credits_enregistres c ON ((u.id = c.utilisateur_id)))
  GROUP BY u.id, r.peut_emprunter, r.credits_actifs_count, r.dette_totale_active, r.ratio_endettement, r.raison_blocage;


--
-- Name: credits_enregistres trigger_maj_credits; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_maj_credits BEFORE UPDATE ON public.credits_enregistres FOR EACH ROW EXECUTE FUNCTION public.maj_date_modification();


--
-- Name: restrictions_credit trigger_maj_restrictions; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_maj_restrictions BEFORE UPDATE ON public.restrictions_credit FOR EACH ROW EXECUTE FUNCTION public.maj_date_modification();


--
-- Name: utilisateurs trigger_maj_utilisateurs; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_maj_utilisateurs BEFORE UPDATE ON public.utilisateurs FOR EACH ROW EXECUTE FUNCTION public.maj_date_modification();


--
-- Name: credits_enregistres credits_enregistres_utilisateur_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.credits_enregistres
    ADD CONSTRAINT credits_enregistres_utilisateur_id_fkey FOREIGN KEY (utilisateur_id) REFERENCES public.utilisateurs(id) ON DELETE CASCADE;


--
-- Name: demandes_credit_longues demandes_credit_longues_decideur_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.demandes_credit_longues
    ADD CONSTRAINT demandes_credit_longues_decideur_id_fkey FOREIGN KEY (decideur_id) REFERENCES public.utilisateurs(id);


--
-- Name: demandes_credit_longues demandes_credit_longues_utilisateur_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.demandes_credit_longues
    ADD CONSTRAINT demandes_credit_longues_utilisateur_id_fkey FOREIGN KEY (utilisateur_id) REFERENCES public.utilisateurs(id) ON DELETE CASCADE;


--
-- Name: historique_paiements historique_paiements_credit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.historique_paiements
    ADD CONSTRAINT historique_paiements_credit_id_fkey FOREIGN KEY (credit_id) REFERENCES public.credits_enregistres(id) ON DELETE CASCADE;


--
-- Name: historique_paiements historique_paiements_utilisateur_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.historique_paiements
    ADD CONSTRAINT historique_paiements_utilisateur_id_fkey FOREIGN KEY (utilisateur_id) REFERENCES public.utilisateurs(id) ON DELETE CASCADE;


--
-- Name: historique_scores historique_scores_utilisateur_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.historique_scores
    ADD CONSTRAINT historique_scores_utilisateur_id_fkey FOREIGN KEY (utilisateur_id) REFERENCES public.utilisateurs(id) ON DELETE CASCADE;


--
-- Name: restrictions_credit restrictions_credit_utilisateur_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.restrictions_credit
    ADD CONSTRAINT restrictions_credit_utilisateur_id_fkey FOREIGN KEY (utilisateur_id) REFERENCES public.utilisateurs(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

