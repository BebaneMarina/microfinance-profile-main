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

--
-- Name: update_demande_longue_modification(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_demande_longue_modification() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.date_modification = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_demande_longue_modification() OWNER TO postgres;

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
    date_modification timestamp without time zone DEFAULT now(),
    username character varying(255),
    decision character varying(255),
    personal_info jsonb,
    credit_details jsonb,
    financial_details jsonb,
    documents jsonb,
    simulation_results jsonb,
    special_conditions text,
    assigned_to integer,
    review_started_date timestamp without time zone,
    created_by integer
);


ALTER TABLE public.demandes_credit_longues OWNER TO postgres;

--
-- Name: TABLE demandes_credit_longues; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.demandes_credit_longues IS 'Demandes de crÃ©dit complexes avec workflow back-office';


--
-- Name: demandes_credit_longues_comments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.demandes_credit_longues_comments (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    long_credit_request_id integer NOT NULL,
    author_name character varying(255) NOT NULL,
    author_id integer,
    comment_type character varying(50) DEFAULT 'general'::character varying,
    content text NOT NULL,
    is_private boolean DEFAULT false,
    created_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.demandes_credit_longues_comments OWNER TO postgres;

--
-- Name: demandes_credit_longues_documents; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.demandes_credit_longues_documents (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    long_credit_request_id integer NOT NULL,
    document_type character varying(100) NOT NULL,
    document_name character varying(255) NOT NULL,
    original_filename character varying(255) NOT NULL,
    file_path character varying(500) NOT NULL,
    file_size bigint NOT NULL,
    mime_type character varying(100) NOT NULL,
    is_required boolean DEFAULT false,
    uploaded_by integer,
    checksum character varying(255),
    uploaded_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.demandes_credit_longues_documents OWNER TO postgres;

--
-- Name: demandes_credit_longues_history; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.demandes_credit_longues_history (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    long_credit_request_id integer NOT NULL,
    action character varying(255) NOT NULL,
    previous_status character varying(50),
    new_status character varying(50),
    agent_name character varying(255) NOT NULL,
    agent_id integer,
    comment text,
    action_date timestamp without time zone DEFAULT now()
);


ALTER TABLE public.demandes_credit_longues_history OWNER TO postgres;

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
151	1	consommation_generale	666600.00	676599.00	676599.00	0.02	1	actif	2025-10-06 17:32:20.07	2025-11-20 17:32:20.07	2025-11-20 17:32:20.07	676599.00	2025-10-06 17:32:20.115435	2025-10-06 17:32:20.115435
453	1	consommation_generale	416625.00	422874.37	422874.37	0.02	1	actif	2025-10-08 13:15:47.673	2025-11-22 13:15:47.673	2025-11-22 13:15:47.673	422874.37	2025-10-08 13:15:47.723559	2025-10-08 13:15:47.723559
455	1	consommation_generale	1250000.00	1268750.00	1268750.00	0.02	1	actif	2025-10-09 16:52:11.425	2025-11-23 16:52:11.425	2025-11-23 16:52:11.425	1268750.00	2025-10-09 16:52:11.498286	2025-10-09 16:52:11.498286
152	1	consommation_generale	666600.00	676599.00	676599.00	0.02	1	actif	2025-10-06 17:45:14.462	2025-11-20 17:45:14.462	2025-11-20 17:45:14.462	676599.00	2025-10-06 17:45:14.525136	2025-10-06 17:45:14.525136
454	1	consommation_generale	416625.00	422874.37	422874.37	0.02	1	actif	2025-10-08 13:26:48.842	2025-11-22 13:26:48.842	2025-11-22 13:26:48.842	422874.37	2025-10-08 13:26:48.887925	2025-10-08 13:26:48.887925
189	7	depannage	885361.00	920775.44	509975.29	0.04	1	actif	2025-09-27 16:29:08.571711	2025-10-30 06:07:54.208522	2025-10-08 08:56:57.123447	356424.39	2025-10-08 00:28:38.149437	2025-10-08 00:28:38.164168
190	8	depannage	738123.00	767647.92	178538.05	0.04	1	actif	2025-08-27 14:53:52.795161	2025-10-11 14:28:51.572351	2025-10-17 02:33:23.090974	299741.84	2025-10-08 00:28:38.149437	2025-10-08 00:28:38.164168
191	9	depannage	973590.00	1012533.60	35066.01	0.04	1	actif	2025-07-25 12:18:02.999622	2025-11-12 01:20:04.917356	2025-10-10 21:54:56.199145	437326.75	2025-10-08 00:28:38.149437	2025-10-08 00:28:38.164168
192	10	depannage	884771.00	920161.84	200131.78	0.04	1	actif	2025-07-29 09:47:04.449224	2025-12-03 02:29:34.658134	2025-10-12 07:18:42.722241	320316.27	2025-10-08 00:28:38.149437	2025-10-08 00:28:38.164168
193	11	depannage	452057.00	470139.28	163136.72	0.04	1	actif	2025-08-31 11:18:53.474125	2025-10-28 11:40:53.743899	2025-10-15 03:48:52.124381	192290.28	2025-10-08 00:28:38.149437	2025-10-08 00:28:38.164168
194	12	depannage	859003.00	893363.12	603572.45	0.04	1	actif	2025-09-03 17:54:54.528185	2025-11-25 22:45:57.610488	2025-10-12 11:48:28.810268	282119.90	2025-10-08 00:28:38.149437	2025-10-08 00:28:38.164168
195	13	depannage	722590.00	751493.60	180719.45	0.04	1	actif	2025-07-16 07:20:40.811509	2025-11-24 02:11:30.712239	2025-10-21 03:16:52.469686	319499.81	2025-10-08 00:28:38.149437	2025-10-08 00:28:38.164168
196	14	depannage	541568.00	563230.72	310404.27	0.04	1	actif	2025-09-30 02:12:44.910959	2025-10-18 20:19:24.514923	2025-10-14 13:24:36.345275	242832.38	2025-10-08 00:28:38.149437	2025-10-08 00:28:38.164168
197	15	depannage	667676.00	694383.04	410725.34	0.04	1	actif	2025-09-27 21:23:29.248327	2025-10-13 06:52:26.305921	2025-10-16 14:59:44.302481	279479.47	2025-10-08 00:28:38.149437	2025-10-08 00:28:38.164168
198	31	avance_salaire	279434.00	287817.02	0.00	0.03	1	solde	2025-02-10 20:06:02.921049	2025-11-21 03:20:13.717114	2025-10-27 13:48:45.842993	\N	2025-10-08 00:28:38.15148	2025-10-08 00:28:38.164168
199	32	consommation_generale	377406.00	388728.18	199929.91	0.03	1	en_retard	2025-08-31 22:07:07.742804	2026-01-28 03:30:22.448093	2025-10-10 20:12:51.396506	153833.71	2025-10-08 00:28:38.15148	2025-10-08 00:28:38.164168
200	33	consommation_generale	568350.00	602451.00	0.00	0.03	2	solde	2025-06-07 08:55:46.807153	2025-11-11 08:16:21.091996	2025-10-22 16:42:20.829061	\N	2025-10-08 00:28:38.15148	2025-10-08 00:28:38.164168
201	34	avance_salaire	663758.00	683670.74	0.00	0.03	1	solde	2025-05-17 03:56:44.848258	2026-01-07 05:07:40.901353	2025-10-23 03:44:35.569528	\N	2025-10-08 00:28:38.15148	2025-10-08 00:28:38.164168
202	35	consommation_generale	761182.00	791629.28	0.00	0.04	1	solde	2025-07-21 03:54:18.545097	2025-12-17 16:53:59.889832	2025-10-17 14:35:39.886699	\N	2025-10-08 00:28:38.15148	2025-10-08 00:28:38.164168
203	36	consommation_generale	729718.00	773501.08	0.00	0.03	2	solde	2025-02-08 17:42:56.309995	2025-12-27 13:01:59.113288	2025-10-27 18:48:07.818526	\N	2025-10-08 00:28:38.15148	2025-10-08 00:28:38.164168
204	37	consommation_generale	405693.00	417863.79	171283.76	0.03	1	actif	2025-06-22 14:20:04.055082	2025-10-18 21:23:32.481507	2025-10-29 17:43:37.266418	125014.73	2025-10-08 00:28:38.15148	2025-10-08 00:28:38.164168
205	38	consommation_generale	245246.00	257508.30	0.00	0.05	1	solde	2025-10-01 19:01:52.706657	2026-01-12 22:27:18.53318	2025-10-12 17:26:37.776304	\N	2025-10-08 00:28:38.15148	2025-10-08 00:28:38.164168
206	39	avance_salaire	266501.00	274496.03	0.00	0.03	1	solde	2025-05-12 22:07:54.217049	2026-01-24 09:29:38.458039	2025-10-15 05:50:48.078764	\N	2025-10-08 00:28:38.15148	2025-10-08 00:28:38.164168
207	40	consommation_generale	279635.00	307598.50	0.00	0.05	2	solde	2025-02-26 23:26:38.623615	2026-01-13 01:19:09.694587	2025-10-23 19:36:28.92215	\N	2025-10-08 00:28:38.15148	2025-10-08 00:28:38.164168
208	41	avance_salaire	705198.00	775717.80	0.00	0.05	2	solde	2025-08-22 12:47:59.478487	2026-02-04 21:50:59.998313	2025-10-12 05:42:26.919607	\N	2025-10-08 00:28:38.15148	2025-10-08 00:28:38.164168
209	42	depannage	522609.00	538287.27	0.00	0.03	1	solde	2025-03-23 06:06:55.908109	2026-01-13 19:01:37.760253	2025-10-29 15:37:16.761048	\N	2025-10-08 00:28:38.15148	2025-10-08 00:28:38.164168
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
210	43	avance_salaire	423219.00	444379.95	0.00	0.05	1	solde	2025-02-25 06:00:13.149166	2026-01-21 21:51:25.148542	2025-10-08 03:57:15.474468	\N	2025-10-08 00:28:38.15148	2025-10-08 00:28:38.164168
211	44	avance_salaire	299468.00	314441.40	188584.58	0.05	1	actif	2025-01-11 02:45:44.168795	2025-10-16 15:54:58.391428	2025-10-25 07:29:09.523807	96265.27	2025-10-08 00:28:38.15148	2025-10-08 00:28:38.164168
212	45	depannage	779895.00	818889.75	247431.14	0.05	1	actif	2025-05-17 10:07:32.791462	2025-11-09 16:29:46.550402	2025-10-23 00:16:36.532224	285911.68	2025-10-08 00:28:38.15148	2025-10-08 00:28:38.164168
213	46	consommation_generale	275230.00	291743.80	0.00	0.03	2	solde	2025-08-14 21:04:59.506656	2026-01-15 11:46:13.121749	2025-10-26 04:53:36.200082	\N	2025-10-08 00:28:38.15148	2025-10-08 00:28:38.164168
214	47	depannage	635522.00	667298.10	0.00	0.05	1	solde	2025-02-25 03:57:06.601345	2025-10-15 00:15:27.856001	2025-10-17 20:57:41.748067	\N	2025-10-08 00:28:38.15148	2025-10-08 00:28:38.164168
215	48	depannage	268049.00	284131.94	0.00	0.03	2	solde	2025-06-10 16:17:37.498812	2025-11-06 08:18:24.683104	2025-10-15 01:00:45.686921	\N	2025-10-08 00:28:38.15148	2025-10-08 00:28:38.164168
216	49	avance_salaire	479425.00	527367.50	0.00	0.05	2	solde	2025-09-28 19:06:04.133723	2025-12-07 05:33:29.060857	2025-10-28 23:07:07.231575	\N	2025-10-08 00:28:38.15148	2025-10-08 00:28:38.164168
217	50	avance_salaire	257596.00	283355.60	166764.79	0.05	2	actif	2025-05-04 14:31:22.087513	2026-01-26 19:15:24.622436	2025-10-12 16:12:17.361062	105853.93	2025-10-08 00:28:38.15148	2025-10-08 00:28:38.164168
218	51	depannage	529314.00	582245.40	489329.21	0.05	2	en_retard	2025-03-24 14:00:45.322934	2026-01-17 13:03:50.385153	2025-10-13 02:16:27.113994	160247.89	2025-10-08 00:28:38.15148	2025-10-08 00:28:38.164168
219	52	avance_salaire	520167.00	561780.36	0.00	0.04	2	solde	2025-05-28 06:00:31.050725	2026-01-09 19:47:20.948102	2025-10-31 02:21:04.875726	\N	2025-10-08 00:28:38.15148	2025-10-08 00:28:38.164168
220	53	avance_salaire	797199.00	845030.94	516311.73	0.03	2	actif	2025-04-09 13:38:25.840898	2025-12-20 01:35:27.743291	2025-10-10 05:41:30.444302	310256.11	2025-10-08 00:28:38.15148	2025-10-08 00:28:38.164168
221	54	depannage	308921.00	318188.63	0.00	0.03	1	solde	2025-08-21 23:06:59.633516	2025-10-24 20:42:57.071044	2025-10-26 00:14:32.870384	\N	2025-10-08 00:28:38.15148	2025-10-08 00:28:38.164168
222	55	consommation_generale	778744.00	802106.32	0.00	0.03	1	solde	2025-05-26 15:23:50.705404	2025-10-24 08:43:44.54014	2025-10-20 07:16:28.77445	\N	2025-10-08 00:28:38.15148	2025-10-08 00:28:38.164168
223	56	avance_salaire	442287.00	486515.70	0.00	0.05	2	solde	2025-04-30 03:12:12.818223	2025-12-10 06:03:55.05174	2025-10-13 19:13:26.034353	\N	2025-10-08 00:28:38.15148	2025-10-08 00:28:38.164168
224	57	avance_salaire	391457.00	414944.42	0.00	0.03	2	solde	2025-01-24 04:42:56.962178	2025-12-14 23:27:02.714652	2025-10-24 04:19:12.267461	\N	2025-10-08 00:28:38.15148	2025-10-08 00:28:38.164168
225	58	consommation_generale	532731.00	548712.93	185979.75	0.03	1	actif	2025-05-19 22:20:37.542491	2026-01-14 17:36:02.117454	2025-10-18 21:33:31.802792	169436.18	2025-10-08 00:28:38.15148	2025-10-08 00:28:38.164168
226	59	avance_salaire	255017.00	270318.02	164846.08	0.03	2	actif	2025-08-15 14:01:01.777026	2025-12-18 10:49:59.261001	2025-10-25 14:47:29.925565	103797.49	2025-10-08 00:28:38.15148	2025-10-08 00:28:38.164168
227	60	avance_salaire	239097.00	253442.82	160865.24	0.03	2	actif	2025-02-18 10:58:49.959473	2026-01-27 03:19:43.351879	2025-10-28 03:04:44.772804	94309.38	2025-10-08 00:28:38.15148	2025-10-08 00:28:38.164168
228	61	depannage	623904.00	661338.24	0.00	0.03	2	solde	2025-02-18 08:01:56.630862	2026-01-10 07:04:52.52614	2025-10-14 10:44:40.623832	\N	2025-10-08 00:28:38.15148	2025-10-08 00:28:38.164168
229	62	avance_salaire	771496.00	794640.88	0.00	0.03	1	solde	2025-04-07 05:47:41.025357	2025-12-04 04:57:31.56903	2025-10-30 09:05:58.963907	\N	2025-10-08 00:28:38.15148	2025-10-08 00:28:38.164168
230	63	avance_salaire	569227.00	586303.81	0.00	0.03	1	solde	2025-05-26 01:41:53.314779	2026-01-19 07:05:22.666495	2025-10-21 15:32:03.217807	\N	2025-10-08 00:28:38.15148	2025-10-08 00:28:38.164168
231	64	avance_salaire	746765.00	821441.50	0.00	0.05	2	solde	2025-02-13 03:43:51.009966	2025-12-09 10:49:10.88838	2025-10-31 17:11:13.212404	\N	2025-10-08 00:28:38.15148	2025-10-08 00:28:38.164168
232	65	avance_salaire	572814.00	601454.70	306448.70	0.05	1	en_retard	2025-09-13 23:22:39.923291	2025-10-08 12:11:42.541237	2025-10-31 23:22:28.410369	198231.93	2025-10-08 00:28:38.15148	2025-10-08 00:28:38.164168
233	66	depannage	651760.00	677830.40	0.00	0.04	1	solde	2025-10-04 20:25:40.941004	2025-12-31 09:10:50.119646	2025-10-26 14:50:44.660519	\N	2025-10-08 00:28:38.15148	2025-10-08 00:28:38.164168
234	67	avance_salaire	568436.00	602542.16	0.00	0.03	2	solde	2025-07-16 19:17:30.471015	2025-11-19 06:04:30.589276	2025-10-26 07:34:09.192005	\N	2025-10-08 00:28:38.15148	2025-10-08 00:28:38.164168
235	68	depannage	748967.00	823863.70	351811.33	0.05	2	actif	2025-07-24 17:00:54.251441	2026-01-09 11:15:16.842747	2025-10-11 10:59:10.088946	269791.50	2025-10-08 00:28:38.15148	2025-10-08 00:28:38.164168
236	69	depannage	642953.00	675100.65	48769.76	0.05	1	actif	2025-09-13 04:15:40.152997	2025-11-25 13:03:24.87372	2025-10-15 03:54:30.675739	275261.35	2025-10-08 00:28:38.15148	2025-10-08 00:28:38.164168
237	70	consommation_generale	262766.00	289042.60	68379.24	0.05	2	actif	2025-07-01 06:46:43.598782	2025-12-25 12:16:48.909889	2025-10-22 21:39:30.411158	90186.10	2025-10-08 00:28:38.15148	2025-10-08 00:28:38.164168
238	31	depannage	531721.00	552989.84	35664.71	0.04	1	actif	2025-08-02 21:53:32.529534	2025-11-12 02:09:47.890838	2025-10-20 11:43:11.866399	238975.27	2025-10-08 00:28:38.154535	2025-10-08 00:28:38.164168
239	32	depannage	540491.00	562110.64	503299.03	0.04	1	en_retard	2025-07-09 22:41:17.909469	2025-11-11 02:57:02.386758	2025-10-20 02:55:25.714449	204867.33	2025-10-08 00:28:38.154535	2025-10-08 00:28:38.164168
240	33	depannage	477372.00	496466.88	310605.06	0.04	1	en_retard	2025-08-02 18:01:24.529812	2025-11-02 21:06:33.232201	2025-10-20 20:47:55.746112	144942.23	2025-10-08 00:28:38.154535	2025-10-08 00:28:38.164168
241	34	depannage	321678.00	334545.12	184785.23	0.04	1	actif	2025-09-28 05:04:05.227691	2025-10-15 10:37:36.702023	2025-10-08 13:22:14.143372	99484.33	2025-10-08 00:28:38.154535	2025-10-08 00:28:38.164168
242	35	depannage	348252.00	362182.08	310122.02	0.04	1	en_retard	2025-07-09 21:03:43.525959	2025-10-31 17:05:47.617098	2025-10-12 23:57:38.445789	118677.54	2025-10-08 00:28:38.154535	2025-10-08 00:28:38.164168
243	36	depannage	237503.00	247003.12	129862.85	0.04	1	actif	2025-09-25 07:10:46.813688	2025-11-13 00:52:22.038057	2025-10-10 08:14:13.806524	78891.49	2025-10-08 00:28:38.154535	2025-10-08 00:28:38.164168
244	37	depannage	164656.00	171242.24	104021.48	0.04	1	en_retard	2025-07-15 11:53:18.465457	2025-10-22 09:11:07.864145	2025-10-14 13:00:56.086983	51983.32	2025-10-08 00:28:38.154535	2025-10-08 00:28:38.164168
245	38	depannage	520180.00	540987.20	97600.50	0.04	1	actif	2025-06-20 02:15:59.844803	2025-11-16 05:24:50.064826	2025-10-13 11:08:02.156442	227481.83	2025-10-08 00:28:38.154535	2025-10-08 00:28:38.164168
246	39	depannage	288502.00	300042.08	207899.24	0.04	1	en_retard	2025-08-16 13:41:28.304938	2025-10-14 18:48:24.271185	2025-10-22 16:36:31.989093	116016.42	2025-10-08 00:28:38.154535	2025-10-08 00:28:38.164168
247	40	depannage	446061.00	463903.44	412501.67	0.04	1	en_retard	2025-08-07 01:16:56.541849	2025-10-29 11:02:10.767908	2025-10-23 22:48:20.647541	191926.78	2025-10-08 00:28:38.154535	2025-10-08 00:28:38.164168
248	41	depannage	219855.00	228649.20	155508.28	0.04	1	actif	2025-08-02 19:31:13.611713	2025-10-11 21:03:56.075081	2025-10-14 01:54:47.041855	71484.38	2025-10-08 00:28:38.154535	2025-10-08 00:28:38.164168
249	42	depannage	465157.00	483763.28	68007.42	0.04	1	actif	2025-06-23 07:46:27.064898	2025-11-15 10:39:07.094621	2025-10-10 12:41:19.988617	150972.97	2025-10-08 00:28:38.154535	2025-10-08 00:28:38.164168
250	43	depannage	407717.00	424025.68	200216.63	0.04	1	actif	2025-08-16 18:11:02.646528	2025-10-16 06:46:30.305268	2025-10-25 05:47:38.474945	172003.93	2025-10-08 00:28:38.154535	2025-10-08 00:28:38.164168
251	44	depannage	249501.00	259481.04	113624.34	0.04	1	actif	2025-08-01 02:37:54.457031	2025-10-19 15:33:59.122526	2025-10-12 10:12:23.01566	82466.85	2025-10-08 00:28:38.154535	2025-10-08 00:28:38.164168
252	45	depannage	299428.00	311405.12	37368.75	0.04	1	actif	2025-09-29 21:11:43.663304	2025-11-06 07:23:56.662226	2025-10-10 10:47:21.972348	109387.37	2025-10-08 00:28:38.154535	2025-10-08 00:28:38.164168
253	46	depannage	178721.00	185869.84	89412.02	0.04	1	actif	2025-07-05 20:18:54.403257	2025-10-24 06:49:52.174152	2025-10-13 13:10:00.393345	71376.28	2025-10-08 00:28:38.154535	2025-10-08 00:28:38.164168
254	47	depannage	389171.00	404737.84	280848.73	0.04	1	en_retard	2025-07-27 06:24:46.987808	2025-10-23 16:51:59.406221	2025-10-13 19:41:51.893246	173499.01	2025-10-08 00:28:38.154535	2025-10-08 00:28:38.164168
255	48	depannage	405934.00	422171.36	48592.28	0.04	1	actif	2025-09-29 07:26:51.823934	2025-11-09 17:56:38.410599	2025-10-12 10:00:30.109255	172963.35	2025-10-08 00:28:38.154535	2025-10-08 00:28:38.164168
256	49	depannage	440367.00	457981.68	280822.33	0.04	1	en_retard	2025-07-14 01:33:30.67993	2025-10-23 22:16:11.925387	2025-10-17 08:37:31.130224	170959.21	2025-10-08 00:28:38.154535	2025-10-08 00:28:38.164168
257	50	depannage	215840.00	224473.60	30162.51	0.04	1	actif	2025-06-23 05:39:12.09693	2025-11-09 01:49:27.738777	2025-10-16 21:22:43.746926	65578.26	2025-10-08 00:28:38.154535	2025-10-08 00:28:38.164168
258	71	depannage	247223.00	259584.15	98760.24	0.05	1	actif	2025-10-05 06:07:42.80047	2025-12-26 22:44:31.933264	2025-10-23 01:16:01.476174	87942.01	2025-10-08 00:28:38.156653	2025-10-08 00:28:38.164168
259	72	consommation_generale	401876.00	413932.28	321198.86	0.03	1	en_retard	2025-05-31 10:52:36.483881	2025-11-06 17:01:01.620699	2025-11-05 16:59:24.206049	127762.28	2025-10-08 00:28:38.156653	2025-10-08 00:28:38.164168
260	73	avance_salaire	101764.00	104816.92	79242.85	0.03	1	en_retard	2025-08-28 18:01:10.322424	2025-10-25 07:27:42.555388	2025-10-16 16:04:29.219473	40327.74	2025-10-08 00:28:38.156653	2025-10-08 00:28:38.164168
261	74	consommation_generale	397385.00	417254.25	0.00	0.05	1	solde	2025-08-03 18:07:45.835537	2025-11-28 03:19:56.778594	2025-10-22 11:34:22.889751	\N	2025-10-08 00:28:38.156653	2025-10-08 00:28:38.164168
262	75	avance_salaire	217155.00	223669.65	35182.99	0.03	1	actif	2025-03-25 02:16:38.446453	2025-11-29 09:19:29.89176	2025-11-05 07:02:09.549636	96344.07	2025-10-08 00:28:38.156653	2025-10-08 00:28:38.164168
263	76	avance_salaire	318102.00	327645.06	0.00	0.03	1	solde	2025-04-29 07:35:35.753571	2025-10-14 09:29:44.163946	2025-10-11 02:30:34.625532	\N	2025-10-08 00:28:38.156653	2025-10-08 00:28:38.164168
264	77	avance_salaire	336413.00	353233.65	0.00	0.05	1	solde	2025-10-06 09:34:47.497436	2025-10-27 21:49:15.542272	2025-10-20 01:51:35.041501	\N	2025-10-08 00:28:38.156653	2025-10-08 00:28:38.164168
265	78	consommation_generale	417690.00	438574.50	38213.03	0.05	1	actif	2025-05-22 01:57:50.833413	2025-12-31 23:19:03.067739	2025-10-28 20:01:29.50761	176567.17	2025-10-08 00:28:38.156653	2025-10-08 00:28:38.164168
266	79	depannage	282203.00	290669.09	195281.56	0.03	1	en_retard	2025-03-26 10:33:40.604655	2025-10-28 16:03:58.507092	2025-10-14 04:27:57.459598	88775.64	2025-10-08 00:28:38.156653	2025-10-08 00:28:38.164168
267	80	consommation_generale	322715.00	332396.45	0.00	0.03	1	solde	2025-04-03 21:32:21.659364	2025-12-02 10:58:19.011583	2025-10-28 15:24:14.254106	\N	2025-10-08 00:28:38.156653	2025-10-08 00:28:38.164168
268	81	consommation_generale	200419.00	208435.76	0.00	0.04	1	solde	2025-05-23 02:17:07.092883	2025-12-29 17:26:02.171171	2025-10-17 12:36:24.465209	\N	2025-10-08 00:28:38.156653	2025-10-08 00:28:38.164168
269	82	depannage	203975.00	210094.25	23839.45	0.03	1	actif	2025-06-15 21:40:03.995671	2025-12-23 16:29:02.981927	2025-10-30 04:22:41.517773	88370.82	2025-10-08 00:28:38.156653	2025-10-08 00:28:38.164168
270	83	depannage	313646.00	329328.30	237502.56	0.05	1	en_retard	2025-04-20 08:43:51.322165	2026-01-04 11:27:37.793678	2025-10-19 07:13:13.756944	115116.40	2025-10-08 00:28:38.156653	2025-10-08 00:28:38.164168
271	84	avance_salaire	112787.00	116170.61	65731.65	0.03	1	en_retard	2025-03-27 12:45:57.45702	2025-12-06 20:03:07.910413	2025-10-17 12:49:17.669814	49975.88	2025-10-08 00:28:38.156653	2025-10-08 00:28:38.164168
272	85	avance_salaire	301755.00	313825.20	159203.72	0.04	1	actif	2025-04-22 19:23:48.102804	2025-12-25 04:17:20.474286	2025-10-21 20:17:44.272756	105445.21	2025-10-08 00:28:38.156653	2025-10-08 00:28:38.164168
273	86	avance_salaire	145155.00	149509.65	0.00	0.03	1	solde	2025-06-23 00:17:14.201406	2025-11-13 22:49:57.852078	2025-10-16 07:30:36.76058	\N	2025-10-08 00:28:38.156653	2025-10-08 00:28:38.164168
274	87	consommation_generale	137180.00	141295.40	0.00	0.03	1	solde	2025-06-22 07:17:46.287444	2025-10-10 13:27:04.109049	2025-10-19 09:59:01.811313	\N	2025-10-08 00:28:38.156653	2025-10-08 00:28:38.164168
275	88	avance_salaire	176086.00	184890.30	65648.69	0.05	1	actif	2025-06-17 06:02:51.38612	2025-11-24 03:25:50.888016	2025-10-21 00:53:14.358067	55402.05	2025-10-08 00:28:38.156653	2025-10-08 00:28:38.164168
276	89	avance_salaire	363743.00	378292.72	262676.28	0.04	1	actif	2025-08-18 01:37:48.781685	2025-10-24 12:33:55.284142	2025-10-22 13:34:59.78189	158920.51	2025-10-08 00:28:38.156653	2025-10-08 00:28:38.164168
277	90	avance_salaire	253048.00	260639.44	0.00	0.03	1	solde	2025-09-14 07:34:27.490849	2025-11-22 12:55:39.33583	2025-10-23 16:03:36.401349	\N	2025-10-08 00:28:38.156653	2025-10-08 00:28:38.164168
278	75	depannage	293552.00	305294.08	173824.77	0.04	1	en_retard	2025-09-10 07:18:39.329185	2025-09-28 08:44:49.366951	2025-10-02 21:48:01.709481	91504.59	2025-10-08 00:28:38.158846	2025-10-08 00:28:38.164168
279	76	depannage	114457.00	119035.28	78368.40	0.04	1	en_retard	2025-09-03 17:04:19.304655	2025-09-23 20:37:13.510663	2025-10-02 19:22:18.163249	40448.50	2025-10-08 00:28:38.158846	2025-10-08 00:28:38.164168
280	77	depannage	179577.00	186760.08	119084.89	0.04	1	en_retard	2025-10-05 09:24:53.236521	2025-10-03 23:17:31.742491	2025-09-30 08:30:17.76705	63324.86	2025-10-08 00:28:38.158846	2025-10-08 00:28:38.164168
281	78	depannage	275525.00	286546.00	232595.36	0.04	1	en_retard	2025-09-30 14:56:14.57365	2025-10-05 07:05:39.159643	2025-09-29 18:06:32.7184	112977.95	2025-10-08 00:28:38.158846	2025-10-08 00:28:38.164168
282	79	depannage	122294.00	127185.76	70722.13	0.04	1	en_retard	2025-09-13 09:35:35.929705	2025-10-02 19:34:21.038026	2025-09-29 08:08:57.073413	47923.98	2025-10-08 00:28:38.158846	2025-10-08 00:28:38.164168
283	80	depannage	309793.00	322184.72	260642.83	0.04	1	en_retard	2025-09-15 23:59:34.752839	2025-10-03 05:00:14.045824	2025-10-05 00:17:28.817411	136831.27	2025-10-08 00:28:38.158846	2025-10-08 00:28:38.164168
284	81	depannage	114166.00	118732.64	61825.43	0.04	1	en_retard	2025-08-22 03:39:52.461098	2025-09-25 01:34:18.484311	2025-10-02 18:20:04.750956	47039.54	2025-10-08 00:28:38.158846	2025-10-08 00:28:38.164168
285	82	depannage	202240.00	210329.60	129748.85	0.04	1	en_retard	2025-10-02 22:56:19.179959	2025-10-04 01:17:44.579543	2025-10-05 11:46:33.315122	89855.31	2025-10-08 00:28:38.158846	2025-10-08 00:28:38.164168
286	83	depannage	263839.00	274392.56	205642.03	0.04	1	en_retard	2025-09-10 06:16:04.263588	2025-10-01 09:21:17.860776	2025-10-02 20:12:27.806975	105509.68	2025-10-08 00:28:38.158846	2025-10-08 00:28:38.164168
287	84	depannage	303291.00	315422.64	194669.82	0.04	1	en_retard	2025-09-29 04:09:12.163099	2025-09-28 21:19:28.233337	2025-10-05 09:18:52.69324	129125.16	2025-10-08 00:28:38.158846	2025-10-08 00:28:38.164168
288	85	depannage	145671.00	151497.84	117032.52	0.04	1	en_retard	2025-08-17 16:14:13.231367	2025-10-03 01:22:55.161751	2025-10-03 09:47:20.942603	54556.74	2025-10-08 00:28:38.158846	2025-10-08 00:28:38.164168
289	91	avance_salaire	149424.00	153906.72	153906.72	0.03	1	defaut	2025-09-14 20:46:56.749633	2025-10-06 00:15:47.675255	2025-09-20 20:04:59.738129	\N	2025-10-08 00:28:38.160858	2025-10-08 00:28:38.164168
290	92	depannage	119455.00	123038.65	80938.70	0.03	1	en_retard	2025-04-20 22:14:04.079489	2025-09-12 21:03:38.675868	2025-09-28 05:41:24.694588	47797.86	2025-10-08 00:28:38.160858	2025-10-08 00:28:38.164168
291	93	depannage	151982.00	156541.46	111353.17	0.03	1	en_retard	2025-06-23 19:13:33.218707	2025-09-18 08:38:44.902201	2025-09-25 05:11:08.417012	46848.44	2025-10-08 00:28:38.160858	2025-10-08 00:28:38.164168
292	94	depannage	110219.00	114627.76	114627.76	0.04	1	defaut	2025-05-26 17:04:15.487802	2025-10-02 09:54:27.266014	2025-09-13 19:19:41.792587	\N	2025-10-08 00:28:38.160858	2025-10-08 00:28:38.164168
293	95	avance_salaire	133430.00	138767.20	101756.70	0.04	1	en_retard	2025-05-08 09:05:12.045669	2025-08-27 09:44:52.192651	2025-09-26 10:17:31.147963	51785.60	2025-10-08 00:28:38.160858	2025-10-08 00:28:38.164168
294	96	depannage	230520.00	239740.80	239740.80	0.04	1	defaut	2025-05-11 11:54:57.553749	2025-09-03 23:57:13.214735	2025-10-05 11:08:02.438113	\N	2025-10-08 00:28:38.160858	2025-10-08 00:28:38.164168
295	97	depannage	213112.00	221636.48	122770.33	0.04	1	en_retard	2025-06-10 12:22:13.47146	2025-10-01 12:32:18.440773	2025-10-03 16:03:16.370793	78731.32	2025-10-08 00:28:38.160858	2025-10-08 00:28:38.164168
296	98	depannage	172976.00	179895.04	179895.04	0.04	1	defaut	2025-07-09 01:07:12.621994	2025-09-04 21:50:22.735583	2025-10-02 18:40:01.796309	\N	2025-10-08 00:28:38.160858	2025-10-08 00:28:38.164168
297	99	depannage	249198.00	256673.94	210441.51	0.03	1	en_retard	2025-07-22 07:42:54.138417	2025-10-01 06:19:36.728832	2025-09-29 23:33:44.213863	82777.84	2025-10-08 00:28:38.160858	2025-10-08 00:28:38.164168
298	91	depannage	120335.00	125148.40	125148.40	0.04	1	defaut	2025-09-25 12:48:30.693218	2025-08-10 06:21:15.683217	2025-10-01 17:29:44.59892	\N	2025-10-08 00:28:38.162973	2025-10-08 00:28:38.164168
299	92	depannage	139470.00	145048.80	145048.80	0.04	1	defaut	2025-08-14 05:03:49.536823	2025-10-01 09:00:37.482476	2025-10-06 16:02:09.914806	\N	2025-10-08 00:28:38.162973	2025-10-08 00:28:38.164168
300	93	depannage	98581.00	102524.24	102524.24	0.04	1	defaut	2025-07-20 06:29:31.694584	2025-09-19 23:52:53.835073	2025-09-06 18:28:07.10536	\N	2025-10-08 00:28:38.162973	2025-10-08 00:28:38.164168
301	94	depannage	149294.00	155265.76	155265.76	0.04	1	defaut	2025-08-27 05:12:52.4015	2025-08-18 10:25:37.457221	2025-10-04 05:38:10.883102	\N	2025-10-08 00:28:38.162973	2025-10-08 00:28:38.164168
302	95	depannage	81755.00	85025.20	85025.20	0.04	1	defaut	2025-09-30 11:06:27.046461	2025-08-16 13:09:25.137029	2025-10-04 00:05:51.137133	\N	2025-10-08 00:28:38.162973	2025-10-08 00:28:38.164168
153	1	consommation_generale	1175312.00	1210571.36	368553.25	0.03	1	actif	2024-11-10 01:50:10.836342	2025-10-13 04:38:30.966573	2025-11-06 10:42:07.12071	424526.27	2025-10-08 00:28:38.131475	2025-10-08 00:28:38.164168
154	2	consommation_generale	1715343.00	1766803.29	0.00	0.03	1	solde	2025-01-31 01:20:13.945684	2026-03-13 00:06:56.579077	2025-10-08 11:38:49.806394	\N	2025-10-08 00:28:38.131475	2025-10-08 00:28:38.164168
155	3	consommation_generale	1554394.00	1632113.70	0.00	0.05	1	solde	2025-09-06 10:42:40.292566	2025-11-07 23:43:04.851689	2025-11-05 16:09:09.721295	\N	2025-10-08 00:28:38.131475	2025-10-08 00:28:38.164168
156	4	avance_salaire	1123022.00	1156712.66	740213.07	0.03	1	actif	2025-03-24 20:36:42.118349	2026-03-26 11:07:26.604818	2025-11-03 17:44:08.367021	426939.02	2025-10-08 00:28:38.131475	2025-10-08 00:28:38.164168
157	5	consommation_generale	687107.00	707720.21	58724.01	0.03	1	actif	2024-11-28 20:16:15.51109	2026-02-01 23:44:37.724853	2025-10-28 08:09:58.479795	221800.91	2025-10-08 00:28:38.131475	2025-10-08 00:28:38.164168
158	6	avance_salaire	751232.00	788793.60	0.00	0.05	1	solde	2025-08-04 23:35:08.967933	2026-03-16 16:10:46.756322	2025-10-22 00:48:10.618027	\N	2025-10-08 00:28:38.131475	2025-10-08 00:28:38.164168
159	7	avance_salaire	682281.00	702749.43	25373.50	0.03	1	actif	2025-08-09 05:03:25.691016	2025-11-10 22:36:31.935747	2025-10-17 16:18:26.831701	208093.45	2025-10-08 00:28:38.131475	2025-10-08 00:28:38.164168
160	8	avance_salaire	1929113.00	2025568.65	718585.69	0.05	1	actif	2025-06-15 10:20:55.316847	2025-12-07 04:00:36.432562	2025-10-08 05:26:11.903653	691813.18	2025-10-08 00:28:38.131475	2025-10-08 00:28:38.164168
161	9	consommation_generale	1254384.00	1317103.20	704808.40	0.05	1	actif	2025-02-13 05:28:25.099959	2026-04-05 05:37:22.263626	2025-11-06 07:44:44.582917	436087.87	2025-10-08 00:28:38.131475	2025-10-08 00:28:38.164168
162	10	consommation_generale	1271985.00	1310144.55	0.00	0.03	1	solde	2025-01-06 01:34:17.908017	2025-12-31 04:38:51.312754	2025-10-21 11:39:14.100386	\N	2025-10-08 00:28:38.131475	2025-10-08 00:28:38.164168
163	11	avance_salaire	816846.00	841351.38	0.00	0.03	1	solde	2025-04-07 13:13:26.292954	2025-12-31 06:48:58.779432	2025-11-02 17:17:00.879457	\N	2025-10-08 00:28:38.131475	2025-10-08 00:28:38.164168
164	12	avance_salaire	1310160.00	1375668.00	0.00	0.05	1	solde	2025-01-30 05:54:06.039785	2025-12-30 13:25:31.957982	2025-10-18 03:13:06.355587	\N	2025-10-08 00:28:38.131475	2025-10-08 00:28:38.164168
165	13	avance_salaire	961323.00	1009389.15	448651.04	0.05	1	actif	2025-05-13 16:26:10.376098	2025-12-31 14:55:03.655869	2025-11-06 09:27:27.150141	375725.40	2025-10-08 00:28:38.131475	2025-10-08 00:28:38.164168
166	14	consommation_generale	735203.00	757259.09	0.00	0.03	1	solde	2025-02-14 06:56:41.258545	2025-11-14 18:09:15.806673	2025-10-19 10:00:54.035343	\N	2025-10-08 00:28:38.131475	2025-10-08 00:28:38.164168
167	15	consommation_generale	1080275.00	1134288.75	702283.78	0.05	1	actif	2025-04-01 14:25:44.414707	2026-03-24 18:47:07.897948	2025-11-06 17:11:53.066508	372137.93	2025-10-08 00:28:38.131475	2025-10-08 00:28:38.164168
168	16	avance_salaire	830572.00	872100.60	591830.07	0.05	1	actif	2025-07-24 06:11:22.137024	2025-10-10 10:21:23.13654	2025-11-06 22:17:46.827474	348264.49	2025-10-08 00:28:38.131475	2025-10-08 00:28:38.164168
169	17	avance_salaire	1823566.00	1914744.30	0.00	0.05	1	solde	2024-10-10 16:13:32.067609	2026-03-15 06:07:43.667145	2025-10-30 19:38:19.082255	\N	2025-10-08 00:28:38.131475	2025-10-08 00:28:38.164168
170	18	consommation_generale	1702279.00	1872506.90	0.00	0.05	2	solde	2025-02-28 11:59:14.361844	2025-10-10 14:00:08.153036	2025-10-23 13:20:44.350537	\N	2025-10-08 00:28:38.131475	2025-10-08 00:28:38.164168
171	19	avance_salaire	918288.00	945836.64	0.00	0.03	1	solde	2025-08-10 11:29:59.631341	2025-11-02 04:06:58.524935	2025-10-20 15:49:53.88734	\N	2025-10-08 00:28:38.131475	2025-10-08 00:28:38.164168
172	20	avance_salaire	1260166.00	1323174.30	574954.30	0.05	1	actif	2025-03-31 16:29:33.306202	2026-01-20 17:22:31.415252	2025-10-21 21:01:57.672639	501500.35	2025-10-08 00:28:38.131475	2025-10-08 00:28:38.164168
173	21	consommation_generale	1743307.00	1917637.70	0.00	0.05	2	solde	2025-09-26 05:39:42.903026	2025-10-17 18:16:27.49842	2025-10-23 15:37:47.449319	\N	2025-10-08 00:28:38.131475	2025-10-08 00:28:38.164168
174	22	avance_salaire	1480782.00	1525205.46	0.00	0.03	1	solde	2025-01-14 19:17:46.580018	2025-11-09 23:22:47.892025	2025-11-06 05:56:03.365536	\N	2025-10-08 00:28:38.131475	2025-10-08 00:28:38.164168
175	23	consommation_generale	1820078.00	1911081.90	0.00	0.05	1	solde	2024-10-08 19:44:56.120699	2025-10-10 14:20:17.35729	2025-10-14 17:01:46.17962	\N	2025-10-08 00:28:38.131475	2025-10-08 00:28:38.164168
176	24	consommation_generale	1854584.00	2021496.56	469818.45	0.03	3	actif	2025-08-30 13:59:37.352366	2025-10-17 12:14:12.328174	2025-10-23 12:51:34.437218	652139.40	2025-10-08 00:28:38.131475	2025-10-08 00:28:38.164168
177	25	consommation_generale	1446965.00	1490373.95	0.00	0.03	1	solde	2024-11-05 23:04:48.666433	2025-12-09 03:11:18.703342	2025-11-02 18:03:11.339538	\N	2025-10-08 00:28:38.131475	2025-10-08 00:28:38.164168
178	26	avance_salaire	1670417.00	1720529.51	0.00	0.03	1	solde	2025-02-24 08:16:30.002958	2026-01-04 23:17:45.467392	2025-11-04 10:12:15.285415	\N	2025-10-08 00:28:38.131475	2025-10-08 00:28:38.164168
179	27	consommation_generale	1630450.00	1711972.50	1138344.27	0.05	1	actif	2025-02-28 06:12:46.763152	2026-02-22 17:23:45.341447	2025-10-12 03:31:25.365136	558444.51	2025-10-08 00:28:38.131475	2025-10-08 00:28:38.164168
303	1	avance_salaire	751076.00	788629.80	0.00	0.05	1	solde	2025-03-24 04:44:51.869444	2025-11-20 14:51:08.7855	2025-11-01 10:24:08.792594	\N	2025-10-08 13:10:20.036559	2025-10-08 13:10:20.057292
180	28	consommation_generale	754449.00	867616.35	138839.53	0.05	3	actif	2025-06-13 07:54:00.711522	2026-02-16 18:17:51.093127	2025-10-29 08:38:49.635054	257472.41	2025-10-08 00:28:38.131475	2025-10-08 00:28:38.164168
181	29	avance_salaire	1248752.00	1361139.68	94913.35	0.03	3	actif	2025-05-03 03:47:53.248854	2025-11-29 07:50:32.357417	2025-11-06 20:16:54.670682	442474.78	2025-10-08 00:28:38.131475	2025-10-08 00:28:38.164168
182	30	avance_salaire	1579568.00	1658546.40	0.00	0.05	1	solde	2024-10-20 22:44:47.076308	2026-03-12 04:04:17.681241	2025-10-08 22:07:10.279002	\N	2025-10-08 00:28:38.131475	2025-10-08 00:28:38.164168
183	1	depannage	651418.00	677474.72	180325.06	0.04	1	actif	2025-08-20 09:22:36.274266	2025-10-14 16:51:08.900798	2025-10-13 09:40:11.694227	213767.01	2025-10-08 00:28:38.149437	2025-10-08 00:28:38.164168
184	2	depannage	954512.00	992692.48	242371.69	0.04	1	actif	2025-08-13 06:50:02.017983	2025-10-09 15:00:28.562561	2025-10-22 12:13:13.722604	378332.35	2025-10-08 00:28:38.149437	2025-10-08 00:28:38.164168
185	3	depannage	519747.00	540536.88	322736.95	0.04	1	actif	2025-07-30 18:39:43.117628	2025-11-29 15:56:57.344035	2025-10-17 13:40:53.999696	204837.04	2025-10-08 00:28:38.149437	2025-10-08 00:28:38.164168
186	4	depannage	321118.00	333962.72	160991.48	0.04	1	actif	2025-08-16 19:17:29.560258	2025-10-24 10:00:46.134987	2025-10-16 10:24:05.772555	123741.24	2025-10-08 00:28:38.149437	2025-10-08 00:28:38.164168
187	5	depannage	583088.00	606411.52	288018.63	0.04	1	actif	2025-09-04 09:10:09.188839	2025-11-16 17:24:28.87164	2025-10-18 08:27:08.856064	232709.60	2025-10-08 00:28:38.149437	2025-10-08 00:28:38.164168
188	6	depannage	463183.00	481710.32	152524.46	0.04	1	actif	2025-10-05 05:48:34.2996	2025-11-25 10:40:55.03165	2025-10-13 10:38:20.379365	176699.73	2025-10-08 00:28:38.149437	2025-10-08 00:28:38.164168
304	2	avance_salaire	1260463.00	1323486.15	0.00	0.05	1	solde	2025-01-30 17:59:10.324913	2026-04-01 17:15:44.081114	2025-10-30 05:52:17.661474	\N	2025-10-08 13:10:20.036559	2025-10-08 13:10:20.057292
305	3	consommation_generale	1851758.00	2129521.70	0.00	0.05	3	solde	2025-09-12 08:01:28.949503	2025-12-29 06:20:34.297166	2025-10-22 14:34:45.302666	\N	2025-10-08 13:10:20.036559	2025-10-08 13:10:20.057292
306	4	avance_salaire	1402267.00	1444335.01	652685.81	0.03	1	actif	2024-12-24 14:26:43.195928	2026-02-13 00:09:57.651264	2025-11-03 09:54:31.681888	617971.19	2025-10-08 13:10:20.036559	2025-10-08 13:10:20.057292
307	5	avance_salaire	1456078.00	1499760.34	0.00	0.03	1	solde	2025-09-28 06:00:06.28043	2026-02-20 20:37:19.180967	2025-10-15 07:01:13.73927	\N	2025-10-08 13:10:20.036559	2025-10-08 13:10:20.057292
308	6	consommation_generale	1598595.00	1678524.75	0.00	0.05	1	solde	2024-11-29 16:47:36.03105	2026-03-18 22:54:25.977178	2025-10-16 16:44:45.394761	\N	2025-10-08 13:10:20.036559	2025-10-08 13:10:20.057292
309	7	consommation_generale	1216822.00	1253326.66	0.00	0.03	1	solde	2025-06-27 03:32:32.48014	2025-12-02 13:10:50.595319	2025-10-16 21:52:06.911352	\N	2025-10-08 13:10:20.036559	2025-10-08 13:10:20.057292
310	8	avance_salaire	627490.00	658864.50	0.00	0.05	1	solde	2025-04-08 16:14:17.13258	2026-01-21 20:28:38.81399	2025-10-13 10:43:19.891177	\N	2025-10-08 13:10:20.036559	2025-10-08 13:10:20.057292
311	9	consommation_generale	1776247.00	1829534.41	0.00	0.03	1	solde	2025-03-07 03:54:04.533268	2026-02-18 14:05:30.027074	2025-10-21 14:41:04.052048	\N	2025-10-08 13:10:20.036559	2025-10-08 13:10:20.057292
312	10	avance_salaire	1027056.00	1078408.80	229169.92	0.05	1	actif	2025-07-01 16:27:38.015128	2026-02-20 12:42:15.960336	2025-10-15 23:12:03.570231	365605.46	2025-10-08 13:10:20.036559	2025-10-08 13:10:20.057292
313	11	avance_salaire	958899.00	987665.97	284155.25	0.03	1	actif	2025-08-23 18:28:36.869791	2026-03-08 01:34:47.742462	2025-10-18 10:59:50.35818	406972.47	2025-10-08 13:10:20.036559	2025-10-08 13:10:20.057292
314	12	avance_salaire	948404.00	1033760.36	225734.04	0.03	3	actif	2025-09-08 20:53:46.582091	2026-03-14 18:32:07.63421	2025-10-28 11:14:13.579952	300197.99	2025-10-08 13:10:20.036559	2025-10-08 13:10:20.057292
315	13	avance_salaire	1243512.00	1280817.36	0.00	0.03	1	solde	2025-03-24 04:22:31.553147	2025-11-19 09:44:38.667419	2025-10-16 23:36:29.411317	\N	2025-10-08 13:10:20.036559	2025-10-08 13:10:20.057292
316	14	consommation_generale	1505011.00	1580261.55	0.00	0.05	1	solde	2024-10-27 17:15:01.506238	2025-11-15 04:03:19.546733	2025-10-10 11:33:49.320616	\N	2025-10-08 13:10:20.036559	2025-10-08 13:10:20.057292
317	15	avance_salaire	824960.00	866208.00	424196.73	0.05	1	actif	2025-09-08 19:07:07.560332	2025-12-07 14:07:02.251735	2025-10-27 13:22:20.961776	341540.66	2025-10-08 13:10:20.036559	2025-10-08 13:10:20.057292
318	16	consommation_generale	1939743.00	2036730.15	736888.81	0.05	1	actif	2025-01-22 02:03:17.293602	2025-11-29 12:05:15.597291	2025-10-17 09:47:47.792521	866400.90	2025-10-08 13:10:20.036559	2025-10-08 13:10:20.057292
319	17	avance_salaire	1717413.00	1768935.39	0.00	0.03	1	solde	2025-05-14 14:37:46.761816	2025-10-16 04:05:38.066285	2025-10-25 23:46:35.521945	\N	2025-10-08 13:10:20.036559	2025-10-08 13:10:20.057292
320	18	consommation_generale	776406.00	799698.18	171431.70	0.03	1	actif	2024-10-08 20:12:25.358681	2025-12-05 12:52:50.913754	2025-11-01 16:16:24.171411	286423.15	2025-10-08 13:10:20.036559	2025-10-08 13:10:20.057292
321	19	consommation_generale	1641111.00	1690344.33	0.00	0.03	1	solde	2025-08-15 10:11:45.172477	2025-12-11 14:34:55.576078	2025-10-09 07:10:47.496965	\N	2025-10-08 13:10:20.036559	2025-10-08 13:10:20.057292
322	20	avance_salaire	1959830.00	2057821.50	0.00	0.05	1	solde	2025-06-02 18:01:24.067672	2026-03-19 04:57:17.89007	2025-10-16 15:43:00.658174	\N	2025-10-08 13:10:20.036559	2025-10-08 13:10:20.057292
323	21	avance_salaire	1916416.00	2012236.80	1382747.76	0.05	1	actif	2025-07-17 17:15:15.546637	2025-10-08 13:48:05.853638	2025-10-13 17:14:46.459065	851367.66	2025-10-08 13:10:20.036559	2025-10-08 13:10:20.057292
324	22	avance_salaire	1792692.00	1846472.76	1046700.12	0.03	1	actif	2024-11-11 09:33:21.170557	2026-04-05 01:28:26.898939	2025-10-20 20:04:07.898655	736662.27	2025-10-08 13:10:20.036559	2025-10-08 13:10:20.057292
325	23	avance_salaire	810126.00	834429.78	0.00	0.03	1	solde	2025-09-15 13:22:57.579181	2026-03-19 13:45:50.036961	2025-10-24 03:45:44.376726	\N	2025-10-08 13:10:20.036559	2025-10-08 13:10:20.057292
326	24	consommation_generale	612643.00	631022.29	0.00	0.03	1	solde	2025-04-19 15:59:29.761404	2026-01-11 08:10:33.580075	2025-10-20 18:37:23.22308	\N	2025-10-08 13:10:20.036559	2025-10-08 13:10:20.057292
327	25	avance_salaire	1828018.00	1882858.54	0.00	0.03	1	solde	2024-10-22 05:18:49.116739	2025-10-23 12:30:27.324612	2025-10-27 23:40:42.293606	\N	2025-10-08 13:10:20.036559	2025-10-08 13:10:20.057292
328	26	avance_salaire	1535437.00	1581500.11	404093.49	0.03	1	actif	2025-05-06 00:20:23.452862	2025-12-14 07:55:24.128985	2025-11-05 10:02:37.481755	630533.58	2025-10-08 13:10:20.036559	2025-10-08 13:10:20.057292
329	27	consommation_generale	917940.00	963837.00	660924.90	0.05	1	actif	2025-05-05 17:43:15.474486	2026-03-31 03:24:55.954396	2025-10-15 18:13:27.617072	290829.16	2025-10-08 13:10:20.036559	2025-10-08 13:10:20.057292
330	28	avance_salaire	854812.00	880456.36	0.00	0.03	1	solde	2025-09-27 15:58:15.133023	2025-12-25 13:07:37.454348	2025-11-03 23:27:04.593187	\N	2025-10-08 13:10:20.036559	2025-10-08 13:10:20.057292
331	29	consommation_generale	1647772.00	1812549.20	949417.06	0.05	2	actif	2025-05-17 04:37:28.566647	2026-01-18 17:56:41.358058	2025-10-26 21:52:02.985249	673647.00	2025-10-08 13:10:20.036559	2025-10-08 13:10:20.057292
332	30	consommation_generale	838823.00	922705.30	0.00	0.05	2	solde	2025-02-08 06:16:07.067119	2025-11-24 15:10:36.054226	2025-11-03 08:19:32.933825	\N	2025-10-08 13:10:20.036559	2025-10-08 13:10:20.057292
333	1	depannage	496653.00	516519.12	22205.03	0.04	1	actif	2025-09-06 18:46:06.788635	2025-11-07 11:44:06.14627	2025-10-22 00:40:21.834879	167101.30	2025-10-08 13:10:20.049438	2025-10-08 13:10:20.057292
334	2	depannage	701338.00	729391.52	367163.21	0.04	1	actif	2025-08-21 05:35:38.957455	2025-12-06 01:56:18.828364	2025-10-15 13:26:25.861524	238854.33	2025-10-08 13:10:20.049438	2025-10-08 13:10:20.057292
335	3	depannage	691744.00	719413.76	447498.90	0.04	1	actif	2025-07-26 13:11:00.656876	2025-11-05 01:29:49.589912	2025-10-22 13:58:44.147137	232558.85	2025-10-08 13:10:20.049438	2025-10-08 13:10:20.057292
336	4	depannage	839181.00	872748.24	359626.79	0.04	1	actif	2025-09-06 17:49:50.436331	2025-12-02 10:09:39.079868	2025-10-16 14:05:49.873687	355560.98	2025-10-08 13:10:20.049438	2025-10-08 13:10:20.057292
337	5	depannage	738920.00	768476.80	282674.85	0.04	1	actif	2025-07-30 07:03:30.303235	2025-11-04 00:41:42.8153	2025-10-17 08:56:08.958287	259903.73	2025-10-08 13:10:20.049438	2025-10-08 13:10:20.057292
338	6	depannage	794832.00	826625.28	392185.56	0.04	1	actif	2025-08-30 13:22:42.776882	2025-10-09 04:00:35.186184	2025-10-13 23:59:12.137336	316471.23	2025-10-08 13:10:20.049438	2025-10-08 13:10:20.057292
339	7	depannage	476602.00	495666.08	283410.97	0.04	1	actif	2025-09-21 15:34:42.142494	2025-12-06 20:08:17.262603	2025-10-20 11:45:33.632734	181161.11	2025-10-08 13:10:20.049438	2025-10-08 13:10:20.057292
340	8	depannage	867671.00	902377.84	294650.17	0.04	1	actif	2025-09-20 08:11:20.464801	2025-11-12 14:20:44.712153	2025-10-12 17:02:02.67263	304163.98	2025-10-08 13:10:20.049438	2025-10-08 13:10:20.057292
341	9	depannage	915919.00	952555.76	496377.07	0.04	1	actif	2025-08-07 21:40:44.6012	2025-10-19 20:52:14.15248	2025-10-09 18:32:41.207112	396806.50	2025-10-08 13:10:20.049438	2025-10-08 13:10:20.057292
342	10	depannage	529575.00	550758.00	318342.56	0.04	1	actif	2025-08-16 08:08:34.13188	2025-11-30 05:31:58.161936	2025-10-12 18:25:02.43093	217379.61	2025-10-08 13:10:20.049438	2025-10-08 13:10:20.057292
343	11	depannage	687263.00	714753.52	324610.98	0.04	1	actif	2025-08-01 20:24:22.260605	2025-11-23 08:45:30.739982	2025-10-10 12:44:15.081302	272187.25	2025-10-08 13:10:20.049438	2025-10-08 13:10:20.057292
344	12	depannage	258468.00	268806.72	99785.23	0.04	1	actif	2025-07-26 08:01:07.791337	2025-11-27 09:42:48.94807	2025-10-11 16:57:26.85522	94744.36	2025-10-08 13:10:20.049438	2025-10-08 13:10:20.057292
345	13	depannage	361999.00	376478.96	69584.94	0.04	1	actif	2025-09-21 11:41:43.420285	2025-10-09 02:12:01.211578	2025-10-20 23:42:04.187786	151980.65	2025-10-08 13:10:20.049438	2025-10-08 13:10:20.057292
346	14	depannage	338070.00	351592.80	233310.88	0.04	1	actif	2025-09-26 12:09:54.795028	2025-10-10 00:56:01.979818	2025-10-17 11:12:02.095481	107720.93	2025-10-08 13:10:20.049438	2025-10-08 13:10:20.057292
347	15	depannage	567761.00	590471.44	342105.14	0.04	1	actif	2025-07-26 07:17:04.251681	2025-10-21 22:01:06.892853	2025-10-19 03:46:49.203548	210358.09	2025-10-08 13:10:20.049438	2025-10-08 13:10:20.057292
348	31	consommation_generale	621172.00	683289.20	0.00	0.05	2	solde	2025-03-15 10:56:23.348183	2025-11-21 19:17:47.398688	2025-10-26 20:57:38.55503	\N	2025-10-08 13:10:20.050543	2025-10-08 13:10:20.057292
349	32	avance_salaire	604813.00	635053.65	274149.31	0.05	1	actif	2025-07-24 12:18:29.366784	2025-10-25 06:43:49.267919	2025-10-27 20:23:43.803609	251559.20	2025-10-08 13:10:20.050543	2025-10-08 13:10:20.057292
350	33	consommation_generale	663687.00	696871.35	468342.89	0.05	1	actif	2025-09-23 12:37:03.19616	2025-11-16 02:49:09.725439	2025-10-28 10:21:10.372318	288051.51	2025-10-08 13:10:20.050543	2025-10-08 13:10:20.057292
351	34	consommation_generale	286585.00	303780.10	211657.38	0.03	2	actif	2025-07-17 14:28:50.641393	2025-12-20 20:21:34.492311	2025-10-19 18:23:21.521192	104066.81	2025-10-08 13:10:20.050543	2025-10-08 13:10:20.057292
352	35	depannage	497700.00	512631.00	284887.43	0.03	1	actif	2025-06-13 13:28:53.208239	2025-12-18 06:44:54.951942	2025-10-16 10:12:59.907975	162653.94	2025-10-08 13:10:20.050543	2025-10-08 13:10:20.057292
353	36	avance_salaire	395687.00	427341.96	0.00	0.04	2	solde	2025-06-24 11:10:16.040071	2025-12-06 06:23:00.33605	2025-10-13 19:42:42.446921	\N	2025-10-08 13:10:20.050543	2025-10-08 13:10:20.057292
354	37	consommation_generale	302353.00	326541.24	0.00	0.04	2	solde	2025-02-23 17:05:06.773588	2026-01-30 12:32:13.960205	2025-10-16 02:52:33.272989	\N	2025-10-08 13:10:20.050543	2025-10-08 13:10:20.057292
355	38	depannage	558214.00	574960.42	384709.93	0.03	1	actif	2025-09-14 06:03:57.448284	2025-12-18 03:21:57.873281	2025-10-18 16:38:27.289608	201536.89	2025-10-08 13:10:20.050543	2025-10-08 13:10:20.057292
356	39	avance_salaire	569144.00	603292.64	0.00	0.03	2	solde	2025-01-21 05:45:51.264383	2025-10-17 09:03:14.7041	2025-10-28 13:01:20.31745	\N	2025-10-08 13:10:20.050543	2025-10-08 13:10:20.057292
357	40	consommation_generale	331773.00	341726.19	211659.70	0.03	1	en_retard	2025-05-16 10:29:10.666606	2026-01-03 18:26:04.576182	2025-10-17 04:11:34.68605	108730.35	2025-10-08 13:10:20.050543	2025-10-08 13:10:20.057292
358	41	consommation_generale	693594.00	714401.82	0.00	0.03	1	solde	2025-01-28 04:23:50.296983	2026-01-16 21:43:52.440312	2025-11-01 13:01:06.08951	\N	2025-10-08 13:10:20.050543	2025-10-08 13:10:20.057292
359	42	avance_salaire	710547.00	746074.35	0.00	0.05	1	solde	2025-04-01 10:40:55.764834	2025-11-05 22:41:08.453739	2025-10-22 10:08:14.07646	\N	2025-10-08 13:10:20.050543	2025-10-08 13:10:20.057292
360	43	avance_salaire	719040.00	740611.20	0.00	0.03	1	solde	2025-04-19 05:03:53.677861	2026-02-04 13:43:36.714172	2025-10-15 04:17:22.997333	\N	2025-10-08 13:10:20.050543	2025-10-08 13:10:20.057292
361	44	avance_salaire	799169.00	823144.07	461760.91	0.03	1	actif	2025-09-23 11:53:59.057892	2025-11-30 16:40:13.324034	2025-10-22 08:17:31.114205	343154.63	2025-10-08 13:10:20.050543	2025-10-08 13:10:20.057292
362	45	consommation_generale	313802.00	332630.12	194755.94	0.03	2	actif	2025-09-17 11:33:47.518346	2026-01-15 07:16:34.245885	2025-10-28 14:46:39.464666	121048.87	2025-10-08 13:10:20.050543	2025-10-08 13:10:20.057292
363	46	avance_salaire	615106.00	633559.18	0.00	0.03	1	solde	2025-04-24 05:41:44.110171	2025-11-13 04:29:37.769973	2025-10-20 18:02:49.702232	\N	2025-10-08 13:10:20.050543	2025-10-08 13:10:20.057292
364	47	consommation_generale	375295.00	394059.75	171548.69	0.05	1	actif	2025-06-15 21:29:48.582557	2025-12-22 11:05:34.096951	2025-10-22 16:38:25.271264	146234.59	2025-10-08 13:10:20.050543	2025-10-08 13:10:20.057292
365	48	avance_salaire	433910.00	455605.50	109833.75	0.05	1	actif	2025-09-04 06:29:18.317312	2025-10-21 17:23:08.724672	2025-10-22 12:22:44.85021	146740.35	2025-10-08 13:10:20.050543	2025-10-08 13:10:20.057292
366	49	consommation_generale	349371.00	359852.13	87886.30	0.03	1	actif	2025-02-07 19:49:01.846372	2025-11-08 02:42:46.028264	2025-10-17 07:12:34.265043	151367.41	2025-10-08 13:10:20.050543	2025-10-08 13:10:20.057292
367	50	avance_salaire	782743.00	861017.30	553052.24	0.05	2	en_retard	2025-08-09 22:17:20.459881	2025-11-12 01:22:08.506521	2025-10-26 11:22:54.42795	287137.62	2025-10-08 13:10:20.050543	2025-10-08 13:10:20.057292
368	51	consommation_generale	464157.00	478081.71	0.00	0.03	1	solde	2025-06-23 11:13:06.623158	2025-10-17 18:49:45.201241	2025-10-29 11:03:55.449911	\N	2025-10-08 13:10:20.050543	2025-10-08 13:10:20.057292
369	52	consommation_generale	502533.00	517608.99	0.00	0.03	1	solde	2025-02-17 09:44:21.913472	2025-10-20 20:06:43.086626	2025-10-22 00:15:25.144174	\N	2025-10-08 13:10:20.050543	2025-10-08 13:10:20.057292
370	53	avance_salaire	230493.00	242017.65	0.00	0.05	1	solde	2025-07-17 18:21:35.848979	2025-12-27 15:59:03.055645	2025-10-23 20:14:08.720128	\N	2025-10-08 13:10:20.050543	2025-10-08 13:10:20.057292
371	54	avance_salaire	575450.00	592713.50	0.00	0.03	1	solde	2025-02-05 07:25:15.169202	2025-10-13 06:00:01.347417	2025-10-25 07:41:47.621429	\N	2025-10-08 13:10:20.050543	2025-10-08 13:10:20.057292
372	55	avance_salaire	681027.00	715078.35	409167.96	0.05	1	actif	2025-08-19 17:01:00.91824	2026-01-25 22:15:35.811758	2025-10-20 05:22:05.432138	208876.31	2025-10-08 13:10:20.050543	2025-10-08 13:10:20.057292
373	56	avance_salaire	570441.00	627485.10	373094.14	0.05	2	en_retard	2025-04-13 10:29:40.681486	2025-12-25 07:50:39.323912	2025-10-24 03:29:25.91383	233602.15	2025-10-08 13:10:20.050543	2025-10-08 13:10:20.057292
374	57	consommation_generale	413994.00	455393.40	0.00	0.05	2	solde	2025-02-22 05:09:38.203793	2025-10-13 17:50:10.747664	2025-10-22 18:20:45.104497	\N	2025-10-08 13:10:20.050543	2025-10-08 13:10:20.057292
375	58	consommation_generale	796463.00	876109.30	0.00	0.05	2	solde	2025-02-01 22:43:18.971251	2025-11-06 21:39:00.324801	2025-10-25 21:34:08.438727	\N	2025-10-08 13:10:20.050543	2025-10-08 13:10:20.057292
376	59	depannage	761636.00	822566.88	491038.40	0.04	2	actif	2025-08-20 17:17:57.99049	2025-11-11 14:26:21.237749	2025-10-21 02:27:15.401785	326486.45	2025-10-08 13:10:20.050543	2025-10-08 13:10:20.057292
377	60	depannage	346256.00	367031.36	214639.41	0.03	2	actif	2025-02-27 07:59:31.595964	2025-10-10 02:46:49.497866	2025-10-23 20:18:55.372199	145388.64	2025-10-08 13:10:20.050543	2025-10-08 13:10:20.057292
378	61	avance_salaire	412278.00	432891.90	0.00	0.05	1	solde	2025-06-15 15:27:52.054918	2025-10-24 17:29:21.996524	2025-10-08 20:39:37.919881	\N	2025-10-08 13:10:20.050543	2025-10-08 13:10:20.057292
379	62	depannage	352913.00	374087.78	163585.36	0.03	2	actif	2025-09-02 01:36:15.51739	2025-11-07 10:14:47.505083	2025-10-13 09:07:05.552662	129400.44	2025-10-08 13:10:20.050543	2025-10-08 13:10:20.057292
380	63	depannage	793095.00	832749.75	581106.42	0.05	1	actif	2025-03-30 07:26:28.712397	2025-11-16 02:21:46.088851	2025-10-10 01:44:14.298379	240252.48	2025-10-08 13:10:20.050543	2025-10-08 13:10:20.057292
381	64	consommation_generale	682643.00	723601.58	0.00	0.03	2	solde	2025-05-18 14:23:37.235033	2025-12-18 16:12:22.118995	2025-10-16 04:58:58.188432	\N	2025-10-08 13:10:20.050543	2025-10-08 13:10:20.057292
382	65	avance_salaire	312771.00	337792.68	44838.17	0.04	2	actif	2025-07-20 08:01:36.975096	2025-10-17 23:26:18.624155	2025-10-26 16:07:55.811449	139332.64	2025-10-08 13:10:20.050543	2025-10-08 13:10:20.057292
383	66	depannage	254135.00	264300.40	149776.80	0.04	1	actif	2025-01-23 09:45:22.154026	2025-10-26 02:27:57.61183	2025-10-30 11:50:06.651288	96403.63	2025-10-08 13:10:20.050543	2025-10-08 13:10:20.057292
384	67	consommation_generale	237483.00	249357.15	2818.52	0.05	1	actif	2025-09-12 10:57:03.021335	2025-10-18 09:02:54.723956	2025-10-12 22:05:33.647857	90961.47	2025-10-08 13:10:20.050543	2025-10-08 13:10:20.057292
385	68	consommation_generale	458118.00	485605.08	129654.73	0.03	2	actif	2025-05-06 00:27:02.581059	2025-10-20 03:28:17.438996	2025-10-20 03:34:42.874124	197131.24	2025-10-08 13:10:20.050543	2025-10-08 13:10:20.057292
386	69	consommation_generale	499992.00	514991.76	68902.87	0.03	1	actif	2025-06-26 19:25:10.607535	2025-12-18 22:00:11.512033	2025-10-30 01:10:45.489156	222767.23	2025-10-08 13:10:20.050543	2025-10-08 13:10:20.057292
387	70	avance_salaire	201480.00	207524.40	0.00	0.03	1	solde	2025-08-21 12:23:33.600008	2025-10-23 18:20:59.817125	2025-10-30 02:52:31.660822	\N	2025-10-08 13:10:20.050543	2025-10-08 13:10:20.057292
388	31	depannage	457899.00	476214.96	124.95	0.04	1	actif	2025-09-13 01:49:02.836409	2025-10-15 13:42:27.706254	2025-10-19 09:00:39.166005	142609.24	2025-10-08 13:10:20.052226	2025-10-08 13:10:20.057292
389	32	depannage	329172.00	342338.88	14933.68	0.04	1	actif	2025-06-29 01:39:17.754138	2025-11-06 19:37:12.942864	2025-10-10 11:16:12.299607	142799.33	2025-10-08 13:10:20.052226	2025-10-08 13:10:20.057292
390	33	depannage	365581.00	380204.24	117778.84	0.04	1	actif	2025-09-08 20:28:24.605706	2025-10-20 10:32:02.820077	2025-10-26 11:09:01.329613	142730.48	2025-10-08 13:10:20.052226	2025-10-08 13:10:20.057292
391	34	depannage	510101.00	530505.04	332384.57	0.04	1	actif	2025-07-05 19:01:48.013123	2025-11-05 11:45:38.748887	2025-10-15 19:43:11.531941	178785.56	2025-10-08 13:10:20.052226	2025-10-08 13:10:20.057292
392	35	depannage	222542.00	231443.68	86644.01	0.04	1	actif	2025-06-13 18:35:09.278648	2025-10-29 00:06:31.858575	2025-10-11 14:28:20.394846	75015.88	2025-10-08 13:10:20.052226	2025-10-08 13:10:20.057292
393	36	depannage	313892.00	326447.68	279137.49	0.04	1	en_retard	2025-06-15 11:27:15.709042	2025-10-10 12:09:27.75765	2025-10-14 15:57:30.087169	97365.65	2025-10-08 13:10:20.052226	2025-10-08 13:10:20.057292
394	37	depannage	499554.00	519536.16	325253.76	0.04	1	en_retard	2025-09-10 10:12:22.451653	2025-10-21 07:58:25.126782	2025-10-27 12:56:08.775295	152344.75	2025-10-08 13:10:20.052226	2025-10-08 13:10:20.057292
395	38	depannage	253424.00	263560.96	223764.28	0.04	1	en_retard	2025-07-13 23:40:28.097997	2025-10-31 16:24:44.695352	2025-10-14 16:20:17.213433	112366.50	2025-10-08 13:10:20.052226	2025-10-08 13:10:20.057292
396	39	depannage	358439.00	372776.56	44738.57	0.04	1	actif	2025-09-21 09:10:02.361684	2025-11-21 20:40:11.127772	2025-10-27 03:35:41.471641	139241.34	2025-10-08 13:10:20.052226	2025-10-08 13:10:20.057292
397	40	depannage	194897.00	202692.88	174898.54	0.04	1	en_retard	2025-07-22 02:36:29.329856	2025-10-27 21:18:13.540666	2025-10-24 23:38:31.772814	65968.92	2025-10-08 13:10:20.052226	2025-10-08 13:10:20.057292
398	41	depannage	485906.00	505342.24	263573.79	0.04	1	en_retard	2025-08-05 16:21:39.230438	2025-10-16 09:51:49.975615	2025-10-26 23:18:46.148189	207699.03	2025-10-08 13:10:20.052226	2025-10-08 13:10:20.057292
399	42	depannage	203517.00	211657.68	113750.28	0.04	1	actif	2025-10-07 16:47:08.021462	2025-10-21 23:14:00.130265	2025-10-26 19:44:13.686615	84731.97	2025-10-08 13:10:20.052226	2025-10-08 13:10:20.057292
400	43	depannage	400971.00	417009.84	366763.57	0.04	1	en_retard	2025-07-05 11:36:42.487658	2025-11-02 18:09:33.102037	2025-10-10 19:18:54.749936	139696.78	2025-10-08 13:10:20.052226	2025-10-08 13:10:20.057292
401	44	depannage	278675.00	289822.00	260042.94	0.04	1	en_retard	2025-08-09 18:54:36.826098	2025-10-29 16:33:03.284641	2025-10-22 07:13:05.980825	110134.79	2025-10-08 13:10:20.052226	2025-10-08 13:10:20.057292
402	45	depannage	266101.00	276745.04	135082.62	0.04	1	actif	2025-06-17 08:38:33.432641	2025-10-18 21:16:04.459292	2025-10-09 14:38:02.156111	83958.45	2025-10-08 13:10:20.052226	2025-10-08 13:10:20.057292
403	46	depannage	181468.00	188726.72	35456.23	0.04	1	actif	2025-07-29 22:05:54.228559	2025-10-23 16:20:48.419681	2025-10-17 23:40:04.669184	64204.27	2025-10-08 13:10:20.052226	2025-10-08 13:10:20.057292
404	47	depannage	417075.00	433758.00	289098.60	0.04	1	actif	2025-07-20 11:37:35.929085	2025-11-20 10:27:16.960049	2025-10-16 10:13:02.659245	157672.96	2025-10-08 13:10:20.052226	2025-10-08 13:10:20.057292
405	48	depannage	211243.00	219692.72	149411.08	0.04	1	actif	2025-07-09 08:43:58.920902	2025-10-10 05:57:23.707481	2025-10-13 18:56:39.043885	75291.31	2025-10-08 13:10:20.052226	2025-10-08 13:10:20.057292
406	49	depannage	297436.00	309333.44	935.24	0.04	1	actif	2025-06-17 00:08:39.089595	2025-11-05 10:10:32.528561	2025-10-20 22:10:45.612398	116796.40	2025-10-08 13:10:20.052226	2025-10-08 13:10:20.057292
407	50	depannage	386460.00	401918.40	41187.34	0.04	1	actif	2025-07-28 16:03:08.609328	2025-11-09 07:36:02.437702	2025-10-24 08:44:05.827144	170799.99	2025-10-08 13:10:20.052226	2025-10-08 13:10:20.057292
408	71	consommation_generale	244186.00	253953.44	15099.96	0.04	1	actif	2025-08-31 16:11:06.470218	2025-10-14 13:33:55.578077	2025-10-19 11:10:07.147025	73983.60	2025-10-08 13:10:20.053342	2025-10-08 13:10:20.057292
409	72	avance_salaire	228355.00	239772.75	0.00	0.05	1	solde	2025-10-03 23:44:10.586246	2025-12-21 15:47:26.381505	2025-10-19 14:34:39.788718	\N	2025-10-08 13:10:20.053342	2025-10-08 13:10:20.057292
410	73	depannage	106940.00	111217.60	2463.92	0.04	1	actif	2025-10-07 22:11:34.212502	2025-12-08 08:54:37.503864	2025-10-30 20:31:51.106239	33924.25	2025-10-08 13:10:20.053342	2025-10-08 13:10:20.057292
411	74	depannage	311741.00	321093.23	0.00	0.03	1	solde	2025-07-10 09:31:31.494647	2025-12-20 06:59:48.033352	2025-10-21 09:09:01.180905	\N	2025-10-08 13:10:20.053342	2025-10-08 13:10:20.057292
412	75	consommation_generale	125996.00	131035.84	97605.54	0.04	1	en_retard	2025-07-03 08:14:32.772656	2025-11-27 22:44:50.336302	2025-10-24 05:32:26.507277	46084.78	2025-10-08 13:10:20.053342	2025-10-08 13:10:20.057292
413	76	avance_salaire	331441.00	344698.64	0.00	0.04	1	solde	2025-04-27 20:45:38.593233	2025-10-25 18:41:12.729649	2025-10-24 08:47:01.181205	\N	2025-10-08 13:10:20.053342	2025-10-08 13:10:20.057292
414	77	consommation_generale	424393.00	441368.72	110605.03	0.04	1	actif	2025-04-15 05:38:22.151262	2025-11-24 00:36:32.556905	2025-10-11 14:47:45.474037	179577.79	2025-10-08 13:10:20.053342	2025-10-08 13:10:20.057292
415	78	avance_salaire	218059.00	228961.95	0.00	0.05	1	solde	2025-06-05 12:00:22.31867	2025-12-01 18:12:16.253021	2025-10-11 19:41:53.822586	\N	2025-10-08 13:10:20.053342	2025-10-08 13:10:20.057292
416	79	avance_salaire	253459.00	266131.95	208343.47	0.05	1	en_retard	2025-07-21 00:11:49.398065	2025-11-09 03:32:15.231582	2025-11-02 03:16:05.246741	76339.94	2025-10-08 13:10:20.053342	2025-10-08 13:10:20.057292
417	80	avance_salaire	370097.00	388601.85	0.00	0.05	1	solde	2025-06-20 04:32:55.04997	2025-11-23 14:19:31.604013	2025-10-16 20:21:46.611539	\N	2025-10-08 13:10:20.053342	2025-10-08 13:10:20.057292
418	81	consommation_generale	443287.00	465451.35	0.00	0.05	1	solde	2025-08-28 16:58:59.169353	2025-11-08 20:06:26.537078	2025-10-26 16:19:54.194454	\N	2025-10-08 13:10:20.053342	2025-10-08 13:10:20.057292
419	82	depannage	358286.00	369034.58	288787.39	0.03	1	en_retard	2025-09-04 15:34:58.471065	2025-12-27 22:12:05.907971	2025-10-28 04:28:01.014761	109153.16	2025-10-08 13:10:20.053342	2025-10-08 13:10:20.057292
420	83	consommation_generale	110574.00	113891.22	55571.53	0.03	1	actif	2025-03-23 15:42:01.936807	2025-11-15 20:17:26.152122	2025-10-09 01:14:41.400548	34704.44	2025-10-08 13:10:20.053342	2025-10-08 13:10:20.057292
421	84	consommation_generale	189942.00	195640.26	166407.26	0.03	1	en_retard	2025-09-26 18:37:50.714747	2025-11-15 04:11:31.121422	2025-11-03 08:46:06.759344	73143.90	2025-10-08 13:10:20.053342	2025-10-08 13:10:20.057292
422	85	avance_salaire	240253.00	249863.12	7805.55	0.04	1	actif	2025-07-09 19:27:23.913755	2025-10-19 05:59:39.427896	2025-10-09 00:42:55.536431	82345.76	2025-10-08 13:10:20.053342	2025-10-08 13:10:20.057292
423	86	avance_salaire	211282.00	221846.10	147096.97	0.05	1	actif	2025-10-04 16:42:54.585617	2025-12-07 17:03:08.831693	2025-10-30 14:15:00.958001	74168.93	2025-10-08 13:10:20.053342	2025-10-08 13:10:20.057292
424	87	depannage	409348.00	425721.92	164024.79	0.04	1	actif	2025-07-16 16:27:53.308481	2025-12-23 19:06:06.01846	2025-10-15 02:09:17.360167	156618.16	2025-10-08 13:10:20.053342	2025-10-08 13:10:20.057292
425	88	consommation_generale	187198.00	196557.90	34751.00	0.05	1	actif	2025-09-14 13:45:31.472818	2025-12-19 19:47:48.595953	2025-11-07 06:52:16.079713	73720.69	2025-10-08 13:10:20.053342	2025-10-08 13:10:20.057292
426	89	avance_salaire	418962.00	431530.86	273611.64	0.03	1	en_retard	2025-06-12 12:31:33.657889	2025-11-20 15:28:03.545619	2025-10-29 15:54:30.585008	186478.59	2025-10-08 13:10:20.053342	2025-10-08 13:10:20.057292
427	90	consommation_generale	382472.00	397770.88	225069.45	0.04	1	actif	2025-04-06 14:04:46.087467	2025-11-28 06:27:09.669861	2025-10-17 20:33:47.959077	121164.63	2025-10-08 13:10:20.053342	2025-10-08 13:10:20.057292
428	75	depannage	267804.00	278516.16	242752.83	0.04	1	en_retard	2025-08-20 14:45:29.370185	2025-10-03 12:04:27.757198	2025-10-08 12:25:59.34565	110387.00	2025-10-08 13:10:20.054554	2025-10-08 13:10:20.057292
429	76	depannage	220815.00	229647.60	177975.70	0.04	1	en_retard	2025-10-07 22:26:03.578442	2025-10-02 17:42:18.977775	2025-10-04 01:37:29.646178	86657.66	2025-10-08 13:10:20.054554	2025-10-08 13:10:20.057292
430	77	depannage	302973.00	315091.92	214469.64	0.04	1	en_retard	2025-09-22 10:22:14.467681	2025-09-30 08:19:17.144782	2025-10-03 15:33:57.207488	128388.95	2025-10-08 13:10:20.054554	2025-10-08 13:10:20.057292
431	78	depannage	230458.00	239676.32	149499.47	0.04	1	en_retard	2025-09-25 08:03:32.659197	2025-09-28 07:20:17.296352	2025-10-01 22:28:05.195937	72632.27	2025-10-08 13:10:20.054554	2025-10-08 13:10:20.057292
432	79	depannage	240275.00	249886.00	203164.37	0.04	1	en_retard	2025-08-10 08:22:10.428214	2025-09-25 04:45:27.610782	2025-09-29 12:20:33.324032	91739.24	2025-10-08 13:10:20.054554	2025-10-08 13:10:20.057292
433	80	depannage	293285.00	305016.40	154803.00	0.04	1	en_retard	2025-09-29 09:54:27.051095	2025-10-06 17:02:44.059219	2025-10-02 02:54:18.121346	102168.19	2025-10-08 13:10:20.054554	2025-10-08 13:10:20.057292
434	81	depannage	322618.00	335522.72	263064.54	0.04	1	en_retard	2025-09-23 05:16:25.084653	2025-10-03 16:42:25.459758	2025-10-03 14:07:31.639429	138489.65	2025-10-08 13:10:20.054554	2025-10-08 13:10:20.057292
435	82	depannage	280584.00	291807.36	180904.74	0.04	1	en_retard	2025-09-28 16:30:12.470644	2025-10-03 17:53:01.687839	2025-10-07 19:09:35.108071	115864.01	2025-10-08 13:10:20.054554	2025-10-08 13:10:20.057292
436	83	depannage	246737.00	256606.48	181254.47	0.04	1	en_retard	2025-09-10 03:58:13.919006	2025-09-25 19:47:38.014383	2025-10-07 12:16:45.129154	97432.05	2025-10-08 13:10:20.054554	2025-10-08 13:10:20.057292
437	84	depannage	266890.00	277565.60	145233.43	0.04	1	en_retard	2025-09-28 18:56:51.604779	2025-09-30 16:48:44.416376	2025-10-04 23:23:16.04318	103348.68	2025-10-08 13:10:20.054554	2025-10-08 13:10:20.057292
438	85	depannage	341730.00	355399.20	207702.91	0.04	1	en_retard	2025-08-14 18:47:21.814521	2025-10-05 07:50:50.129308	2025-09-29 14:09:29.089258	122878.21	2025-10-08 13:10:20.054554	2025-10-08 13:10:20.057292
439	91	avance_salaire	228145.00	237270.80	212805.42	0.04	1	en_retard	2025-09-23 16:03:45.730839	2025-10-03 16:00:26.285147	2025-09-18 13:01:52.031312	92918.45	2025-10-08 13:10:20.055438	2025-10-08 13:10:20.057292
440	92	depannage	123943.00	127661.29	93710.30	0.03	1	en_retard	2025-06-29 17:22:04.189212	2025-08-29 21:49:53.458042	2025-10-04 02:04:39.097656	45205.91	2025-10-08 13:10:20.055438	2025-10-08 13:10:20.057292
441	93	avance_salaire	144520.00	150300.80	107910.55	0.04	1	en_retard	2025-04-11 13:42:33.251295	2025-08-30 01:24:57.559283	2025-09-20 23:02:45.195402	64739.67	2025-10-08 13:10:20.055438	2025-10-08 13:10:20.057292
442	94	avance_salaire	261824.00	269678.72	171407.58	0.03	1	en_retard	2025-06-02 15:11:33.790172	2025-09-01 04:02:02.499239	2025-09-09 23:39:02.8081	96909.12	2025-10-08 13:10:20.055438	2025-10-08 13:10:20.057292
443	95	avance_salaire	111391.00	115846.64	115846.64	0.04	1	defaut	2025-05-10 17:22:09.348207	2025-08-30 05:35:41.072719	2025-10-07 06:47:24.593007	\N	2025-10-08 13:10:20.055438	2025-10-08 13:10:20.057292
444	96	depannage	177550.00	182876.50	182876.50	0.03	1	defaut	2025-04-22 10:26:02.792245	2025-10-02 00:52:39.045964	2025-09-22 07:28:28.736773	\N	2025-10-08 13:10:20.055438	2025-10-08 13:10:20.057292
445	97	avance_salaire	102111.00	106195.44	92878.05	0.04	1	en_retard	2025-07-13 02:44:16.997556	2025-09-22 02:45:51.767865	2025-09-18 15:39:28.742231	42321.88	2025-10-08 13:10:20.055438	2025-10-08 13:10:20.057292
446	98	avance_salaire	112222.00	116710.88	116710.88	0.04	1	defaut	2025-07-04 02:13:35.275356	2025-09-24 14:23:06.377762	2025-10-03 13:04:12.421837	\N	2025-10-08 13:10:20.055438	2025-10-08 13:10:20.057292
447	99	avance_salaire	217971.00	224510.13	121706.32	0.03	1	en_retard	2025-06-18 07:26:56.941775	2025-09-29 19:38:14.645022	2025-10-05 11:12:13.89502	74395.01	2025-10-08 13:10:20.055438	2025-10-08 13:10:20.057292
448	91	depannage	134439.00	139816.56	139816.56	0.04	1	defaut	2025-08-27 23:01:00.527007	2025-08-19 05:44:56.569141	2025-09-26 14:31:52.567973	\N	2025-10-08 13:10:20.056322	2025-10-08 13:10:20.057292
449	92	depannage	76808.00	79880.32	79880.32	0.04	1	defaut	2025-08-03 03:23:28.099241	2025-08-26 20:53:35.665759	2025-09-06 17:25:18.954538	\N	2025-10-08 13:10:20.056322	2025-10-08 13:10:20.057292
450	93	depannage	147313.00	153205.52	153205.52	0.04	1	defaut	2025-07-15 06:48:51.232586	2025-09-11 15:39:10.874282	2025-09-04 17:39:37.953054	\N	2025-10-08 13:10:20.056322	2025-10-08 13:10:20.057292
451	94	depannage	170920.00	177756.80	177756.80	0.04	1	defaut	2025-08-18 14:40:22.62522	2025-10-06 13:02:38.238573	2025-09-12 16:33:51.213741	\N	2025-10-08 13:10:20.056322	2025-10-08 13:10:20.057292
452	95	depannage	105528.00	109749.12	109749.12	0.04	1	defaut	2025-08-01 09:37:22.592454	2025-09-10 11:08:00.299091	2025-08-26 17:26:56.904051	\N	2025-10-08 13:10:20.056322	2025-10-08 13:10:20.057292
\.


--
-- Data for Name: demandes_credit_longues; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.demandes_credit_longues (id, numero_demande, utilisateur_id, type_credit, montant_demande, duree_mois, objectif, statut, date_soumission, date_decision, decideur_id, montant_approuve, taux_approuve, notes_decision, score_au_moment_demande, niveau_risque_evaluation, date_creation, date_modification, username, decision, personal_info, credit_details, financial_details, documents, simulation_results, special_conditions, assigned_to, review_started_date, created_by) FROM stdin;
1	LCR-20251002-5038	1	investissement	2076643.00	24	Achat de vÃ©hicule professionnel	soumise	2025-09-24 11:05:22.652533	2025-08-23 04:33:14.44043	\N	1810600.00	0.08	Revenus insuffisants pour le montant demandÃ©	9.2	tres_bas	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
2	LCR-20251002-5564	2	consommation_generale	3152160.00	25	DÃ©veloppement d'activitÃ© commerciale	soumise	2025-06-19 06:58:35.753698	2025-09-10 09:42:25.813432	2	\N	0.10	En cours d'analyse par le comitÃ©	8.9	tres_bas	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
3	LCR-20251002-8526	4	consommation_generale	2161474.00	21	Travaux de rÃ©novation immobiliÃ¨re	en_examen	2025-09-21 03:56:15.818959	2025-08-10 11:16:48.225331	\N	1267353.00	0.09	Dossier complet - Approbation accordÃ©e	8.7	tres_bas	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
4	LCR-20251002-2432	5	investissement	3528556.00	24	DÃ©veloppement d'activitÃ© commerciale	soumise	2025-08-09 11:16:29.738186	\N	\N	\N	\N	Documents complÃ©mentaires requis	8.3	bas	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
5	LCR-20251002-1737	8	consommation_generale	2110375.00	25	Achat de vÃ©hicule professionnel	en_examen	2025-07-04 18:57:38.967167	2025-09-28 21:29:08.697724	2	\N	0.07	Revenus insuffisants pour le montant demandÃ©	8.4	bas	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
6	LCR-20251002-8379	12	consommation_generale	3653378.00	24	Achat de vÃ©hicule professionnel	en_examen	2025-07-12 21:14:12.076735	2025-08-26 23:08:10.287799	\N	\N	\N	Revenus insuffisants pour le montant demandÃ©	8.1	bas	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
7	LCR-20251002-5895	13	consommation_generale	1986301.00	30	Achat de vÃ©hicule professionnel	en_examen	2025-06-19 13:41:09.040968	2025-09-17 08:23:40.378878	2	1014427.00	0.08	En cours d'analyse par le comitÃ©	8.0	bas	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
8	LCR-20251002-1064	16	investissement	3342408.00	30	Achat de vÃ©hicule professionnel	en_examen	2025-06-24 03:37:42.157471	\N	2	2303128.00	0.08	Revenus insuffisants pour le montant demandÃ©	8.2	bas	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
9	LCR-20251002-7046	21	consommation_generale	2632677.00	18	Travaux de rÃ©novation immobiliÃ¨re	soumise	2025-07-17 12:34:44.249581	2025-08-13 23:25:05.764421	2	\N	0.08	En cours d'analyse par le comitÃ©	8.4	bas	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
10	LCR-20251002-2697	24	consommation_generale	1283881.00	18	DÃ©veloppement d'activitÃ© commerciale	soumise	2025-06-12 05:13:10.570338	2025-09-03 21:58:47.062608	2	\N	\N	Dossier complet - Approbation accordÃ©e	8.6	bas	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
11	LCR-20251002-4575	26	consommation_generale	2497720.00	26	DÃ©veloppement d'activitÃ© commerciale	rejetee	2025-08-19 05:45:32.346574	2025-08-29 02:14:22.341604	2	1490881.00	0.06	Dossier complet - Approbation accordÃ©e	8.2	bas	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
12	LCR-20251002-9459	28	consommation_generale	3236778.00	30	Investissement dans Ã©quipements professionnels	en_examen	2025-06-08 14:49:23.576799	2025-08-07 10:20:45.860141	2	978118.00	0.09	Dossier complet - Approbation accordÃ©e	8.7	tres_bas	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
13	LCR-20251002-4502	31	investissement	3979871.00	19	Travaux de rÃ©novation immobiliÃ¨re	rejetee	2025-08-27 12:52:44.578988	2025-09-24 19:53:05.682008	\N	2239694.00	0.09	Documents complÃ©mentaires requis	7.2	moyen	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
14	LCR-20251002-0391	33	investissement	3722818.00	31	Travaux de rÃ©novation immobiliÃ¨re	en_examen	2025-08-16 17:35:24.996418	\N	\N	\N	\N	Documents complÃ©mentaires requis	7.0	moyen	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
15	LCR-20251002-2030	35	consommation_generale	1652047.00	21	Achat de vÃ©hicule professionnel	en_examen	2025-09-27 08:08:29.024662	2025-08-28 07:45:25.388919	\N	\N	\N	Revenus insuffisants pour le montant demandÃ©	7.1	moyen	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
16	LCR-20251002-4047	36	investissement	1666072.00	35	DÃ©veloppement d'activitÃ© commerciale	en_examen	2025-07-01 09:45:08.354801	\N	2	\N	\N	Revenus insuffisants pour le montant demandÃ©	6.9	moyen	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
17	LCR-20251002-1305	37	consommation_generale	3038096.00	26	DÃ©veloppement d'activitÃ© commerciale	soumise	2025-07-06 13:13:57.151956	\N	2	\N	\N	En cours d'analyse par le comitÃ©	6.7	moyen	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
18	LCR-20251002-5093	40	consommation_generale	2344485.00	17	Travaux de rÃ©novation immobiliÃ¨re	soumise	2025-06-15 00:33:43.382378	\N	2	\N	\N	Revenus insuffisants pour le montant demandÃ©	7.0	moyen	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
19	LCR-20251002-1144	43	consommation_generale	2126928.00	25	Achat de vÃ©hicule professionnel	approuvee	2025-06-12 04:25:24.727717	2025-09-06 03:44:50.636074	2	1762261.00	\N	Revenus insuffisants pour le montant demandÃ©	6.5	moyen	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
20	LCR-20251002-3670	49	consommation_generale	3124246.00	26	DÃ©veloppement d'activitÃ© commerciale	soumise	2025-06-12 19:24:50.002033	\N	2	\N	\N	Dossier complet - Approbation accordÃ©e	6.2	moyen	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
21	LCR-20251002-8352	50	consommation_generale	2006786.00	16	Achat de vÃ©hicule professionnel	en_examen	2025-06-21 05:59:32.398228	\N	\N	2844953.00	0.09	Dossier complet - Approbation accordÃ©e	6.6	moyen	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
22	LCR-20251002-1439	51	consommation_generale	3585207.00	32	Achat de vÃ©hicule professionnel	en_examen	2025-07-31 01:05:55.448039	2025-08-16 16:36:18.166181	\N	\N	0.08	Revenus insuffisants pour le montant demandÃ©	6.9	moyen	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
23	LCR-20251002-5664	52	consommation_generale	3656640.00	24	Achat de vÃ©hicule professionnel	approuvee	2025-09-24 01:51:06.12193	2025-09-12 18:08:58.423044	2	1629329.00	\N	Documents complÃ©mentaires requis	6.3	moyen	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
24	LCR-20251002-5948	56	investissement	1606552.00	26	DÃ©veloppement d'activitÃ© commerciale	soumise	2025-07-23 15:53:11.749871	2025-10-02 06:46:28.08739	\N	\N	0.07	Revenus insuffisants pour le montant demandÃ©	7.0	moyen	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
25	LCR-20251002-5055	63	investissement	3639865.00	17	Travaux de rÃ©novation immobiliÃ¨re	soumise	2025-08-07 12:25:49.166388	2025-09-02 18:29:01.242301	\N	1600244.00	0.07	Documents complÃ©mentaires requis	7.0	moyen	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
26	LCR-20251002-9659	66	investissement	1590400.00	34	Achat de vÃ©hicule professionnel	en_examen	2025-07-27 02:36:34.25995	\N	2	\N	0.06	Dossier complet - Approbation accordÃ©e	7.1	moyen	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
27	LCR-20251002-9829	68	consommation_generale	2610680.00	16	DÃ©veloppement d'activitÃ© commerciale	soumise	2025-08-20 15:24:46.962512	2025-09-06 02:13:20.95794	2	1896679.00	\N	Revenus insuffisants pour le montant demandÃ©	6.3	moyen	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
28	LCR-20251002-2608	69	investissement	1207517.00	29	Achat de vÃ©hicule professionnel	rejetee	2025-08-08 23:14:05.513904	2025-09-29 10:26:45.56466	\N	\N	\N	Dossier complet - Approbation accordÃ©e	6.7	moyen	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
29	LCR-20251002-7314	70	consommation_generale	1333737.00	20	Investissement dans Ã©quipements professionnels	en_examen	2025-06-07 07:37:15.038013	\N	2	\N	\N	Revenus insuffisants pour le montant demandÃ©	5.2	moyen	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
30	LCR-20251002-3920	81	consommation_generale	1537120.00	27	Travaux de rÃ©novation immobiliÃ¨re	soumise	2025-07-27 07:03:21.41427	\N	\N	\N	0.09	Dossier complet - Approbation accordÃ©e	5.3	moyen	2025-10-02 08:01:52.919978	2025-10-02 08:01:52.919978	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
31	LCR-20251008-7794	2	consommation_generale	3498617.00	19	Travaux de rÃ©novation immobiliÃ¨re	en_examen	2025-09-20 02:26:38.520507	\N	\N	3197053.00	\N	Documents complÃ©mentaires requis	8.9	tres_bas	2025-10-08 00:28:38.263517	2025-10-08 00:28:38.263517	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
32	LCR-20251008-8547	27	investissement	2708059.00	21	Travaux de rÃ©novation immobiliÃ¨re	en_examen	2025-10-03 04:51:23.788321	2025-09-09 22:57:05.942293	2	\N	0.08	Documents complÃ©mentaires requis	8.1	bas	2025-10-08 00:28:38.263517	2025-10-08 00:28:38.263517	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
33	LCR-20251008-4388	28	investissement	1219208.00	29	Travaux de rÃ©novation immobiliÃ¨re	rejetee	2025-08-05 15:30:24.276962	2025-09-09 15:35:11.126341	2	\N	\N	Revenus insuffisants pour le montant demandÃ©	8.7	tres_bas	2025-10-08 00:28:38.263517	2025-10-08 00:28:38.263517	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
34	LCR-20251008-9465	32	consommation_generale	3486448.00	13	DÃ©veloppement d'activitÃ© commerciale	en_examen	2025-06-17 11:52:49.816235	2025-08-30 17:33:00.11932	2	2784540.00	\N	Dossier complet - Approbation accordÃ©e	6.8	moyen	2025-10-08 00:28:38.263517	2025-10-08 00:28:38.263517	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
35	LCR-20251008-3684	42	consommation_generale	2525553.00	15	Achat de vÃ©hicule professionnel	soumise	2025-07-23 17:50:34.996666	2025-09-19 13:31:43.44954	\N	1007362.00	0.09	Documents complÃ©mentaires requis	6.8	moyen	2025-10-08 00:28:38.263517	2025-10-08 00:28:38.263517	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
36	LCR-20251008-2006	44	consommation_generale	1556838.00	24	Travaux de rÃ©novation immobiliÃ¨re	approuvee	2025-09-23 07:09:30.012684	2025-08-21 10:00:07.733562	\N	\N	0.09	En cours d'analyse par le comitÃ©	6.7	moyen	2025-10-08 00:28:38.263517	2025-10-08 00:28:38.263517	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
37	LCR-20251008-9371	46	investissement	3544695.00	28	Travaux de rÃ©novation immobiliÃ¨re	en_examen	2025-06-22 13:25:17.321523	\N	2	\N	0.06	Revenus insuffisants pour le montant demandÃ©	7.1	moyen	2025-10-08 00:28:38.263517	2025-10-08 00:28:38.263517	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
38	LCR-20251008-3318	54	investissement	2433948.00	28	Achat de vÃ©hicule professionnel	soumise	2025-09-16 09:52:54.371365	2025-09-30 21:13:28.60516	2	\N	\N	Dossier complet - Approbation accordÃ©e	6.9	moyen	2025-10-08 00:28:38.263517	2025-10-08 00:28:38.263517	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
39	LCR-20251008-3077	59	consommation_generale	1434110.00	14	Achat de vÃ©hicule professionnel	approuvee	2025-08-25 11:20:01.525595	2025-10-04 21:55:12.542468	\N	1954232.00	0.08	Revenus insuffisants pour le montant demandÃ©	6.4	moyen	2025-10-08 00:28:38.263517	2025-10-08 00:28:38.263517	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
40	LCR-20251008-5234	60	consommation_generale	3566234.00	21	Travaux de rÃ©novation immobiliÃ¨re	en_examen	2025-09-07 05:30:32.761455	\N	2	2663058.00	\N	Dossier complet - Approbation accordÃ©e	6.9	moyen	2025-10-08 00:28:38.263517	2025-10-08 00:28:38.263517	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
41	LCR-20251008-4234	63	consommation_generale	3146412.00	31	Travaux de rÃ©novation immobiliÃ¨re	en_examen	2025-06-20 10:49:23.737352	2025-09-14 01:09:01.519737	2	\N	\N	Documents complÃ©mentaires requis	7.0	moyen	2025-10-08 00:28:38.263517	2025-10-08 00:28:38.263517	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
42	LCR-20251008-4686	65	investissement	3220888.00	18	Travaux de rÃ©novation immobiliÃ¨re	en_examen	2025-09-28 19:25:30.397671	2025-09-07 01:11:22.611588	2	2701886.00	0.08	Documents complÃ©mentaires requis	6.8	moyen	2025-10-08 00:28:38.263517	2025-10-08 00:28:38.263517	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
43	LCR-20251008-0023	66	investissement	2090289.00	29	Travaux de rÃ©novation immobiliÃ¨re	soumise	2025-09-09 06:53:57.360107	2025-09-20 00:00:27.888968	2	1914520.00	0.07	Revenus insuffisants pour le montant demandÃ©	7.1	moyen	2025-10-08 00:28:38.263517	2025-10-08 00:28:38.263517	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
44	LCR-20251008-6971	67	consommation_generale	2998539.00	25	Achat de vÃ©hicule professionnel	soumise	2025-10-03 12:44:50.970398	2025-09-12 21:59:17.577746	2	\N	\N	Documents complÃ©mentaires requis	6.9	moyen	2025-10-08 00:28:38.263517	2025-10-08 00:28:38.263517	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
45	LCR-20251008-0776	68	consommation_generale	1328858.00	19	Travaux de rÃ©novation immobiliÃ¨re	en_examen	2025-08-31 15:01:01.921241	\N	2	1811213.00	0.06	Revenus insuffisants pour le montant demandÃ©	6.3	moyen	2025-10-08 00:28:38.263517	2025-10-08 00:28:38.263517	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
46	LCR-20251008-7077	69	investissement	1212253.00	27	Investissement dans Ã©quipements professionnels	approuvee	2025-08-24 21:07:38.035032	2025-08-23 17:07:45.769192	2	1065289.00	0.07	Dossier complet - Approbation accordÃ©e	6.7	moyen	2025-10-08 00:28:38.263517	2025-10-08 00:28:38.263517	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
47	LCR-20251008-3392	70	investissement	1277929.00	21	Achat de vÃ©hicule professionnel	approuvee	2025-08-29 04:11:49.055436	\N	2	2026969.00	\N	Dossier complet - Approbation accordÃ©e	5.2	moyen	2025-10-08 00:28:38.263517	2025-10-08 00:28:38.263517	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
48	LCR-20251008-0789	15	investissement	2530840.00	12	DÃ©veloppement d'activitÃ© commerciale	soumise	2025-08-31 13:22:31.16392	2025-09-15 18:02:02.644323	2	2737192.00	\N	Documents complÃ©mentaires requis	8.6	tres_bas	2025-10-08 00:28:38.263517	2025-10-08 00:28:38.263517	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
49	LCR-20251008-3859	16	investissement	1318384.00	17	DÃ©veloppement d'activitÃ© commerciale	en_examen	2025-08-25 07:17:11.136442	2025-08-25 00:36:17.432215	\N	\N	0.09	Dossier complet - Approbation accordÃ©e	8.2	bas	2025-10-08 00:28:38.263517	2025-10-08 00:28:38.263517	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
50	LCR-20251008-4903	18	investissement	2411173.00	26	Achat de vÃ©hicule professionnel	approuvee	2025-09-02 23:57:45.707295	\N	2	\N	\N	Revenus insuffisants pour le montant demandÃ©	8.5	bas	2025-10-08 00:28:38.263517	2025-10-08 00:28:38.263517	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
51	LCR-20251008-1026	19	investissement	1516285.00	17	DÃ©veloppement d'activitÃ© commerciale	en_examen	2025-10-04 13:45:55.751311	2025-08-18 17:02:06.355119	2	2586696.00	0.09	Dossier complet - Approbation accordÃ©e	8.1	bas	2025-10-08 00:28:38.263517	2025-10-08 00:28:38.263517	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
52	LCR-20251008-3273	75	consommation_generale	1747203.00	35	Achat de vÃ©hicule professionnel	approuvee	2025-09-27 06:29:41.509573	2025-09-14 02:19:13.947438	\N	2101914.00	\N	Revenus insuffisants pour le montant demandÃ©	5.0	moyen	2025-10-08 00:28:38.263517	2025-10-08 00:28:38.263517	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
53	LCR-20251008-7069	20	investissement	3182954.00	27	Travaux de rÃ©novation immobiliÃ¨re	soumise	2025-07-05 10:14:06.715243	2025-08-28 18:01:41.096594	2	2474929.00	0.08	Dossier complet - Approbation accordÃ©e	8.8	tres_bas	2025-10-08 00:28:38.263517	2025-10-08 00:28:38.263517	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
54	LCR-20251008-3029	22	consommation_generale	3424366.00	28	DÃ©veloppement d'activitÃ© commerciale	soumise	2025-06-24 06:05:07.191389	2025-08-14 07:28:20.741369	2	3132358.00	\N	Documents complÃ©mentaires requis	8.3	bas	2025-10-08 00:28:38.263517	2025-10-08 00:28:38.263517	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
55	LCR-20251008-7812	4	consommation_generale	2232299.00	17	Travaux de rÃ©novation immobiliÃ¨re	soumise	2025-07-18 10:44:22.866097	2025-08-17 16:25:06.417932	2	\N	\N	Documents complÃ©mentaires requis	8.7	tres_bas	2025-10-08 00:28:38.263517	2025-10-08 00:28:38.263517	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
56	LCR-20251008-1837	7	consommation_generale	1080353.00	26	DÃ©veloppement d'activitÃ© commerciale	en_examen	2025-09-05 23:24:04.258381	\N	2	\N	\N	Dossier complet - Approbation accordÃ©e	8.8	tres_bas	2025-10-08 00:28:38.263517	2025-10-08 00:28:38.263517	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
57	LCR-20251008-9576	8	consommation_generale	1972219.00	24	Travaux de rÃ©novation immobiliÃ¨re	en_examen	2025-08-31 05:42:13.416829	2025-09-17 06:58:21.505607	2	1098441.00	0.09	Dossier complet - Approbation accordÃ©e	8.4	bas	2025-10-08 00:28:38.263517	2025-10-08 00:28:38.263517	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
58	LCR-20251008-0696	11	consommation_generale	2530957.00	14	DÃ©veloppement d'activitÃ© commerciale	soumise	2025-09-16 08:54:29.490477	2025-09-28 21:54:15.595335	2	\N	0.09	Revenus insuffisants pour le montant demandÃ©	8.9	tres_bas	2025-10-08 00:28:38.263517	2025-10-08 00:28:38.263517	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
59	LCR-20251008-4937	81	investissement	3058043.00	25	Travaux de rÃ©novation immobiliÃ¨re	en_examen	2025-07-15 23:46:26.332527	2025-08-10 07:50:02.712981	\N	2688598.00	\N	Dossier complet - Approbation accordÃ©e	5.3	moyen	2025-10-08 00:28:38.263517	2025-10-08 00:28:38.263517	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
60	LCR-20251008-9042	84	consommation_generale	2947259.00	21	Achat de vÃ©hicule professionnel	en_examen	2025-09-26 19:53:19.560887	2025-08-10 15:10:13.745035	2	\N	0.09	En cours d'analyse par le comitÃ©	5.4	moyen	2025-10-08 00:28:38.263517	2025-10-08 00:28:38.263517	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
61	LCR-20251008-6138	2	consommation_generale	2991139.00	16	DÃ©veloppement d'activitÃ© commerciale	soumise	2025-09-02 07:05:43.68481	2025-10-07 07:06:43.708401	\N	3120111.00	\N	Revenus insuffisants pour le montant demandÃ©	8.9	tres_bas	2025-10-08 13:10:20.142122	2025-10-08 13:10:20.142122	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
62	LCR-20251008-4312	13	consommation_generale	3462823.00	29	Investissement dans Ã©quipements professionnels	en_examen	2025-09-27 18:46:57.699151	2025-09-27 01:30:34.925012	2	\N	\N	Revenus insuffisants pour le montant demandÃ©	8.0	bas	2025-10-08 13:10:20.142122	2025-10-08 13:10:20.142122	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
63	LCR-20251008-4765	25	consommation_generale	3547302.00	19	Achat de vÃ©hicule professionnel	soumise	2025-09-26 07:04:57.55764	2025-10-07 09:44:49.583044	2	2500270.00	\N	Revenus insuffisants pour le montant demandÃ©	8.3	bas	2025-10-08 13:10:20.142122	2025-10-08 13:10:20.142122	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
64	LCR-20251008-6633	26	investissement	1644954.00	17	Investissement dans Ã©quipements professionnels	approuvee	2025-07-29 22:12:01.932267	2025-08-28 12:36:48.895287	\N	2765424.00	0.06	Documents complÃ©mentaires requis	8.2	bas	2025-10-08 13:10:20.142122	2025-10-08 13:10:20.142122	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
65	LCR-20251008-5583	27	consommation_generale	3058650.00	26	Travaux de rÃ©novation immobiliÃ¨re	soumise	2025-07-06 14:36:50.305751	2025-09-18 06:43:20.165246	\N	1970681.00	\N	Revenus insuffisants pour le montant demandÃ©	8.1	bas	2025-10-08 13:10:20.142122	2025-10-08 13:10:20.142122	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
66	LCR-20251008-4494	43	investissement	3538416.00	33	Achat de vÃ©hicule professionnel	rejetee	2025-07-30 23:44:32.777877	2025-09-14 20:56:22.708326	2	\N	0.10	En cours d'analyse par le comitÃ©	6.5	moyen	2025-10-08 13:10:20.142122	2025-10-08 13:10:20.142122	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
67	LCR-20251008-5532	44	investissement	2836077.00	24	DÃ©veloppement d'activitÃ© commerciale	en_examen	2025-06-22 07:59:53.594291	\N	2	\N	\N	Dossier complet - Approbation accordÃ©e	6.7	moyen	2025-10-08 13:10:20.142122	2025-10-08 13:10:20.142122	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
68	LCR-20251008-5866	45	consommation_generale	1748373.00	26	Travaux de rÃ©novation immobiliÃ¨re	soumise	2025-09-01 19:45:04.37612	2025-08-27 21:53:49.243226	\N	\N	0.07	Revenus insuffisants pour le montant demandÃ©	6.4	moyen	2025-10-08 13:10:20.142122	2025-10-08 13:10:20.142122	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
69	LCR-20251008-6363	47	consommation_generale	2735674.00	32	Travaux de rÃ©novation immobiliÃ¨re	rejetee	2025-07-17 22:56:28.674727	2025-09-19 16:57:09.001605	\N	1073122.00	\N	Documents complÃ©mentaires requis	6.5	moyen	2025-10-08 13:10:20.142122	2025-10-08 13:10:20.142122	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
70	LCR-20251008-5582	1	consommation_generale	3166699.00	18	Investissement dans Ã©quipements professionnels	approuvee	2025-08-23 22:04:04.061257	2025-08-12 07:41:19.935492	2	1072364.00	0.09	Revenus insuffisants pour le montant demandÃ©	6.5	moyen	2025-10-08 13:10:20.142122	2025-10-08 13:10:20.142122	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
71	LCR-20251008-5306	3	investissement	2229648.00	27	Achat de vÃ©hicule professionnel	en_examen	2025-07-17 17:32:46.662943	2025-09-10 11:36:44.340476	\N	1814183.00	0.10	Revenus insuffisants pour le montant demandÃ©	8.5	bas	2025-10-08 13:10:20.142122	2025-10-08 13:10:20.142122	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
72	LCR-20251008-1915	49	consommation_generale	3835022.00	22	DÃ©veloppement d'activitÃ© commerciale	en_examen	2025-07-09 15:48:01.631725	\N	2	1350822.00	0.08	Revenus insuffisants pour le montant demandÃ©	6.2	moyen	2025-10-08 13:10:20.142122	2025-10-08 13:10:20.142122	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
73	LCR-20251008-6943	52	investissement	1345121.00	26	Travaux de rÃ©novation immobiliÃ¨re	soumise	2025-08-05 15:10:09.707371	2025-08-31 12:05:04.201422	2	981964.00	0.06	Revenus insuffisants pour le montant demandÃ©	6.3	moyen	2025-10-08 13:10:20.142122	2025-10-08 13:10:20.142122	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
74	LCR-20251008-4240	53	investissement	3016636.00	18	Achat de vÃ©hicule professionnel	soumise	2025-07-19 01:07:46.48108	2025-10-03 18:29:05.121332	2	1032673.00	\N	Revenus insuffisants pour le montant demandÃ©	6.7	moyen	2025-10-08 13:10:20.142122	2025-10-08 13:10:20.142122	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
75	LCR-20251008-2505	55	consommation_generale	3647873.00	19	Travaux de rÃ©novation immobiliÃ¨re	approuvee	2025-07-27 10:04:53.853322	2025-09-05 23:32:24.101517	2	\N	0.07	Dossier complet - Approbation accordÃ©e	6.2	moyen	2025-10-08 13:10:20.142122	2025-10-08 13:10:20.142122	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
76	LCR-20251008-9107	58	consommation_generale	2352671.00	27	Achat de vÃ©hicule professionnel	soumise	2025-08-10 09:32:42.163941	\N	\N	3226153.00	\N	En cours d'analyse par le comitÃ©	6.8	moyen	2025-10-08 13:10:20.142122	2025-10-08 13:10:20.142122	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
77	LCR-20251008-8919	60	consommation_generale	2462092.00	28	DÃ©veloppement d'activitÃ© commerciale	rejetee	2025-09-17 11:21:46.120983	2025-09-17 14:10:51.87627	2	\N	\N	Revenus insuffisants pour le montant demandÃ©	6.9	moyen	2025-10-08 13:10:20.142122	2025-10-08 13:10:20.142122	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
78	LCR-20251008-0075	63	investissement	3029411.00	27	Travaux de rÃ©novation immobiliÃ¨re	approuvee	2025-10-02 06:47:05.229624	2025-09-01 13:42:06.831561	\N	2048117.00	0.07	Dossier complet - Approbation accordÃ©e	7.0	moyen	2025-10-08 13:10:20.142122	2025-10-08 13:10:20.142122	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
79	LCR-20251008-7223	64	consommation_generale	3924921.00	23	DÃ©veloppement d'activitÃ© commerciale	rejetee	2025-08-03 20:50:17.526185	\N	2	\N	\N	Documents complÃ©mentaires requis	6.6	moyen	2025-10-08 13:10:20.142122	2025-10-08 13:10:20.142122	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
80	LCR-20251008-0877	67	investissement	3878757.00	29	DÃ©veloppement d'activitÃ© commerciale	en_examen	2025-09-05 05:43:33.007388	2025-09-18 22:38:57.324611	2	\N	\N	Revenus insuffisants pour le montant demandÃ©	6.9	moyen	2025-10-08 13:10:20.142122	2025-10-08 13:10:20.142122	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
81	LCR-20251008-3454	69	investissement	1050919.00	29	DÃ©veloppement d'activitÃ© commerciale	soumise	2025-09-20 07:47:47.628068	\N	2	\N	0.09	En cours d'analyse par le comitÃ©	6.7	moyen	2025-10-08 13:10:20.142122	2025-10-08 13:10:20.142122	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
82	LCR-20251008-3590	17	investissement	1373130.00	14	DÃ©veloppement d'activitÃ© commerciale	en_examen	2025-06-12 12:18:48.603757	2025-09-25 20:43:38.43856	2	\N	\N	En cours d'analyse par le comitÃ©	8.0	bas	2025-10-08 13:10:20.142122	2025-10-08 13:10:20.142122	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
83	LCR-20251008-7715	19	consommation_generale	1982092.00	25	Travaux de rÃ©novation immobiliÃ¨re	soumise	2025-07-22 07:26:51.91899	2025-10-07 22:33:58.015896	2	\N	\N	Revenus insuffisants pour le montant demandÃ©	8.1	bas	2025-10-08 13:10:20.142122	2025-10-08 13:10:20.142122	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
84	LCR-20251008-2263	75	investissement	1036910.00	23	DÃ©veloppement d'activitÃ© commerciale	soumise	2025-08-25 07:24:39.286688	2025-09-05 04:54:09.676244	2	2243987.00	0.08	Revenus insuffisants pour le montant demandÃ©	5.0	moyen	2025-10-08 13:10:20.142122	2025-10-08 13:10:20.142122	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
85	LCR-20251008-9033	23	consommation_generale	3565693.00	23	DÃ©veloppement d'activitÃ© commerciale	soumise	2025-09-24 14:54:15.272837	\N	2	\N	\N	Dossier complet - Approbation accordÃ©e	8.5	bas	2025-10-08 13:10:20.142122	2025-10-08 13:10:20.142122	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
86	LCR-20251008-0681	6	investissement	3051519.00	20	DÃ©veloppement d'activitÃ© commerciale	soumise	2025-08-28 04:42:35.421295	2025-08-30 21:21:13.084139	2	\N	\N	Revenus insuffisants pour le montant demandÃ©	8.6	bas	2025-10-08 13:10:20.142122	2025-10-08 13:10:20.142122	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
87	LCR-20251008-9739	34	consommation_generale	1731909.00	18	Achat de vÃ©hicule professionnel	en_examen	2025-07-25 06:38:53.381928	2025-08-11 10:53:37.559617	2	3193808.00	0.08	Revenus insuffisants pour le montant demandÃ©	6.9	moyen	2025-10-08 13:10:20.142122	2025-10-08 13:10:20.142122	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
88	LCR-20251008-5787	39	consommation_generale	3324967.00	17	Achat de vÃ©hicule professionnel	en_examen	2025-07-10 03:36:26.294207	\N	\N	\N	0.07	Documents complÃ©mentaires requis	6.6	moyen	2025-10-08 13:10:20.142122	2025-10-08 13:10:20.142122	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
89	LCR-20251008-3977	40	investissement	2329649.00	18	DÃ©veloppement d'activitÃ© commerciale	approuvee	2025-07-01 00:43:57.745567	\N	2	1753237.00	0.07	Documents complÃ©mentaires requis	7.0	moyen	2025-10-08 13:10:20.142122	2025-10-08 13:10:20.142122	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
90	LCR-20251008-2957	79	investissement	1959232.00	32	DÃ©veloppement d'activitÃ© commerciale	soumise	2025-08-05 19:57:54.504276	\N	\N	\N	0.07	Revenus insuffisants pour le montant demandÃ©	5.0	moyen	2025-10-08 13:10:20.142122	2025-10-08 13:10:20.142122	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
91	LCR-20251009-0001	1	consommation_generale	2000000.00	12	jhryehrherehr	draft	2025-10-09 16:28:27.559356	\N	\N	\N	\N	\N	6.5	moyen	2025-10-09 16:28:27.559356	2025-10-09 16:30:48.565194	jp.obame@email.ga	\N	{"email": "jp.obame@email.ga", "phone": "077111001", "address": "Glass, Libreville", "company": "Total Gabon", "fullName": "Jean-Pierre OBAME", "dependents": 0, "profession": "IngÃ©nieur PÃ©trole", "maritalStatus": "celibataire"}	{"purpose": "jhryehrherehr", "duration": 12, "preferredRate": 10.5, "requestedAmount": 2000000, "repaymentFrequency": "mensuel"}	{"assets": [], "otherIncomes": [], "existingLoans": [], "monthlyIncome": 2500000, "monthlyExpenses": 0, "employmentDetails": {"employer": "ventis", "position": "chef projet", "netSalary": 2500000, "seniority": 10, "grossSalary": 3250000, "contractType": "CDI"}}	{"incomeProof": true, "businessPlan": false, "identityProof": true, "propertyDeeds": false, "bankStatements": true, "guarantorDocuments": false, "employmentCertificate": true}	{"riskLevel": "faible", "suggestedRate": 10.5, "totalInterest": 132376, "monthlyPayment": 177698, "calculatedScore": 8, "debtToIncomeRatio": 7.107919999999999, "recommendedAmount": 2000000, "approvalProbability": 0.85}	\N	\N	\N	1
92	LCR-20251009-0002	1	consommation_generale	2000000.00	12	jhryehrherehr	submitted	2025-10-09 16:30:18.783359	\N	\N	\N	\N	\N	6.5	moyen	2025-10-09 16:30:18.783359	2025-10-09 16:30:18.783359	jp.obame@email.ga	\N	{"email": "jp.obame@email.ga", "phone": "077111001", "address": "Glass, Libreville", "company": "Total Gabon", "fullName": "Jean-Pierre OBAME", "dependents": 0, "profession": "IngÃ©nieur PÃ©trole", "maritalStatus": "celibataire"}	{"purpose": "jhryehrherehr", "duration": 12, "guarantors": [], "preferredRate": 10.5, "requestedAmount": 2000000, "repaymentFrequency": "mensuel"}	{"assets": [], "otherIncomes": [], "existingLoans": [], "monthlyIncome": 2500000, "monthlyExpenses": 0, "employmentDetails": {"employer": "ventis", "position": "chef projet", "netSalary": 2500000, "seniority": 10, "grossSalary": 3250000, "contractType": "CDI"}}	{"incomeProof": true, "businessPlan": false, "identityProof": true, "propertyDeeds": false, "bankStatements": true, "guarantorDocuments": false, "employmentCertificate": true}	{"riskLevel": "faible", "suggestedRate": 10.5, "totalInterest": 132376, "monthlyPayment": 177698, "calculatedScore": 8, "debtToIncomeRatio": 7.107919999999999, "recommendedAmount": 2000000, "approvalProbability": 0.85}	\N	\N	\N	1
\.


--
-- Data for Name: demandes_credit_longues_comments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.demandes_credit_longues_comments (id, long_credit_request_id, author_name, author_id, comment_type, content, is_private, created_at) FROM stdin;
\.


--
-- Data for Name: demandes_credit_longues_documents; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.demandes_credit_longues_documents (id, long_credit_request_id, document_type, document_name, original_filename, file_path, file_size, mime_type, is_required, uploaded_by, checksum, uploaded_at) FROM stdin;
4b1a7bb0-d1c4-4d00-9276-04ea101354d4	92	identityProof	Pièce d'identité	simbot_devis_auto_1759853695416.pdf	uploads\\credit-documents\\86991200-bc82-4133-afac-bc32efccdce5-simbot_devis_auto_1759853695416.pdf	14535	application/pdf	t	\N	d398b626c9144cd9cc7c2a8e3133dc0be444ceb476949726dd810e81fad43669	2025-10-09 16:30:18.900739
33602a37-7cb7-427f-ac72-39c616c1d63d	92	incomeProof	Justificatif de revenus	Tableau d'amortissement - Jean-Pierre OBAME.pdf	uploads\\credit-documents\\962a5c58-6389-484a-b4f2-644a27e4685e-Tableau d'amortissement - Jean-Pierre OBAME.pdf	362556	application/pdf	t	\N	ec8f1097bb476289b7b909652cad342d3114a35a806235d5f75f291a2fe3f10b	2025-10-09 16:30:18.987032
e942f147-aa91-420a-abc5-00e1f963affd	92	bankStatements	Relevés bancaires	CamScanner 01-10-2025 16.02.pdf	uploads\\credit-documents\\ba391fad-9b09-47ce-b8e5-bac5d169d160-CamScanner 01-10-2025 16.02.pdf	296190	application/pdf	f	\N	0fc0dcee4248d8ebcf008c619e3622dcc6897ff4fe4817b95dbfa5ba505a4a78	2025-10-09 16:30:18.991965
58315cb9-212d-4ca1-b126-4b9af1f5df19	92	employmentCertificate	Attestation de travail	CamScanner 01-10-2025 16.03.pdf	uploads\\credit-documents\\834461d5-58ae-4b64-8038-b9eab540cc4d-CamScanner 01-10-2025 16.03.pdf	290770	application/pdf	t	\N	399aca44ba5721effe2bea332f445326b8fc650c2de5b39bcc2e6983a73d4180	2025-10-09 16:30:19.000038
\.


--
-- Data for Name: demandes_credit_longues_history; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.demandes_credit_longues_history (id, long_credit_request_id, action, previous_status, new_status, agent_name, agent_id, comment, action_date) FROM stdin;
9452358d-e860-4969-a1de-f0b5620cd472	91	Brouillon créé	\N	\N	Client	1	Demande initiale	2025-10-09 16:28:27.591455
12f58401-a4b4-48d0-99bd-45c570aec50a	92	Brouillon créé	\N	\N	Client	1	Demande initiale	2025-10-09 16:30:18.788827
d152799e-fbe2-4beb-89be-12a2e772909d	92	Document uploadé: Pièce d'identité	\N	\N	Client	\N	Fichier: simbot_devis_auto_1759853695416.pdf	2025-10-09 16:30:18.936959
586a32ab-af98-41b3-9455-6121b2b964b0	92	Document uploadé: Justificatif de revenus	\N	\N	Client	\N	Fichier: Tableau d'amortissement - Jean-Pierre OBAME.pdf	2025-10-09 16:30:19.003878
9cd122f8-d8d6-4a2b-a0ed-47f00fd3e3aa	92	Document uploadé: Relevés bancaires	\N	\N	Client	\N	Fichier: CamScanner 01-10-2025 16.02.pdf	2025-10-09 16:30:19.010267
35d74206-11e6-4c9c-bdfc-89c091eea6c5	92	Document uploadé: Attestation de travail	\N	\N	Client	\N	Fichier: CamScanner 01-10-2025 16.03.pdf	2025-10-09 16:30:19.016763
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
136	2	2	1643619.83	2025-05-21 11:11:10.958657	2025-05-21 11:11:10.958657	0	a_temps	0.00	2025-10-08 00:28:38.178512
137	4	4	691542.75	2025-10-11 22:37:27.230529	2025-10-11 22:37:27.230529	0	a_temps	0.00	2025-10-08 00:28:38.178512
138	5	5	1247969.21	2025-02-26 20:09:49.416982	2025-02-26 20:09:49.416982	0	a_temps	0.00	2025-10-08 00:28:38.178512
139	8	8	750147.64	2025-06-20 22:49:13.906371	2025-06-20 22:49:13.906371	0	a_temps	0.00	2025-10-08 00:28:38.178512
140	9	9	297633.45	2025-04-26 13:31:05.74943	2025-04-26 13:31:05.74943	0	a_temps	0.00	2025-10-08 00:28:38.178512
141	11	11	581233.36	2024-12-06 09:34:24.688008	2024-12-06 09:34:24.688008	0	a_temps	0.00	2025-10-08 00:28:38.178512
142	13	13	704949.21	2025-04-21 16:20:04.641186	2025-04-21 16:20:04.641186	0	a_temps	0.00	2025-10-08 00:28:38.178512
143	13	13	752042.70	2025-05-21 16:20:04.641186	2025-05-21 16:20:04.641186	0	a_temps	0.00	2025-10-08 00:28:38.178512
144	13	13	695293.96	2025-06-20 16:20:04.641186	2025-06-20 16:20:04.641186	0	a_temps	0.00	2025-10-08 00:28:38.178512
145	14	14	648485.16	2025-07-11 18:38:40.037667	2025-07-11 18:38:40.037667	0	a_temps	0.00	2025-10-08 00:28:38.178512
146	14	14	688092.82	2025-08-10 18:38:40.037667	2025-08-10 18:38:40.037667	0	a_temps	0.00	2025-10-08 00:28:38.178512
147	14	14	638341.99	2025-09-09 18:38:40.037667	2025-09-09 18:38:40.037667	0	a_temps	0.00	2025-10-08 00:28:38.178512
148	15	15	1150685.54	2025-07-06 11:34:28.679069	2025-07-06 11:34:28.679069	0	a_temps	0.00	2025-10-08 00:28:38.178512
149	16	16	1182714.79	2025-04-28 15:43:21.25365	2025-04-28 15:43:21.25365	0	a_temps	0.00	2025-10-08 00:28:38.178512
150	17	17	1502518.64	2025-10-11 23:24:56.371407	2025-10-11 23:24:56.371407	0	a_temps	0.00	2025-10-08 00:28:38.178512
151	19	19	258446.81	2025-09-08 02:56:52.774093	2025-09-08 02:56:52.774093	0	a_temps	0.00	2025-10-08 00:28:38.178512
152	19	19	253436.37	2025-10-08 02:56:52.774093	2025-10-08 02:56:52.774093	0	a_temps	0.00	2025-10-08 00:28:38.178512
153	19	19	299551.58	2025-11-07 02:56:52.774093	2025-11-07 02:56:52.774093	0	a_temps	0.00	2025-10-08 00:28:38.178512
154	20	20	1913443.69	2025-10-27 18:53:28.85246	2025-10-27 18:53:28.85246	0	a_temps	0.00	2025-10-08 00:28:38.178512
155	21	21	347037.27	2025-11-27 22:38:47.838063	2025-10-26 22:38:47.838063	32	en_retard	16000.00	2025-10-08 00:28:38.178512
156	22	22	1438946.58	2024-11-12 17:49:08.792501	2024-11-12 17:49:08.792501	0	a_temps	0.00	2025-10-08 00:28:38.178512
157	23	23	729307.26	2025-03-11 20:42:38.659398	2025-03-11 20:42:38.659398	0	a_temps	0.00	2025-10-08 00:28:38.178512
158	25	25	1292450.97	2025-01-14 23:16:49.089899	2025-01-14 23:16:49.089899	0	a_temps	0.00	2025-10-08 00:28:38.178512
159	27	27	604409.20	2025-03-15 01:12:03.980074	2025-03-15 01:12:03.980074	0	a_temps	0.00	2025-10-08 00:28:38.178512
160	29	29	634784.48	2025-03-25 11:48:49.360185	2025-03-25 11:48:49.360185	0	a_temps	0.00	2025-10-08 00:28:38.178512
161	46	31	245844.85	2025-10-16 10:37:59.911985	2025-10-16 10:37:59.911985	0	a_temps	0.00	2025-10-08 00:28:38.178512
162	46	31	236980.10	2025-11-15 10:37:59.911985	2025-11-15 10:37:59.911985	0	a_temps	0.00	2025-10-08 00:28:38.178512
163	47	32	308577.51	2025-10-17 00:08:00.483171	2025-10-17 00:08:00.483171	0	a_temps	0.00	2025-10-08 00:28:38.178512
164	47	32	261730.12	2025-11-16 00:08:00.483171	2025-11-16 00:08:00.483171	0	a_temps	0.00	2025-10-08 00:28:38.178512
165	48	33	0.00	2025-03-28 17:10:17.617682	2025-03-28 17:10:17.617682	59	manque	35000.00	2025-10-08 00:28:38.178512
166	48	33	0.00	2025-04-27 17:10:17.617682	2025-04-27 17:10:17.617682	51	manque	33000.00	2025-10-08 00:28:38.178512
167	48	33	0.00	2025-05-27 17:10:17.617682	2025-05-27 17:10:17.617682	82	manque	26500.00	2025-10-08 00:28:38.178512
168	49	34	301420.27	2025-02-06 20:04:53.324022	2025-02-06 20:04:53.324022	0	a_temps	0.00	2025-10-08 00:28:38.178512
169	49	34	311613.19	2025-03-08 20:04:53.324022	2025-03-08 20:04:53.324022	0	a_temps	0.00	2025-10-08 00:28:38.178512
170	50	35	0.00	2025-10-26 00:36:31.17746	2025-10-26 00:36:31.17746	36	manque	29500.00	2025-10-08 00:28:38.178512
171	51	36	715803.18	2025-03-11 15:55:56.901817	2025-03-11 15:55:56.901817	0	a_temps	0.00	2025-10-08 00:28:38.178512
172	55	40	282713.53	2025-09-19 10:54:15.038803	2025-09-19 10:54:15.038803	0	a_temps	0.00	2025-10-08 00:28:38.178512
173	55	40	263544.02	2025-10-19 10:54:15.038803	2025-10-19 10:54:15.038803	0	a_temps	0.00	2025-10-08 00:28:38.178512
174	56	41	485246.64	2025-03-25 18:35:10.193316	2025-03-25 18:35:10.193316	0	a_temps	0.00	2025-10-08 00:28:38.178512
175	57	42	274181.19	2025-03-20 01:13:00.04763	2025-03-20 01:13:00.04763	0	a_temps	0.00	2025-10-08 00:28:38.178512
176	57	42	261306.48	2025-04-19 01:13:00.04763	2025-04-19 01:13:00.04763	0	a_temps	0.00	2025-10-08 00:28:38.178512
177	58	43	354209.16	2025-10-04 22:38:02.02038	2025-10-04 22:38:02.02038	0	a_temps	0.00	2025-10-08 00:28:38.178512
178	60	45	212842.90	2025-09-22 04:47:51.503472	2025-09-22 04:47:51.503472	0	a_temps	0.00	2025-10-08 00:28:38.178512
179	60	45	203417.14	2025-10-22 04:47:51.503472	2025-10-22 04:47:51.503472	0	a_temps	0.00	2025-10-08 00:28:38.178512
180	61	46	305604.42	2025-04-03 22:04:03.690437	2025-04-03 22:04:03.690437	0	a_temps	0.00	2025-10-08 00:28:38.178512
181	61	46	304081.73	2025-05-03 22:04:03.690437	2025-05-03 22:04:03.690437	0	a_temps	0.00	2025-10-08 00:28:38.178512
182	62	47	471632.12	2025-03-27 05:45:20.949243	2025-03-27 05:45:20.949243	0	a_temps	0.00	2025-10-08 00:28:38.178512
183	64	49	415653.56	2025-02-25 08:38:00.742785	2025-02-25 08:38:00.742785	0	a_temps	0.00	2025-10-08 00:28:38.178512
184	65	50	276813.75	2025-02-28 08:34:46.822178	2025-02-28 08:34:46.822178	0	a_temps	0.00	2025-10-08 00:28:38.178512
185	66	51	177703.12	2025-02-27 11:35:45.589659	2025-02-27 11:35:45.589659	0	a_temps	0.00	2025-10-08 00:28:38.178512
186	66	51	172143.32	2025-03-29 11:35:45.589659	2025-03-29 11:35:45.589659	0	a_temps	0.00	2025-10-08 00:28:38.178512
187	67	52	244500.33	2025-09-30 02:01:20.405515	2025-09-28 02:01:20.405515	2	en_retard	1000.00	2025-10-08 00:28:38.178512
188	68	53	142028.75	2025-07-05 05:23:01.251111	2025-07-05 05:23:01.251111	0	a_temps	0.00	2025-10-08 00:28:38.178512
189	68	53	143892.04	2025-08-04 05:23:01.251111	2025-08-04 05:23:01.251111	0	a_temps	0.00	2025-10-08 00:28:38.178512
190	70	55	111984.93	2025-03-30 04:50:27.497469	2025-03-30 04:50:27.497469	0	a_temps	0.00	2025-10-08 00:28:38.178512
191	71	56	376365.85	2025-07-13 21:28:20.935285	2025-07-13 21:28:20.935285	0	a_temps	0.00	2025-10-08 00:28:38.178512
192	71	56	369168.85	2025-08-12 21:28:20.935285	2025-08-12 21:28:20.935285	0	a_temps	0.00	2025-10-08 00:28:38.178512
193	72	57	253779.53	2025-03-17 22:58:40.401315	2025-03-17 22:58:40.401315	0	a_temps	0.00	2025-10-08 00:28:38.178512
194	72	57	249620.14	2025-04-16 22:58:40.401315	2025-04-16 22:58:40.401315	0	a_temps	0.00	2025-10-08 00:28:38.178512
195	74	59	222626.11	2025-05-03 18:28:26.822464	2025-05-03 18:28:26.822464	0	a_temps	0.00	2025-10-08 00:28:38.178512
196	74	59	259594.50	2025-06-02 18:28:26.822464	2025-06-02 18:28:26.822464	0	a_temps	0.00	2025-10-08 00:28:38.178512
197	77	62	331440.33	2025-05-19 18:47:48.088537	2025-05-19 18:47:48.088537	0	a_temps	0.00	2025-10-08 00:28:38.178512
198	78	63	282503.10	2025-03-18 19:38:57.467382	2025-03-18 19:38:57.467382	0	a_temps	0.00	2025-10-08 00:28:38.178512
199	78	63	280867.54	2025-04-17 19:38:57.467382	2025-04-17 19:38:57.467382	0	a_temps	0.00	2025-10-08 00:28:38.178512
200	80	65	426528.26	2025-05-20 21:18:32.629696	2025-05-20 21:18:32.629696	0	a_temps	0.00	2025-10-08 00:28:38.178512
201	80	65	421105.28	2025-06-19 21:18:32.629696	2025-06-19 21:18:32.629696	0	a_temps	0.00	2025-10-08 00:28:38.178512
202	82	67	399152.30	2025-08-04 00:42:51.038809	2025-08-04 00:42:51.038809	0	a_temps	0.00	2025-10-08 00:28:38.178512
203	82	67	392019.46	2025-09-03 00:42:51.038809	2025-09-03 00:42:51.038809	0	a_temps	0.00	2025-10-08 00:28:38.178512
204	84	69	689189.77	2025-08-12 21:34:22.504549	2025-08-12 21:34:22.504549	0	a_temps	0.00	2025-10-08 00:28:38.178512
205	85	70	347208.17	2025-03-24 10:32:22.278869	2025-03-24 10:32:22.278869	0	a_temps	0.00	2025-10-08 00:28:38.178512
206	85	70	314423.77	2025-04-23 10:32:22.278869	2025-04-23 10:32:22.278869	0	a_temps	0.00	2025-10-08 00:28:38.178512
207	86	31	0.00	2025-09-03 07:05:38.262677	2025-09-03 07:05:38.262677	75	manque	28500.00	2025-10-08 00:28:38.178512
208	86	31	0.00	2025-10-03 07:05:38.262677	2025-10-03 07:05:38.262677	86	manque	24000.00	2025-10-08 00:28:38.178512
209	86	31	0.00	2025-11-02 07:05:38.262677	2025-11-02 07:05:38.262677	68	manque	41000.00	2025-10-08 00:28:38.178512
210	89	34	0.00	2025-10-30 13:23:31.605617	2025-10-30 13:23:31.605617	65	manque	29500.00	2025-10-08 00:28:38.178512
211	90	35	0.00	2025-07-08 21:34:27.390891	2025-07-08 21:34:27.390891	78	manque	15000.00	2025-10-08 00:28:38.178512
212	90	35	0.00	2025-08-07 21:34:27.390891	2025-08-07 21:34:27.390891	70	manque	35500.00	2025-10-08 00:28:38.178512
213	95	40	0.00	2025-10-17 16:04:54.002176	2025-10-17 16:04:54.002176	56	manque	33000.00	2025-10-08 00:28:38.178512
214	95	40	0.00	2025-11-16 16:04:54.002176	2025-11-16 16:04:54.002176	50	manque	19000.00	2025-10-08 00:28:38.178512
215	95	40	0.00	2025-12-16 16:04:54.002176	2025-12-16 16:04:54.002176	45	manque	38500.00	2025-10-08 00:28:38.178512
216	97	42	0.00	2025-07-17 08:39:51.394881	2025-07-17 08:39:51.394881	31	manque	39500.00	2025-10-08 00:28:38.178512
217	97	42	0.00	2025-08-16 08:39:51.394881	2025-08-16 08:39:51.394881	42	manque	20000.00	2025-10-08 00:28:38.178512
218	101	46	0.00	2025-08-12 18:20:11.759923	2025-08-12 18:20:11.759923	54	manque	41000.00	2025-10-08 00:28:38.178512
219	101	46	0.00	2025-09-11 18:20:11.759923	2025-09-11 18:20:11.759923	77	manque	41000.00	2025-10-08 00:28:38.178512
220	106	71	212459.96	2025-05-20 19:44:47.071897	2025-05-20 19:44:47.071897	0	a_temps	0.00	2025-10-08 00:28:38.178512
221	109	74	297463.42	2025-06-19 17:04:13.519471	2025-06-19 17:04:13.519471	0	a_temps	0.00	2025-10-08 00:28:38.178512
222	110	75	0.00	2025-10-03 09:56:08.78283	2025-10-03 09:56:08.78283	32	manque	43000.00	2025-10-08 00:28:38.178512
223	110	75	0.00	2025-11-02 09:56:08.78283	2025-11-02 09:56:08.78283	59	manque	23000.00	2025-10-08 00:28:38.178512
224	113	78	413292.23	2025-05-09 09:17:22.129783	2025-05-09 09:17:22.129783	0	a_temps	0.00	2025-10-08 00:28:38.178512
225	117	82	244070.83	2025-10-06 17:40:29.815255	2025-10-06 17:40:29.815255	0	a_temps	0.00	2025-10-08 00:28:38.178512
226	118	83	0.00	2025-05-06 01:54:51.113866	2025-05-06 01:54:51.113866	72	manque	34500.00	2025-10-08 00:28:38.178512
227	118	83	0.00	2025-06-05 01:54:51.113866	2025-06-05 01:54:51.113866	41	manque	18000.00	2025-10-08 00:28:38.178512
228	118	83	0.00	2025-07-05 01:54:51.113866	2025-07-05 01:54:51.113866	43	manque	31000.00	2025-10-08 00:28:38.178512
229	119	84	0.00	2025-10-06 23:50:07.204611	2025-10-06 23:50:07.204611	89	manque	41500.00	2025-10-08 00:28:38.178512
230	120	85	0.00	2025-07-10 00:34:19.986358	2025-07-10 00:34:19.986358	53	manque	38500.00	2025-10-08 00:28:38.178512
231	120	85	0.00	2025-08-09 00:34:19.986358	2025-08-09 00:34:19.986358	64	manque	43500.00	2025-10-08 00:28:38.178512
232	120	85	0.00	2025-09-08 00:34:19.986358	2025-09-08 00:34:19.986358	55	manque	16000.00	2025-10-08 00:28:38.178512
233	121	86	139417.71	2025-05-26 20:28:22.712225	2025-05-26 20:28:22.712225	0	a_temps	0.00	2025-10-08 00:28:38.178512
234	123	88	349566.86	2025-05-29 16:15:26.080859	2025-05-29 16:15:26.080859	0	a_temps	0.00	2025-10-08 00:28:38.178512
235	126	75	0.00	2025-10-16 01:17:08.112315	2025-10-16 01:17:08.112315	84	manque	43500.00	2025-10-08 00:28:38.178512
236	126	75	0.00	2025-11-15 01:17:08.112315	2025-11-15 01:17:08.112315	42	manque	36000.00	2025-10-08 00:28:38.178512
237	127	76	0.00	2025-09-14 20:57:07.072737	2025-09-14 20:57:07.072737	85	manque	26000.00	2025-10-08 00:28:38.178512
238	127	76	0.00	2025-10-14 20:57:07.072737	2025-10-14 20:57:07.072737	71	manque	19500.00	2025-10-08 00:28:38.178512
239	127	76	0.00	2025-11-13 20:57:07.072737	2025-11-13 20:57:07.072737	40	manque	27500.00	2025-10-08 00:28:38.178512
240	128	77	0.00	2025-10-31 10:04:35.604583	2025-10-31 10:04:35.604583	62	manque	35000.00	2025-10-08 00:28:38.178512
241	129	78	0.00	2025-10-08 10:24:50.127478	2025-10-08 10:24:50.127478	77	manque	31000.00	2025-10-08 00:28:38.178512
242	129	78	0.00	2025-11-07 10:24:50.127478	2025-11-07 10:24:50.127478	55	manque	24000.00	2025-10-08 00:28:38.178512
243	129	78	0.00	2025-12-07 10:24:50.127478	2025-12-07 10:24:50.127478	88	manque	41000.00	2025-10-08 00:28:38.178512
244	130	79	0.00	2025-10-31 08:22:32.000441	2025-10-31 08:22:32.000441	36	manque	18500.00	2025-10-08 00:28:38.178512
245	130	79	0.00	2025-11-30 08:22:32.000441	2025-11-30 08:22:32.000441	32	manque	30500.00	2025-10-08 00:28:38.178512
246	131	80	0.00	2025-10-19 18:58:47.02583	2025-10-19 18:58:47.02583	84	manque	17500.00	2025-10-08 00:28:38.178512
247	131	80	0.00	2025-11-18 18:58:47.02583	2025-11-18 18:58:47.02583	33	manque	34000.00	2025-10-08 00:28:38.178512
248	131	80	0.00	2025-12-18 18:58:47.02583	2025-12-18 18:58:47.02583	48	manque	31500.00	2025-10-08 00:28:38.178512
249	132	81	0.00	2025-10-14 06:52:39.689084	2025-10-14 06:52:39.689084	44	manque	27000.00	2025-10-08 00:28:38.178512
250	132	81	0.00	2025-11-13 06:52:39.689084	2025-11-13 06:52:39.689084	79	manque	17000.00	2025-10-08 00:28:38.178512
251	132	81	0.00	2025-12-13 06:52:39.689084	2025-12-13 06:52:39.689084	74	manque	23500.00	2025-10-08 00:28:38.178512
252	133	82	0.00	2025-09-12 19:28:30.662871	2025-09-12 19:28:30.662871	89	manque	26000.00	2025-10-08 00:28:38.178512
253	133	82	0.00	2025-10-12 19:28:30.662871	2025-10-12 19:28:30.662871	63	manque	15500.00	2025-10-08 00:28:38.178512
254	134	83	0.00	2025-10-14 09:20:08.408359	2025-10-14 09:20:08.408359	87	manque	23500.00	2025-10-08 00:28:38.178512
255	135	84	0.00	2025-09-27 07:20:12.841113	2025-09-27 07:20:12.841113	89	manque	24500.00	2025-10-08 00:28:38.178512
256	135	84	0.00	2025-10-27 07:20:12.841113	2025-10-27 07:20:12.841113	34	manque	33500.00	2025-10-08 00:28:38.178512
257	136	85	0.00	2025-09-12 04:20:37.16385	2025-09-12 04:20:37.16385	60	manque	26500.00	2025-10-08 00:28:38.178512
258	136	85	0.00	2025-10-12 04:20:37.16385	2025-10-12 04:20:37.16385	76	manque	20000.00	2025-10-08 00:28:38.178512
259	137	91	0.00	2025-10-26 18:13:25.415486	2025-10-26 18:13:25.415486	79	manque	15000.00	2025-10-08 00:28:38.178512
260	137	91	0.00	2025-11-25 18:13:25.415486	2025-11-25 18:13:25.415486	65	manque	38000.00	2025-10-08 00:28:38.178512
261	137	91	0.00	2025-12-25 18:13:25.415486	2025-12-25 18:13:25.415486	47	manque	33000.00	2025-10-08 00:28:38.178512
262	138	92	0.00	2025-08-03 01:19:54.583987	2025-08-03 01:19:54.583987	62	manque	38500.00	2025-10-08 00:28:38.178512
263	138	92	0.00	2025-09-02 01:19:54.583987	2025-09-02 01:19:54.583987	70	manque	43500.00	2025-10-08 00:28:38.178512
264	139	93	0.00	2025-08-08 04:12:41.469997	2025-08-08 04:12:41.469997	87	manque	38500.00	2025-10-08 00:28:38.178512
265	139	93	0.00	2025-09-07 04:12:41.469997	2025-09-07 04:12:41.469997	55	manque	37000.00	2025-10-08 00:28:38.178512
266	139	93	0.00	2025-10-07 04:12:41.469997	2025-10-07 04:12:41.469997	63	manque	17500.00	2025-10-08 00:28:38.178512
267	140	94	0.00	2025-10-28 06:19:44.735625	2025-10-28 06:19:44.735625	47	manque	29500.00	2025-10-08 00:28:38.178512
268	141	95	0.00	2025-06-04 21:48:14.128286	2025-06-04 21:48:14.128286	85	manque	18000.00	2025-10-08 00:28:38.178512
269	141	95	0.00	2025-07-04 21:48:14.128286	2025-07-04 21:48:14.128286	30	manque	42500.00	2025-10-08 00:28:38.178512
270	141	95	0.00	2025-08-03 21:48:14.128286	2025-08-03 21:48:14.128286	83	manque	38500.00	2025-10-08 00:28:38.178512
271	142	96	0.00	2025-07-25 05:53:19.60818	2025-07-25 05:53:19.60818	79	manque	22500.00	2025-10-08 00:28:38.178512
272	142	96	0.00	2025-08-24 05:53:19.60818	2025-08-24 05:53:19.60818	60	manque	25500.00	2025-10-08 00:28:38.178512
273	143	97	0.00	2025-06-17 13:10:01.589228	2025-06-17 13:10:01.589228	57	manque	22500.00	2025-10-08 00:28:38.178512
274	144	98	0.00	2025-09-11 16:59:35.541902	2025-09-11 16:59:35.541902	85	manque	41500.00	2025-10-08 00:28:38.178512
275	145	99	0.00	2025-10-08 14:57:39.559141	2025-10-08 14:57:39.559141	74	manque	43500.00	2025-10-08 00:28:38.178512
276	146	91	0.00	2025-10-17 18:09:25.729052	2025-10-17 18:09:25.729052	89	manque	17500.00	2025-10-08 00:28:38.178512
277	146	91	0.00	2025-11-16 18:09:25.729052	2025-11-16 18:09:25.729052	89	manque	42500.00	2025-10-08 00:28:38.178512
278	147	92	0.00	2025-10-15 14:44:24.718995	2025-10-15 14:44:24.718995	56	manque	16000.00	2025-10-08 00:28:38.178512
279	147	92	0.00	2025-11-14 14:44:24.718995	2025-11-14 14:44:24.718995	85	manque	28500.00	2025-10-08 00:28:38.178512
280	148	93	0.00	2025-10-12 23:18:48.980555	2025-10-12 23:18:48.980555	68	manque	16000.00	2025-10-08 00:28:38.178512
281	149	94	0.00	2025-10-06 16:06:12.807148	2025-10-06 16:06:12.807148	89	manque	19500.00	2025-10-08 00:28:38.178512
282	149	94	0.00	2025-11-05 16:06:12.807148	2025-11-05 16:06:12.807148	59	manque	19000.00	2025-10-08 00:28:38.178512
283	150	95	0.00	2025-09-24 23:38:18.149877	2025-09-24 23:38:18.149877	86	manque	16500.00	2025-10-08 00:28:38.178512
284	150	95	0.00	2025-10-24 23:38:18.149877	2025-10-24 23:38:18.149877	59	manque	35000.00	2025-10-08 00:28:38.178512
285	150	95	0.00	2025-11-23 23:38:18.149877	2025-11-23 23:38:18.149877	73	manque	30000.00	2025-10-08 00:28:38.178512
286	154	2	1819448.19	2025-03-02 01:20:13.945684	2025-03-02 01:20:13.945684	0	a_temps	0.00	2025-10-08 00:28:38.178512
287	155	3	1502500.72	2025-10-06 10:42:40.292566	2025-10-06 10:42:40.292566	0	a_temps	0.00	2025-10-08 00:28:38.178512
288	158	6	772959.38	2025-09-03 23:35:08.967933	2025-09-03 23:35:08.967933	0	a_temps	0.00	2025-10-08 00:28:38.178512
289	162	10	1251542.76	2025-02-05 01:34:17.908017	2025-02-05 01:34:17.908017	0	a_temps	0.00	2025-10-08 00:28:38.178512
290	163	11	872108.69	2025-05-07 13:13:26.292954	2025-05-07 13:13:26.292954	0	a_temps	0.00	2025-10-08 00:28:38.178512
291	164	12	1409340.85	2025-03-01 05:54:06.039785	2025-03-01 05:54:06.039785	0	a_temps	0.00	2025-10-08 00:28:38.178512
292	166	14	829826.25	2025-03-16 06:56:41.258545	2025-03-16 06:56:41.258545	0	a_temps	0.00	2025-10-08 00:28:38.178512
293	169	17	1739878.53	2024-11-09 16:13:32.067609	2024-11-09 16:13:32.067609	0	a_temps	0.00	2025-10-08 00:28:38.178512
294	170	18	875030.07	2025-03-30 11:59:14.361844	2025-03-30 11:59:14.361844	0	a_temps	0.00	2025-10-08 00:28:38.178512
295	170	18	934293.44	2025-04-29 11:59:14.361844	2025-04-29 11:59:14.361844	0	a_temps	0.00	2025-10-08 00:28:38.178512
296	171	19	983799.88	2025-09-09 11:29:59.631341	2025-09-09 11:29:59.631341	0	a_temps	0.00	2025-10-08 00:28:38.178512
297	173	21	933823.27	2025-10-26 05:39:42.903026	2025-10-26 05:39:42.903026	0	a_temps	0.00	2025-10-08 00:28:38.178512
298	173	21	986589.40	2025-11-25 05:39:42.903026	2025-11-25 05:39:42.903026	0	a_temps	0.00	2025-10-08 00:28:38.178512
299	174	22	1628570.47	2025-02-13 19:17:46.580018	2025-02-13 19:17:46.580018	0	a_temps	0.00	2025-10-08 00:28:38.178512
300	175	23	1885477.98	2024-11-07 19:44:56.120699	2024-11-07 19:44:56.120699	0	a_temps	0.00	2025-10-08 00:28:38.178512
301	176	24	636950.42	2025-09-29 13:59:37.352366	2025-09-29 13:59:37.352366	0	a_temps	0.00	2025-10-08 00:28:38.178512
302	177	25	1563621.60	2024-12-05 23:04:48.666433	2024-12-05 23:04:48.666433	0	a_temps	0.00	2025-10-08 00:28:38.178512
303	178	26	1557835.95	2025-03-26 08:16:30.002958	2025-03-26 08:16:30.002958	0	a_temps	0.00	2025-10-08 00:28:38.178512
304	180	28	317040.96	2025-07-19 07:54:00.711522	2025-07-13 07:54:00.711522	6	en_retard	3000.00	2025-10-08 00:28:38.178512
305	180	28	302887.43	2025-08-12 07:54:00.711522	2025-08-12 07:54:00.711522	0	a_temps	0.00	2025-10-08 00:28:38.178512
306	181	29	455326.20	2025-06-02 03:47:53.248854	2025-06-02 03:47:53.248854	0	a_temps	0.00	2025-10-08 00:28:38.178512
307	182	30	1524262.74	2024-11-19 22:44:47.076308	2024-11-19 22:44:47.076308	0	a_temps	0.00	2025-10-08 00:28:38.178512
308	198	31	276475.36	2025-03-12 20:06:02.921049	2025-03-12 20:06:02.921049	0	a_temps	0.00	2025-10-08 00:28:38.178512
309	199	32	0.00	2025-09-30 22:07:07.742804	2025-09-30 22:07:07.742804	62	manque	35500.00	2025-10-08 00:28:38.178512
310	200	33	322155.21	2025-07-07 08:55:46.807153	2025-07-07 08:55:46.807153	0	a_temps	0.00	2025-10-08 00:28:38.178512
311	200	33	329923.05	2025-08-06 08:55:46.807153	2025-08-06 08:55:46.807153	0	a_temps	0.00	2025-10-08 00:28:38.178512
312	201	34	693750.54	2025-06-16 03:56:44.848258	2025-06-16 03:56:44.848258	0	a_temps	0.00	2025-10-08 00:28:38.178512
313	202	35	818063.69	2025-08-20 03:54:18.545097	2025-08-20 03:54:18.545097	0	a_temps	0.00	2025-10-08 00:28:38.178512
314	203	36	378322.71	2025-03-10 17:42:56.309995	2025-03-10 17:42:56.309995	0	a_temps	0.00	2025-10-08 00:28:38.178512
315	203	36	380171.09	2025-04-09 17:42:56.309995	2025-04-09 17:42:56.309995	0	a_temps	0.00	2025-10-08 00:28:38.178512
316	205	38	281178.66	2025-10-31 19:01:52.706657	2025-10-31 19:01:52.706657	0	a_temps	0.00	2025-10-08 00:28:38.178512
317	206	39	298272.92	2025-06-11 22:07:54.217049	2025-06-11 22:07:54.217049	0	a_temps	0.00	2025-10-08 00:28:38.178512
318	207	40	165810.34	2025-03-28 23:26:38.623615	2025-03-28 23:26:38.623615	0	a_temps	0.00	2025-10-08 00:28:38.178512
319	207	40	150370.93	2025-04-27 23:26:38.623615	2025-04-27 23:26:38.623615	0	a_temps	0.00	2025-10-08 00:28:38.178512
320	208	41	353220.78	2025-09-21 12:47:59.478487	2025-09-21 12:47:59.478487	0	a_temps	0.00	2025-10-08 00:28:38.178512
321	208	41	392899.67	2025-10-21 12:47:59.478487	2025-10-21 12:47:59.478487	0	a_temps	0.00	2025-10-08 00:28:38.178512
322	209	42	529249.72	2025-04-22 06:06:55.908109	2025-04-22 06:06:55.908109	0	a_temps	0.00	2025-10-08 00:28:38.178512
323	210	43	430140.15	2025-03-27 06:00:13.149166	2025-03-27 06:00:13.149166	0	a_temps	0.00	2025-10-08 00:28:38.178512
324	213	46	136304.07	2025-09-13 21:04:59.506656	2025-09-13 21:04:59.506656	0	a_temps	0.00	2025-10-08 00:28:38.178512
325	213	46	152281.59	2025-10-13 21:04:59.506656	2025-10-13 21:04:59.506656	0	a_temps	0.00	2025-10-08 00:28:38.178512
326	214	47	731727.63	2025-03-27 03:57:06.601345	2025-03-27 03:57:06.601345	0	a_temps	0.00	2025-10-08 00:28:38.178512
327	215	48	147550.32	2025-07-10 16:17:37.498812	2025-07-10 16:17:37.498812	0	a_temps	0.00	2025-10-08 00:28:38.178512
328	215	48	142914.48	2025-08-09 16:17:37.498812	2025-08-09 16:17:37.498812	0	a_temps	0.00	2025-10-08 00:28:38.178512
329	216	49	254076.86	2025-10-28 19:06:04.133723	2025-10-28 19:06:04.133723	0	a_temps	0.00	2025-10-08 00:28:38.178512
330	216	49	243485.66	2025-11-27 19:06:04.133723	2025-11-27 19:06:04.133723	0	a_temps	0.00	2025-10-08 00:28:38.178512
331	217	50	128381.12	2025-07-26 14:31:22.087513	2025-06-03 14:31:22.087513	53	en_retard	26500.00	2025-10-08 00:28:38.178512
332	218	51	0.00	2025-04-23 14:00:45.322934	2025-04-23 14:00:45.322934	65	manque	23500.00	2025-10-08 00:28:38.178512
333	218	51	0.00	2025-05-23 14:00:45.322934	2025-05-23 14:00:45.322934	56	manque	31000.00	2025-10-08 00:28:38.178512
334	218	51	0.00	2025-06-22 14:00:45.322934	2025-06-22 14:00:45.322934	52	manque	16500.00	2025-10-08 00:28:38.178512
335	219	52	270496.42	2025-06-27 06:00:31.050725	2025-06-27 06:00:31.050725	0	a_temps	0.00	2025-10-08 00:28:38.178512
336	219	52	256433.53	2025-07-27 06:00:31.050725	2025-07-27 06:00:31.050725	0	a_temps	0.00	2025-10-08 00:28:38.178512
337	220	53	423911.31	2025-05-09 13:38:25.840898	2025-05-09 13:38:25.840898	0	a_temps	0.00	2025-10-08 00:28:38.178512
338	221	54	330329.26	2025-09-20 23:06:59.633516	2025-09-20 23:06:59.633516	0	a_temps	0.00	2025-10-08 00:28:38.178512
339	222	55	854306.75	2025-06-25 15:23:50.705404	2025-06-25 15:23:50.705404	0	a_temps	0.00	2025-10-08 00:28:38.178512
340	223	56	232904.34	2025-05-30 03:12:12.818223	2025-05-30 03:12:12.818223	0	a_temps	0.00	2025-10-08 00:28:38.178512
341	223	56	255628.22	2025-06-29 03:12:12.818223	2025-06-29 03:12:12.818223	0	a_temps	0.00	2025-10-08 00:28:38.178512
342	224	57	199742.41	2025-02-23 04:42:56.962178	2025-02-23 04:42:56.962178	0	a_temps	0.00	2025-10-08 00:28:38.178512
343	224	57	219590.44	2025-03-25 04:42:56.962178	2025-03-25 04:42:56.962178	0	a_temps	0.00	2025-10-08 00:28:38.178512
344	226	59	122375.65	2025-09-14 14:01:01.777026	2025-09-14 14:01:01.777026	0	a_temps	0.00	2025-10-08 00:28:38.178512
345	227	60	138818.36	2025-03-20 10:58:49.959473	2025-03-20 10:58:49.959473	0	a_temps	0.00	2025-10-08 00:28:38.178512
346	228	61	335705.58	2025-03-20 08:01:56.630862	2025-03-20 08:01:56.630862	0	a_temps	0.00	2025-10-08 00:28:38.178512
347	228	61	339218.27	2025-04-19 08:01:56.630862	2025-04-19 08:01:56.630862	0	a_temps	0.00	2025-10-08 00:28:38.178512
348	229	62	830784.93	2025-05-07 05:47:41.025357	2025-05-07 05:47:41.025357	0	a_temps	0.00	2025-10-08 00:28:38.178512
349	230	63	626000.92	2025-06-25 01:41:53.314779	2025-06-25 01:41:53.314779	0	a_temps	0.00	2025-10-08 00:28:38.178512
350	231	64	397668.00	2025-03-15 03:43:51.009966	2025-03-15 03:43:51.009966	0	a_temps	0.00	2025-10-08 00:28:38.178512
351	231	64	428043.64	2025-04-14 03:43:51.009966	2025-04-14 03:43:51.009966	0	a_temps	0.00	2025-10-08 00:28:38.178512
352	232	65	0.00	2025-10-13 23:22:39.923291	2025-10-13 23:22:39.923291	53	manque	43500.00	2025-10-08 00:28:38.178512
353	233	66	636927.21	2025-11-03 20:25:40.941004	2025-11-03 20:25:40.941004	0	a_temps	0.00	2025-10-08 00:28:38.178512
354	234	67	279254.85	2025-08-15 19:17:30.471015	2025-08-15 19:17:30.471015	0	a_temps	0.00	2025-10-08 00:28:38.178512
355	234	67	319388.75	2025-09-14 19:17:30.471015	2025-09-14 19:17:30.471015	0	a_temps	0.00	2025-10-08 00:28:38.178512
356	239	32	0.00	2025-08-08 22:41:17.909469	2025-08-08 22:41:17.909469	72	manque	25500.00	2025-10-08 00:28:38.178512
357	240	33	0.00	2025-09-01 18:01:24.529812	2025-09-01 18:01:24.529812	52	manque	40000.00	2025-10-08 00:28:38.178512
358	242	35	0.00	2025-08-08 21:03:43.525959	2025-08-08 21:03:43.525959	46	manque	35000.00	2025-10-08 00:28:38.178512
359	244	37	0.00	2025-08-14 11:53:18.465457	2025-08-14 11:53:18.465457	72	manque	28000.00	2025-10-08 00:28:38.178512
360	244	37	0.00	2025-09-13 11:53:18.465457	2025-09-13 11:53:18.465457	46	manque	39000.00	2025-10-08 00:28:38.178512
361	246	39	0.00	2025-09-15 13:41:28.304938	2025-09-15 13:41:28.304938	48	manque	36000.00	2025-10-08 00:28:38.178512
362	246	39	0.00	2025-10-15 13:41:28.304938	2025-10-15 13:41:28.304938	66	manque	16000.00	2025-10-08 00:28:38.178512
363	247	40	0.00	2025-09-06 01:16:56.541849	2025-09-06 01:16:56.541849	61	manque	31500.00	2025-10-08 00:28:38.178512
364	247	40	0.00	2025-10-06 01:16:56.541849	2025-10-06 01:16:56.541849	61	manque	42500.00	2025-10-08 00:28:38.178512
365	254	47	0.00	2025-08-26 06:24:46.987808	2025-08-26 06:24:46.987808	43	manque	28500.00	2025-10-08 00:28:38.178512
366	256	49	0.00	2025-08-13 01:33:30.67993	2025-08-13 01:33:30.67993	77	manque	34500.00	2025-10-08 00:28:38.178512
367	256	49	0.00	2025-09-12 01:33:30.67993	2025-09-12 01:33:30.67993	73	manque	25500.00	2025-10-08 00:28:38.178512
368	256	49	0.00	2025-10-12 01:33:30.67993	2025-10-12 01:33:30.67993	88	manque	42000.00	2025-10-08 00:28:38.178512
369	259	72	0.00	2025-06-30 10:52:36.483881	2025-06-30 10:52:36.483881	32	manque	24000.00	2025-10-08 00:28:38.178512
370	259	72	0.00	2025-07-30 10:52:36.483881	2025-07-30 10:52:36.483881	45	manque	19000.00	2025-10-08 00:28:38.178512
371	260	73	0.00	2025-09-27 18:01:10.322424	2025-09-27 18:01:10.322424	58	manque	32000.00	2025-10-08 00:28:38.178512
372	260	73	0.00	2025-10-27 18:01:10.322424	2025-10-27 18:01:10.322424	88	manque	27500.00	2025-10-08 00:28:38.178512
373	261	74	430454.03	2025-09-02 18:07:45.835537	2025-09-02 18:07:45.835537	0	a_temps	0.00	2025-10-08 00:28:38.178512
374	263	76	348725.38	2025-05-29 07:35:35.753571	2025-05-29 07:35:35.753571	0	a_temps	0.00	2025-10-08 00:28:38.178512
375	264	77	337522.36	2025-11-05 09:34:47.497436	2025-11-05 09:34:47.497436	0	a_temps	0.00	2025-10-08 00:28:38.178512
376	266	79	0.00	2025-04-25 10:33:40.604655	2025-04-25 10:33:40.604655	53	manque	31000.00	2025-10-08 00:28:38.178512
377	266	79	0.00	2025-05-25 10:33:40.604655	2025-05-25 10:33:40.604655	55	manque	32500.00	2025-10-08 00:28:38.178512
378	266	79	0.00	2025-06-24 10:33:40.604655	2025-06-24 10:33:40.604655	58	manque	18500.00	2025-10-08 00:28:38.178512
379	267	80	315419.95	2025-05-03 21:32:21.659364	2025-05-03 21:32:21.659364	0	a_temps	0.00	2025-10-08 00:28:38.178512
380	268	81	215374.09	2025-06-22 02:17:07.092883	2025-06-22 02:17:07.092883	0	a_temps	0.00	2025-10-08 00:28:38.178512
381	270	83	0.00	2025-05-20 08:43:51.322165	2025-05-20 08:43:51.322165	42	manque	21500.00	2025-10-08 00:28:38.178512
382	270	83	0.00	2025-06-19 08:43:51.322165	2025-06-19 08:43:51.322165	59	manque	25000.00	2025-10-08 00:28:38.178512
383	271	84	0.00	2025-04-26 12:45:57.45702	2025-04-26 12:45:57.45702	52	manque	36000.00	2025-10-08 00:28:38.178512
384	271	84	0.00	2025-05-26 12:45:57.45702	2025-05-26 12:45:57.45702	73	manque	15500.00	2025-10-08 00:28:38.178512
385	271	84	0.00	2025-06-25 12:45:57.45702	2025-06-25 12:45:57.45702	76	manque	30500.00	2025-10-08 00:28:38.178512
386	273	86	144003.36	2025-07-23 00:17:14.201406	2025-07-23 00:17:14.201406	0	a_temps	0.00	2025-10-08 00:28:38.178512
387	274	87	129195.64	2025-07-22 07:17:46.287444	2025-07-22 07:17:46.287444	0	a_temps	0.00	2025-10-08 00:28:38.178512
388	277	90	260369.76	2025-10-14 07:34:27.490849	2025-10-14 07:34:27.490849	0	a_temps	0.00	2025-10-08 00:28:38.178512
389	278	75	0.00	2025-10-10 07:18:39.329185	2025-10-10 07:18:39.329185	87	manque	15500.00	2025-10-08 00:28:38.178512
390	278	75	0.00	2025-11-09 07:18:39.329185	2025-11-09 07:18:39.329185	80	manque	38000.00	2025-10-08 00:28:38.178512
391	279	76	0.00	2025-10-03 17:04:19.304655	2025-10-03 17:04:19.304655	76	manque	15000.00	2025-10-08 00:28:38.178512
392	280	77	0.00	2025-11-04 09:24:53.236521	2025-11-04 09:24:53.236521	51	manque	17500.00	2025-10-08 00:28:38.178512
393	280	77	0.00	2025-12-04 09:24:53.236521	2025-12-04 09:24:53.236521	54	manque	26500.00	2025-10-08 00:28:38.178512
394	281	78	0.00	2025-10-30 14:56:14.57365	2025-10-30 14:56:14.57365	44	manque	31500.00	2025-10-08 00:28:38.178512
395	281	78	0.00	2025-11-29 14:56:14.57365	2025-11-29 14:56:14.57365	56	manque	19000.00	2025-10-08 00:28:38.178512
396	282	79	0.00	2025-10-13 09:35:35.929705	2025-10-13 09:35:35.929705	73	manque	29000.00	2025-10-08 00:28:38.178512
397	282	79	0.00	2025-11-12 09:35:35.929705	2025-11-12 09:35:35.929705	30	manque	27000.00	2025-10-08 00:28:38.178512
398	283	80	0.00	2025-10-15 23:59:34.752839	2025-10-15 23:59:34.752839	38	manque	32500.00	2025-10-08 00:28:38.178512
399	283	80	0.00	2025-11-14 23:59:34.752839	2025-11-14 23:59:34.752839	40	manque	16000.00	2025-10-08 00:28:38.178512
400	283	80	0.00	2025-12-14 23:59:34.752839	2025-12-14 23:59:34.752839	35	manque	43500.00	2025-10-08 00:28:38.178512
401	284	81	0.00	2025-09-21 03:39:52.461098	2025-09-21 03:39:52.461098	32	manque	41000.00	2025-10-08 00:28:38.178512
402	284	81	0.00	2025-10-21 03:39:52.461098	2025-10-21 03:39:52.461098	45	manque	43000.00	2025-10-08 00:28:38.178512
403	285	82	0.00	2025-11-01 22:56:19.179959	2025-11-01 22:56:19.179959	31	manque	33000.00	2025-10-08 00:28:38.178512
404	285	82	0.00	2025-12-01 22:56:19.179959	2025-12-01 22:56:19.179959	58	manque	35500.00	2025-10-08 00:28:38.178512
405	285	82	0.00	2025-12-31 22:56:19.179959	2025-12-31 22:56:19.179959	45	manque	28000.00	2025-10-08 00:28:38.178512
406	286	83	0.00	2025-10-10 06:16:04.263588	2025-10-10 06:16:04.263588	83	manque	18500.00	2025-10-08 00:28:38.178512
407	286	83	0.00	2025-11-09 06:16:04.263588	2025-11-09 06:16:04.263588	48	manque	16000.00	2025-10-08 00:28:38.178512
408	287	84	0.00	2025-10-29 04:09:12.163099	2025-10-29 04:09:12.163099	56	manque	39000.00	2025-10-08 00:28:38.178512
409	287	84	0.00	2025-11-28 04:09:12.163099	2025-11-28 04:09:12.163099	83	manque	27000.00	2025-10-08 00:28:38.178512
410	287	84	0.00	2025-12-28 04:09:12.163099	2025-12-28 04:09:12.163099	61	manque	36500.00	2025-10-08 00:28:38.178512
411	288	85	0.00	2025-09-16 16:14:13.231367	2025-09-16 16:14:13.231367	45	manque	32000.00	2025-10-08 00:28:38.178512
412	289	91	0.00	2025-10-14 20:46:56.749633	2025-10-14 20:46:56.749633	88	manque	42500.00	2025-10-08 00:28:38.178512
413	289	91	0.00	2025-11-13 20:46:56.749633	2025-11-13 20:46:56.749633	82	manque	22000.00	2025-10-08 00:28:38.178512
414	289	91	0.00	2025-12-13 20:46:56.749633	2025-12-13 20:46:56.749633	42	manque	30500.00	2025-10-08 00:28:38.178512
415	290	92	0.00	2025-05-20 22:14:04.079489	2025-05-20 22:14:04.079489	85	manque	20000.00	2025-10-08 00:28:38.178512
416	290	92	0.00	2025-06-19 22:14:04.079489	2025-06-19 22:14:04.079489	60	manque	37000.00	2025-10-08 00:28:38.178512
417	290	92	0.00	2025-07-19 22:14:04.079489	2025-07-19 22:14:04.079489	45	manque	25500.00	2025-10-08 00:28:38.178512
418	291	93	0.00	2025-07-23 19:13:33.218707	2025-07-23 19:13:33.218707	37	manque	33500.00	2025-10-08 00:28:38.178512
419	291	93	0.00	2025-08-22 19:13:33.218707	2025-08-22 19:13:33.218707	58	manque	18500.00	2025-10-08 00:28:38.178512
420	291	93	0.00	2025-09-21 19:13:33.218707	2025-09-21 19:13:33.218707	50	manque	19500.00	2025-10-08 00:28:38.178512
421	292	94	0.00	2025-06-25 17:04:15.487802	2025-06-25 17:04:15.487802	84	manque	18500.00	2025-10-08 00:28:38.178512
422	292	94	0.00	2025-07-25 17:04:15.487802	2025-07-25 17:04:15.487802	33	manque	32000.00	2025-10-08 00:28:38.178512
423	292	94	0.00	2025-08-24 17:04:15.487802	2025-08-24 17:04:15.487802	77	manque	43000.00	2025-10-08 00:28:38.178512
424	293	95	0.00	2025-06-07 09:05:12.045669	2025-06-07 09:05:12.045669	64	manque	40500.00	2025-10-08 00:28:38.178512
425	293	95	0.00	2025-07-07 09:05:12.045669	2025-07-07 09:05:12.045669	79	manque	44500.00	2025-10-08 00:28:38.178512
426	294	96	0.00	2025-06-10 11:54:57.553749	2025-06-10 11:54:57.553749	44	manque	27000.00	2025-10-08 00:28:38.178512
427	295	97	0.00	2025-07-10 12:22:13.47146	2025-07-10 12:22:13.47146	68	manque	22000.00	2025-10-08 00:28:38.178512
428	296	98	0.00	2025-08-08 01:07:12.621994	2025-08-08 01:07:12.621994	48	manque	42500.00	2025-10-08 00:28:38.178512
429	297	99	0.00	2025-08-21 07:42:54.138417	2025-08-21 07:42:54.138417	52	manque	26000.00	2025-10-08 00:28:38.178512
430	297	99	0.00	2025-09-20 07:42:54.138417	2025-09-20 07:42:54.138417	36	manque	35500.00	2025-10-08 00:28:38.178512
431	297	99	0.00	2025-10-20 07:42:54.138417	2025-10-20 07:42:54.138417	37	manque	22000.00	2025-10-08 00:28:38.178512
432	298	91	0.00	2025-10-25 12:48:30.693218	2025-10-25 12:48:30.693218	34	manque	21000.00	2025-10-08 00:28:38.178512
433	298	91	0.00	2025-11-24 12:48:30.693218	2025-11-24 12:48:30.693218	49	manque	40000.00	2025-10-08 00:28:38.178512
434	298	91	0.00	2025-12-24 12:48:30.693218	2025-12-24 12:48:30.693218	86	manque	17500.00	2025-10-08 00:28:38.178512
435	299	92	0.00	2025-09-13 05:03:49.536823	2025-09-13 05:03:49.536823	78	manque	39000.00	2025-10-08 00:28:38.178512
436	299	92	0.00	2025-10-13 05:03:49.536823	2025-10-13 05:03:49.536823	78	manque	28500.00	2025-10-08 00:28:38.178512
437	300	93	0.00	2025-08-19 06:29:31.694584	2025-08-19 06:29:31.694584	73	manque	42500.00	2025-10-08 00:28:38.178512
438	300	93	0.00	2025-09-18 06:29:31.694584	2025-09-18 06:29:31.694584	83	manque	16000.00	2025-10-08 00:28:38.178512
439	300	93	0.00	2025-10-18 06:29:31.694584	2025-10-18 06:29:31.694584	51	manque	38500.00	2025-10-08 00:28:38.178512
440	301	94	0.00	2025-09-26 05:12:52.4015	2025-09-26 05:12:52.4015	84	manque	20500.00	2025-10-08 00:28:38.178512
441	301	94	0.00	2025-10-26 05:12:52.4015	2025-10-26 05:12:52.4015	50	manque	24500.00	2025-10-08 00:28:38.178512
442	301	94	0.00	2025-11-25 05:12:52.4015	2025-11-25 05:12:52.4015	35	manque	23000.00	2025-10-08 00:28:38.178512
443	302	95	0.00	2025-10-30 11:06:27.046461	2025-10-30 11:06:27.046461	88	manque	16000.00	2025-10-08 00:28:38.178512
444	302	95	0.00	2025-11-29 11:06:27.046461	2025-11-29 11:06:27.046461	68	manque	22500.00	2025-10-08 00:28:38.178512
445	2	2	1487036.76	2025-05-21 11:11:10.958657	2025-05-21 11:11:10.958657	0	a_temps	0.00	2025-10-08 13:10:20.06687
446	4	4	739434.12	2025-10-11 22:37:27.230529	2025-10-11 22:37:27.230529	0	a_temps	0.00	2025-10-08 13:10:20.06687
447	5	5	1256830.13	2025-02-26 20:09:49.416982	2025-02-26 20:09:49.416982	0	a_temps	0.00	2025-10-08 13:10:20.06687
448	8	8	703988.17	2025-06-20 22:49:13.906371	2025-06-20 22:49:13.906371	0	a_temps	0.00	2025-10-08 13:10:20.06687
449	11	11	559633.37	2024-12-06 09:34:24.688008	2024-12-06 09:34:24.688008	0	a_temps	0.00	2025-10-08 13:10:20.06687
450	13	13	774438.55	2025-04-21 16:20:04.641186	2025-04-21 16:20:04.641186	0	a_temps	0.00	2025-10-08 13:10:20.06687
451	13	13	681253.04	2025-05-21 16:20:04.641186	2025-05-21 16:20:04.641186	0	a_temps	0.00	2025-10-08 13:10:20.06687
452	13	13	746675.80	2025-06-20 16:20:04.641186	2025-06-20 16:20:04.641186	0	a_temps	0.00	2025-10-08 13:10:20.06687
453	14	14	706953.22	2025-07-11 18:38:40.037667	2025-07-11 18:38:40.037667	0	a_temps	0.00	2025-10-08 13:10:20.06687
454	14	14	631019.40	2025-08-10 18:38:40.037667	2025-08-10 18:38:40.037667	0	a_temps	0.00	2025-10-08 13:10:20.06687
455	14	14	675036.94	2025-09-09 18:38:40.037667	2025-09-09 18:38:40.037667	0	a_temps	0.00	2025-10-08 13:10:20.06687
456	15	15	1186670.24	2025-07-06 11:34:28.679069	2025-07-06 11:34:28.679069	0	a_temps	0.00	2025-10-08 13:10:20.06687
457	16	16	1266369.68	2025-04-28 15:43:21.25365	2025-04-28 15:43:21.25365	0	a_temps	0.00	2025-10-08 13:10:20.06687
458	17	17	1478908.25	2025-10-11 23:24:56.371407	2025-10-11 23:24:56.371407	0	a_temps	0.00	2025-10-08 13:10:20.06687
459	19	19	279792.03	2025-09-08 02:56:52.774093	2025-09-08 02:56:52.774093	0	a_temps	0.00	2025-10-08 13:10:20.06687
460	19	19	249928.28	2025-10-08 02:56:52.774093	2025-10-08 02:56:52.774093	0	a_temps	0.00	2025-10-08 13:10:20.06687
461	19	19	268015.59	2025-11-07 02:56:52.774093	2025-11-07 02:56:52.774093	0	a_temps	0.00	2025-10-08 13:10:20.06687
462	20	20	1985643.13	2025-10-27 18:53:28.85246	2025-10-27 18:53:28.85246	0	a_temps	0.00	2025-10-08 13:10:20.06687
463	21	21	297898.39	2025-10-26 22:38:47.838063	2025-10-26 22:38:47.838063	0	a_temps	0.00	2025-10-08 13:10:20.06687
464	22	22	1506829.57	2024-11-12 17:49:08.792501	2024-11-12 17:49:08.792501	0	a_temps	0.00	2025-10-08 13:10:20.06687
465	23	23	718944.55	2025-03-11 20:42:38.659398	2025-03-11 20:42:38.659398	0	a_temps	0.00	2025-10-08 13:10:20.06687
466	25	25	1353500.91	2025-01-14 23:16:49.089899	2025-01-14 23:16:49.089899	0	a_temps	0.00	2025-10-08 13:10:20.06687
467	27	27	617782.70	2025-03-15 01:12:03.980074	2025-03-15 01:12:03.980074	0	a_temps	0.00	2025-10-08 13:10:20.06687
468	29	29	570595.45	2025-04-30 11:48:49.360185	2025-03-25 11:48:49.360185	36	en_retard	18000.00	2025-10-08 13:10:20.06687
469	29	29	547210.50	2025-04-24 11:48:49.360185	2025-04-24 11:48:49.360185	0	a_temps	0.00	2025-10-08 13:10:20.06687
470	46	31	247766.22	2025-10-16 10:37:59.911985	2025-10-16 10:37:59.911985	0	a_temps	0.00	2025-10-08 13:10:20.06687
471	46	31	245554.38	2025-11-15 10:37:59.911985	2025-11-15 10:37:59.911985	0	a_temps	0.00	2025-10-08 13:10:20.06687
472	47	32	291615.73	2025-10-17 00:08:00.483171	2025-10-17 00:08:00.483171	0	a_temps	0.00	2025-10-08 13:10:20.06687
473	47	32	302440.26	2025-11-16 00:08:00.483171	2025-11-16 00:08:00.483171	0	a_temps	0.00	2025-10-08 13:10:20.06687
474	48	33	0.00	2025-03-28 17:10:17.617682	2025-03-28 17:10:17.617682	87	manque	29000.00	2025-10-08 13:10:20.06687
475	48	33	0.00	2025-04-27 17:10:17.617682	2025-04-27 17:10:17.617682	79	manque	36000.00	2025-10-08 13:10:20.06687
476	49	34	311153.07	2025-02-06 20:04:53.324022	2025-02-06 20:04:53.324022	0	a_temps	0.00	2025-10-08 13:10:20.06687
477	49	34	292268.97	2025-03-08 20:04:53.324022	2025-03-08 20:04:53.324022	0	a_temps	0.00	2025-10-08 13:10:20.06687
478	50	35	180472.93	2025-11-17 00:36:31.17746	2025-10-26 00:36:31.17746	22	en_retard	11000.00	2025-10-08 13:10:20.06687
479	50	35	0.00	2025-11-25 00:36:31.17746	2025-11-25 00:36:31.17746	34	manque	41500.00	2025-10-08 13:10:20.06687
480	50	35	0.00	2025-12-25 00:36:31.17746	2025-12-25 00:36:31.17746	70	manque	21000.00	2025-10-08 13:10:20.06687
481	50	35	0.00	2026-01-24 00:36:31.17746	2026-01-24 00:36:31.17746	46	manque	17000.00	2025-10-08 13:10:20.06687
482	51	36	712278.66	2025-03-11 15:55:56.901817	2025-03-11 15:55:56.901817	0	a_temps	0.00	2025-10-08 13:10:20.06687
483	55	40	263718.53	2025-09-19 10:54:15.038803	2025-09-19 10:54:15.038803	0	a_temps	0.00	2025-10-08 13:10:20.06687
484	55	40	274335.53	2025-10-19 10:54:15.038803	2025-10-19 10:54:15.038803	0	a_temps	0.00	2025-10-08 13:10:20.06687
485	56	41	420305.11	2025-03-25 18:35:10.193316	2025-03-25 18:35:10.193316	0	a_temps	0.00	2025-10-08 13:10:20.06687
486	57	42	245026.94	2025-03-20 01:13:00.04763	2025-03-20 01:13:00.04763	0	a_temps	0.00	2025-10-08 13:10:20.06687
487	57	42	270974.03	2025-04-19 01:13:00.04763	2025-04-19 01:13:00.04763	0	a_temps	0.00	2025-10-08 13:10:20.06687
488	60	45	228596.91	2025-09-22 04:47:51.503472	2025-09-22 04:47:51.503472	0	a_temps	0.00	2025-10-08 13:10:20.06687
489	60	45	195651.77	2025-10-22 04:47:51.503472	2025-10-22 04:47:51.503472	0	a_temps	0.00	2025-10-08 13:10:20.06687
490	61	46	315344.47	2025-04-03 22:04:03.690437	2025-04-03 22:04:03.690437	0	a_temps	0.00	2025-10-08 13:10:20.06687
491	61	46	362220.27	2025-05-03 22:04:03.690437	2025-05-03 22:04:03.690437	0	a_temps	0.00	2025-10-08 13:10:20.06687
492	62	47	419806.73	2025-03-27 05:45:20.949243	2025-03-27 05:45:20.949243	0	a_temps	0.00	2025-10-08 13:10:20.06687
493	64	49	378552.93	2025-02-25 08:38:00.742785	2025-02-25 08:38:00.742785	0	a_temps	0.00	2025-10-08 13:10:20.06687
494	65	50	289656.52	2025-02-28 08:34:46.822178	2025-02-28 08:34:46.822178	0	a_temps	0.00	2025-10-08 13:10:20.06687
495	66	51	159243.61	2025-02-27 11:35:45.589659	2025-02-27 11:35:45.589659	0	a_temps	0.00	2025-10-08 13:10:20.06687
496	66	51	166323.51	2025-03-29 11:35:45.589659	2025-03-29 11:35:45.589659	0	a_temps	0.00	2025-10-08 13:10:20.06687
497	67	52	285223.53	2025-09-28 02:01:20.405515	2025-09-28 02:01:20.405515	0	a_temps	0.00	2025-10-08 13:10:20.06687
498	68	53	141992.69	2025-07-05 05:23:01.251111	2025-07-05 05:23:01.251111	0	a_temps	0.00	2025-10-08 13:10:20.06687
499	68	53	136442.88	2025-08-04 05:23:01.251111	2025-08-04 05:23:01.251111	0	a_temps	0.00	2025-10-08 13:10:20.06687
500	69	54	249737.77	2025-10-06 22:11:07.667394	2025-10-06 22:11:07.667394	0	a_temps	0.00	2025-10-08 13:10:20.06687
501	70	55	108474.92	2025-03-30 04:50:27.497469	2025-03-30 04:50:27.497469	0	a_temps	0.00	2025-10-08 13:10:20.06687
502	71	56	375771.98	2025-07-13 21:28:20.935285	2025-07-13 21:28:20.935285	0	a_temps	0.00	2025-10-08 13:10:20.06687
503	71	56	333436.49	2025-08-12 21:28:20.935285	2025-08-12 21:28:20.935285	0	a_temps	0.00	2025-10-08 13:10:20.06687
504	72	57	262456.34	2025-03-17 22:58:40.401315	2025-03-17 22:58:40.401315	0	a_temps	0.00	2025-10-08 13:10:20.06687
505	72	57	247224.53	2025-04-16 22:58:40.401315	2025-04-16 22:58:40.401315	0	a_temps	0.00	2025-10-08 13:10:20.06687
506	74	59	237843.44	2025-05-03 18:28:26.822464	2025-05-03 18:28:26.822464	0	a_temps	0.00	2025-10-08 13:10:20.06687
507	74	59	266284.58	2025-06-02 18:28:26.822464	2025-06-02 18:28:26.822464	0	a_temps	0.00	2025-10-08 13:10:20.06687
508	77	62	373404.80	2025-05-19 18:47:48.088537	2025-05-19 18:47:48.088537	0	a_temps	0.00	2025-10-08 13:10:20.06687
509	78	63	299659.30	2025-03-18 19:38:57.467382	2025-03-18 19:38:57.467382	0	a_temps	0.00	2025-10-08 13:10:20.06687
510	78	63	253199.67	2025-04-17 19:38:57.467382	2025-04-17 19:38:57.467382	0	a_temps	0.00	2025-10-08 13:10:20.06687
511	80	65	412586.54	2025-05-20 21:18:32.629696	2025-05-20 21:18:32.629696	0	a_temps	0.00	2025-10-08 13:10:20.06687
512	80	65	394598.17	2025-06-19 21:18:32.629696	2025-06-19 21:18:32.629696	0	a_temps	0.00	2025-10-08 13:10:20.06687
513	81	66	117935.06	2025-06-25 17:56:25.393843	2025-06-15 17:56:25.393843	10	en_retard	5000.00	2025-10-08 13:10:20.06687
514	82	67	414601.51	2025-08-04 00:42:51.038809	2025-08-04 00:42:51.038809	0	a_temps	0.00	2025-10-08 13:10:20.06687
515	82	67	374290.94	2025-09-03 00:42:51.038809	2025-09-03 00:42:51.038809	0	a_temps	0.00	2025-10-08 13:10:20.06687
516	84	69	693874.64	2025-08-12 21:34:22.504549	2025-08-12 21:34:22.504549	0	a_temps	0.00	2025-10-08 13:10:20.06687
517	85	70	335116.11	2025-03-24 10:32:22.278869	2025-03-24 10:32:22.278869	0	a_temps	0.00	2025-10-08 13:10:20.06687
518	85	70	315086.56	2025-04-23 10:32:22.278869	2025-04-23 10:32:22.278869	0	a_temps	0.00	2025-10-08 13:10:20.06687
519	86	31	0.00	2025-09-03 07:05:38.262677	2025-09-03 07:05:38.262677	59	manque	22500.00	2025-10-08 13:10:20.06687
520	89	34	0.00	2025-10-30 13:23:31.605617	2025-10-30 13:23:31.605617	54	manque	43500.00	2025-10-08 13:10:20.06687
521	89	34	0.00	2025-11-29 13:23:31.605617	2025-11-29 13:23:31.605617	74	manque	25500.00	2025-10-08 13:10:20.06687
522	90	35	0.00	2025-07-08 21:34:27.390891	2025-07-08 21:34:27.390891	60	manque	18000.00	2025-10-08 13:10:20.06687
523	90	35	0.00	2025-08-07 21:34:27.390891	2025-08-07 21:34:27.390891	55	manque	32500.00	2025-10-08 13:10:20.06687
524	90	35	0.00	2025-09-06 21:34:27.390891	2025-09-06 21:34:27.390891	47	manque	28500.00	2025-10-08 13:10:20.06687
525	95	40	0.00	2025-10-17 16:04:54.002176	2025-10-17 16:04:54.002176	45	manque	22000.00	2025-10-08 13:10:20.06687
526	95	40	0.00	2025-11-16 16:04:54.002176	2025-11-16 16:04:54.002176	40	manque	39000.00	2025-10-08 13:10:20.06687
527	95	40	0.00	2025-12-16 16:04:54.002176	2025-12-16 16:04:54.002176	48	manque	33500.00	2025-10-08 13:10:20.06687
528	97	42	0.00	2025-07-17 08:39:51.394881	2025-07-17 08:39:51.394881	77	manque	17500.00	2025-10-08 13:10:20.06687
529	97	42	0.00	2025-08-16 08:39:51.394881	2025-08-16 08:39:51.394881	50	manque	31000.00	2025-10-08 13:10:20.06687
530	97	42	0.00	2025-09-15 08:39:51.394881	2025-09-15 08:39:51.394881	51	manque	40000.00	2025-10-08 13:10:20.06687
531	101	46	0.00	2025-08-12 18:20:11.759923	2025-08-12 18:20:11.759923	68	manque	15500.00	2025-10-08 13:10:20.06687
532	101	46	0.00	2025-09-11 18:20:11.759923	2025-09-11 18:20:11.759923	43	manque	20500.00	2025-10-08 13:10:20.06687
533	101	46	0.00	2025-10-11 18:20:11.759923	2025-10-11 18:20:11.759923	63	manque	33500.00	2025-10-08 13:10:20.06687
534	106	71	216541.78	2025-05-20 19:44:47.071897	2025-05-20 19:44:47.071897	0	a_temps	0.00	2025-10-08 13:10:20.06687
535	109	74	295935.92	2025-06-19 17:04:13.519471	2025-06-19 17:04:13.519471	0	a_temps	0.00	2025-10-08 13:10:20.06687
536	110	75	0.00	2025-10-03 09:56:08.78283	2025-10-03 09:56:08.78283	31	manque	16000.00	2025-10-08 13:10:20.06687
537	113	78	419732.11	2025-05-09 09:17:22.129783	2025-05-09 09:17:22.129783	0	a_temps	0.00	2025-10-08 13:10:20.06687
538	117	82	214911.23	2025-10-06 17:40:29.815255	2025-10-06 17:40:29.815255	0	a_temps	0.00	2025-10-08 13:10:20.06687
539	118	83	0.00	2025-05-06 01:54:51.113866	2025-05-06 01:54:51.113866	54	manque	27000.00	2025-10-08 13:10:20.06687
540	118	83	0.00	2025-06-05 01:54:51.113866	2025-06-05 01:54:51.113866	77	manque	30000.00	2025-10-08 13:10:20.06687
541	119	84	0.00	2025-10-06 23:50:07.204611	2025-10-06 23:50:07.204611	66	manque	20500.00	2025-10-08 13:10:20.06687
542	119	84	0.00	2025-11-05 23:50:07.204611	2025-11-05 23:50:07.204611	88	manque	31500.00	2025-10-08 13:10:20.06687
543	119	84	0.00	2025-12-05 23:50:07.204611	2025-12-05 23:50:07.204611	71	manque	28000.00	2025-10-08 13:10:20.06687
544	120	85	0.00	2025-07-10 00:34:19.986358	2025-07-10 00:34:19.986358	34	manque	44000.00	2025-10-08 13:10:20.06687
545	120	85	0.00	2025-08-09 00:34:19.986358	2025-08-09 00:34:19.986358	46	manque	36500.00	2025-10-08 13:10:20.06687
546	121	86	155368.92	2025-05-26 20:28:22.712225	2025-05-26 20:28:22.712225	0	a_temps	0.00	2025-10-08 13:10:20.06687
547	123	88	305505.03	2025-05-29 16:15:26.080859	2025-05-29 16:15:26.080859	0	a_temps	0.00	2025-10-08 13:10:20.06687
548	126	75	0.00	2025-10-16 01:17:08.112315	2025-10-16 01:17:08.112315	48	manque	19500.00	2025-10-08 13:10:20.06687
549	127	76	0.00	2025-09-14 20:57:07.072737	2025-09-14 20:57:07.072737	57	manque	20000.00	2025-10-08 13:10:20.06687
550	127	76	0.00	2025-10-14 20:57:07.072737	2025-10-14 20:57:07.072737	64	manque	18000.00	2025-10-08 13:10:20.06687
551	127	76	0.00	2025-11-13 20:57:07.072737	2025-11-13 20:57:07.072737	74	manque	40500.00	2025-10-08 13:10:20.06687
552	128	77	0.00	2025-10-31 10:04:35.604583	2025-10-31 10:04:35.604583	66	manque	29500.00	2025-10-08 13:10:20.06687
553	128	77	0.00	2025-11-30 10:04:35.604583	2025-11-30 10:04:35.604583	71	manque	34000.00	2025-10-08 13:10:20.06687
554	128	77	0.00	2025-12-30 10:04:35.604583	2025-12-30 10:04:35.604583	51	manque	26500.00	2025-10-08 13:10:20.06687
555	129	78	0.00	2025-10-08 10:24:50.127478	2025-10-08 10:24:50.127478	84	manque	41500.00	2025-10-08 13:10:20.06687
556	130	79	0.00	2025-10-31 08:22:32.000441	2025-10-31 08:22:32.000441	40	manque	23000.00	2025-10-08 13:10:20.06687
557	130	79	0.00	2025-11-30 08:22:32.000441	2025-11-30 08:22:32.000441	45	manque	37000.00	2025-10-08 13:10:20.06687
558	131	80	0.00	2025-10-19 18:58:47.02583	2025-10-19 18:58:47.02583	39	manque	28000.00	2025-10-08 13:10:20.06687
559	131	80	0.00	2025-11-18 18:58:47.02583	2025-11-18 18:58:47.02583	31	manque	18500.00	2025-10-08 13:10:20.06687
560	132	81	0.00	2025-10-14 06:52:39.689084	2025-10-14 06:52:39.689084	57	manque	32500.00	2025-10-08 13:10:20.06687
561	132	81	0.00	2025-11-13 06:52:39.689084	2025-11-13 06:52:39.689084	34	manque	21500.00	2025-10-08 13:10:20.06687
562	132	81	0.00	2025-12-13 06:52:39.689084	2025-12-13 06:52:39.689084	36	manque	32000.00	2025-10-08 13:10:20.06687
563	133	82	0.00	2025-09-12 19:28:30.662871	2025-09-12 19:28:30.662871	65	manque	26500.00	2025-10-08 13:10:20.06687
564	133	82	0.00	2025-10-12 19:28:30.662871	2025-10-12 19:28:30.662871	60	manque	42000.00	2025-10-08 13:10:20.06687
565	134	83	0.00	2025-10-14 09:20:08.408359	2025-10-14 09:20:08.408359	34	manque	42500.00	2025-10-08 13:10:20.06687
566	134	83	0.00	2025-11-13 09:20:08.408359	2025-11-13 09:20:08.408359	59	manque	27500.00	2025-10-08 13:10:20.06687
567	134	83	0.00	2025-12-13 09:20:08.408359	2025-12-13 09:20:08.408359	53	manque	21500.00	2025-10-08 13:10:20.06687
568	135	84	0.00	2025-09-27 07:20:12.841113	2025-09-27 07:20:12.841113	35	manque	19000.00	2025-10-08 13:10:20.06687
569	135	84	0.00	2025-10-27 07:20:12.841113	2025-10-27 07:20:12.841113	78	manque	41000.00	2025-10-08 13:10:20.06687
570	136	85	0.00	2025-09-12 04:20:37.16385	2025-09-12 04:20:37.16385	74	manque	42000.00	2025-10-08 13:10:20.06687
571	136	85	0.00	2025-10-12 04:20:37.16385	2025-10-12 04:20:37.16385	30	manque	38500.00	2025-10-08 13:10:20.06687
572	137	91	0.00	2025-10-26 18:13:25.415486	2025-10-26 18:13:25.415486	82	manque	27500.00	2025-10-08 13:10:20.06687
573	137	91	0.00	2025-11-25 18:13:25.415486	2025-11-25 18:13:25.415486	85	manque	24500.00	2025-10-08 13:10:20.06687
574	137	91	0.00	2025-12-25 18:13:25.415486	2025-12-25 18:13:25.415486	72	manque	27500.00	2025-10-08 13:10:20.06687
575	138	92	0.00	2025-08-03 01:19:54.583987	2025-08-03 01:19:54.583987	70	manque	22500.00	2025-10-08 13:10:20.06687
576	138	92	0.00	2025-09-02 01:19:54.583987	2025-09-02 01:19:54.583987	31	manque	26500.00	2025-10-08 13:10:20.06687
577	138	92	0.00	2025-10-02 01:19:54.583987	2025-10-02 01:19:54.583987	30	manque	38500.00	2025-10-08 13:10:20.06687
578	139	93	0.00	2025-08-08 04:12:41.469997	2025-08-08 04:12:41.469997	67	manque	26000.00	2025-10-08 13:10:20.06687
579	139	93	0.00	2025-09-07 04:12:41.469997	2025-09-07 04:12:41.469997	61	manque	23500.00	2025-10-08 13:10:20.06687
580	140	94	0.00	2025-10-28 06:19:44.735625	2025-10-28 06:19:44.735625	87	manque	30500.00	2025-10-08 13:10:20.06687
581	141	95	0.00	2025-06-04 21:48:14.128286	2025-06-04 21:48:14.128286	78	manque	25000.00	2025-10-08 13:10:20.06687
582	141	95	0.00	2025-07-04 21:48:14.128286	2025-07-04 21:48:14.128286	61	manque	17500.00	2025-10-08 13:10:20.06687
583	142	96	0.00	2025-07-25 05:53:19.60818	2025-07-25 05:53:19.60818	35	manque	19000.00	2025-10-08 13:10:20.06687
584	142	96	0.00	2025-08-24 05:53:19.60818	2025-08-24 05:53:19.60818	30	manque	34000.00	2025-10-08 13:10:20.06687
585	143	97	0.00	2025-06-17 13:10:01.589228	2025-06-17 13:10:01.589228	39	manque	25500.00	2025-10-08 13:10:20.06687
586	143	97	0.00	2025-07-17 13:10:01.589228	2025-07-17 13:10:01.589228	70	manque	28500.00	2025-10-08 13:10:20.06687
587	144	98	0.00	2025-09-11 16:59:35.541902	2025-09-11 16:59:35.541902	83	manque	36000.00	2025-10-08 13:10:20.06687
588	144	98	0.00	2025-10-11 16:59:35.541902	2025-10-11 16:59:35.541902	86	manque	19500.00	2025-10-08 13:10:20.06687
589	144	98	0.00	2025-11-10 16:59:35.541902	2025-11-10 16:59:35.541902	36	manque	43500.00	2025-10-08 13:10:20.06687
590	145	99	0.00	2025-10-08 14:57:39.559141	2025-10-08 14:57:39.559141	61	manque	15000.00	2025-10-08 13:10:20.06687
591	145	99	0.00	2025-11-07 14:57:39.559141	2025-11-07 14:57:39.559141	60	manque	28500.00	2025-10-08 13:10:20.06687
592	145	99	0.00	2025-12-07 14:57:39.559141	2025-12-07 14:57:39.559141	67	manque	25000.00	2025-10-08 13:10:20.06687
593	146	91	0.00	2025-10-17 18:09:25.729052	2025-10-17 18:09:25.729052	37	manque	33000.00	2025-10-08 13:10:20.06687
594	146	91	0.00	2025-11-16 18:09:25.729052	2025-11-16 18:09:25.729052	81	manque	31000.00	2025-10-08 13:10:20.06687
595	147	92	0.00	2025-10-15 14:44:24.718995	2025-10-15 14:44:24.718995	32	manque	36000.00	2025-10-08 13:10:20.06687
596	147	92	0.00	2025-11-14 14:44:24.718995	2025-11-14 14:44:24.718995	79	manque	22000.00	2025-10-08 13:10:20.06687
597	147	92	0.00	2025-12-14 14:44:24.718995	2025-12-14 14:44:24.718995	82	manque	17000.00	2025-10-08 13:10:20.06687
598	148	93	0.00	2025-10-12 23:18:48.980555	2025-10-12 23:18:48.980555	33	manque	37000.00	2025-10-08 13:10:20.06687
599	149	94	0.00	2025-10-06 16:06:12.807148	2025-10-06 16:06:12.807148	51	manque	33000.00	2025-10-08 13:10:20.06687
600	149	94	0.00	2025-11-05 16:06:12.807148	2025-11-05 16:06:12.807148	47	manque	41000.00	2025-10-08 13:10:20.06687
601	149	94	0.00	2025-12-05 16:06:12.807148	2025-12-05 16:06:12.807148	38	manque	44500.00	2025-10-08 13:10:20.06687
602	150	95	0.00	2025-09-24 23:38:18.149877	2025-09-24 23:38:18.149877	66	manque	25000.00	2025-10-08 13:10:20.06687
603	154	2	1893726.71	2025-03-02 01:20:13.945684	2025-03-02 01:20:13.945684	0	a_temps	0.00	2025-10-08 13:10:20.06687
604	155	3	1592910.07	2025-10-06 10:42:40.292566	2025-10-06 10:42:40.292566	0	a_temps	0.00	2025-10-08 13:10:20.06687
605	158	6	741147.31	2025-09-03 23:35:08.967933	2025-09-03 23:35:08.967933	0	a_temps	0.00	2025-10-08 13:10:20.06687
606	162	10	1288238.10	2025-02-05 01:34:17.908017	2025-02-05 01:34:17.908017	0	a_temps	0.00	2025-10-08 13:10:20.06687
607	163	11	917321.06	2025-05-07 13:13:26.292954	2025-05-07 13:13:26.292954	0	a_temps	0.00	2025-10-08 13:10:20.06687
608	164	12	1350047.73	2025-03-01 05:54:06.039785	2025-03-01 05:54:06.039785	0	a_temps	0.00	2025-10-08 13:10:20.06687
609	166	14	772848.80	2025-03-16 06:56:41.258545	2025-03-16 06:56:41.258545	0	a_temps	0.00	2025-10-08 13:10:20.06687
610	169	17	1999513.88	2024-11-09 16:13:32.067609	2024-11-09 16:13:32.067609	0	a_temps	0.00	2025-10-08 13:10:20.06687
611	170	18	863082.68	2025-03-30 11:59:14.361844	2025-03-30 11:59:14.361844	0	a_temps	0.00	2025-10-08 13:10:20.06687
612	170	18	853267.88	2025-04-29 11:59:14.361844	2025-04-29 11:59:14.361844	0	a_temps	0.00	2025-10-08 13:10:20.06687
613	171	19	988630.58	2025-09-09 11:29:59.631341	2025-09-09 11:29:59.631341	0	a_temps	0.00	2025-10-08 13:10:20.06687
614	173	21	969825.36	2025-10-26 05:39:42.903026	2025-10-26 05:39:42.903026	0	a_temps	0.00	2025-10-08 13:10:20.06687
615	173	21	964936.49	2025-11-25 05:39:42.903026	2025-11-25 05:39:42.903026	0	a_temps	0.00	2025-10-08 13:10:20.06687
616	174	22	1598264.66	2025-02-13 19:17:46.580018	2025-02-13 19:17:46.580018	0	a_temps	0.00	2025-10-08 13:10:20.06687
617	175	23	1792198.27	2024-11-07 19:44:56.120699	2024-11-07 19:44:56.120699	0	a_temps	0.00	2025-10-08 13:10:20.06687
618	176	24	669970.11	2025-09-29 13:59:37.352366	2025-09-29 13:59:37.352366	0	a_temps	0.00	2025-10-08 13:10:20.06687
619	177	25	1485342.06	2024-12-05 23:04:48.666433	2024-12-05 23:04:48.666433	0	a_temps	0.00	2025-10-08 13:10:20.06687
620	178	26	1758661.67	2025-03-26 08:16:30.002958	2025-03-26 08:16:30.002958	0	a_temps	0.00	2025-10-08 13:10:20.06687
621	180	28	268599.76	2025-07-13 07:54:00.711522	2025-07-13 07:54:00.711522	0	a_temps	0.00	2025-10-08 13:10:20.06687
622	180	28	282691.55	2025-08-12 07:54:00.711522	2025-08-12 07:54:00.711522	0	a_temps	0.00	2025-10-08 13:10:20.06687
623	181	29	469520.06	2025-06-29 03:47:53.248854	2025-06-02 03:47:53.248854	27	en_retard	13500.00	2025-10-08 13:10:20.06687
624	182	30	1685358.37	2024-11-19 22:44:47.076308	2024-11-19 22:44:47.076308	0	a_temps	0.00	2025-10-08 13:10:20.06687
625	198	31	305217.76	2025-03-12 20:06:02.921049	2025-03-12 20:06:02.921049	0	a_temps	0.00	2025-10-08 13:10:20.06687
626	199	32	0.00	2025-09-30 22:07:07.742804	2025-09-30 22:07:07.742804	37	manque	15500.00	2025-10-08 13:10:20.06687
627	199	32	0.00	2025-10-30 22:07:07.742804	2025-10-30 22:07:07.742804	61	manque	29000.00	2025-10-08 13:10:20.06687
628	199	32	0.00	2025-11-29 22:07:07.742804	2025-11-29 22:07:07.742804	39	manque	28000.00	2025-10-08 13:10:20.06687
629	200	33	309843.93	2025-07-07 08:55:46.807153	2025-07-07 08:55:46.807153	0	a_temps	0.00	2025-10-08 13:10:20.06687
630	200	33	284866.82	2025-08-06 08:55:46.807153	2025-08-06 08:55:46.807153	0	a_temps	0.00	2025-10-08 13:10:20.06687
631	201	34	630969.69	2025-06-16 03:56:44.848258	2025-06-16 03:56:44.848258	0	a_temps	0.00	2025-10-08 13:10:20.06687
632	202	35	726405.20	2025-08-20 03:54:18.545097	2025-08-20 03:54:18.545097	0	a_temps	0.00	2025-10-08 13:10:20.06687
633	203	36	404432.75	2025-03-10 17:42:56.309995	2025-03-10 17:42:56.309995	0	a_temps	0.00	2025-10-08 13:10:20.06687
634	203	36	386126.41	2025-04-09 17:42:56.309995	2025-04-09 17:42:56.309995	0	a_temps	0.00	2025-10-08 13:10:20.06687
635	205	38	240849.21	2025-10-31 19:01:52.706657	2025-10-31 19:01:52.706657	0	a_temps	0.00	2025-10-08 13:10:20.06687
636	206	39	251323.89	2025-06-11 22:07:54.217049	2025-06-11 22:07:54.217049	0	a_temps	0.00	2025-10-08 13:10:20.06687
637	207	40	154903.87	2025-03-28 23:26:38.623615	2025-03-28 23:26:38.623615	0	a_temps	0.00	2025-10-08 13:10:20.06687
638	207	40	145148.79	2025-04-27 23:26:38.623615	2025-04-27 23:26:38.623615	0	a_temps	0.00	2025-10-08 13:10:20.06687
639	208	41	422011.56	2025-09-21 12:47:59.478487	2025-09-21 12:47:59.478487	0	a_temps	0.00	2025-10-08 13:10:20.06687
640	208	41	358061.01	2025-10-21 12:47:59.478487	2025-10-21 12:47:59.478487	0	a_temps	0.00	2025-10-08 13:10:20.06687
641	209	42	563909.78	2025-04-22 06:06:55.908109	2025-04-22 06:06:55.908109	0	a_temps	0.00	2025-10-08 13:10:20.06687
642	210	43	412308.34	2025-03-27 06:00:13.149166	2025-03-27 06:00:13.149166	0	a_temps	0.00	2025-10-08 13:10:20.06687
643	213	46	139114.53	2025-09-13 21:04:59.506656	2025-09-13 21:04:59.506656	0	a_temps	0.00	2025-10-08 13:10:20.06687
644	213	46	137313.69	2025-10-13 21:04:59.506656	2025-10-13 21:04:59.506656	0	a_temps	0.00	2025-10-08 13:10:20.06687
645	214	47	701717.00	2025-03-27 03:57:06.601345	2025-03-27 03:57:06.601345	0	a_temps	0.00	2025-10-08 13:10:20.06687
646	215	48	131915.19	2025-07-10 16:17:37.498812	2025-07-10 16:17:37.498812	0	a_temps	0.00	2025-10-08 13:10:20.06687
647	215	48	147654.68	2025-08-09 16:17:37.498812	2025-08-09 16:17:37.498812	0	a_temps	0.00	2025-10-08 13:10:20.06687
648	216	49	272733.62	2025-10-28 19:06:04.133723	2025-10-28 19:06:04.133723	0	a_temps	0.00	2025-10-08 13:10:20.06687
649	216	49	243877.43	2025-11-27 19:06:04.133723	2025-11-27 19:06:04.133723	0	a_temps	0.00	2025-10-08 13:10:20.06687
650	217	50	133945.97	2025-06-03 14:31:22.087513	2025-06-03 14:31:22.087513	0	a_temps	0.00	2025-10-08 13:10:20.06687
651	218	51	0.00	2025-04-23 14:00:45.322934	2025-04-23 14:00:45.322934	42	manque	23000.00	2025-10-08 13:10:20.06687
652	218	51	0.00	2025-05-23 14:00:45.322934	2025-05-23 14:00:45.322934	86	manque	20500.00	2025-10-08 13:10:20.06687
653	218	51	0.00	2025-06-22 14:00:45.322934	2025-06-22 14:00:45.322934	33	manque	40500.00	2025-10-08 13:10:20.06687
654	219	52	296377.39	2025-06-27 06:00:31.050725	2025-06-27 06:00:31.050725	0	a_temps	0.00	2025-10-08 13:10:20.06687
655	219	52	296675.40	2025-07-27 06:00:31.050725	2025-07-27 06:00:31.050725	0	a_temps	0.00	2025-10-08 13:10:20.06687
656	220	53	397169.52	2025-05-09 13:38:25.840898	2025-05-09 13:38:25.840898	0	a_temps	0.00	2025-10-08 13:10:20.06687
657	221	54	303454.87	2025-09-20 23:06:59.633516	2025-09-20 23:06:59.633516	0	a_temps	0.00	2025-10-08 13:10:20.06687
658	222	55	826312.60	2025-06-25 15:23:50.705404	2025-06-25 15:23:50.705404	0	a_temps	0.00	2025-10-08 13:10:20.06687
659	223	56	237876.86	2025-05-30 03:12:12.818223	2025-05-30 03:12:12.818223	0	a_temps	0.00	2025-10-08 13:10:20.06687
660	223	56	230040.35	2025-06-29 03:12:12.818223	2025-06-29 03:12:12.818223	0	a_temps	0.00	2025-10-08 13:10:20.06687
661	224	57	209535.27	2025-02-23 04:42:56.962178	2025-02-23 04:42:56.962178	0	a_temps	0.00	2025-10-08 13:10:20.06687
662	224	57	208041.72	2025-03-25 04:42:56.962178	2025-03-25 04:42:56.962178	0	a_temps	0.00	2025-10-08 13:10:20.06687
663	226	59	123739.39	2025-09-14 14:01:01.777026	2025-09-14 14:01:01.777026	0	a_temps	0.00	2025-10-08 13:10:20.06687
664	227	60	138966.35	2025-03-20 10:58:49.959473	2025-03-20 10:58:49.959473	0	a_temps	0.00	2025-10-08 13:10:20.06687
665	228	61	341577.86	2025-03-20 08:01:56.630862	2025-03-20 08:01:56.630862	0	a_temps	0.00	2025-10-08 13:10:20.06687
666	228	61	335649.22	2025-04-19 08:01:56.630862	2025-04-19 08:01:56.630862	0	a_temps	0.00	2025-10-08 13:10:20.06687
667	229	62	767249.94	2025-05-07 05:47:41.025357	2025-05-07 05:47:41.025357	0	a_temps	0.00	2025-10-08 13:10:20.06687
668	230	63	642571.72	2025-06-25 01:41:53.314779	2025-06-25 01:41:53.314779	0	a_temps	0.00	2025-10-08 13:10:20.06687
669	231	64	399941.55	2025-03-15 03:43:51.009966	2025-03-15 03:43:51.009966	0	a_temps	0.00	2025-10-08 13:10:20.06687
670	231	64	433601.89	2025-04-14 03:43:51.009966	2025-04-14 03:43:51.009966	0	a_temps	0.00	2025-10-08 13:10:20.06687
671	232	65	0.00	2025-10-13 23:22:39.923291	2025-10-13 23:22:39.923291	88	manque	21000.00	2025-10-08 13:10:20.06687
672	233	66	682711.71	2025-11-03 20:25:40.941004	2025-11-03 20:25:40.941004	0	a_temps	0.00	2025-10-08 13:10:20.06687
673	234	67	316573.18	2025-08-15 19:17:30.471015	2025-08-15 19:17:30.471015	0	a_temps	0.00	2025-10-08 13:10:20.06687
674	234	67	316680.32	2025-09-14 19:17:30.471015	2025-09-14 19:17:30.471015	0	a_temps	0.00	2025-10-08 13:10:20.06687
675	235	68	452525.48	2025-08-23 17:00:54.251441	2025-08-23 17:00:54.251441	0	a_temps	0.00	2025-10-08 13:10:20.06687
676	237	70	143308.17	2025-07-31 06:46:43.598782	2025-07-31 06:46:43.598782	0	a_temps	0.00	2025-10-08 13:10:20.06687
677	239	32	0.00	2025-08-08 22:41:17.909469	2025-08-08 22:41:17.909469	73	manque	37000.00	2025-10-08 13:10:20.06687
678	239	32	0.00	2025-09-07 22:41:17.909469	2025-09-07 22:41:17.909469	86	manque	37000.00	2025-10-08 13:10:20.06687
679	240	33	0.00	2025-09-01 18:01:24.529812	2025-09-01 18:01:24.529812	72	manque	44000.00	2025-10-08 13:10:20.06687
680	242	35	0.00	2025-08-08 21:03:43.525959	2025-08-08 21:03:43.525959	43	manque	32000.00	2025-10-08 13:10:20.06687
681	242	35	0.00	2025-09-07 21:03:43.525959	2025-09-07 21:03:43.525959	82	manque	16500.00	2025-10-08 13:10:20.06687
682	242	35	0.00	2025-10-07 21:03:43.525959	2025-10-07 21:03:43.525959	49	manque	38500.00	2025-10-08 13:10:20.06687
683	244	37	0.00	2025-08-14 11:53:18.465457	2025-08-14 11:53:18.465457	75	manque	44500.00	2025-10-08 13:10:20.06687
684	246	39	0.00	2025-09-15 13:41:28.304938	2025-09-15 13:41:28.304938	66	manque	39000.00	2025-10-08 13:10:20.06687
685	246	39	0.00	2025-10-15 13:41:28.304938	2025-10-15 13:41:28.304938	52	manque	28000.00	2025-10-08 13:10:20.06687
686	246	39	0.00	2025-11-14 13:41:28.304938	2025-11-14 13:41:28.304938	82	manque	20000.00	2025-10-08 13:10:20.06687
687	247	40	0.00	2025-09-06 01:16:56.541849	2025-09-06 01:16:56.541849	80	manque	44000.00	2025-10-08 13:10:20.06687
688	247	40	0.00	2025-10-06 01:16:56.541849	2025-10-06 01:16:56.541849	35	manque	26000.00	2025-10-08 13:10:20.06687
689	247	40	0.00	2025-11-05 01:16:56.541849	2025-11-05 01:16:56.541849	79	manque	18500.00	2025-10-08 13:10:20.06687
690	254	47	0.00	2025-08-26 06:24:46.987808	2025-08-26 06:24:46.987808	80	manque	38500.00	2025-10-08 13:10:20.06687
691	254	47	0.00	2025-09-25 06:24:46.987808	2025-09-25 06:24:46.987808	59	manque	34500.00	2025-10-08 13:10:20.06687
692	254	47	0.00	2025-10-25 06:24:46.987808	2025-10-25 06:24:46.987808	84	manque	25000.00	2025-10-08 13:10:20.06687
693	256	49	0.00	2025-08-13 01:33:30.67993	2025-08-13 01:33:30.67993	58	manque	30000.00	2025-10-08 13:10:20.06687
694	256	49	0.00	2025-09-12 01:33:30.67993	2025-09-12 01:33:30.67993	36	manque	24500.00	2025-10-08 13:10:20.06687
695	256	49	0.00	2025-10-12 01:33:30.67993	2025-10-12 01:33:30.67993	36	manque	17000.00	2025-10-08 13:10:20.06687
696	259	72	0.00	2025-06-30 10:52:36.483881	2025-06-30 10:52:36.483881	57	manque	24000.00	2025-10-08 13:10:20.06687
697	259	72	0.00	2025-07-30 10:52:36.483881	2025-07-30 10:52:36.483881	54	manque	28000.00	2025-10-08 13:10:20.06687
698	260	73	0.00	2025-09-27 18:01:10.322424	2025-09-27 18:01:10.322424	61	manque	34500.00	2025-10-08 13:10:20.06687
699	260	73	0.00	2025-10-27 18:01:10.322424	2025-10-27 18:01:10.322424	48	manque	39500.00	2025-10-08 13:10:20.06687
700	261	74	387519.87	2025-09-02 18:07:45.835537	2025-09-02 18:07:45.835537	0	a_temps	0.00	2025-10-08 13:10:20.06687
701	263	76	296051.17	2025-05-29 07:35:35.753571	2025-05-29 07:35:35.753571	0	a_temps	0.00	2025-10-08 13:10:20.06687
702	264	77	376785.64	2025-11-05 09:34:47.497436	2025-11-05 09:34:47.497436	0	a_temps	0.00	2025-10-08 13:10:20.06687
703	266	79	0.00	2025-04-25 10:33:40.604655	2025-04-25 10:33:40.604655	64	manque	16000.00	2025-10-08 13:10:20.06687
704	266	79	0.00	2025-05-25 10:33:40.604655	2025-05-25 10:33:40.604655	80	manque	35000.00	2025-10-08 13:10:20.06687
705	267	80	318525.63	2025-05-03 21:32:21.659364	2025-05-03 21:32:21.659364	0	a_temps	0.00	2025-10-08 13:10:20.06687
706	268	81	191854.58	2025-06-22 02:17:07.092883	2025-06-22 02:17:07.092883	0	a_temps	0.00	2025-10-08 13:10:20.06687
707	270	83	0.00	2025-05-20 08:43:51.322165	2025-05-20 08:43:51.322165	89	manque	15000.00	2025-10-08 13:10:20.06687
708	270	83	0.00	2025-06-19 08:43:51.322165	2025-06-19 08:43:51.322165	41	manque	38500.00	2025-10-08 13:10:20.06687
709	270	83	0.00	2025-07-19 08:43:51.322165	2025-07-19 08:43:51.322165	53	manque	19500.00	2025-10-08 13:10:20.06687
710	271	84	0.00	2025-04-26 12:45:57.45702	2025-04-26 12:45:57.45702	45	manque	17000.00	2025-10-08 13:10:20.06687
711	271	84	0.00	2025-05-26 12:45:57.45702	2025-05-26 12:45:57.45702	75	manque	36000.00	2025-10-08 13:10:20.06687
712	271	84	0.00	2025-06-25 12:45:57.45702	2025-06-25 12:45:57.45702	86	manque	36500.00	2025-10-08 13:10:20.06687
713	273	86	147434.57	2025-07-23 00:17:14.201406	2025-07-23 00:17:14.201406	0	a_temps	0.00	2025-10-08 13:10:20.06687
714	274	87	149035.30	2025-07-22 07:17:46.287444	2025-07-22 07:17:46.287444	0	a_temps	0.00	2025-10-08 13:10:20.06687
715	277	90	286067.73	2025-10-14 07:34:27.490849	2025-10-14 07:34:27.490849	0	a_temps	0.00	2025-10-08 13:10:20.06687
716	278	75	0.00	2025-10-10 07:18:39.329185	2025-10-10 07:18:39.329185	83	manque	40000.00	2025-10-08 13:10:20.06687
717	278	75	0.00	2025-11-09 07:18:39.329185	2025-11-09 07:18:39.329185	69	manque	22500.00	2025-10-08 13:10:20.06687
718	279	76	0.00	2025-10-03 17:04:19.304655	2025-10-03 17:04:19.304655	66	manque	17000.00	2025-10-08 13:10:20.06687
719	280	77	0.00	2025-11-04 09:24:53.236521	2025-11-04 09:24:53.236521	50	manque	40500.00	2025-10-08 13:10:20.06687
720	281	78	0.00	2025-10-30 14:56:14.57365	2025-10-30 14:56:14.57365	82	manque	35500.00	2025-10-08 13:10:20.06687
721	281	78	0.00	2025-11-29 14:56:14.57365	2025-11-29 14:56:14.57365	32	manque	25500.00	2025-10-08 13:10:20.06687
722	281	78	0.00	2025-12-29 14:56:14.57365	2025-12-29 14:56:14.57365	80	manque	44500.00	2025-10-08 13:10:20.06687
723	282	79	0.00	2025-10-13 09:35:35.929705	2025-10-13 09:35:35.929705	56	manque	39500.00	2025-10-08 13:10:20.06687
724	282	79	0.00	2025-11-12 09:35:35.929705	2025-11-12 09:35:35.929705	49	manque	19000.00	2025-10-08 13:10:20.06687
725	283	80	0.00	2025-10-15 23:59:34.752839	2025-10-15 23:59:34.752839	81	manque	36500.00	2025-10-08 13:10:20.06687
726	283	80	0.00	2025-11-14 23:59:34.752839	2025-11-14 23:59:34.752839	41	manque	42000.00	2025-10-08 13:10:20.06687
727	283	80	0.00	2025-12-14 23:59:34.752839	2025-12-14 23:59:34.752839	35	manque	29500.00	2025-10-08 13:10:20.06687
728	284	81	0.00	2025-09-21 03:39:52.461098	2025-09-21 03:39:52.461098	86	manque	41500.00	2025-10-08 13:10:20.06687
729	285	82	0.00	2025-11-01 22:56:19.179959	2025-11-01 22:56:19.179959	58	manque	35500.00	2025-10-08 13:10:20.06687
730	285	82	0.00	2025-12-01 22:56:19.179959	2025-12-01 22:56:19.179959	79	manque	23000.00	2025-10-08 13:10:20.06687
731	286	83	0.00	2025-10-10 06:16:04.263588	2025-10-10 06:16:04.263588	50	manque	43500.00	2025-10-08 13:10:20.06687
732	286	83	0.00	2025-11-09 06:16:04.263588	2025-11-09 06:16:04.263588	47	manque	22000.00	2025-10-08 13:10:20.06687
733	286	83	0.00	2025-12-09 06:16:04.263588	2025-12-09 06:16:04.263588	33	manque	34500.00	2025-10-08 13:10:20.06687
734	287	84	0.00	2025-10-29 04:09:12.163099	2025-10-29 04:09:12.163099	61	manque	32000.00	2025-10-08 13:10:20.06687
735	287	84	0.00	2025-11-28 04:09:12.163099	2025-11-28 04:09:12.163099	45	manque	33500.00	2025-10-08 13:10:20.06687
736	287	84	0.00	2025-12-28 04:09:12.163099	2025-12-28 04:09:12.163099	60	manque	33500.00	2025-10-08 13:10:20.06687
737	288	85	0.00	2025-09-16 16:14:13.231367	2025-09-16 16:14:13.231367	33	manque	33000.00	2025-10-08 13:10:20.06687
738	288	85	0.00	2025-10-16 16:14:13.231367	2025-10-16 16:14:13.231367	56	manque	25500.00	2025-10-08 13:10:20.06687
739	289	91	0.00	2025-10-14 20:46:56.749633	2025-10-14 20:46:56.749633	61	manque	36000.00	2025-10-08 13:10:20.06687
740	289	91	0.00	2025-11-13 20:46:56.749633	2025-11-13 20:46:56.749633	48	manque	20000.00	2025-10-08 13:10:20.06687
741	290	92	0.00	2025-05-20 22:14:04.079489	2025-05-20 22:14:04.079489	75	manque	42500.00	2025-10-08 13:10:20.06687
742	291	93	0.00	2025-07-23 19:13:33.218707	2025-07-23 19:13:33.218707	68	manque	37000.00	2025-10-08 13:10:20.06687
743	291	93	0.00	2025-08-22 19:13:33.218707	2025-08-22 19:13:33.218707	75	manque	30500.00	2025-10-08 13:10:20.06687
744	292	94	0.00	2025-06-25 17:04:15.487802	2025-06-25 17:04:15.487802	69	manque	24000.00	2025-10-08 13:10:20.06687
745	293	95	0.00	2025-06-07 09:05:12.045669	2025-06-07 09:05:12.045669	61	manque	28000.00	2025-10-08 13:10:20.06687
746	293	95	0.00	2025-07-07 09:05:12.045669	2025-07-07 09:05:12.045669	65	manque	38500.00	2025-10-08 13:10:20.06687
747	294	96	0.00	2025-06-10 11:54:57.553749	2025-06-10 11:54:57.553749	36	manque	16500.00	2025-10-08 13:10:20.06687
748	294	96	0.00	2025-07-10 11:54:57.553749	2025-07-10 11:54:57.553749	52	manque	29000.00	2025-10-08 13:10:20.06687
749	295	97	0.00	2025-07-10 12:22:13.47146	2025-07-10 12:22:13.47146	54	manque	22000.00	2025-10-08 13:10:20.06687
750	295	97	0.00	2025-08-09 12:22:13.47146	2025-08-09 12:22:13.47146	80	manque	15000.00	2025-10-08 13:10:20.06687
751	295	97	0.00	2025-09-08 12:22:13.47146	2025-09-08 12:22:13.47146	77	manque	23500.00	2025-10-08 13:10:20.06687
752	296	98	0.00	2025-08-08 01:07:12.621994	2025-08-08 01:07:12.621994	38	manque	37500.00	2025-10-08 13:10:20.06687
753	297	99	0.00	2025-08-21 07:42:54.138417	2025-08-21 07:42:54.138417	38	manque	36500.00	2025-10-08 13:10:20.06687
754	297	99	0.00	2025-09-20 07:42:54.138417	2025-09-20 07:42:54.138417	51	manque	32000.00	2025-10-08 13:10:20.06687
755	298	91	0.00	2025-10-25 12:48:30.693218	2025-10-25 12:48:30.693218	40	manque	33500.00	2025-10-08 13:10:20.06687
756	298	91	0.00	2025-11-24 12:48:30.693218	2025-11-24 12:48:30.693218	48	manque	31000.00	2025-10-08 13:10:20.06687
757	299	92	0.00	2025-09-13 05:03:49.536823	2025-09-13 05:03:49.536823	80	manque	28500.00	2025-10-08 13:10:20.06687
758	300	93	0.00	2025-08-19 06:29:31.694584	2025-08-19 06:29:31.694584	60	manque	31500.00	2025-10-08 13:10:20.06687
759	300	93	0.00	2025-09-18 06:29:31.694584	2025-09-18 06:29:31.694584	59	manque	30500.00	2025-10-08 13:10:20.06687
760	301	94	0.00	2025-09-26 05:12:52.4015	2025-09-26 05:12:52.4015	62	manque	28000.00	2025-10-08 13:10:20.06687
761	302	95	0.00	2025-10-30 11:06:27.046461	2025-10-30 11:06:27.046461	88	manque	25500.00	2025-10-08 13:10:20.06687
762	302	95	0.00	2025-11-29 11:06:27.046461	2025-11-29 11:06:27.046461	45	manque	15500.00	2025-10-08 13:10:20.06687
763	303	1	736518.84	2025-04-23 04:44:51.869444	2025-04-23 04:44:51.869444	0	a_temps	0.00	2025-10-08 13:10:20.06687
764	304	2	1407775.25	2025-03-01 17:59:10.324913	2025-03-01 17:59:10.324913	0	a_temps	0.00	2025-10-08 13:10:20.06687
765	305	3	644134.86	2025-10-12 08:01:28.949503	2025-10-12 08:01:28.949503	0	a_temps	0.00	2025-10-08 13:10:20.06687
766	305	3	707672.31	2025-11-11 08:01:28.949503	2025-11-11 08:01:28.949503	0	a_temps	0.00	2025-10-08 13:10:20.06687
767	305	3	725422.89	2025-12-11 08:01:28.949503	2025-12-11 08:01:28.949503	0	a_temps	0.00	2025-10-08 13:10:20.06687
768	307	5	1621597.81	2025-10-28 06:00:06.28043	2025-10-28 06:00:06.28043	0	a_temps	0.00	2025-10-08 13:10:20.06687
769	308	6	1526096.68	2024-12-29 16:47:36.03105	2024-12-29 16:47:36.03105	0	a_temps	0.00	2025-10-08 13:10:20.06687
770	309	7	1201147.14	2025-07-27 03:32:32.48014	2025-07-27 03:32:32.48014	0	a_temps	0.00	2025-10-08 13:10:20.06687
771	310	8	716808.29	2025-05-08 16:14:17.13258	2025-05-08 16:14:17.13258	0	a_temps	0.00	2025-10-08 13:10:20.06687
772	311	9	1884514.09	2025-04-06 03:54:04.533268	2025-04-06 03:54:04.533268	0	a_temps	0.00	2025-10-08 13:10:20.06687
773	314	12	332607.31	2025-10-08 20:53:46.582091	2025-10-08 20:53:46.582091	0	a_temps	0.00	2025-10-08 13:10:20.06687
774	315	13	1161597.18	2025-04-23 04:22:31.553147	2025-04-23 04:22:31.553147	0	a_temps	0.00	2025-10-08 13:10:20.06687
775	316	14	1573527.93	2024-11-26 17:15:01.506238	2024-11-26 17:15:01.506238	0	a_temps	0.00	2025-10-08 13:10:20.06687
776	319	17	1898417.85	2025-06-13 14:37:46.761816	2025-06-13 14:37:46.761816	0	a_temps	0.00	2025-10-08 13:10:20.06687
777	321	19	1815962.16	2025-09-14 10:11:45.172477	2025-09-14 10:11:45.172477	0	a_temps	0.00	2025-10-08 13:10:20.06687
778	322	20	1869484.73	2025-07-02 18:01:24.067672	2025-07-02 18:01:24.067672	0	a_temps	0.00	2025-10-08 13:10:20.06687
779	325	23	909386.75	2025-10-15 13:22:57.579181	2025-10-15 13:22:57.579181	0	a_temps	0.00	2025-10-08 13:10:20.06687
780	326	24	582561.90	2025-05-19 15:59:29.761404	2025-05-19 15:59:29.761404	0	a_temps	0.00	2025-10-08 13:10:20.06687
781	327	25	1695203.41	2024-11-21 05:18:49.116739	2024-11-21 05:18:49.116739	0	a_temps	0.00	2025-10-08 13:10:20.06687
782	330	28	867104.68	2025-10-27 15:58:15.133023	2025-10-27 15:58:15.133023	0	a_temps	0.00	2025-10-08 13:10:20.06687
783	331	29	953179.01	2025-06-16 04:37:28.566647	2025-06-16 04:37:28.566647	0	a_temps	0.00	2025-10-08 13:10:20.06687
784	332	30	462231.35	2025-03-10 06:16:07.067119	2025-03-10 06:16:07.067119	0	a_temps	0.00	2025-10-08 13:10:20.06687
785	332	30	469224.98	2025-04-09 06:16:07.067119	2025-04-09 06:16:07.067119	0	a_temps	0.00	2025-10-08 13:10:20.06687
786	348	31	349273.58	2025-04-14 10:56:23.348183	2025-04-14 10:56:23.348183	0	a_temps	0.00	2025-10-08 13:10:20.06687
787	348	31	357040.63	2025-05-14 10:56:23.348183	2025-05-14 10:56:23.348183	0	a_temps	0.00	2025-10-08 13:10:20.06687
788	351	34	157625.94	2025-08-16 14:28:50.641393	2025-08-16 14:28:50.641393	0	a_temps	0.00	2025-10-08 13:10:20.06687
789	353	36	227131.64	2025-07-24 11:10:16.040071	2025-07-24 11:10:16.040071	0	a_temps	0.00	2025-10-08 13:10:20.06687
790	353	36	230398.18	2025-08-23 11:10:16.040071	2025-08-23 11:10:16.040071	0	a_temps	0.00	2025-10-08 13:10:20.06687
791	354	37	163859.14	2025-03-25 17:05:06.773588	2025-03-25 17:05:06.773588	0	a_temps	0.00	2025-10-08 13:10:20.06687
792	354	37	175361.11	2025-04-24 17:05:06.773588	2025-04-24 17:05:06.773588	0	a_temps	0.00	2025-10-08 13:10:20.06687
793	356	39	301124.48	2025-02-20 05:45:51.264383	2025-02-20 05:45:51.264383	0	a_temps	0.00	2025-10-08 13:10:20.06687
794	356	39	277772.51	2025-03-22 05:45:51.264383	2025-03-22 05:45:51.264383	0	a_temps	0.00	2025-10-08 13:10:20.06687
795	357	40	0.00	2025-06-15 10:29:10.666606	2025-06-15 10:29:10.666606	47	manque	35500.00	2025-10-08 13:10:20.06687
796	357	40	0.00	2025-07-15 10:29:10.666606	2025-07-15 10:29:10.666606	54	manque	36000.00	2025-10-08 13:10:20.06687
797	358	41	696768.05	2025-02-27 04:23:50.296983	2025-02-27 04:23:50.296983	0	a_temps	0.00	2025-10-08 13:10:20.06687
798	359	42	760422.35	2025-05-01 10:40:55.764834	2025-05-01 10:40:55.764834	0	a_temps	0.00	2025-10-08 13:10:20.06687
799	360	43	788698.98	2025-05-19 05:03:53.677861	2025-05-19 05:03:53.677861	0	a_temps	0.00	2025-10-08 13:10:20.06687
800	362	45	172994.34	2025-10-17 11:33:47.518346	2025-10-17 11:33:47.518346	0	a_temps	0.00	2025-10-08 13:10:20.06687
801	363	46	584469.63	2025-05-24 05:41:44.110171	2025-05-24 05:41:44.110171	0	a_temps	0.00	2025-10-08 13:10:20.06687
802	367	50	0.00	2025-09-08 22:17:20.459881	2025-09-08 22:17:20.459881	71	manque	43000.00	2025-10-08 13:10:20.06687
803	368	51	501425.08	2025-07-23 11:13:06.623158	2025-07-23 11:13:06.623158	0	a_temps	0.00	2025-10-08 13:10:20.06687
804	369	52	480076.53	2025-03-19 09:44:21.913472	2025-03-19 09:44:21.913472	0	a_temps	0.00	2025-10-08 13:10:20.06687
805	370	53	231601.93	2025-08-16 18:21:35.848979	2025-08-16 18:21:35.848979	0	a_temps	0.00	2025-10-08 13:10:20.06687
806	371	54	606632.36	2025-03-07 07:25:15.169202	2025-03-07 07:25:15.169202	0	a_temps	0.00	2025-10-08 13:10:20.06687
807	373	56	310552.05	2025-07-03 10:29:40.681486	2025-05-13 10:29:40.681486	51	en_retard	25500.00	2025-10-08 13:10:20.06687
808	373	56	0.00	2025-06-12 10:29:40.681486	2025-06-12 10:29:40.681486	47	manque	32000.00	2025-10-08 13:10:20.06687
809	373	56	0.00	2025-07-12 10:29:40.681486	2025-07-12 10:29:40.681486	88	manque	22000.00	2025-10-08 13:10:20.06687
810	374	57	223173.06	2025-03-24 05:09:38.203793	2025-03-24 05:09:38.203793	0	a_temps	0.00	2025-10-08 13:10:20.06687
811	374	57	241141.60	2025-04-23 05:09:38.203793	2025-04-23 05:09:38.203793	0	a_temps	0.00	2025-10-08 13:10:20.06687
812	375	58	443762.62	2025-03-03 22:43:18.971251	2025-03-03 22:43:18.971251	0	a_temps	0.00	2025-10-08 13:10:20.06687
813	375	58	425195.90	2025-04-02 22:43:18.971251	2025-04-02 22:43:18.971251	0	a_temps	0.00	2025-10-08 13:10:20.06687
814	377	60	187633.39	2025-03-29 07:59:31.595964	2025-03-29 07:59:31.595964	0	a_temps	0.00	2025-10-08 13:10:20.06687
815	378	61	426313.31	2025-07-15 15:27:52.054918	2025-07-15 15:27:52.054918	0	a_temps	0.00	2025-10-08 13:10:20.06687
816	379	62	183362.66	2025-10-02 01:36:15.51739	2025-10-02 01:36:15.51739	0	a_temps	0.00	2025-10-08 13:10:20.06687
817	381	64	382614.55	2025-06-17 14:23:37.235033	2025-06-17 14:23:37.235033	0	a_temps	0.00	2025-10-08 13:10:20.06687
818	381	64	371043.18	2025-07-17 14:23:37.235033	2025-07-17 14:23:37.235033	0	a_temps	0.00	2025-10-08 13:10:20.06687
819	382	65	160657.91	2025-08-19 08:01:36.975096	2025-08-19 08:01:36.975096	0	a_temps	0.00	2025-10-08 13:10:20.06687
820	385	68	244073.29	2025-06-05 00:27:02.581059	2025-06-05 00:27:02.581059	0	a_temps	0.00	2025-10-08 13:10:20.06687
821	387	70	196358.52	2025-09-20 12:23:33.600008	2025-09-20 12:23:33.600008	0	a_temps	0.00	2025-10-08 13:10:20.06687
822	393	36	0.00	2025-07-15 11:27:15.709042	2025-07-15 11:27:15.709042	53	manque	37500.00	2025-10-08 13:10:20.06687
823	393	36	0.00	2025-08-14 11:27:15.709042	2025-08-14 11:27:15.709042	46	manque	30500.00	2025-10-08 13:10:20.06687
824	394	37	0.00	2025-10-10 10:12:22.451653	2025-10-10 10:12:22.451653	56	manque	22000.00	2025-10-08 13:10:20.06687
825	394	37	0.00	2025-11-09 10:12:22.451653	2025-11-09 10:12:22.451653	65	manque	37000.00	2025-10-08 13:10:20.06687
826	395	38	0.00	2025-08-12 23:40:28.097997	2025-08-12 23:40:28.097997	60	manque	37500.00	2025-10-08 13:10:20.06687
827	395	38	0.00	2025-09-11 23:40:28.097997	2025-09-11 23:40:28.097997	85	manque	15500.00	2025-10-08 13:10:20.06687
828	397	40	0.00	2025-08-21 02:36:29.329856	2025-08-21 02:36:29.329856	38	manque	15000.00	2025-10-08 13:10:20.06687
829	398	41	0.00	2025-09-04 16:21:39.230438	2025-09-04 16:21:39.230438	53	manque	30500.00	2025-10-08 13:10:20.06687
830	400	43	0.00	2025-08-04 11:36:42.487658	2025-08-04 11:36:42.487658	66	manque	25000.00	2025-10-08 13:10:20.06687
831	400	43	0.00	2025-09-03 11:36:42.487658	2025-09-03 11:36:42.487658	42	manque	35000.00	2025-10-08 13:10:20.06687
832	401	44	0.00	2025-09-08 18:54:36.826098	2025-09-08 18:54:36.826098	51	manque	22500.00	2025-10-08 13:10:20.06687
833	409	72	245385.45	2025-11-02 23:44:10.586246	2025-11-02 23:44:10.586246	0	a_temps	0.00	2025-10-08 13:10:20.06687
834	411	74	312460.54	2025-08-09 09:31:31.494647	2025-08-09 09:31:31.494647	0	a_temps	0.00	2025-10-08 13:10:20.06687
835	412	75	0.00	2025-08-02 08:14:32.772656	2025-08-02 08:14:32.772656	81	manque	28000.00	2025-10-08 13:10:20.06687
836	413	76	378055.34	2025-05-27 20:45:38.593233	2025-05-27 20:45:38.593233	0	a_temps	0.00	2025-10-08 13:10:20.06687
837	415	78	246920.38	2025-07-05 12:00:22.31867	2025-07-05 12:00:22.31867	0	a_temps	0.00	2025-10-08 13:10:20.06687
838	416	79	0.00	2025-08-20 00:11:49.398065	2025-08-20 00:11:49.398065	38	manque	24000.00	2025-10-08 13:10:20.06687
839	416	79	0.00	2025-09-19 00:11:49.398065	2025-09-19 00:11:49.398065	43	manque	35500.00	2025-10-08 13:10:20.06687
840	416	79	0.00	2025-10-19 00:11:49.398065	2025-10-19 00:11:49.398065	48	manque	27500.00	2025-10-08 13:10:20.06687
841	417	80	355148.04	2025-07-20 04:32:55.04997	2025-07-20 04:32:55.04997	0	a_temps	0.00	2025-10-08 13:10:20.06687
842	418	81	472606.06	2025-09-27 16:58:59.169353	2025-09-27 16:58:59.169353	0	a_temps	0.00	2025-10-08 13:10:20.06687
843	419	82	0.00	2025-10-04 15:34:58.471065	2025-10-04 15:34:58.471065	64	manque	25000.00	2025-10-08 13:10:20.06687
844	421	84	0.00	2025-10-26 18:37:50.714747	2025-10-26 18:37:50.714747	72	manque	28000.00	2025-10-08 13:10:20.06687
845	421	84	0.00	2025-11-25 18:37:50.714747	2025-11-25 18:37:50.714747	43	manque	38000.00	2025-10-08 13:10:20.06687
846	421	84	0.00	2025-12-25 18:37:50.714747	2025-12-25 18:37:50.714747	82	manque	16500.00	2025-10-08 13:10:20.06687
847	426	89	0.00	2025-07-12 12:31:33.657889	2025-07-12 12:31:33.657889	67	manque	30500.00	2025-10-08 13:10:20.06687
848	426	89	0.00	2025-08-11 12:31:33.657889	2025-08-11 12:31:33.657889	61	manque	19000.00	2025-10-08 13:10:20.06687
849	428	75	0.00	2025-09-19 14:45:29.370185	2025-09-19 14:45:29.370185	43	manque	17500.00	2025-10-08 13:10:20.06687
850	428	75	0.00	2025-10-19 14:45:29.370185	2025-10-19 14:45:29.370185	51	manque	40500.00	2025-10-08 13:10:20.06687
851	429	76	0.00	2025-11-06 22:26:03.578442	2025-11-06 22:26:03.578442	84	manque	29500.00	2025-10-08 13:10:20.06687
852	429	76	0.00	2025-12-06 22:26:03.578442	2025-12-06 22:26:03.578442	73	manque	26000.00	2025-10-08 13:10:20.06687
853	430	77	0.00	2025-10-22 10:22:14.467681	2025-10-22 10:22:14.467681	61	manque	33000.00	2025-10-08 13:10:20.06687
854	430	77	0.00	2025-11-21 10:22:14.467681	2025-11-21 10:22:14.467681	76	manque	25000.00	2025-10-08 13:10:20.06687
855	431	78	0.00	2025-10-25 08:03:32.659197	2025-10-25 08:03:32.659197	34	manque	25000.00	2025-10-08 13:10:20.06687
856	431	78	0.00	2025-11-24 08:03:32.659197	2025-11-24 08:03:32.659197	79	manque	32000.00	2025-10-08 13:10:20.06687
857	432	79	0.00	2025-09-09 08:22:10.428214	2025-09-09 08:22:10.428214	67	manque	22500.00	2025-10-08 13:10:20.06687
858	432	79	0.00	2025-10-09 08:22:10.428214	2025-10-09 08:22:10.428214	79	manque	33000.00	2025-10-08 13:10:20.06687
859	432	79	0.00	2025-11-08 08:22:10.428214	2025-11-08 08:22:10.428214	30	manque	16500.00	2025-10-08 13:10:20.06687
860	433	80	0.00	2025-10-29 09:54:27.051095	2025-10-29 09:54:27.051095	33	manque	35000.00	2025-10-08 13:10:20.06687
861	433	80	0.00	2025-11-28 09:54:27.051095	2025-11-28 09:54:27.051095	69	manque	37500.00	2025-10-08 13:10:20.06687
862	433	80	0.00	2025-12-28 09:54:27.051095	2025-12-28 09:54:27.051095	51	manque	19000.00	2025-10-08 13:10:20.06687
863	434	81	0.00	2025-10-23 05:16:25.084653	2025-10-23 05:16:25.084653	88	manque	38500.00	2025-10-08 13:10:20.06687
864	434	81	0.00	2025-11-22 05:16:25.084653	2025-11-22 05:16:25.084653	34	manque	23500.00	2025-10-08 13:10:20.06687
865	434	81	0.00	2025-12-22 05:16:25.084653	2025-12-22 05:16:25.084653	66	manque	30500.00	2025-10-08 13:10:20.06687
866	435	82	0.00	2025-10-28 16:30:12.470644	2025-10-28 16:30:12.470644	85	manque	31500.00	2025-10-08 13:10:20.06687
867	435	82	0.00	2025-11-27 16:30:12.470644	2025-11-27 16:30:12.470644	66	manque	33000.00	2025-10-08 13:10:20.06687
868	436	83	0.00	2025-10-10 03:58:13.919006	2025-10-10 03:58:13.919006	86	manque	27500.00	2025-10-08 13:10:20.06687
869	436	83	0.00	2025-11-09 03:58:13.919006	2025-11-09 03:58:13.919006	67	manque	44000.00	2025-10-08 13:10:20.06687
870	437	84	0.00	2025-10-28 18:56:51.604779	2025-10-28 18:56:51.604779	86	manque	33500.00	2025-10-08 13:10:20.06687
871	438	85	0.00	2025-09-13 18:47:21.814521	2025-09-13 18:47:21.814521	39	manque	22500.00	2025-10-08 13:10:20.06687
872	438	85	0.00	2025-10-13 18:47:21.814521	2025-10-13 18:47:21.814521	87	manque	15500.00	2025-10-08 13:10:20.06687
873	439	91	0.00	2025-10-23 16:03:45.730839	2025-10-23 16:03:45.730839	50	manque	29000.00	2025-10-08 13:10:20.06687
874	439	91	0.00	2025-11-22 16:03:45.730839	2025-11-22 16:03:45.730839	54	manque	44500.00	2025-10-08 13:10:20.06687
875	439	91	0.00	2025-12-22 16:03:45.730839	2025-12-22 16:03:45.730839	52	manque	35000.00	2025-10-08 13:10:20.06687
876	440	92	0.00	2025-07-29 17:22:04.189212	2025-07-29 17:22:04.189212	84	manque	42000.00	2025-10-08 13:10:20.06687
877	440	92	0.00	2025-08-28 17:22:04.189212	2025-08-28 17:22:04.189212	35	manque	28500.00	2025-10-08 13:10:20.06687
878	441	93	0.00	2025-05-11 13:42:33.251295	2025-05-11 13:42:33.251295	84	manque	28500.00	2025-10-08 13:10:20.06687
879	441	93	0.00	2025-06-10 13:42:33.251295	2025-06-10 13:42:33.251295	52	manque	35000.00	2025-10-08 13:10:20.06687
880	441	93	0.00	2025-07-10 13:42:33.251295	2025-07-10 13:42:33.251295	44	manque	23500.00	2025-10-08 13:10:20.06687
881	442	94	0.00	2025-07-02 15:11:33.790172	2025-07-02 15:11:33.790172	41	manque	15500.00	2025-10-08 13:10:20.06687
882	442	94	0.00	2025-08-01 15:11:33.790172	2025-08-01 15:11:33.790172	66	manque	22000.00	2025-10-08 13:10:20.06687
883	443	95	0.00	2025-06-09 17:22:09.348207	2025-06-09 17:22:09.348207	45	manque	39000.00	2025-10-08 13:10:20.06687
884	444	96	0.00	2025-05-22 10:26:02.792245	2025-05-22 10:26:02.792245	51	manque	22500.00	2025-10-08 13:10:20.06687
885	445	97	0.00	2025-08-12 02:44:16.997556	2025-08-12 02:44:16.997556	73	manque	27000.00	2025-10-08 13:10:20.06687
886	445	97	0.00	2025-09-11 02:44:16.997556	2025-09-11 02:44:16.997556	32	manque	19500.00	2025-10-08 13:10:20.06687
887	446	98	0.00	2025-08-03 02:13:35.275356	2025-08-03 02:13:35.275356	30	manque	35000.00	2025-10-08 13:10:20.06687
888	447	99	0.00	2025-07-18 07:26:56.941775	2025-07-18 07:26:56.941775	49	manque	16500.00	2025-10-08 13:10:20.06687
889	447	99	0.00	2025-08-17 07:26:56.941775	2025-08-17 07:26:56.941775	53	manque	34000.00	2025-10-08 13:10:20.06687
890	447	99	0.00	2025-09-16 07:26:56.941775	2025-09-16 07:26:56.941775	65	manque	24000.00	2025-10-08 13:10:20.06687
891	448	91	0.00	2025-09-26 23:01:00.527007	2025-09-26 23:01:00.527007	70	manque	27000.00	2025-10-08 13:10:20.06687
892	448	91	0.00	2025-10-26 23:01:00.527007	2025-10-26 23:01:00.527007	80	manque	17500.00	2025-10-08 13:10:20.06687
893	448	91	0.00	2025-11-25 23:01:00.527007	2025-11-25 23:01:00.527007	72	manque	29500.00	2025-10-08 13:10:20.06687
894	449	92	0.00	2025-09-02 03:23:28.099241	2025-09-02 03:23:28.099241	56	manque	25000.00	2025-10-08 13:10:20.06687
895	449	92	0.00	2025-10-02 03:23:28.099241	2025-10-02 03:23:28.099241	75	manque	34000.00	2025-10-08 13:10:20.06687
896	450	93	0.00	2025-08-14 06:48:51.232586	2025-08-14 06:48:51.232586	70	manque	36000.00	2025-10-08 13:10:20.06687
897	451	94	0.00	2025-09-17 14:40:22.62522	2025-09-17 14:40:22.62522	73	manque	26000.00	2025-10-08 13:10:20.06687
898	452	95	0.00	2025-08-31 09:37:22.592454	2025-08-31 09:37:22.592454	37	manque	36000.00	2025-10-08 13:10:20.06687
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
1906	1	6.5	657	\N	\N	moyen	1250000.00	Recalcul automatique	\N	\N	2025-10-08 13:26:49.772642
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
641	1	6.5	657	\N	\N	moyen	1250000.00	Recalcul automatique	\N	\N	2025-10-06 17:45:15.892385
642	1	5.3	591	4.9	0.4	eleve	750000.00	Nouveau crÃ©dit accordÃ©	0.81	amelioration	2025-05-26 00:28:38.216148
643	1	5.7	613	5.3	0.4	eleve	750000.00	Paiement Ã  temps	0.82	amelioration	2025-07-10 00:28:38.216148
644	1	6.2	641	5.7	0.5	moyen	1250000.00	Paiement Ã  temps	0.84	amelioration	2025-08-24 00:28:38.216148
645	1	6.6	663	6.2	0.4	moyen	1250000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.85	amelioration	2025-10-08 00:28:38.216148
646	2	6.5	657	6.2	0.3	moyen	900000.00	Nouveau crÃ©dit accordÃ©	0.85	amelioration	2024-11-27 00:28:38.216148
647	2	6.7	668	6.5	0.2	moyen	900000.00	Paiement Ã  temps	0.85	stable	2025-01-11 00:28:38.216148
648	2	7.0	685	6.7	0.3	moyen	900000.00	Nouveau crÃ©dit accordÃ©	0.86	amelioration	2025-02-25 00:28:38.216148
649	2	7.3	701	7.0	0.3	moyen	900000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.87	amelioration	2025-04-11 00:28:38.216148
650	2	7.6	718	7.3	0.3	moyen	900000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.88	amelioration	2025-05-26 00:28:38.216148
651	2	8.1	745	7.6	0.5	bas	1260000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.89	amelioration	2025-07-10 00:28:38.216148
652	2	8.6	773	8.1	0.5	bas	1260000.00	Paiement Ã  temps	0.91	amelioration	2025-08-24 00:28:38.216148
653	2	8.9	789	8.6	0.3	bas	1260000.00	Nouveau crÃ©dit accordÃ©	0.92	amelioration	2025-10-08 00:28:38.216148
654	3	6.1	635	5.7	0.4	moyen	750000.00	Paiement Ã  temps	0.83	amelioration	2025-02-25 00:28:38.216148
655	3	6.7	668	6.1	0.6	moyen	750000.00	Paiement Ã  temps	0.85	amelioration	2025-04-11 00:28:38.216148
656	3	7.3	701	6.7	0.6	moyen	750000.00	Nouveau crÃ©dit accordÃ©	0.87	amelioration	2025-05-26 00:28:38.216148
657	3	7.7	723	7.3	0.4	moyen	750000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.88	amelioration	2025-07-10 00:28:38.216148
658	3	8.1	745	7.7	0.4	bas	1050000.00	Paiement Ã  temps	0.89	amelioration	2025-08-24 00:28:38.216148
659	3	8.4	762	8.1	0.3	bas	1050000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.90	amelioration	2025-10-08 00:28:38.216148
660	4	7.6	718	7.5	0.1	moyen	600000.00	Nouveau crÃ©dit accordÃ©	0.88	stable	2024-11-27 00:28:38.216148
661	4	7.7	723	7.6	0.1	moyen	600000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.88	stable	2025-01-11 00:28:38.216148
662	4	7.9	734	7.7	0.2	moyen	600000.00	Paiement Ã  temps	0.89	stable	2025-02-25 00:28:38.216148
663	4	7.9	734	7.9	0.0	moyen	600000.00	Paiement Ã  temps	0.89	stable	2025-04-11 00:28:38.216148
664	4	8.1	745	7.9	0.2	bas	840000.00	Paiement Ã  temps	0.89	stable	2025-05-26 00:28:38.216148
665	4	8.2	751	8.1	0.1	bas	840000.00	Paiement Ã  temps	0.90	stable	2025-07-10 00:28:38.216148
666	4	8.5	767	8.2	0.3	bas	840000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.91	amelioration	2025-08-24 00:28:38.216148
667	4	8.6	773	8.5	0.1	bas	840000.00	Paiement Ã  temps	0.91	stable	2025-10-08 00:28:38.216148
668	5	7.2	696	6.9	0.3	moyen	1000000.00	Paiement Ã  temps	0.87	amelioration	2025-01-11 00:28:38.216148
669	5	7.5	712	7.2	0.3	moyen	1000000.00	Paiement Ã  temps	0.88	amelioration	2025-02-25 00:28:38.216148
670	5	7.6	718	7.5	0.1	moyen	1000000.00	Paiement Ã  temps	0.88	stable	2025-04-11 00:28:38.216148
671	5	7.9	734	7.6	0.3	moyen	1000000.00	Nouveau crÃ©dit accordÃ©	0.89	amelioration	2025-05-26 00:28:38.216148
672	5	7.9	734	7.9	0.0	moyen	1000000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.89	stable	2025-07-10 00:28:38.216148
673	5	8.1	745	7.9	0.2	bas	1400000.00	Paiement Ã  temps	0.89	stable	2025-08-24 00:28:38.216148
674	5	8.3	756	8.1	0.2	bas	1400000.00	Nouveau crÃ©dit accordÃ©	0.90	stable	2025-10-08 00:28:38.216148
675	6	7.5	712	7.2	0.3	moyen	700000.00	Paiement Ã  temps	0.88	amelioration	2025-05-26 00:28:38.216148
676	6	8.0	740	7.5	0.5	bas	980000.00	Nouveau crÃ©dit accordÃ©	0.89	amelioration	2025-07-10 00:28:38.216148
677	6	8.2	751	8.0	0.2	bas	980000.00	Nouveau crÃ©dit accordÃ©	0.90	stable	2025-08-24 00:28:38.216148
678	6	8.5	767	8.2	0.3	bas	980000.00	Nouveau crÃ©dit accordÃ©	0.91	amelioration	2025-10-08 00:28:38.216148
679	7	7.8	729	7.5	0.3	moyen	950000.00	Nouveau crÃ©dit accordÃ©	0.88	amelioration	2025-01-11 00:28:38.216148
680	7	7.9	734	7.8	0.1	moyen	950000.00	Paiement Ã  temps	0.89	stable	2025-02-25 00:28:38.216148
681	7	8.1	745	7.9	0.2	bas	1330000.00	Nouveau crÃ©dit accordÃ©	0.89	stable	2025-04-11 00:28:38.216148
682	7	8.3	756	8.1	0.2	bas	1330000.00	Nouveau crÃ©dit accordÃ©	0.90	stable	2025-05-26 00:28:38.216148
683	7	8.4	762	8.3	0.1	bas	1330000.00	Paiement Ã  temps	0.90	stable	2025-07-10 00:28:38.216148
684	7	8.7	778	8.4	0.3	bas	1330000.00	Nouveau crÃ©dit accordÃ©	0.91	amelioration	2025-08-24 00:28:38.216148
685	7	8.8	784	8.7	0.1	bas	1330000.00	Paiement en retard	0.91	stable	2025-10-08 00:28:38.216148
686	8	6.1	635	5.5	0.6	moyen	550000.00	Nouveau crÃ©dit accordÃ©	0.83	amelioration	2025-02-25 00:28:38.216148
687	8	6.6	663	6.1	0.5	moyen	550000.00	Paiement Ã  temps	0.85	amelioration	2025-04-11 00:28:38.216148
688	8	7.1	690	6.6	0.5	moyen	550000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.86	amelioration	2025-05-26 00:28:38.216148
689	8	7.6	718	7.1	0.5	moyen	550000.00	Paiement Ã  temps	0.88	amelioration	2025-07-10 00:28:38.216148
690	8	8.0	740	7.6	0.4	bas	770000.00	Paiement en retard	0.89	amelioration	2025-08-24 00:28:38.216148
691	8	8.5	767	8.0	0.5	bas	770000.00	Nouveau crÃ©dit accordÃ©	0.91	amelioration	2025-10-08 00:28:38.216148
692	9	7.0	685	6.4	0.6	moyen	800000.00	Nouveau crÃ©dit accordÃ©	0.86	amelioration	2025-07-10 00:28:38.216148
693	9	7.6	718	7.0	0.6	moyen	800000.00	Paiement Ã  temps	0.88	amelioration	2025-08-24 00:28:38.216148
694	9	8.3	756	7.6	0.7	bas	1120000.00	Nouveau crÃ©dit accordÃ©	0.90	amelioration	2025-10-08 00:28:38.216148
695	10	7.3	701	6.9	0.4	moyen	675000.00	Paiement Ã  temps	0.87	amelioration	2025-05-26 00:28:38.216148
696	10	7.9	734	7.3	0.6	moyen	675000.00	Nouveau crÃ©dit accordÃ©	0.89	amelioration	2025-07-10 00:28:38.216148
697	10	8.3	756	7.9	0.4	bas	945000.00	Paiement Ã  temps	0.90	amelioration	2025-08-24 00:28:38.216148
698	10	8.8	784	8.3	0.5	bas	945000.00	Nouveau crÃ©dit accordÃ©	0.91	amelioration	2025-10-08 00:28:38.216148
699	11	6.9	679	6.5	0.4	moyen	725000.00	Nouveau crÃ©dit accordÃ©	0.86	amelioration	2024-10-13 00:28:38.216148
700	11	7.3	701	6.9	0.4	moyen	725000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.87	amelioration	2024-11-27 00:28:38.216148
701	11	7.6	718	7.3	0.3	moyen	725000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.88	amelioration	2025-01-11 00:28:38.216148
702	11	7.8	729	7.6	0.2	moyen	725000.00	Nouveau crÃ©dit accordÃ©	0.88	stable	2025-02-25 00:28:38.216148
703	11	7.9	734	7.8	0.1	moyen	725000.00	Nouveau crÃ©dit accordÃ©	0.89	stable	2025-04-11 00:28:38.216148
704	11	8.1	745	7.9	0.2	bas	1015000.00	Paiement Ã  temps	0.89	stable	2025-05-26 00:28:38.216148
705	11	8.4	762	8.1	0.3	bas	1015000.00	Nouveau crÃ©dit accordÃ©	0.90	amelioration	2025-07-10 00:28:38.216148
706	11	8.7	778	8.4	0.3	bas	1015000.00	Paiement Ã  temps	0.91	amelioration	2025-08-24 00:28:38.216148
707	11	8.8	784	8.7	0.1	bas	1015000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.91	stable	2025-10-08 00:28:38.216148
708	12	6.2	641	5.8	0.4	moyen	475000.00	Nouveau crÃ©dit accordÃ©	0.84	amelioration	2025-02-25 00:28:38.216148
709	12	6.6	663	6.2	0.4	moyen	475000.00	Paiement Ã  temps	0.85	amelioration	2025-04-11 00:28:38.216148
710	12	7.0	685	6.6	0.4	moyen	475000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.86	amelioration	2025-05-26 00:28:38.216148
711	12	7.4	707	7.0	0.4	moyen	475000.00	Paiement Ã  temps	0.87	amelioration	2025-07-10 00:28:38.216148
712	12	7.7	723	7.4	0.3	moyen	475000.00	Nouveau crÃ©dit accordÃ©	0.88	amelioration	2025-08-24 00:28:38.216148
713	12	8.1	745	7.7	0.4	bas	665000.00	Paiement en retard	0.89	amelioration	2025-10-08 00:28:38.216148
714	13	6.6	663	6.4	0.2	moyen	425000.00	Nouveau crÃ©dit accordÃ©	0.85	stable	2024-08-29 00:28:38.216148
715	13	6.6	663	6.6	0.0	moyen	425000.00	Paiement Ã  temps	0.85	stable	2024-10-13 00:28:38.216148
716	13	6.7	668	6.6	0.1	moyen	425000.00	Nouveau crÃ©dit accordÃ©	0.85	stable	2024-11-27 00:28:38.216148
717	13	6.8	674	6.7	0.1	moyen	425000.00	Nouveau crÃ©dit accordÃ©	0.85	stable	2025-01-11 00:28:38.216148
718	13	7.1	690	6.8	0.3	moyen	425000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.86	amelioration	2025-02-25 00:28:38.216148
719	13	7.3	701	7.1	0.2	moyen	425000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.87	stable	2025-04-11 00:28:38.216148
720	13	7.3	701	7.3	0.0	moyen	425000.00	Nouveau crÃ©dit accordÃ©	0.87	stable	2025-05-26 00:28:38.216148
721	13	7.4	707	7.3	0.1	moyen	425000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.87	stable	2025-07-10 00:28:38.216148
722	13	7.6	718	7.4	0.2	moyen	425000.00	Nouveau crÃ©dit accordÃ©	0.88	stable	2025-08-24 00:28:38.216148
723	13	7.9	734	7.6	0.3	moyen	425000.00	Paiement Ã  temps	0.89	amelioration	2025-10-08 00:28:38.216148
724	14	6.6	663	6.4	0.2	moyen	640000.00	Nouveau crÃ©dit accordÃ©	0.85	stable	2024-11-27 00:28:38.216148
725	14	6.8	674	6.6	0.2	moyen	640000.00	Paiement Ã  temps	0.85	stable	2025-01-11 00:28:38.216148
726	14	7.0	685	6.8	0.2	moyen	640000.00	Paiement Ã  temps	0.86	stable	2025-02-25 00:28:38.216148
727	14	7.4	707	7.0	0.4	moyen	640000.00	Paiement Ã  temps	0.87	amelioration	2025-04-11 00:28:38.216148
728	14	7.6	718	7.4	0.2	moyen	640000.00	Paiement Ã  temps	0.88	stable	2025-05-26 00:28:38.216148
729	14	7.9	734	7.6	0.3	moyen	640000.00	Paiement Ã  temps	0.89	amelioration	2025-07-10 00:28:38.216148
730	14	8.1	745	7.9	0.2	bas	896000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.89	stable	2025-08-24 00:28:38.216148
731	14	8.4	762	8.1	0.3	bas	896000.00	Nouveau crÃ©dit accordÃ©	0.90	amelioration	2025-10-08 00:28:38.216148
732	15	6.0	630	5.7	0.3	moyen	775000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.83	amelioration	2024-11-27 00:28:38.216148
733	15	6.3	646	6.0	0.3	moyen	775000.00	Paiement Ã  temps	0.84	amelioration	2025-01-11 00:28:38.216148
734	15	6.8	674	6.3	0.5	moyen	775000.00	Paiement en retard	0.85	amelioration	2025-02-25 00:28:38.216148
735	15	7.1	690	6.8	0.3	moyen	775000.00	Paiement Ã  temps	0.86	amelioration	2025-04-11 00:28:38.216148
736	15	7.4	707	7.1	0.3	moyen	775000.00	Nouveau crÃ©dit accordÃ©	0.87	amelioration	2025-05-26 00:28:38.216148
737	15	7.8	729	7.4	0.4	moyen	775000.00	Paiement Ã  temps	0.88	amelioration	2025-07-10 00:28:38.216148
738	15	8.2	751	7.8	0.4	bas	1085000.00	Paiement en retard	0.90	amelioration	2025-08-24 00:28:38.216148
739	15	8.5	767	8.2	0.3	bas	1085000.00	Paiement Ã  temps	0.91	amelioration	2025-10-08 00:28:38.216148
740	16	7.2	696	6.6	0.6	moyen	575000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.87	amelioration	2025-07-10 00:28:38.216148
741	16	7.6	718	7.2	0.4	moyen	575000.00	Paiement en retard	0.88	amelioration	2025-08-24 00:28:38.216148
742	16	8.3	756	7.6	0.7	bas	805000.00	Paiement Ã  temps	0.90	amelioration	2025-10-08 00:28:38.216148
743	17	7.1	690	7.0	0.1	moyen	840000.00	Nouveau crÃ©dit accordÃ©	0.86	stable	2025-01-11 00:28:38.216148
744	17	7.3	701	7.1	0.2	moyen	840000.00	Paiement Ã  temps	0.87	stable	2025-02-25 00:28:38.216148
745	17	7.5	712	7.3	0.2	moyen	840000.00	Paiement Ã  temps	0.88	stable	2025-04-11 00:28:38.216148
746	17	7.5	712	7.5	0.0	moyen	840000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.88	stable	2025-05-26 00:28:38.216148
747	17	7.8	729	7.5	0.3	moyen	840000.00	Paiement Ã  temps	0.88	amelioration	2025-07-10 00:28:38.216148
748	17	8.0	740	7.8	0.2	bas	1176000.00	Nouveau crÃ©dit accordÃ©	0.89	stable	2025-08-24 00:28:38.216148
749	17	7.9	734	8.0	-0.1	moyen	840000.00	Paiement Ã  temps	0.89	stable	2025-10-08 00:28:38.216148
750	18	7.1	690	6.8	0.3	moyen	710000.00	Paiement Ã  temps	0.86	amelioration	2024-08-29 00:28:38.216148
751	18	7.2	696	7.1	0.1	moyen	710000.00	Paiement Ã  temps	0.87	stable	2024-10-13 00:28:38.216148
752	18	7.4	707	7.2	0.2	moyen	710000.00	Paiement Ã  temps	0.87	stable	2024-11-27 00:28:38.216148
753	18	7.6	718	7.4	0.2	moyen	710000.00	Nouveau crÃ©dit accordÃ©	0.88	stable	2025-01-11 00:28:38.216148
754	18	7.8	729	7.6	0.2	moyen	710000.00	Paiement Ã  temps	0.88	stable	2025-02-25 00:28:38.216148
755	18	7.9	734	7.8	0.1	moyen	710000.00	Paiement Ã  temps	0.89	stable	2025-04-11 00:28:38.216148
756	18	8.1	745	7.9	0.2	bas	994000.00	Paiement Ã  temps	0.89	stable	2025-05-26 00:28:38.216148
757	18	8.3	756	8.1	0.2	bas	994000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.90	stable	2025-07-10 00:28:38.216148
758	18	8.4	762	8.3	0.1	bas	994000.00	Nouveau crÃ©dit accordÃ©	0.90	stable	2025-08-24 00:28:38.216148
759	18	8.6	773	8.4	0.2	bas	994000.00	Paiement Ã  temps	0.91	stable	2025-10-08 00:28:38.216148
760	19	6.7	668	6.7	0.0	moyen	1050000.00	Nouveau crÃ©dit accordÃ©	0.85	stable	2024-08-29 00:28:38.216148
761	19	6.9	679	6.7	0.2	moyen	1050000.00	Paiement Ã  temps	0.86	stable	2024-10-13 00:28:38.216148
762	19	6.9	679	6.9	0.0	moyen	1050000.00	Paiement en retard	0.86	stable	2024-11-27 00:28:38.216148
763	19	7.1	690	6.9	0.2	moyen	1050000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.86	stable	2025-01-11 00:28:38.216148
764	19	7.2	696	7.1	0.1	moyen	1050000.00	Paiement Ã  temps	0.87	stable	2025-02-25 00:28:38.216148
765	19	7.4	707	7.2	0.2	moyen	1050000.00	Nouveau crÃ©dit accordÃ©	0.87	stable	2025-04-11 00:28:38.216148
766	19	7.4	707	7.4	0.0	moyen	1050000.00	Nouveau crÃ©dit accordÃ©	0.87	stable	2025-05-26 00:28:38.216148
767	19	7.5	712	7.4	0.1	moyen	1050000.00	Nouveau crÃ©dit accordÃ©	0.88	stable	2025-07-10 00:28:38.216148
768	19	7.7	723	7.5	0.2	moyen	1050000.00	Nouveau crÃ©dit accordÃ©	0.88	stable	2025-08-24 00:28:38.216148
769	19	8.0	740	7.7	0.3	bas	1470000.00	Paiement Ã  temps	0.89	amelioration	2025-10-08 00:28:38.216148
770	20	7.9	734	7.7	0.2	moyen	875000.00	Paiement Ã  temps	0.89	stable	2024-08-29 00:28:38.216148
771	20	8.1	745	7.9	0.2	bas	1225000.00	Paiement Ã  temps	0.89	stable	2024-10-13 00:28:38.216148
772	20	8.1	745	8.1	0.0	bas	1225000.00	Paiement Ã  temps	0.89	stable	2024-11-27 00:28:38.216148
773	20	8.1	745	8.1	0.0	bas	1225000.00	Nouveau crÃ©dit accordÃ©	0.89	stable	2025-01-11 00:28:38.216148
774	20	8.2	751	8.1	0.1	bas	1225000.00	Paiement Ã  temps	0.90	stable	2025-02-25 00:28:38.216148
775	20	8.5	767	8.2	0.3	bas	1225000.00	Paiement Ã  temps	0.91	amelioration	2025-04-11 00:28:38.216148
776	20	8.6	773	8.5	0.1	bas	1225000.00	Mise Ã  jour automatique	0.91	stable	2025-05-26 00:28:38.216148
777	20	8.8	784	8.6	0.2	bas	1225000.00	Nouveau crÃ©dit accordÃ©	0.91	stable	2025-07-10 00:28:38.216148
778	20	8.9	789	8.8	0.1	bas	1225000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.92	stable	2025-08-24 00:28:38.216148
779	20	8.9	789	8.9	0.0	bas	1225000.00	Paiement en retard	0.92	stable	2025-10-08 00:28:38.216148
780	21	6.3	646	5.8	0.5	moyen	940000.00	Paiement Ã  temps	0.84	amelioration	2025-02-25 00:28:38.216148
781	21	6.7	668	6.3	0.4	moyen	940000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.85	amelioration	2025-04-11 00:28:38.216148
782	21	7.0	685	6.7	0.3	moyen	940000.00	Nouveau crÃ©dit accordÃ©	0.86	amelioration	2025-05-26 00:28:38.216148
783	21	7.6	718	7.0	0.6	moyen	940000.00	Paiement Ã  temps	0.88	amelioration	2025-07-10 00:28:38.216148
784	21	7.9	734	7.6	0.3	moyen	940000.00	Paiement Ã  temps	0.89	amelioration	2025-08-24 00:28:38.216148
785	21	8.4	762	7.9	0.5	bas	1316000.00	Nouveau crÃ©dit accordÃ©	0.90	amelioration	2025-10-08 00:28:38.216148
786	22	7.3	701	6.9	0.4	moyen	660000.00	Paiement Ã  temps	0.87	amelioration	2025-05-26 00:28:38.216148
787	22	7.7	723	7.3	0.4	moyen	660000.00	Nouveau crÃ©dit accordÃ©	0.88	amelioration	2025-07-10 00:28:38.216148
788	22	7.9	734	7.7	0.2	moyen	660000.00	Paiement Ã  temps	0.89	stable	2025-08-24 00:28:38.216148
789	22	8.3	756	7.9	0.4	bas	924000.00	Paiement Ã  temps	0.90	amelioration	2025-10-08 00:28:38.216148
790	23	7.1	690	6.5	0.6	moyen	740000.00	Nouveau crÃ©dit accordÃ©	0.86	amelioration	2025-07-10 00:28:38.216148
791	23	7.8	729	7.1	0.7	moyen	740000.00	Nouveau crÃ©dit accordÃ©	0.88	amelioration	2025-08-24 00:28:38.216148
792	23	8.6	773	7.8	0.8	bas	1036000.00	Paiement Ã  temps	0.91	amelioration	2025-10-08 00:28:38.216148
793	24	6.6	663	5.8	0.8	moyen	810000.00	Nouveau crÃ©dit accordÃ©	0.85	amelioration	2025-05-26 00:28:38.216148
794	24	7.3	701	6.6	0.7	moyen	810000.00	Nouveau crÃ©dit accordÃ©	0.87	amelioration	2025-07-10 00:28:38.216148
795	24	8.0	740	7.3	0.7	bas	1134000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.89	amelioration	2025-08-24 00:28:38.216148
796	24	8.5	767	8.0	0.5	bas	1134000.00	Nouveau crÃ©dit accordÃ©	0.91	amelioration	2025-10-08 00:28:38.216148
797	25	6.5	657	6.2	0.3	moyen	595000.00	Nouveau crÃ©dit accordÃ©	0.85	amelioration	2024-11-27 00:28:38.216148
798	25	6.7	668	6.5	0.2	moyen	595000.00	Nouveau crÃ©dit accordÃ©	0.85	stable	2025-01-11 00:28:38.216148
799	25	7.1	690	6.7	0.4	moyen	595000.00	Nouveau crÃ©dit accordÃ©	0.86	amelioration	2025-02-25 00:28:38.216148
800	25	7.4	707	7.1	0.3	moyen	595000.00	Paiement Ã  temps	0.87	amelioration	2025-04-11 00:28:38.216148
801	25	7.5	712	7.4	0.1	moyen	595000.00	Paiement en retard	0.88	stable	2025-05-26 00:28:38.216148
802	25	7.8	729	7.5	0.3	moyen	595000.00	Paiement Ã  temps	0.88	amelioration	2025-07-10 00:28:38.216148
803	25	8.1	745	7.8	0.3	bas	833000.00	Paiement Ã  temps	0.89	amelioration	2025-08-24 00:28:38.216148
804	25	8.3	756	8.1	0.2	bas	833000.00	Paiement Ã  temps	0.90	stable	2025-10-08 00:28:38.216148
805	26	6.4	652	5.8	0.6	moyen	525000.00	Nouveau crÃ©dit accordÃ©	0.84	amelioration	2025-05-26 00:28:38.216148
806	26	6.9	679	6.4	0.5	moyen	525000.00	Nouveau crÃ©dit accordÃ©	0.86	amelioration	2025-07-10 00:28:38.216148
807	26	7.4	707	6.9	0.5	moyen	525000.00	Nouveau crÃ©dit accordÃ©	0.87	amelioration	2025-08-24 00:28:38.216148
808	26	8.1	745	7.4	0.7	bas	735000.00	Paiement Ã  temps	0.89	amelioration	2025-10-08 00:28:38.216148
809	27	6.0	630	5.6	0.4	moyen	675000.00	Nouveau crÃ©dit accordÃ©	0.83	amelioration	2025-02-25 00:28:38.216148
810	27	6.5	657	6.0	0.5	moyen	675000.00	Nouveau crÃ©dit accordÃ©	0.85	amelioration	2025-04-11 00:28:38.216148
811	27	7.0	685	6.5	0.5	moyen	675000.00	Paiement Ã  temps	0.86	amelioration	2025-05-26 00:28:38.216148
812	27	7.4	707	7.0	0.4	moyen	675000.00	Paiement Ã  temps	0.87	amelioration	2025-07-10 00:28:38.216148
813	27	7.8	729	7.4	0.4	moyen	675000.00	Paiement Ã  temps	0.88	amelioration	2025-08-24 00:28:38.216148
814	27	8.2	751	7.8	0.4	bas	945000.00	Nouveau crÃ©dit accordÃ©	0.90	amelioration	2025-10-08 00:28:38.216148
815	28	6.4	652	6.0	0.4	moyen	790000.00	Nouveau crÃ©dit accordÃ©	0.84	amelioration	2024-11-27 00:28:38.216148
816	28	6.9	679	6.4	0.5	moyen	790000.00	Paiement Ã  temps	0.86	amelioration	2025-01-11 00:28:38.216148
817	28	7.3	701	6.9	0.4	moyen	790000.00	Paiement Ã  temps	0.87	amelioration	2025-02-25 00:28:38.216148
818	28	7.5	712	7.3	0.2	moyen	790000.00	Paiement Ã  temps	0.88	stable	2025-04-11 00:28:38.216148
819	28	7.9	734	7.5	0.4	moyen	790000.00	Paiement Ã  temps	0.89	amelioration	2025-05-26 00:28:38.216148
820	28	8.3	756	7.9	0.4	bas	1106000.00	Nouveau crÃ©dit accordÃ©	0.90	amelioration	2025-07-10 00:28:38.216148
821	28	8.5	767	8.3	0.2	bas	1106000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.91	stable	2025-08-24 00:28:38.216148
822	28	8.8	784	8.5	0.3	bas	1106000.00	Nouveau crÃ©dit accordÃ©	0.91	amelioration	2025-10-08 00:28:38.216148
823	29	6.1	635	6.0	0.1	moyen	710000.00	Paiement Ã  temps	0.83	stable	2024-08-29 00:28:38.216148
824	29	6.5	657	6.1	0.4	moyen	710000.00	Paiement Ã  temps	0.85	amelioration	2024-10-13 00:28:38.216148
825	29	6.7	668	6.5	0.2	moyen	710000.00	Paiement Ã  temps	0.85	stable	2024-11-27 00:28:38.216148
826	29	6.9	679	6.7	0.2	moyen	710000.00	Nouveau crÃ©dit accordÃ©	0.86	stable	2025-01-11 00:28:38.216148
827	29	7.3	701	6.9	0.4	moyen	710000.00	Nouveau crÃ©dit accordÃ©	0.87	amelioration	2025-02-25 00:28:38.216148
828	29	7.6	718	7.3	0.3	moyen	710000.00	Nouveau crÃ©dit accordÃ©	0.88	amelioration	2025-04-11 00:28:38.216148
829	29	7.9	734	7.6	0.3	moyen	710000.00	Paiement Ã  temps	0.89	amelioration	2025-05-26 00:28:38.216148
830	29	8.1	745	7.9	0.2	bas	994000.00	Paiement en retard	0.89	stable	2025-07-10 00:28:38.216148
831	29	8.2	751	8.1	0.1	bas	994000.00	Paiement Ã  temps	0.90	stable	2025-08-24 00:28:38.216148
832	29	8.3	756	8.2	0.1	bas	994000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.90	stable	2025-10-08 00:28:38.216148
833	30	7.6	718	7.3	0.3	moyen	640000.00	Paiement Ã  temps	0.88	amelioration	2025-04-11 00:28:38.216148
834	30	7.8	729	7.6	0.2	moyen	640000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.88	stable	2025-05-26 00:28:38.216148
835	30	8.0	740	7.8	0.2	bas	896000.00	Paiement en retard	0.89	stable	2025-07-10 00:28:38.216148
836	30	8.2	751	8.0	0.2	bas	896000.00	Nouveau crÃ©dit accordÃ©	0.90	stable	2025-08-24 00:28:38.216148
837	30	8.6	773	8.2	0.4	bas	896000.00	Paiement Ã  temps	0.91	amelioration	2025-10-08 00:28:38.216148
838	31	4.8	564	4.3	0.5	eleve	204000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.79	amelioration	2024-11-27 00:28:38.216148
839	31	5.1	580	4.8	0.3	eleve	204000.00	Nouveau crÃ©dit accordÃ©	0.80	amelioration	2025-01-11 00:28:38.216148
840	31	5.4	597	5.1	0.3	eleve	204000.00	Nouveau crÃ©dit accordÃ©	0.81	amelioration	2025-02-25 00:28:38.216148
841	31	5.9	624	5.4	0.5	eleve	204000.00	Paiement en retard	0.83	amelioration	2025-04-11 00:28:38.216148
842	31	6.3	646	5.9	0.4	moyen	340000.00	Nouveau crÃ©dit accordÃ©	0.84	amelioration	2025-05-26 00:28:38.216148
843	31	6.6	663	6.3	0.3	moyen	340000.00	Paiement en retard	0.85	amelioration	2025-07-10 00:28:38.216148
844	31	6.9	679	6.6	0.3	moyen	340000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.86	amelioration	2025-08-24 00:28:38.216148
845	31	7.2	696	6.9	0.3	moyen	340000.00	Paiement Ã  temps	0.87	amelioration	2025-10-08 00:28:38.216148
846	32	4.9	569	4.3	0.6	eleve	156000.00	Nouveau crÃ©dit accordÃ©	0.80	amelioration	2025-05-26 00:28:38.216148
847	32	5.6	608	4.9	0.7	eleve	156000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.82	amelioration	2025-07-10 00:28:38.216148
848	32	6.2	641	5.6	0.6	moyen	260000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.84	amelioration	2025-08-24 00:28:38.216148
849	32	6.8	674	6.2	0.6	moyen	260000.00	Paiement en retard	0.85	amelioration	2025-10-08 00:28:38.216148
850	33	4.5	547	4.2	0.3	eleve	225000.00	Nouveau crÃ©dit accordÃ©	0.79	amelioration	2025-02-25 00:28:38.216148
851	33	5.1	580	4.5	0.6	eleve	225000.00	Paiement Ã  temps	0.80	amelioration	2025-04-11 00:28:38.216148
852	33	5.4	597	5.1	0.3	eleve	225000.00	Paiement Ã  temps	0.81	amelioration	2025-05-26 00:28:38.216148
853	33	6.0	630	5.4	0.6	moyen	375000.00	Paiement Ã  temps	0.83	amelioration	2025-07-10 00:28:38.216148
854	33	6.4	652	6.0	0.4	moyen	375000.00	Nouveau crÃ©dit accordÃ©	0.84	amelioration	2025-08-24 00:28:38.216148
855	33	7.0	685	6.4	0.6	moyen	375000.00	Paiement Ã  temps	0.86	amelioration	2025-10-08 00:28:38.216148
856	34	5.5	602	5.1	0.4	eleve	144000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.82	amelioration	2025-02-25 00:28:38.216148
857	34	5.8	619	5.5	0.3	eleve	144000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.82	amelioration	2025-04-11 00:28:38.216148
858	34	6.2	641	5.8	0.4	moyen	240000.00	Paiement Ã  temps	0.84	amelioration	2025-05-26 00:28:38.216148
859	34	6.3	646	6.2	0.1	moyen	240000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.84	stable	2025-07-10 00:28:38.216148
860	34	6.5	657	6.3	0.2	moyen	240000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.85	stable	2025-08-24 00:28:38.216148
861	34	6.9	679	6.5	0.4	moyen	240000.00	Nouveau crÃ©dit accordÃ©	0.86	amelioration	2025-10-08 00:28:38.216148
862	35	5.1	580	4.3	0.8	eleve	186000.00	Paiement Ã  temps	0.80	amelioration	2025-05-26 00:28:38.216148
863	35	5.9	624	5.1	0.8	eleve	186000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.83	amelioration	2025-07-10 00:28:38.216148
864	35	6.6	663	5.9	0.7	moyen	310000.00	Nouveau crÃ©dit accordÃ©	0.85	amelioration	2025-08-24 00:28:38.216148
865	35	7.0	685	6.6	0.4	moyen	310000.00	Paiement Ã  temps	0.86	amelioration	2025-10-08 00:28:38.216148
866	36	5.7	613	5.6	0.1	eleve	192000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.82	stable	2024-10-13 00:28:38.216148
867	36	6.0	630	5.7	0.3	moyen	320000.00	Paiement en retard	0.83	amelioration	2024-11-27 00:28:38.216148
868	36	6.0	630	6.0	0.0	moyen	320000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.83	stable	2025-01-11 00:28:38.216148
869	36	6.2	641	6.0	0.2	moyen	320000.00	Paiement Ã  temps	0.84	stable	2025-02-25 00:28:38.216148
870	36	6.3	646	6.2	0.1	moyen	320000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.84	stable	2025-04-11 00:28:38.216148
871	36	6.5	657	6.3	0.2	moyen	320000.00	Paiement Ã  temps	0.85	stable	2025-05-26 00:28:38.216148
872	36	6.7	668	6.5	0.2	moyen	320000.00	Paiement Ã  temps	0.85	stable	2025-07-10 00:28:38.216148
873	36	6.9	679	6.7	0.2	moyen	320000.00	Nouveau crÃ©dit accordÃ©	0.86	stable	2025-08-24 00:28:38.216148
874	36	6.9	679	6.9	0.0	moyen	320000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.86	stable	2025-10-08 00:28:38.216148
875	37	5.7	613	5.4	0.3	eleve	165000.00	Nouveau crÃ©dit accordÃ©	0.82	amelioration	2025-02-25 00:28:38.216148
876	37	5.8	619	5.7	0.1	eleve	165000.00	Nouveau crÃ©dit accordÃ©	0.82	stable	2025-04-11 00:28:38.216148
877	37	6.0	630	5.8	0.2	moyen	275000.00	Paiement Ã  temps	0.83	stable	2025-05-26 00:28:38.216148
878	37	6.1	635	6.0	0.1	moyen	275000.00	Paiement Ã  temps	0.83	stable	2025-07-10 00:28:38.216148
879	37	6.4	652	6.1	0.3	moyen	275000.00	Paiement Ã  temps	0.84	amelioration	2025-08-24 00:28:38.216148
880	37	6.6	663	6.4	0.2	moyen	275000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.85	stable	2025-10-08 00:28:38.216148
881	38	6.3	646	6.1	0.2	moyen	360000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.84	stable	2025-04-11 00:28:38.216148
882	38	6.5	657	6.3	0.2	moyen	360000.00	Paiement Ã  temps	0.85	stable	2025-05-26 00:28:38.216148
883	38	6.6	663	6.5	0.1	moyen	360000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.85	stable	2025-07-10 00:28:38.216148
884	38	6.9	679	6.6	0.3	moyen	360000.00	Nouveau crÃ©dit accordÃ©	0.86	amelioration	2025-08-24 00:28:38.216148
885	38	7.2	696	6.9	0.3	moyen	360000.00	Paiement Ã  temps	0.87	amelioration	2025-10-08 00:28:38.216148
886	39	5.1	580	4.8	0.3	eleve	144000.00	Paiement en retard	0.80	amelioration	2025-02-25 00:28:38.216148
887	39	5.5	602	5.1	0.4	eleve	144000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.82	amelioration	2025-04-11 00:28:38.216148
888	39	5.8	619	5.5	0.3	eleve	144000.00	Nouveau crÃ©dit accordÃ©	0.82	amelioration	2025-05-26 00:28:38.216148
889	39	6.1	635	5.8	0.3	moyen	240000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.83	amelioration	2025-07-10 00:28:38.216148
890	39	6.2	641	6.1	0.1	moyen	240000.00	Paiement Ã  temps	0.84	stable	2025-08-24 00:28:38.216148
891	39	6.5	657	6.2	0.3	moyen	240000.00	Paiement en retard	0.85	amelioration	2025-10-08 00:28:38.216148
892	40	5.9	624	5.8	0.1	eleve	177000.00	Paiement Ã  temps	0.83	stable	2025-01-11 00:28:38.216148
893	40	6.0	630	5.9	0.1	moyen	295000.00	Paiement Ã  temps	0.83	stable	2025-02-25 00:28:38.216148
894	40	6.2	641	6.0	0.2	moyen	295000.00	Paiement Ã  temps	0.84	stable	2025-04-11 00:28:38.216148
895	40	6.5	657	6.2	0.3	moyen	295000.00	Paiement Ã  temps	0.85	amelioration	2025-05-26 00:28:38.216148
896	40	6.5	657	6.5	0.0	moyen	295000.00	Nouveau crÃ©dit accordÃ©	0.85	stable	2025-07-10 00:28:38.216148
897	40	6.8	674	6.5	0.3	moyen	295000.00	Nouveau crÃ©dit accordÃ©	0.85	amelioration	2025-08-24 00:28:38.216148
898	40	7.1	690	6.8	0.3	moyen	295000.00	Paiement Ã  temps	0.86	amelioration	2025-10-08 00:28:38.216148
899	41	4.8	564	4.3	0.5	eleve	195000.00	Nouveau crÃ©dit accordÃ©	0.79	amelioration	2025-04-11 00:28:38.216148
900	41	5.5	602	4.8	0.7	eleve	195000.00	Nouveau crÃ©dit accordÃ©	0.82	amelioration	2025-05-26 00:28:38.216148
901	41	6.2	641	5.5	0.7	moyen	325000.00	Nouveau crÃ©dit accordÃ©	0.84	amelioration	2025-07-10 00:28:38.216148
902	41	6.8	674	6.2	0.6	moyen	325000.00	Nouveau crÃ©dit accordÃ©	0.85	amelioration	2025-08-24 00:28:38.216148
903	41	7.4	707	6.8	0.6	moyen	325000.00	Paiement en retard	0.87	amelioration	2025-10-08 00:28:38.216148
904	42	5.7	613	5.6	0.1	eleve	168000.00	Nouveau crÃ©dit accordÃ©	0.82	stable	2024-11-27 00:28:38.216148
905	42	5.9	624	5.7	0.2	eleve	168000.00	Paiement Ã  temps	0.83	stable	2025-01-11 00:28:38.216148
906	42	6.1	635	5.9	0.2	moyen	280000.00	Paiement Ã  temps	0.83	stable	2025-02-25 00:28:38.216148
907	42	6.3	646	6.1	0.2	moyen	280000.00	Paiement Ã  temps	0.84	stable	2025-04-11 00:28:38.216148
908	42	6.4	652	6.3	0.1	moyen	280000.00	Paiement Ã  temps	0.84	stable	2025-05-26 00:28:38.216148
909	42	6.5	657	6.4	0.1	moyen	280000.00	Paiement Ã  temps	0.85	stable	2025-07-10 00:28:38.216148
910	42	6.6	663	6.5	0.1	moyen	280000.00	Nouveau crÃ©dit accordÃ©	0.85	stable	2025-08-24 00:28:38.216148
911	42	6.9	679	6.6	0.3	moyen	280000.00	Nouveau crÃ©dit accordÃ©	0.86	amelioration	2025-10-08 00:28:38.216148
912	43	4.8	564	4.4	0.4	eleve	126000.00	Nouveau crÃ©dit accordÃ©	0.79	amelioration	2025-05-26 00:28:38.216148
913	43	5.3	591	4.8	0.5	eleve	126000.00	Paiement Ã  temps	0.81	amelioration	2025-07-10 00:28:38.216148
914	43	5.9	624	5.3	0.6	eleve	126000.00	Nouveau crÃ©dit accordÃ©	0.83	amelioration	2025-08-24 00:28:38.216148
915	43	6.6	663	5.9	0.7	moyen	210000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.85	amelioration	2025-10-08 00:28:38.216148
916	44	4.8	564	4.7	0.1	eleve	135000.00	Nouveau crÃ©dit accordÃ©	0.79	stable	2024-10-13 00:28:38.216148
917	44	4.9	569	4.8	0.1	eleve	135000.00	Nouveau crÃ©dit accordÃ©	0.80	stable	2024-11-27 00:28:38.216148
918	44	5.0	575	4.9	0.1	eleve	135000.00	Paiement Ã  temps	0.80	stable	2025-01-11 00:28:38.216148
919	44	5.4	597	5.0	0.4	eleve	135000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.81	amelioration	2025-02-25 00:28:38.216148
920	44	5.5	602	5.4	0.1	eleve	135000.00	Paiement Ã  temps	0.82	stable	2025-04-11 00:28:38.216148
921	44	5.7	613	5.5	0.2	eleve	135000.00	Paiement Ã  temps	0.82	stable	2025-05-26 00:28:38.216148
922	44	6.0	630	5.7	0.3	moyen	225000.00	Paiement Ã  temps	0.83	amelioration	2025-07-10 00:28:38.216148
923	44	6.4	652	6.0	0.4	moyen	225000.00	Nouveau crÃ©dit accordÃ©	0.84	amelioration	2025-08-24 00:28:38.216148
924	44	6.7	668	6.4	0.3	moyen	225000.00	Paiement Ã  temps	0.85	amelioration	2025-10-08 00:28:38.216148
925	45	4.2	531	3.7	0.5	eleve	114000.00	Nouveau crÃ©dit accordÃ©	0.78	amelioration	2025-05-26 00:28:38.216148
926	45	5.1	580	4.2	0.9	eleve	114000.00	Nouveau crÃ©dit accordÃ©	0.80	amelioration	2025-07-10 00:28:38.216148
927	45	5.7	613	5.1	0.6	eleve	114000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.82	amelioration	2025-08-24 00:28:38.216148
928	45	6.5	657	5.7	0.8	moyen	190000.00	Mise Ã  jour automatique	0.85	amelioration	2025-10-08 00:28:38.216148
929	46	5.6	608	5.3	0.3	eleve	201000.00	Paiement Ã  temps	0.82	amelioration	2024-10-13 00:28:38.216148
930	46	5.8	619	5.6	0.2	eleve	201000.00	Paiement Ã  temps	0.82	stable	2024-11-27 00:28:38.216148
931	46	5.9	624	5.8	0.1	eleve	201000.00	Paiement Ã  temps	0.83	stable	2025-01-11 00:28:38.216148
932	46	6.1	635	5.9	0.2	moyen	335000.00	Paiement Ã  temps	0.83	stable	2025-02-25 00:28:38.216148
933	46	6.2	641	6.1	0.1	moyen	335000.00	Paiement Ã  temps	0.84	stable	2025-04-11 00:28:38.216148
934	46	6.4	652	6.2	0.2	moyen	335000.00	Paiement Ã  temps	0.84	stable	2025-05-26 00:28:38.216148
935	46	6.7	668	6.4	0.3	moyen	335000.00	Paiement Ã  temps	0.85	amelioration	2025-07-10 00:28:38.216148
936	46	6.9	679	6.7	0.2	moyen	335000.00	Nouveau crÃ©dit accordÃ©	0.86	stable	2025-08-24 00:28:38.216148
937	46	7.1	690	6.9	0.2	moyen	335000.00	Nouveau crÃ©dit accordÃ©	0.86	stable	2025-10-08 00:28:38.216148
938	47	4.6	553	4.1	0.5	eleve	138000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.79	amelioration	2025-01-11 00:28:38.216148
939	47	4.8	564	4.6	0.2	eleve	138000.00	Nouveau crÃ©dit accordÃ©	0.79	stable	2025-02-25 00:28:38.216148
940	47	5.1	580	4.8	0.3	eleve	138000.00	Nouveau crÃ©dit accordÃ©	0.80	amelioration	2025-04-11 00:28:38.216148
941	47	5.4	597	5.1	0.3	eleve	138000.00	Nouveau crÃ©dit accordÃ©	0.81	amelioration	2025-05-26 00:28:38.216148
942	47	5.8	619	5.4	0.4	eleve	138000.00	Nouveau crÃ©dit accordÃ©	0.82	amelioration	2025-07-10 00:28:38.216148
943	47	6.1	635	5.8	0.3	moyen	230000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.83	amelioration	2025-08-24 00:28:38.216148
944	47	6.6	663	6.1	0.5	moyen	230000.00	Paiement Ã  temps	0.85	amelioration	2025-10-08 00:28:38.216148
945	48	4.9	569	4.6	0.3	eleve	156000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.80	amelioration	2025-02-25 00:28:38.216148
946	48	5.3	591	4.9	0.4	eleve	156000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.81	amelioration	2025-04-11 00:28:38.216148
947	48	5.8	619	5.3	0.5	eleve	156000.00	Paiement Ã  temps	0.82	amelioration	2025-05-26 00:28:38.216148
948	48	6.0	630	5.8	0.2	moyen	260000.00	Nouveau crÃ©dit accordÃ©	0.83	stable	2025-07-10 00:28:38.216148
949	48	6.5	657	6.0	0.5	moyen	260000.00	Paiement Ã  temps	0.85	amelioration	2025-08-24 00:28:38.216148
950	48	6.9	679	6.5	0.4	moyen	260000.00	Paiement Ã  temps	0.86	amelioration	2025-10-08 00:28:38.216148
951	49	4.5	547	3.5	1.0	eleve	102000.00	Paiement Ã  temps	0.79	amelioration	2025-07-10 00:28:38.216148
952	49	5.2	586	4.5	0.7	eleve	102000.00	Paiement Ã  temps	0.81	amelioration	2025-08-24 00:28:38.216148
953	49	6.2	641	5.2	1.0	moyen	170000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.84	amelioration	2025-10-08 00:28:38.216148
954	50	5.1	580	4.8	0.3	eleve	147000.00	Nouveau crÃ©dit accordÃ©	0.80	amelioration	2025-05-26 00:28:38.216148
955	50	5.6	608	5.1	0.5	eleve	147000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.82	amelioration	2025-07-10 00:28:38.216148
956	50	6.1	635	5.6	0.5	moyen	245000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.83	amelioration	2025-08-24 00:28:38.216148
957	50	6.7	668	6.1	0.6	moyen	245000.00	Paiement Ã  temps	0.85	amelioration	2025-10-08 00:28:38.216148
958	51	5.6	608	5.6	0.0	eleve	162000.00	Paiement en retard	0.82	stable	2024-11-27 00:28:38.216148
959	51	5.7	613	5.6	0.1	eleve	162000.00	Nouveau crÃ©dit accordÃ©	0.82	stable	2025-01-11 00:28:38.216148
960	51	5.8	619	5.7	0.1	eleve	162000.00	Paiement Ã  temps	0.82	stable	2025-02-25 00:28:38.216148
961	51	6.0	630	5.8	0.2	moyen	270000.00	Nouveau crÃ©dit accordÃ©	0.83	stable	2025-04-11 00:28:38.216148
962	51	6.3	646	6.0	0.3	moyen	270000.00	Nouveau crÃ©dit accordÃ©	0.84	amelioration	2025-05-26 00:28:38.216148
963	51	6.5	657	6.3	0.2	moyen	270000.00	Nouveau crÃ©dit accordÃ©	0.85	stable	2025-07-10 00:28:38.216148
964	51	6.7	668	6.5	0.2	moyen	270000.00	Paiement en retard	0.85	stable	2025-08-24 00:28:38.216148
965	51	6.9	679	6.7	0.2	moyen	270000.00	Nouveau crÃ©dit accordÃ©	0.86	stable	2025-10-08 00:28:38.216148
966	52	4.1	525	3.6	0.5	eleve	108000.00	Nouveau crÃ©dit accordÃ©	0.77	amelioration	2024-11-27 00:28:38.216148
967	52	4.3	536	4.1	0.2	eleve	108000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.78	stable	2025-01-11 00:28:38.216148
968	52	4.5	547	4.3	0.2	eleve	108000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.79	stable	2025-02-25 00:28:38.216148
969	52	4.9	569	4.5	0.4	eleve	108000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.80	amelioration	2025-04-11 00:28:38.216148
970	52	5.2	586	4.9	0.3	eleve	108000.00	Nouveau crÃ©dit accordÃ©	0.81	amelioration	2025-05-26 00:28:38.216148
971	52	5.6	608	5.2	0.4	eleve	108000.00	Paiement Ã  temps	0.82	amelioration	2025-07-10 00:28:38.216148
972	52	5.8	619	5.6	0.2	eleve	108000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.82	stable	2025-08-24 00:28:38.216148
973	52	6.2	641	5.8	0.4	moyen	180000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.84	amelioration	2025-10-08 00:28:38.216148
974	53	4.2	531	3.7	0.5	eleve	141000.00	Nouveau crÃ©dit accordÃ©	0.78	amelioration	2025-01-11 00:28:38.216148
975	53	4.7	558	4.2	0.5	eleve	141000.00	Paiement Ã  temps	0.79	amelioration	2025-02-25 00:28:38.216148
976	53	5.0	575	4.7	0.3	eleve	141000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.80	amelioration	2025-04-11 00:28:38.216148
977	53	5.4	597	5.0	0.4	eleve	141000.00	Nouveau crÃ©dit accordÃ©	0.81	amelioration	2025-05-26 00:28:38.216148
978	53	5.8	619	5.4	0.4	eleve	141000.00	Nouveau crÃ©dit accordÃ©	0.82	amelioration	2025-07-10 00:28:38.216148
979	53	6.1	635	5.8	0.3	moyen	235000.00	Nouveau crÃ©dit accordÃ©	0.83	amelioration	2025-08-24 00:28:38.216148
980	53	6.6	663	6.1	0.5	moyen	235000.00	Paiement Ã  temps	0.85	amelioration	2025-10-08 00:28:38.216148
981	54	5.6	608	5.3	0.3	eleve	165000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.82	amelioration	2025-01-11 00:28:38.216148
982	54	5.7	613	5.6	0.1	eleve	165000.00	Nouveau crÃ©dit accordÃ©	0.82	stable	2025-02-25 00:28:38.216148
983	54	6.0	630	5.7	0.3	moyen	275000.00	Nouveau crÃ©dit accordÃ©	0.83	amelioration	2025-04-11 00:28:38.216148
984	54	6.3	646	6.0	0.3	moyen	275000.00	Nouveau crÃ©dit accordÃ©	0.84	amelioration	2025-05-26 00:28:38.216148
985	54	6.5	657	6.3	0.2	moyen	275000.00	Paiement en retard	0.85	stable	2025-07-10 00:28:38.216148
986	54	6.8	674	6.5	0.3	moyen	275000.00	Paiement Ã  temps	0.85	amelioration	2025-08-24 00:28:38.216148
987	54	7.0	685	6.8	0.2	moyen	275000.00	Nouveau crÃ©dit accordÃ©	0.86	stable	2025-10-08 00:28:38.216148
988	55	3.9	514	3.3	0.6	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.77	amelioration	2025-02-25 00:28:38.216148
989	55	4.5	547	3.9	0.6	eleve	105000.00	Paiement Ã  temps	0.79	amelioration	2025-04-11 00:28:38.216148
990	55	5.0	575	4.5	0.5	eleve	105000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.80	amelioration	2025-05-26 00:28:38.216148
991	55	5.3	591	5.0	0.3	eleve	105000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.81	amelioration	2025-07-10 00:28:38.216148
992	55	5.8	619	5.3	0.5	eleve	105000.00	Nouveau crÃ©dit accordÃ©	0.82	amelioration	2025-08-24 00:28:38.216148
993	55	6.3	646	5.8	0.5	moyen	175000.00	Nouveau crÃ©dit accordÃ©	0.84	amelioration	2025-10-08 00:28:38.216148
994	56	5.6	608	5.3	0.3	eleve	174000.00	Nouveau crÃ©dit accordÃ©	0.82	amelioration	2025-05-26 00:28:38.216148
995	56	6.0	630	5.6	0.4	moyen	290000.00	Nouveau crÃ©dit accordÃ©	0.83	amelioration	2025-07-10 00:28:38.216148
996	56	6.4	652	6.0	0.4	moyen	290000.00	Paiement Ã  temps	0.84	amelioration	2025-08-24 00:28:38.216148
997	56	7.1	690	6.4	0.7	moyen	290000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.86	amelioration	2025-10-08 00:28:38.216148
998	57	4.1	525	3.8	0.3	eleve	126000.00	Nouveau crÃ©dit accordÃ©	0.77	amelioration	2024-08-29 00:28:38.216148
999	57	4.3	536	4.1	0.2	eleve	126000.00	Nouveau crÃ©dit accordÃ©	0.78	stable	2024-10-13 00:28:38.216148
1000	57	4.5	547	4.3	0.2	eleve	126000.00	Nouveau crÃ©dit accordÃ©	0.79	stable	2024-11-27 00:28:38.216148
1001	57	4.9	569	4.5	0.4	eleve	126000.00	Nouveau crÃ©dit accordÃ©	0.80	amelioration	2025-01-11 00:28:38.216148
1002	57	5.3	591	4.9	0.4	eleve	126000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.81	amelioration	2025-02-25 00:28:38.216148
1003	57	5.7	613	5.3	0.4	eleve	126000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.82	amelioration	2025-04-11 00:28:38.216148
1004	57	5.8	619	5.7	0.1	eleve	126000.00	Nouveau crÃ©dit accordÃ©	0.82	stable	2025-05-26 00:28:38.216148
1005	57	6.1	635	5.8	0.3	moyen	210000.00	Nouveau crÃ©dit accordÃ©	0.83	amelioration	2025-07-10 00:28:38.216148
1006	57	6.4	652	6.1	0.3	moyen	210000.00	Paiement Ã  temps	0.84	amelioration	2025-08-24 00:28:38.216148
1007	57	6.6	663	6.4	0.2	moyen	210000.00	Nouveau crÃ©dit accordÃ©	0.85	stable	2025-10-08 00:28:38.216148
1008	58	5.0	575	4.1	0.9	eleve	153000.00	Nouveau crÃ©dit accordÃ©	0.80	amelioration	2025-07-10 00:28:38.216148
1009	58	5.8	619	5.0	0.8	eleve	153000.00	Paiement Ã  temps	0.82	amelioration	2025-08-24 00:28:38.216148
1010	58	6.7	668	5.8	0.9	moyen	255000.00	Paiement Ã  temps	0.85	amelioration	2025-10-08 00:28:38.216148
1011	59	5.1	580	4.6	0.5	eleve	117000.00	Paiement en retard	0.80	amelioration	2025-05-26 00:28:38.216148
1012	59	5.5	602	5.1	0.4	eleve	117000.00	Nouveau crÃ©dit accordÃ©	0.82	amelioration	2025-07-10 00:28:38.216148
1013	59	6.1	635	5.5	0.6	moyen	195000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.83	amelioration	2025-08-24 00:28:38.216148
1014	59	6.4	652	6.1	0.3	moyen	195000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.84	amelioration	2025-10-08 00:28:38.216148
1015	60	5.5	602	5.2	0.3	eleve	156000.00	Paiement Ã  temps	0.82	amelioration	2024-11-27 00:28:38.216148
1016	60	5.6	608	5.5	0.1	eleve	156000.00	Paiement Ã  temps	0.82	stable	2025-01-11 00:28:38.216148
1017	60	5.9	624	5.6	0.3	eleve	156000.00	Nouveau crÃ©dit accordÃ©	0.83	amelioration	2025-02-25 00:28:38.216148
1018	60	6.2	641	5.9	0.3	moyen	260000.00	Nouveau crÃ©dit accordÃ©	0.84	amelioration	2025-04-11 00:28:38.216148
1019	60	6.5	657	6.2	0.3	moyen	260000.00	Paiement Ã  temps	0.85	amelioration	2025-05-26 00:28:38.216148
1020	60	6.6	663	6.5	0.1	moyen	260000.00	Nouveau crÃ©dit accordÃ©	0.85	stable	2025-07-10 00:28:38.216148
1021	60	6.7	668	6.6	0.1	moyen	260000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.85	stable	2025-08-24 00:28:38.216148
1022	60	6.8	674	6.7	0.1	moyen	260000.00	Paiement Ã  temps	0.85	stable	2025-10-08 00:28:38.216148
1023	61	5.3	591	5.0	0.3	eleve	180000.00	Paiement Ã  temps	0.81	amelioration	2024-08-29 00:28:38.216148
1024	61	5.6	608	5.3	0.3	eleve	180000.00	Nouveau crÃ©dit accordÃ©	0.82	amelioration	2024-10-13 00:28:38.216148
1025	61	5.9	624	5.6	0.3	eleve	180000.00	Nouveau crÃ©dit accordÃ©	0.83	amelioration	2024-11-27 00:28:38.216148
1026	61	6.0	630	5.9	0.1	moyen	300000.00	Nouveau crÃ©dit accordÃ©	0.83	stable	2025-01-11 00:28:38.216148
1027	61	6.3	646	6.0	0.3	moyen	300000.00	Paiement en retard	0.84	amelioration	2025-02-25 00:28:38.216148
1028	61	6.5	657	6.3	0.2	moyen	300000.00	Nouveau crÃ©dit accordÃ©	0.85	stable	2025-04-11 00:28:38.216148
1029	61	6.5	657	6.5	0.0	moyen	300000.00	Nouveau crÃ©dit accordÃ©	0.85	stable	2025-05-26 00:28:38.216148
1030	61	6.7	668	6.5	0.2	moyen	300000.00	Nouveau crÃ©dit accordÃ©	0.85	stable	2025-07-10 00:28:38.216148
1031	61	6.8	674	6.7	0.1	moyen	300000.00	Paiement Ã  temps	0.85	stable	2025-08-24 00:28:38.216148
1032	61	7.2	696	6.8	0.4	moyen	300000.00	Nouveau crÃ©dit accordÃ©	0.87	amelioration	2025-10-08 00:28:38.216148
1033	62	4.9	569	4.4	0.5	eleve	204000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.80	amelioration	2025-01-11 00:28:38.216148
1034	62	5.2	586	4.9	0.3	eleve	204000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.81	amelioration	2025-02-25 00:28:38.216148
1035	62	5.6	608	5.2	0.4	eleve	204000.00	Paiement Ã  temps	0.82	amelioration	2025-04-11 00:28:38.216148
1036	62	5.9	624	5.6	0.3	eleve	204000.00	Nouveau crÃ©dit accordÃ©	0.83	amelioration	2025-05-26 00:28:38.216148
1037	62	6.3	646	5.9	0.4	moyen	340000.00	Nouveau crÃ©dit accordÃ©	0.84	amelioration	2025-07-10 00:28:38.216148
1038	62	6.8	674	6.3	0.5	moyen	340000.00	Paiement Ã  temps	0.85	amelioration	2025-08-24 00:28:38.216148
1039	62	7.1	690	6.8	0.3	moyen	340000.00	Paiement Ã  temps	0.86	amelioration	2025-10-08 00:28:38.216148
1040	63	4.9	569	4.0	0.9	eleve	186000.00	Nouveau crÃ©dit accordÃ©	0.80	amelioration	2025-05-26 00:28:38.216148
1041	63	5.6	608	4.9	0.7	eleve	186000.00	Paiement Ã  temps	0.82	amelioration	2025-07-10 00:28:38.216148
1042	63	6.2	641	5.6	0.6	moyen	310000.00	Nouveau crÃ©dit accordÃ©	0.84	amelioration	2025-08-24 00:28:38.216148
1043	63	7.1	690	6.2	0.9	moyen	310000.00	Nouveau crÃ©dit accordÃ©	0.86	amelioration	2025-10-08 00:28:38.216148
1044	64	4.8	564	4.6	0.2	eleve	132000.00	Paiement Ã  temps	0.79	stable	2024-10-13 00:28:38.216148
1045	64	5.0	575	4.8	0.2	eleve	132000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.80	stable	2024-11-27 00:28:38.216148
1046	64	5.2	586	5.0	0.2	eleve	132000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.81	stable	2025-01-11 00:28:38.216148
1047	64	5.6	608	5.2	0.4	eleve	132000.00	Nouveau crÃ©dit accordÃ©	0.82	amelioration	2025-02-25 00:28:38.216148
1048	64	5.8	619	5.6	0.2	eleve	132000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.82	stable	2025-04-11 00:28:38.216148
1049	64	6.0	630	5.8	0.2	moyen	220000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.83	stable	2025-05-26 00:28:38.216148
1050	64	6.3	646	6.0	0.3	moyen	220000.00	Paiement Ã  temps	0.84	amelioration	2025-07-10 00:28:38.216148
1051	64	6.4	652	6.3	0.1	moyen	220000.00	Paiement Ã  temps	0.84	stable	2025-08-24 00:28:38.216148
1052	64	6.6	663	6.4	0.2	moyen	220000.00	Paiement Ã  temps	0.85	stable	2025-10-08 00:28:38.216148
1053	65	5.7	613	5.0	0.7	eleve	150000.00	Paiement Ã  temps	0.82	amelioration	2025-07-10 00:28:38.216148
1054	65	6.4	652	5.7	0.7	moyen	250000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.84	amelioration	2025-08-24 00:28:38.216148
1055	65	6.7	668	6.4	0.3	moyen	250000.00	Paiement Ã  temps	0.85	amelioration	2025-10-08 00:28:38.216148
1056	66	6.2	641	6.1	0.1	moyen	310000.00	Paiement Ã  temps	0.84	stable	2024-10-13 00:28:38.216148
1057	66	6.4	652	6.2	0.2	moyen	310000.00	Paiement Ã  temps	0.84	stable	2024-11-27 00:28:38.216148
1058	66	6.4	652	6.4	0.0	moyen	310000.00	Paiement Ã  temps	0.84	stable	2025-01-11 00:28:38.216148
1059	66	6.4	652	6.4	0.0	moyen	310000.00	Nouveau crÃ©dit accordÃ©	0.84	stable	2025-02-25 00:28:38.216148
1060	66	6.6	663	6.4	0.2	moyen	310000.00	Paiement Ã  temps	0.85	stable	2025-04-11 00:28:38.216148
1061	66	6.6	663	6.6	0.0	moyen	310000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.85	stable	2025-05-26 00:28:38.216148
1062	66	6.7	668	6.6	0.1	moyen	310000.00	Nouveau crÃ©dit accordÃ©	0.85	stable	2025-07-10 00:28:38.216148
1063	66	6.9	679	6.7	0.2	moyen	310000.00	Paiement Ã  temps	0.86	stable	2025-08-24 00:28:38.216148
1064	66	7.0	685	6.9	0.1	moyen	310000.00	Nouveau crÃ©dit accordÃ©	0.86	stable	2025-10-08 00:28:38.216148
1065	67	5.8	619	5.4	0.4	eleve	165000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.82	amelioration	2025-05-26 00:28:38.216148
1066	67	6.0	630	5.8	0.2	moyen	275000.00	Paiement Ã  temps	0.83	stable	2025-07-10 00:28:38.216148
1067	67	6.5	657	6.0	0.5	moyen	275000.00	Nouveau crÃ©dit accordÃ©	0.85	amelioration	2025-08-24 00:28:38.216148
1068	67	6.8	674	6.5	0.3	moyen	275000.00	Paiement Ã  temps	0.85	amelioration	2025-10-08 00:28:38.216148
1069	68	3.9	514	3.5	0.4	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.77	amelioration	2024-08-29 00:28:38.216148
1070	68	4.1	525	3.9	0.2	eleve	114000.00	Nouveau crÃ©dit accordÃ©	0.77	stable	2024-10-13 00:28:38.216148
1071	68	4.4	542	4.1	0.3	eleve	114000.00	Paiement Ã  temps	0.78	amelioration	2024-11-27 00:28:38.216148
1072	68	4.6	553	4.4	0.2	eleve	114000.00	Paiement Ã  temps	0.79	stable	2025-01-11 00:28:38.216148
1073	68	4.9	569	4.6	0.3	eleve	114000.00	Paiement Ã  temps	0.80	amelioration	2025-02-25 00:28:38.216148
1074	68	5.2	586	4.9	0.3	eleve	114000.00	Nouveau crÃ©dit accordÃ©	0.81	amelioration	2025-04-11 00:28:38.216148
1075	68	5.5	602	5.2	0.3	eleve	114000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.82	amelioration	2025-05-26 00:28:38.216148
1076	68	5.8	619	5.5	0.3	eleve	114000.00	Nouveau crÃ©dit accordÃ©	0.82	amelioration	2025-07-10 00:28:38.216148
1077	68	6.1	635	5.8	0.3	moyen	190000.00	Paiement Ã  temps	0.83	amelioration	2025-08-24 00:28:38.216148
1078	68	6.2	641	6.1	0.1	moyen	190000.00	Nouveau crÃ©dit accordÃ©	0.84	stable	2025-10-08 00:28:38.216148
1079	69	4.2	531	3.7	0.5	eleve	138000.00	Nouveau crÃ©dit accordÃ©	0.78	amelioration	2025-02-25 00:28:38.216148
1080	69	4.8	564	4.2	0.6	eleve	138000.00	Paiement Ã  temps	0.79	amelioration	2025-04-11 00:28:38.216148
1081	69	5.4	597	4.8	0.6	eleve	138000.00	Paiement Ã  temps	0.81	amelioration	2025-05-26 00:28:38.216148
1082	69	5.9	624	5.4	0.5	eleve	138000.00	Paiement Ã  temps	0.83	amelioration	2025-07-10 00:28:38.216148
1083	69	6.2	641	5.9	0.3	moyen	230000.00	Nouveau crÃ©dit accordÃ©	0.84	amelioration	2025-08-24 00:28:38.216148
1084	69	6.7	668	6.2	0.5	moyen	230000.00	Paiement en retard	0.85	amelioration	2025-10-08 00:28:38.216148
1085	70	4.4	542	4.2	0.2	eleve	84000.00	Nouveau crÃ©dit accordÃ©	0.78	stable	2024-11-27 00:28:38.216148
1086	70	4.6	553	4.4	0.2	eleve	84000.00	Nouveau crÃ©dit accordÃ©	0.79	stable	2025-01-11 00:28:38.216148
1087	70	4.8	564	4.6	0.2	eleve	84000.00	Paiement Ã  temps	0.79	stable	2025-02-25 00:28:38.216148
1088	70	4.9	569	4.8	0.1	eleve	84000.00	Nouveau crÃ©dit accordÃ©	0.80	stable	2025-04-11 00:28:38.216148
1089	70	5.0	575	4.9	0.1	eleve	84000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.80	stable	2025-05-26 00:28:38.216148
1090	70	5.0	575	5.0	0.0	eleve	84000.00	Paiement Ã  temps	0.80	stable	2025-07-10 00:28:38.216148
1091	70	5.1	580	5.0	0.1	eleve	84000.00	Paiement Ã  temps	0.80	stable	2025-08-24 00:28:38.216148
1092	70	5.2	586	5.1	0.1	eleve	84000.00	Paiement Ã  temps	0.81	stable	2025-10-08 00:28:38.216148
1093	71	3.9	514	3.8	0.1	tres_eleve	0.00	Paiement Ã  temps	0.77	stable	2024-11-27 00:28:38.216148
1094	71	3.9	514	3.9	0.0	tres_eleve	0.00	Paiement Ã  temps	0.77	stable	2025-01-11 00:28:38.216148
1095	71	3.9	514	3.9	0.0	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.77	stable	2025-02-25 00:28:38.216148
1096	71	4.1	525	3.9	0.2	eleve	54000.00	Paiement Ã  temps	0.77	stable	2025-04-11 00:28:38.216148
1097	71	4.2	531	4.1	0.1	eleve	54000.00	Paiement Ã  temps	0.78	stable	2025-05-26 00:28:38.216148
1098	71	4.4	542	4.2	0.2	eleve	54000.00	Nouveau crÃ©dit accordÃ©	0.78	stable	2025-07-10 00:28:38.216148
1099	71	4.5	547	4.4	0.1	eleve	54000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.79	stable	2025-08-24 00:28:38.216148
1100	71	4.7	558	4.5	0.2	eleve	54000.00	Nouveau crÃ©dit accordÃ©	0.79	stable	2025-10-08 00:28:38.216148
1101	72	3.4	487	3.2	0.2	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.75	stable	2024-08-29 00:28:38.216148
1102	72	3.6	498	3.4	0.2	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.76	stable	2024-10-13 00:28:38.216148
1103	72	3.7	503	3.6	0.1	tres_eleve	0.00	Paiement Ã  temps	0.76	stable	2024-11-27 00:28:38.216148
1104	72	3.9	514	3.7	0.2	tres_eleve	0.00	Paiement Ã  temps	0.77	stable	2025-01-11 00:28:38.216148
1105	72	4.0	520	3.9	0.1	eleve	66000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.77	stable	2025-02-25 00:28:38.216148
1106	72	4.0	520	4.0	0.0	eleve	66000.00	Nouveau crÃ©dit accordÃ©	0.77	stable	2025-04-11 00:28:38.216148
1107	72	4.0	520	4.0	0.0	eleve	66000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.77	stable	2025-05-26 00:28:38.216148
1108	72	4.3	536	4.0	0.3	eleve	66000.00	Paiement Ã  temps	0.78	amelioration	2025-07-10 00:28:38.216148
1109	72	4.4	542	4.3	0.1	eleve	66000.00	Paiement Ã  temps	0.78	stable	2025-08-24 00:28:38.216148
1110	72	4.6	553	4.4	0.2	eleve	66000.00	Paiement Ã  temps	0.79	stable	2025-10-08 00:28:38.216148
1111	73	3.4	487	3.0	0.4	tres_eleve	0.00	Paiement Ã  temps	0.75	amelioration	2025-05-26 00:28:38.216148
1112	73	3.7	503	3.4	0.3	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.76	amelioration	2025-07-10 00:28:38.216148
1113	73	4.1	525	3.7	0.4	eleve	57000.00	Paiement Ã  temps	0.77	amelioration	2025-08-24 00:28:38.216148
1114	73	4.5	547	4.1	0.4	eleve	57000.00	Paiement Ã  temps	0.79	amelioration	2025-10-08 00:28:38.216148
1115	74	3.9	514	3.9	0.0	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.77	stable	2024-08-29 00:28:38.216148
1116	74	4.0	520	3.9	0.1	eleve	72000.00	Paiement Ã  temps	0.77	stable	2024-10-13 00:28:38.216148
1117	74	4.2	531	4.0	0.2	eleve	72000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.78	stable	2024-11-27 00:28:38.216148
1118	74	4.3	536	4.2	0.1	eleve	72000.00	Paiement Ã  temps	0.78	stable	2025-01-11 00:28:38.216148
1119	74	4.5	547	4.3	0.2	eleve	72000.00	Nouveau crÃ©dit accordÃ©	0.79	stable	2025-02-25 00:28:38.216148
1120	74	4.6	553	4.5	0.1	eleve	72000.00	Paiement en retard	0.79	stable	2025-04-11 00:28:38.216148
1121	74	4.6	553	4.6	0.0	eleve	72000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.79	stable	2025-05-26 00:28:38.216148
1122	74	4.6	553	4.6	0.0	eleve	72000.00	Nouveau crÃ©dit accordÃ©	0.79	stable	2025-07-10 00:28:38.216148
1123	74	4.7	558	4.6	0.1	eleve	72000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.79	stable	2025-08-24 00:28:38.216148
1124	74	4.8	564	4.7	0.1	eleve	72000.00	Paiement en retard	0.79	stable	2025-10-08 00:28:38.216148
1125	75	3.1	470	2.4	0.7	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.74	amelioration	2025-05-26 00:28:38.216148
1126	75	3.6	498	3.1	0.5	tres_eleve	0.00	Paiement Ã  temps	0.76	amelioration	2025-07-10 00:28:38.216148
1127	75	4.2	531	3.6	0.6	eleve	63000.00	Nouveau crÃ©dit accordÃ©	0.78	amelioration	2025-08-24 00:28:38.216148
1128	75	5.1	580	4.2	0.9	eleve	63000.00	Paiement Ã  temps	0.80	amelioration	2025-10-08 00:28:38.216148
1129	76	2.2	421	1.9	0.3	tres_eleve	0.00	Paiement Ã  temps	0.72	amelioration	2025-02-25 00:28:38.216148
1130	76	2.7	448	2.2	0.5	tres_eleve	0.00	Paiement Ã  temps	0.73	amelioration	2025-04-11 00:28:38.216148
1131	76	3.0	465	2.7	0.3	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.74	amelioration	2025-05-26 00:28:38.216148
1132	76	3.4	487	3.0	0.4	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.75	amelioration	2025-07-10 00:28:38.216148
1133	76	3.8	509	3.4	0.4	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.76	amelioration	2025-08-24 00:28:38.216148
1134	76	4.3	536	3.8	0.5	eleve	48000.00	Nouveau crÃ©dit accordÃ©	0.78	amelioration	2025-10-08 00:28:38.216148
1135	77	3.5	492	3.4	0.1	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.76	stable	2025-01-11 00:28:38.216148
1136	77	3.8	509	3.5	0.3	tres_eleve	0.00	Paiement Ã  temps	0.76	amelioration	2025-02-25 00:28:38.216148
1137	77	4.0	520	3.8	0.2	eleve	60000.00	Paiement Ã  temps	0.77	stable	2025-04-11 00:28:38.216148
1138	77	4.1	525	4.0	0.1	eleve	60000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.77	stable	2025-05-26 00:28:38.216148
1139	77	4.3	536	4.1	0.2	eleve	60000.00	Nouveau crÃ©dit accordÃ©	0.78	stable	2025-07-10 00:28:38.216148
1140	77	4.4	542	4.3	0.1	eleve	60000.00	Nouveau crÃ©dit accordÃ©	0.78	stable	2025-08-24 00:28:38.216148
1141	77	4.8	564	4.4	0.4	eleve	60000.00	Nouveau crÃ©dit accordÃ©	0.79	amelioration	2025-10-08 00:28:38.216148
1142	78	3.2	476	2.8	0.4	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.75	amelioration	2024-10-13 00:28:38.216148
1143	78	3.3	481	3.2	0.1	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.75	stable	2024-11-27 00:28:38.216148
1144	78	3.6	498	3.3	0.3	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.76	amelioration	2025-01-11 00:28:38.216148
1145	78	3.8	509	3.6	0.2	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.76	stable	2025-02-25 00:28:38.216148
1146	78	4.1	525	3.8	0.3	eleve	75000.00	Paiement Ã  temps	0.77	amelioration	2025-04-11 00:28:38.216148
1147	78	4.3	536	4.1	0.2	eleve	75000.00	Paiement Ã  temps	0.78	stable	2025-05-26 00:28:38.216148
1148	78	4.6	553	4.3	0.3	eleve	75000.00	Paiement Ã  temps	0.79	amelioration	2025-07-10 00:28:38.216148
1149	78	4.9	569	4.6	0.3	eleve	75000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.80	amelioration	2025-08-24 00:28:38.216148
1150	78	5.0	575	4.9	0.1	eleve	75000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.80	stable	2025-10-08 00:28:38.216148
1151	79	3.9	514	3.9	0.0	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.77	stable	2024-10-13 00:28:38.216148
1152	79	4.2	531	3.9	0.3	eleve	69000.00	Paiement Ã  temps	0.78	amelioration	2024-11-27 00:28:38.216148
1153	79	4.4	542	4.2	0.2	eleve	69000.00	Nouveau crÃ©dit accordÃ©	0.78	stable	2025-01-11 00:28:38.216148
1154	79	4.6	553	4.4	0.2	eleve	69000.00	Paiement Ã  temps	0.79	stable	2025-02-25 00:28:38.216148
1155	79	4.7	558	4.6	0.1	eleve	69000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.79	stable	2025-04-11 00:28:38.216148
1156	79	4.9	569	4.7	0.2	eleve	69000.00	Paiement Ã  temps	0.80	stable	2025-05-26 00:28:38.216148
1157	79	4.9	569	4.9	0.0	eleve	69000.00	Paiement Ã  temps	0.80	stable	2025-07-10 00:28:38.216148
1158	79	5.0	575	4.9	0.1	eleve	69000.00	Paiement Ã  temps	0.80	stable	2025-08-24 00:28:38.216148
1159	79	5.1	580	5.0	0.1	eleve	69000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.80	stable	2025-10-08 00:28:38.216148
1160	80	3.3	481	3.2	0.1	tres_eleve	0.00	Paiement Ã  temps	0.75	stable	2024-10-13 00:28:38.216148
1161	80	3.6	498	3.3	0.3	tres_eleve	0.00	Paiement Ã  temps	0.76	amelioration	2024-11-27 00:28:38.216148
1162	80	3.6	498	3.6	0.0	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.76	stable	2025-01-11 00:28:38.216148
1163	80	3.8	509	3.6	0.2	tres_eleve	0.00	Paiement Ã  temps	0.76	stable	2025-02-25 00:28:38.216148
1164	80	4.0	520	3.8	0.2	eleve	51000.00	Nouveau crÃ©dit accordÃ©	0.77	stable	2025-04-11 00:28:38.216148
1165	80	4.0	520	4.0	0.0	eleve	51000.00	Paiement en retard	0.77	stable	2025-05-26 00:28:38.216148
1166	80	4.2	531	4.0	0.2	eleve	51000.00	Nouveau crÃ©dit accordÃ©	0.78	stable	2025-07-10 00:28:38.216148
1167	80	4.3	536	4.2	0.1	eleve	51000.00	Nouveau crÃ©dit accordÃ©	0.78	stable	2025-08-24 00:28:38.216148
1168	80	4.5	547	4.3	0.2	eleve	51000.00	Paiement Ã  temps	0.79	stable	2025-10-08 00:28:38.216148
1169	81	3.6	498	3.3	0.3	tres_eleve	0.00	Paiement Ã  temps	0.76	amelioration	2024-11-27 00:28:38.216148
1170	81	3.8	509	3.6	0.2	tres_eleve	0.00	Paiement Ã  temps	0.76	stable	2025-01-11 00:28:38.216148
1171	81	4.0	520	3.8	0.2	eleve	78000.00	Nouveau crÃ©dit accordÃ©	0.77	stable	2025-02-25 00:28:38.216148
1172	81	4.3	536	4.0	0.3	eleve	78000.00	Paiement Ã  temps	0.78	amelioration	2025-04-11 00:28:38.216148
1173	81	4.6	553	4.3	0.3	eleve	78000.00	Nouveau crÃ©dit accordÃ©	0.79	amelioration	2025-05-26 00:28:38.216148
1174	81	4.8	564	4.6	0.2	eleve	78000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.79	stable	2025-07-10 00:28:38.216148
1175	81	5.1	580	4.8	0.3	eleve	78000.00	Paiement Ã  temps	0.80	amelioration	2025-08-24 00:28:38.216148
1176	81	5.3	591	5.1	0.2	eleve	78000.00	Paiement Ã  temps	0.81	stable	2025-10-08 00:28:38.216148
1177	82	2.6	443	2.2	0.4	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.73	amelioration	2025-02-25 00:28:38.216148
1178	82	3.1	470	2.6	0.5	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.74	amelioration	2025-04-11 00:28:38.216148
1179	82	3.4	487	3.1	0.3	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.75	amelioration	2025-05-26 00:28:38.216148
1180	82	3.9	514	3.4	0.5	tres_eleve	0.00	Paiement Ã  temps	0.77	amelioration	2025-07-10 00:28:38.216148
1181	82	4.2	531	3.9	0.3	eleve	55500.00	CrÃ©dit remboursÃ© intÃ©gralement	0.78	amelioration	2025-08-24 00:28:38.216148
1182	82	4.6	553	4.2	0.4	eleve	55500.00	Paiement Ã  temps	0.79	amelioration	2025-10-08 00:28:38.216148
1183	83	2.7	448	2.4	0.3	tres_eleve	0.00	Paiement Ã  temps	0.73	amelioration	2025-02-25 00:28:38.216148
1184	83	3.2	476	2.7	0.5	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.75	amelioration	2025-04-11 00:28:38.216148
1185	83	3.7	503	3.2	0.5	tres_eleve	0.00	Paiement Ã  temps	0.76	amelioration	2025-05-26 00:28:38.216148
1186	83	3.9	514	3.7	0.2	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.77	stable	2025-07-10 00:28:38.216148
1187	83	4.2	531	3.9	0.3	eleve	58500.00	Paiement Ã  temps	0.78	amelioration	2025-08-24 00:28:38.216148
1188	83	4.6	553	4.2	0.4	eleve	58500.00	Nouveau crÃ©dit accordÃ©	0.79	amelioration	2025-10-08 00:28:38.216148
1189	84	4.1	525	3.9	0.2	eleve	81000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.77	stable	2024-10-13 00:28:38.216148
1190	84	4.2	531	4.1	0.1	eleve	81000.00	Nouveau crÃ©dit accordÃ©	0.78	stable	2024-11-27 00:28:38.216148
1191	84	4.2	531	4.2	0.0	eleve	81000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.78	stable	2025-01-11 00:28:38.216148
1192	84	4.4	542	4.2	0.2	eleve	81000.00	Nouveau crÃ©dit accordÃ©	0.78	stable	2025-02-25 00:28:38.216148
1193	84	4.7	558	4.4	0.3	eleve	81000.00	Paiement Ã  temps	0.79	amelioration	2025-04-11 00:28:38.216148
1194	84	4.8	564	4.7	0.1	eleve	81000.00	Nouveau crÃ©dit accordÃ©	0.79	stable	2025-05-26 00:28:38.216148
1195	84	5.1	580	4.8	0.3	eleve	81000.00	Paiement Ã  temps	0.80	amelioration	2025-07-10 00:28:38.216148
1196	84	5.2	586	5.1	0.1	eleve	81000.00	Nouveau crÃ©dit accordÃ©	0.81	stable	2025-08-24 00:28:38.216148
1197	84	5.4	597	5.2	0.2	eleve	81000.00	Nouveau crÃ©dit accordÃ©	0.81	stable	2025-10-08 00:28:38.216148
1198	85	3.5	492	3.3	0.2	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.76	stable	2025-04-11 00:28:38.216148
1199	85	3.8	509	3.5	0.3	tres_eleve	0.00	Paiement Ã  temps	0.76	amelioration	2025-05-26 00:28:38.216148
1200	85	4.2	531	3.8	0.4	eleve	52500.00	Nouveau crÃ©dit accordÃ©	0.78	amelioration	2025-07-10 00:28:38.216148
1201	85	4.4	542	4.2	0.2	eleve	52500.00	Nouveau crÃ©dit accordÃ©	0.78	stable	2025-08-24 00:28:38.216148
1202	85	4.5	547	4.4	0.1	eleve	52500.00	Paiement Ã  temps	0.79	stable	2025-10-08 00:28:38.216148
1203	86	3.0	465	2.7	0.3	tres_eleve	0.00	Paiement Ã  temps	0.74	amelioration	2024-10-13 00:28:38.216148
1204	86	3.1	470	3.0	0.1	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.74	stable	2024-11-27 00:28:38.216148
1205	86	3.3	481	3.1	0.2	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.75	stable	2025-01-11 00:28:38.216148
1206	86	3.6	498	3.3	0.3	tres_eleve	0.00	Paiement Ã  temps	0.76	amelioration	2025-02-25 00:28:38.216148
1207	86	3.7	503	3.6	0.1	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.76	stable	2025-04-11 00:28:38.216148
1208	86	3.9	514	3.7	0.2	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.77	stable	2025-05-26 00:28:38.216148
1209	86	4.1	525	3.9	0.2	eleve	46500.00	CrÃ©dit remboursÃ© intÃ©gralement	0.77	stable	2025-07-10 00:28:38.216148
1210	86	4.1	525	4.1	0.0	eleve	46500.00	Nouveau crÃ©dit accordÃ©	0.77	stable	2025-08-24 00:28:38.216148
1211	86	4.2	531	4.1	0.1	eleve	46500.00	Paiement Ã  temps	0.78	stable	2025-10-08 00:28:38.216148
1212	87	2.9	459	2.5	0.4	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.74	amelioration	2025-01-11 00:28:38.216148
1213	87	3.1	470	2.9	0.2	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.74	stable	2025-02-25 00:28:38.216148
1214	87	3.5	492	3.1	0.4	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.76	amelioration	2025-04-11 00:28:38.216148
1215	87	3.9	514	3.5	0.4	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.77	amelioration	2025-05-26 00:28:38.216148
1216	87	4.1	525	3.9	0.2	eleve	61500.00	Nouveau crÃ©dit accordÃ©	0.77	stable	2025-07-10 00:28:38.216148
1217	87	4.3	536	4.1	0.2	eleve	61500.00	Paiement Ã  temps	0.78	stable	2025-08-24 00:28:38.216148
1218	87	4.8	564	4.3	0.5	eleve	61500.00	Paiement Ã  temps	0.79	amelioration	2025-10-08 00:28:38.216148
1219	88	3.7	503	2.9	0.8	tres_eleve	0.00	Paiement Ã  temps	0.76	amelioration	2025-07-10 00:28:38.216148
1220	88	4.7	558	3.7	1.0	eleve	87000.00	Paiement Ã  temps	0.79	amelioration	2025-08-24 00:28:38.216148
1221	88	5.4	597	4.7	0.7	eleve	87000.00	Nouveau crÃ©dit accordÃ©	0.81	amelioration	2025-10-08 00:28:38.216148
1222	89	3.3	481	2.9	0.4	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.75	amelioration	2025-01-11 00:28:38.216148
1223	89	3.7	503	3.3	0.4	tres_eleve	0.00	Paiement en retard	0.76	amelioration	2025-02-25 00:28:38.216148
1224	89	4.1	525	3.7	0.4	eleve	66000.00	Paiement Ã  temps	0.77	amelioration	2025-04-11 00:28:38.216148
1225	89	4.3	536	4.1	0.2	eleve	66000.00	Nouveau crÃ©dit accordÃ©	0.78	stable	2025-05-26 00:28:38.216148
1226	89	4.5	547	4.3	0.2	eleve	66000.00	Nouveau crÃ©dit accordÃ©	0.79	stable	2025-07-10 00:28:38.216148
1227	89	4.8	564	4.5	0.3	eleve	66000.00	Paiement en retard	0.79	amelioration	2025-08-24 00:28:38.216148
1228	89	5.2	586	4.8	0.4	eleve	66000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.81	amelioration	2025-10-08 00:28:38.216148
1229	90	1.8	399	1.6	0.2	tres_eleve	0.00	Paiement Ã  temps	0.70	stable	2024-11-27 00:28:38.216148
1230	90	2.0	410	1.8	0.2	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.71	stable	2025-01-11 00:28:38.216148
1231	90	2.2	421	2.0	0.2	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.72	stable	2025-02-25 00:28:38.216148
1232	90	2.4	432	2.2	0.2	tres_eleve	0.00	Paiement en retard	0.72	stable	2025-04-11 00:28:38.216148
1233	90	2.6	443	2.4	0.2	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.73	stable	2025-05-26 00:28:38.216148
1234	90	2.7	448	2.6	0.1	tres_eleve	0.00	Paiement Ã  temps	0.73	stable	2025-07-10 00:28:38.216148
1235	90	2.9	459	2.7	0.2	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.74	stable	2025-08-24 00:28:38.216148
1236	90	3.3	481	2.9	0.4	tres_eleve	0.00	Paiement Ã  temps	0.75	amelioration	2025-10-08 00:28:38.216148
1237	91	1.3	371	0.7	0.6	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.69	amelioration	2025-07-10 00:28:38.216148
1238	91	2.1	415	1.3	0.8	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.71	amelioration	2025-08-24 00:28:38.216148
1239	91	2.9	459	2.1	0.8	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.74	amelioration	2025-10-08 00:28:38.216148
1240	92	0.5	327	-0.1	0.6	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.67	amelioration	2025-04-11 00:28:38.216148
1241	92	0.9	349	0.5	0.4	tres_eleve	0.00	Paiement Ã  temps	0.68	amelioration	2025-05-26 00:28:38.216148
1242	92	1.3	371	0.9	0.4	tres_eleve	0.00	Paiement Ã  temps	0.69	amelioration	2025-07-10 00:28:38.216148
1243	92	1.8	399	1.3	0.5	tres_eleve	0.00	Paiement Ã  temps	0.70	amelioration	2025-08-24 00:28:38.216148
1244	92	2.5	437	1.8	0.7	tres_eleve	0.00	Paiement Ã  temps	0.73	amelioration	2025-10-08 00:28:38.216148
1245	93	0.4	322	0.1	0.3	tres_eleve	0.00	Paiement Ã  temps	0.66	amelioration	2025-01-11 00:28:38.216148
1246	93	1.0	355	0.4	0.6	tres_eleve	0.00	Paiement Ã  temps	0.68	amelioration	2025-02-25 00:28:38.216148
1247	93	1.3	371	1.0	0.3	tres_eleve	0.00	Paiement Ã  temps	0.69	amelioration	2025-04-11 00:28:38.216148
1248	93	1.7	393	1.3	0.4	tres_eleve	0.00	Paiement Ã  temps	0.70	amelioration	2025-05-26 00:28:38.216148
1249	93	2.2	421	1.7	0.5	tres_eleve	0.00	Paiement Ã  temps	0.72	amelioration	2025-07-10 00:28:38.216148
1250	93	2.6	443	2.2	0.4	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.73	amelioration	2025-08-24 00:28:38.216148
1251	93	3.0	465	2.6	0.4	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.74	amelioration	2025-10-08 00:28:38.216148
1252	94	2.6	443	2.1	0.5	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.73	amelioration	2025-07-10 00:28:38.216148
1253	94	3.0	465	2.6	0.4	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.74	amelioration	2025-08-24 00:28:38.216148
1254	94	3.3	481	3.0	0.3	tres_eleve	0.00	Paiement Ã  temps	0.75	amelioration	2025-10-08 00:28:38.216148
1255	95	1.1	360	0.5	0.6	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.68	amelioration	2025-05-26 00:28:38.216148
1256	95	1.7	393	1.1	0.6	tres_eleve	0.00	Paiement Ã  temps	0.70	amelioration	2025-07-10 00:28:38.216148
1257	95	2.1	415	1.7	0.4	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.71	amelioration	2025-08-24 00:28:38.216148
1258	95	2.6	443	2.1	0.5	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.73	amelioration	2025-10-08 00:28:38.216148
1259	96	1.5	382	0.9	0.6	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.70	amelioration	2025-04-11 00:28:38.216148
1260	96	1.9	404	1.5	0.4	tres_eleve	0.00	Paiement en retard	0.71	amelioration	2025-05-26 00:28:38.216148
1261	96	2.4	432	1.9	0.5	tres_eleve	0.00	Paiement Ã  temps	0.72	amelioration	2025-07-10 00:28:38.216148
1262	96	2.9	459	2.4	0.5	tres_eleve	0.00	Paiement Ã  temps	0.74	amelioration	2025-08-24 00:28:38.216148
1263	96	3.5	492	2.9	0.6	tres_eleve	0.00	Paiement Ã  temps	0.76	amelioration	2025-10-08 00:28:38.216148
1264	97	1.7	393	1.4	0.3	tres_eleve	0.00	Paiement Ã  temps	0.70	amelioration	2025-02-25 00:28:38.216148
1265	97	2.0	410	1.7	0.3	tres_eleve	0.00	Paiement Ã  temps	0.71	amelioration	2025-04-11 00:28:38.216148
1266	97	2.3	426	2.0	0.3	tres_eleve	0.00	Paiement Ã  temps	0.72	amelioration	2025-05-26 00:28:38.216148
1267	97	2.6	443	2.3	0.3	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.73	amelioration	2025-07-10 00:28:38.216148
1268	97	2.7	448	2.6	0.1	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.73	stable	2025-08-24 00:28:38.216148
1269	97	3.0	465	2.7	0.3	tres_eleve	0.00	Paiement Ã  temps	0.74	amelioration	2025-10-08 00:28:38.216148
1270	98	0.1	305	-0.5	0.6	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.65	amelioration	2025-05-26 00:28:38.216148
1271	98	0.7	338	0.1	0.6	tres_eleve	0.00	Paiement Ã  temps	0.67	amelioration	2025-07-10 00:28:38.216148
1272	98	1.4	377	0.7	0.7	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.69	amelioration	2025-08-24 00:28:38.216148
1273	98	2.2	421	1.4	0.8	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.72	amelioration	2025-10-08 00:28:38.216148
1274	99	0.1	305	-0.3	0.4	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.65	amelioration	2024-11-27 00:28:38.216148
1275	99	0.4	322	0.1	0.3	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.66	amelioration	2025-01-11 00:28:38.216148
1276	99	0.7	338	0.4	0.3	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.67	amelioration	2025-02-25 00:28:38.216148
1277	99	1.2	366	0.7	0.5	tres_eleve	0.00	Paiement Ã  temps	0.69	amelioration	2025-04-11 00:28:38.216148
1278	99	1.6	388	1.2	0.4	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.70	amelioration	2025-05-26 00:28:38.216148
1279	99	2.0	410	1.6	0.4	tres_eleve	0.00	Paiement Ã  temps	0.71	amelioration	2025-07-10 00:28:38.216148
1280	99	2.3	426	2.0	0.3	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.72	amelioration	2025-08-24 00:28:38.216148
1281	99	2.5	437	2.3	0.2	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.73	stable	2025-10-08 00:28:38.216148
1282	1	4.3	536	3.9	0.4	eleve	750000.00	Paiement Ã  temps	0.78	amelioration	2025-02-25 13:10:20.103562
1283	1	4.7	558	4.3	0.4	eleve	750000.00	Paiement en retard	0.79	amelioration	2025-04-11 13:10:20.103562
1284	1	5.3	591	4.7	0.6	eleve	750000.00	Nouveau crÃ©dit accordÃ©	0.81	amelioration	2025-05-26 13:10:20.103562
1285	1	5.8	619	5.3	0.5	eleve	750000.00	Paiement Ã  temps	0.82	amelioration	2025-07-10 13:10:20.103562
1286	1	6.2	641	5.8	0.4	moyen	1250000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.84	amelioration	2025-08-24 13:10:20.103562
1287	1	6.6	663	6.2	0.4	moyen	1250000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.85	amelioration	2025-10-08 13:10:20.103562
1288	2	6.7	668	6.5	0.2	moyen	900000.00	Nouveau crÃ©dit accordÃ©	0.85	stable	2025-01-11 13:10:20.103562
1289	2	7.0	685	6.7	0.3	moyen	900000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.86	amelioration	2025-02-25 13:10:20.103562
1290	2	7.4	707	7.0	0.4	moyen	900000.00	Paiement en retard	0.87	amelioration	2025-04-11 13:10:20.103562
1291	2	7.7	723	7.4	0.3	moyen	900000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.88	amelioration	2025-05-26 13:10:20.103562
1292	2	8.0	740	7.7	0.3	bas	1260000.00	Nouveau crÃ©dit accordÃ©	0.89	amelioration	2025-07-10 13:10:20.103562
1293	2	8.3	756	8.0	0.3	bas	1260000.00	Nouveau crÃ©dit accordÃ©	0.90	amelioration	2025-08-24 13:10:20.103562
1294	2	8.8	784	8.3	0.5	bas	1260000.00	Nouveau crÃ©dit accordÃ©	0.91	amelioration	2025-10-08 13:10:20.103562
1295	3	7.1	690	6.8	0.3	moyen	750000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.86	amelioration	2025-04-11 13:10:20.103562
1296	3	7.3	701	7.1	0.2	moyen	750000.00	Paiement Ã  temps	0.87	stable	2025-05-26 13:10:20.103562
1297	3	7.7	723	7.3	0.4	moyen	750000.00	Nouveau crÃ©dit accordÃ©	0.88	amelioration	2025-07-10 13:10:20.103562
1298	3	8.0	740	7.7	0.3	bas	1050000.00	Nouveau crÃ©dit accordÃ©	0.89	amelioration	2025-08-24 13:10:20.103562
1299	3	8.4	762	8.0	0.4	bas	1050000.00	Nouveau crÃ©dit accordÃ©	0.90	amelioration	2025-10-08 13:10:20.103562
1300	4	6.6	663	6.0	0.6	moyen	600000.00	Paiement Ã  temps	0.85	amelioration	2025-05-26 13:10:20.103562
1301	4	7.3	701	6.6	0.7	moyen	600000.00	Nouveau crÃ©dit accordÃ©	0.87	amelioration	2025-07-10 13:10:20.103562
1302	4	7.9	734	7.3	0.6	moyen	600000.00	Paiement Ã  temps	0.89	amelioration	2025-08-24 13:10:20.103562
1303	4	8.6	773	7.9	0.7	bas	840000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.91	amelioration	2025-10-08 13:10:20.103562
1304	5	6.9	679	6.5	0.4	moyen	1000000.00	Paiement Ã  temps	0.86	amelioration	2025-01-11 13:10:20.103562
1305	5	7.2	696	6.9	0.3	moyen	1000000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.87	amelioration	2025-02-25 13:10:20.103562
1306	5	7.3	701	7.2	0.1	moyen	1000000.00	Paiement Ã  temps	0.87	stable	2025-04-11 13:10:20.103562
1307	5	7.6	718	7.3	0.3	moyen	1000000.00	Paiement Ã  temps	0.88	amelioration	2025-05-26 13:10:20.103562
1308	5	8.0	740	7.6	0.4	bas	1400000.00	Nouveau crÃ©dit accordÃ©	0.89	amelioration	2025-07-10 13:10:20.103562
1309	5	8.0	740	8.0	0.0	bas	1400000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.89	stable	2025-08-24 13:10:20.103562
1310	5	8.3	756	8.0	0.3	bas	1400000.00	Paiement Ã  temps	0.90	amelioration	2025-10-08 13:10:20.103562
1311	6	6.0	630	5.8	0.2	moyen	700000.00	Nouveau crÃ©dit accordÃ©	0.83	stable	2024-11-27 13:10:20.103562
1312	6	6.4	652	6.0	0.4	moyen	700000.00	Paiement Ã  temps	0.84	amelioration	2025-01-11 13:10:20.103562
1313	6	6.8	674	6.4	0.4	moyen	700000.00	Paiement Ã  temps	0.85	amelioration	2025-02-25 13:10:20.103562
1314	6	7.3	701	6.8	0.5	moyen	700000.00	Nouveau crÃ©dit accordÃ©	0.87	amelioration	2025-04-11 13:10:20.103562
1315	6	7.5	712	7.3	0.2	moyen	700000.00	Nouveau crÃ©dit accordÃ©	0.88	stable	2025-05-26 13:10:20.103562
1316	6	7.8	729	7.5	0.3	moyen	700000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.88	amelioration	2025-07-10 13:10:20.103562
1317	6	8.3	756	7.8	0.5	bas	980000.00	Paiement Ã  temps	0.90	amelioration	2025-08-24 13:10:20.103562
1318	6	8.7	778	8.3	0.4	bas	980000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.91	amelioration	2025-10-08 13:10:20.103562
1319	7	7.0	685	6.8	0.2	moyen	950000.00	Nouveau crÃ©dit accordÃ©	0.86	stable	2025-01-11 13:10:20.103562
1320	7	7.4	707	7.0	0.4	moyen	950000.00	Nouveau crÃ©dit accordÃ©	0.87	amelioration	2025-02-25 13:10:20.103562
1321	7	7.6	718	7.4	0.2	moyen	950000.00	Paiement Ã  temps	0.88	stable	2025-04-11 13:10:20.103562
1322	7	7.9	734	7.6	0.3	moyen	950000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.89	amelioration	2025-05-26 13:10:20.103562
1323	7	8.3	756	7.9	0.4	bas	1330000.00	Nouveau crÃ©dit accordÃ©	0.90	amelioration	2025-07-10 13:10:20.103562
1324	7	8.5	767	8.3	0.2	bas	1330000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.91	stable	2025-08-24 13:10:20.103562
1325	7	8.9	789	8.5	0.4	bas	1330000.00	Paiement Ã  temps	0.92	amelioration	2025-10-08 13:10:20.103562
1326	8	5.7	613	5.5	0.2	eleve	330000.00	Nouveau crÃ©dit accordÃ©	0.82	stable	2024-10-13 13:10:20.103562
1327	8	6.1	635	5.7	0.4	moyen	550000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.83	amelioration	2024-11-27 13:10:20.103562
1328	8	6.4	652	6.1	0.3	moyen	550000.00	Nouveau crÃ©dit accordÃ©	0.84	amelioration	2025-01-11 13:10:20.103562
1329	8	6.8	674	6.4	0.4	moyen	550000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.85	amelioration	2025-02-25 13:10:20.103562
1330	8	7.0	685	6.8	0.2	moyen	550000.00	Nouveau crÃ©dit accordÃ©	0.86	stable	2025-04-11 13:10:20.103562
1331	8	7.4	707	7.0	0.4	moyen	550000.00	Nouveau crÃ©dit accordÃ©	0.87	amelioration	2025-05-26 13:10:20.103562
1332	8	7.8	729	7.4	0.4	moyen	550000.00	Paiement Ã  temps	0.88	amelioration	2025-07-10 13:10:20.103562
1333	8	8.0	740	7.8	0.2	bas	770000.00	Nouveau crÃ©dit accordÃ©	0.89	stable	2025-08-24 13:10:20.103562
1334	8	8.5	767	8.0	0.5	bas	770000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.91	amelioration	2025-10-08 13:10:20.103562
1335	9	7.3	701	6.9	0.4	moyen	800000.00	Paiement Ã  temps	0.87	amelioration	2025-05-26 13:10:20.103562
1336	9	7.5	712	7.3	0.2	moyen	800000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.88	stable	2025-07-10 13:10:20.103562
1337	9	7.9	734	7.5	0.4	moyen	800000.00	Paiement Ã  temps	0.89	amelioration	2025-08-24 13:10:20.103562
1338	9	8.3	756	7.9	0.4	bas	1120000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.90	amelioration	2025-10-08 13:10:20.103562
1339	10	7.9	734	7.6	0.3	moyen	675000.00	Paiement Ã  temps	0.89	amelioration	2025-07-10 13:10:20.103562
1340	10	8.3	756	7.9	0.4	bas	945000.00	Nouveau crÃ©dit accordÃ©	0.90	amelioration	2025-08-24 13:10:20.103562
1341	10	8.6	773	8.3	0.3	bas	945000.00	Paiement Ã  temps	0.91	amelioration	2025-10-08 13:10:20.103562
1342	11	7.0	685	6.6	0.4	moyen	725000.00	Paiement Ã  temps	0.86	amelioration	2025-04-11 13:10:20.103562
1343	11	7.5	712	7.0	0.5	moyen	725000.00	Paiement Ã  temps	0.88	amelioration	2025-05-26 13:10:20.103562
1344	11	8.1	745	7.5	0.6	bas	1015000.00	Nouveau crÃ©dit accordÃ©	0.89	amelioration	2025-07-10 13:10:20.103562
1345	11	8.4	762	8.1	0.3	bas	1015000.00	Paiement Ã  temps	0.90	amelioration	2025-08-24 13:10:20.103562
1346	11	9.0	795	8.4	0.6	bas	1015000.00	Paiement en retard	0.92	amelioration	2025-10-08 13:10:20.103562
1347	12	6.5	657	6.1	0.4	moyen	475000.00	Paiement Ã  temps	0.85	amelioration	2025-05-26 13:10:20.103562
1348	12	7.0	685	6.5	0.5	moyen	475000.00	Paiement Ã  temps	0.86	amelioration	2025-07-10 13:10:20.103562
1349	12	7.6	718	7.0	0.6	moyen	475000.00	Nouveau crÃ©dit accordÃ©	0.88	amelioration	2025-08-24 13:10:20.103562
1350	12	8.0	740	7.6	0.4	bas	665000.00	Nouveau crÃ©dit accordÃ©	0.89	amelioration	2025-10-08 13:10:20.103562
1351	13	7.0	685	6.8	0.2	moyen	425000.00	Paiement Ã  temps	0.86	stable	2025-02-25 13:10:20.103562
1352	13	7.1	690	7.0	0.1	moyen	425000.00	Nouveau crÃ©dit accordÃ©	0.86	stable	2025-04-11 13:10:20.103562
1353	13	7.2	696	7.1	0.1	moyen	425000.00	Paiement Ã  temps	0.87	stable	2025-05-26 13:10:20.103562
1354	13	7.6	718	7.2	0.4	moyen	425000.00	Paiement en retard	0.88	amelioration	2025-07-10 13:10:20.103562
1355	13	7.9	734	7.6	0.3	moyen	425000.00	Nouveau crÃ©dit accordÃ©	0.89	amelioration	2025-08-24 13:10:20.103562
1356	13	8.0	740	7.9	0.1	bas	595000.00	Paiement Ã  temps	0.89	stable	2025-10-08 13:10:20.103562
1357	14	6.0	630	5.9	0.1	moyen	640000.00	Nouveau crÃ©dit accordÃ©	0.83	stable	2024-10-13 13:10:20.103562
1358	14	6.4	652	6.0	0.4	moyen	640000.00	Paiement Ã  temps	0.84	amelioration	2024-11-27 13:10:20.103562
1359	14	6.7	668	6.4	0.3	moyen	640000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.85	amelioration	2025-01-11 13:10:20.103562
1360	14	7.1	690	6.7	0.4	moyen	640000.00	Nouveau crÃ©dit accordÃ©	0.86	amelioration	2025-02-25 13:10:20.103562
1361	14	7.3	701	7.1	0.2	moyen	640000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.87	stable	2025-04-11 13:10:20.103562
1362	14	7.4	707	7.3	0.1	moyen	640000.00	Paiement Ã  temps	0.87	stable	2025-05-26 13:10:20.103562
1363	14	7.7	723	7.4	0.3	moyen	640000.00	Paiement Ã  temps	0.88	amelioration	2025-07-10 13:10:20.103562
1364	14	8.0	740	7.7	0.3	bas	896000.00	Paiement Ã  temps	0.89	amelioration	2025-08-24 13:10:20.103562
1365	14	8.3	756	8.0	0.3	bas	896000.00	Paiement Ã  temps	0.90	amelioration	2025-10-08 13:10:20.103562
1366	15	6.2	641	5.7	0.5	moyen	775000.00	Nouveau crÃ©dit accordÃ©	0.84	amelioration	2025-04-11 13:10:20.103562
1367	15	6.7	668	6.2	0.5	moyen	775000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.85	amelioration	2025-05-26 13:10:20.103562
1368	15	7.2	696	6.7	0.5	moyen	775000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.87	amelioration	2025-07-10 13:10:20.103562
1369	15	8.0	740	7.2	0.8	bas	1085000.00	Paiement Ã  temps	0.89	amelioration	2025-08-24 13:10:20.103562
1370	15	8.6	773	8.0	0.6	bas	1085000.00	Paiement Ã  temps	0.91	amelioration	2025-10-08 13:10:20.103562
1371	16	6.3	646	6.1	0.2	moyen	575000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.84	stable	2024-10-13 13:10:20.103562
1372	16	6.5	657	6.3	0.2	moyen	575000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.85	stable	2024-11-27 13:10:20.103562
1373	16	6.7	668	6.5	0.2	moyen	575000.00	Nouveau crÃ©dit accordÃ©	0.85	stable	2025-01-11 13:10:20.103562
1374	16	7.0	685	6.7	0.3	moyen	575000.00	Paiement en retard	0.86	amelioration	2025-02-25 13:10:20.103562
1375	16	7.2	696	7.0	0.2	moyen	575000.00	Paiement Ã  temps	0.87	stable	2025-04-11 13:10:20.103562
1376	16	7.5	712	7.2	0.3	moyen	575000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.88	amelioration	2025-05-26 13:10:20.103562
1377	16	7.8	729	7.5	0.3	moyen	575000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.88	amelioration	2025-07-10 13:10:20.103562
1378	16	7.9	734	7.8	0.1	moyen	575000.00	Nouveau crÃ©dit accordÃ©	0.89	stable	2025-08-24 13:10:20.103562
1379	16	8.3	756	7.9	0.4	bas	805000.00	Nouveau crÃ©dit accordÃ©	0.90	amelioration	2025-10-08 13:10:20.103562
1380	17	5.5	602	5.1	0.4	eleve	504000.00	Nouveau crÃ©dit accordÃ©	0.82	amelioration	2024-08-29 13:10:20.103562
1381	17	5.8	619	5.5	0.3	eleve	504000.00	Nouveau crÃ©dit accordÃ©	0.82	amelioration	2024-10-13 13:10:20.103562
1382	17	6.2	641	5.8	0.4	moyen	840000.00	Nouveau crÃ©dit accordÃ©	0.84	amelioration	2024-11-27 13:10:20.103562
1383	17	6.4	652	6.2	0.2	moyen	840000.00	Nouveau crÃ©dit accordÃ©	0.84	stable	2025-01-11 13:10:20.103562
1384	17	6.8	674	6.4	0.4	moyen	840000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.85	amelioration	2025-02-25 13:10:20.103562
1385	17	7.0	685	6.8	0.2	moyen	840000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.86	stable	2025-04-11 13:10:20.103562
1386	17	7.3	701	7.0	0.3	moyen	840000.00	Nouveau crÃ©dit accordÃ©	0.87	amelioration	2025-05-26 13:10:20.103562
1387	17	7.7	723	7.3	0.4	moyen	840000.00	Nouveau crÃ©dit accordÃ©	0.88	amelioration	2025-07-10 13:10:20.103562
1388	17	8.0	740	7.7	0.3	bas	1176000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.89	amelioration	2025-08-24 13:10:20.103562
1389	17	8.1	745	8.0	0.1	bas	1176000.00	Nouveau crÃ©dit accordÃ©	0.89	stable	2025-10-08 13:10:20.103562
1390	18	7.5	712	7.1	0.4	moyen	710000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.88	amelioration	2025-07-10 13:10:20.103562
1391	18	7.9	734	7.5	0.4	moyen	710000.00	Paiement Ã  temps	0.89	amelioration	2025-08-24 13:10:20.103562
1392	18	8.5	767	7.9	0.6	bas	994000.00	Nouveau crÃ©dit accordÃ©	0.91	amelioration	2025-10-08 13:10:20.103562
1393	19	6.2	641	5.9	0.3	moyen	1050000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.84	amelioration	2025-01-11 13:10:20.103562
1394	19	6.6	663	6.2	0.4	moyen	1050000.00	Paiement Ã  temps	0.85	amelioration	2025-02-25 13:10:20.103562
1395	19	7.0	685	6.6	0.4	moyen	1050000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.86	amelioration	2025-04-11 13:10:20.103562
1396	19	7.2	696	7.0	0.2	moyen	1050000.00	Nouveau crÃ©dit accordÃ©	0.87	stable	2025-05-26 13:10:20.103562
1397	19	7.4	707	7.2	0.2	moyen	1050000.00	Paiement Ã  temps	0.87	stable	2025-07-10 13:10:20.103562
1398	19	7.7	723	7.4	0.3	moyen	1050000.00	Nouveau crÃ©dit accordÃ©	0.88	amelioration	2025-08-24 13:10:20.103562
1399	19	8.2	751	7.7	0.5	bas	1470000.00	Paiement Ã  temps	0.90	amelioration	2025-10-08 13:10:20.103562
1400	20	6.2	641	6.0	0.2	moyen	875000.00	Paiement Ã  temps	0.84	stable	2024-10-13 13:10:20.103562
1401	20	6.5	657	6.2	0.3	moyen	875000.00	Nouveau crÃ©dit accordÃ©	0.85	amelioration	2024-11-27 13:10:20.103562
1402	20	6.8	674	6.5	0.3	moyen	875000.00	Paiement Ã  temps	0.85	amelioration	2025-01-11 13:10:20.103562
1403	20	7.3	701	6.8	0.5	moyen	875000.00	Nouveau crÃ©dit accordÃ©	0.87	amelioration	2025-02-25 13:10:20.103562
1404	20	7.5	712	7.3	0.2	moyen	875000.00	Paiement Ã  temps	0.88	stable	2025-04-11 13:10:20.103562
1405	20	7.8	729	7.5	0.3	moyen	875000.00	Nouveau crÃ©dit accordÃ©	0.88	amelioration	2025-05-26 13:10:20.103562
1406	20	8.1	745	7.8	0.3	bas	1225000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.89	amelioration	2025-07-10 13:10:20.103562
1407	20	8.6	773	8.1	0.5	bas	1225000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.91	amelioration	2025-08-24 13:10:20.103562
1408	20	8.7	778	8.6	0.1	bas	1225000.00	Nouveau crÃ©dit accordÃ©	0.91	stable	2025-10-08 13:10:20.103562
1409	21	5.8	619	5.5	0.3	eleve	564000.00	Paiement Ã  temps	0.82	amelioration	2025-01-11 13:10:20.103562
1410	21	6.3	646	5.8	0.5	moyen	940000.00	Nouveau crÃ©dit accordÃ©	0.84	amelioration	2025-02-25 13:10:20.103562
1411	21	6.8	674	6.3	0.5	moyen	940000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.85	amelioration	2025-04-11 13:10:20.103562
1412	21	7.1	690	6.8	0.3	moyen	940000.00	Paiement Ã  temps	0.86	amelioration	2025-05-26 13:10:20.103562
1413	21	7.6	718	7.1	0.5	moyen	940000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.88	amelioration	2025-07-10 13:10:20.103562
1414	21	8.0	740	7.6	0.4	bas	1316000.00	Nouveau crÃ©dit accordÃ©	0.89	amelioration	2025-08-24 13:10:20.103562
1415	21	8.3	756	8.0	0.3	bas	1316000.00	Paiement Ã  temps	0.90	amelioration	2025-10-08 13:10:20.103562
1416	22	5.8	619	5.5	0.3	eleve	396000.00	Nouveau crÃ©dit accordÃ©	0.82	amelioration	2025-01-11 13:10:20.103562
1417	22	6.2	641	5.8	0.4	moyen	660000.00	Paiement Ã  temps	0.84	amelioration	2025-02-25 13:10:20.103562
1418	22	6.7	668	6.2	0.5	moyen	660000.00	Paiement Ã  temps	0.85	amelioration	2025-04-11 13:10:20.103562
1419	22	7.1	690	6.7	0.4	moyen	660000.00	Nouveau crÃ©dit accordÃ©	0.86	amelioration	2025-05-26 13:10:20.103562
1420	22	7.5	712	7.1	0.4	moyen	660000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.88	amelioration	2025-07-10 13:10:20.103562
1421	22	7.8	729	7.5	0.3	moyen	660000.00	Paiement Ã  temps	0.88	amelioration	2025-08-24 13:10:20.103562
1422	22	8.2	751	7.8	0.4	bas	924000.00	Nouveau crÃ©dit accordÃ©	0.90	amelioration	2025-10-08 13:10:20.103562
1423	23	7.3	701	6.7	0.6	moyen	740000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.87	amelioration	2025-05-26 13:10:20.103562
1424	23	7.7	723	7.3	0.4	moyen	740000.00	Nouveau crÃ©dit accordÃ©	0.88	amelioration	2025-07-10 13:10:20.103562
1425	23	8.1	745	7.7	0.4	bas	1036000.00	Nouveau crÃ©dit accordÃ©	0.89	amelioration	2025-08-24 13:10:20.103562
1426	23	8.6	773	8.1	0.5	bas	1036000.00	Paiement Ã  temps	0.91	amelioration	2025-10-08 13:10:20.103562
1427	24	7.5	712	7.3	0.2	moyen	810000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.88	stable	2025-01-11 13:10:20.103562
1428	24	7.7	723	7.5	0.2	moyen	810000.00	Paiement Ã  temps	0.88	stable	2025-02-25 13:10:20.103562
1429	24	8.0	740	7.7	0.3	bas	1134000.00	Paiement Ã  temps	0.89	amelioration	2025-04-11 13:10:20.103562
1430	24	8.1	745	8.0	0.1	bas	1134000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.89	stable	2025-05-26 13:10:20.103562
1431	24	8.4	762	8.1	0.3	bas	1134000.00	Paiement Ã  temps	0.90	amelioration	2025-07-10 13:10:20.103562
1432	24	8.5	767	8.4	0.1	bas	1134000.00	Nouveau crÃ©dit accordÃ©	0.91	stable	2025-08-24 13:10:20.103562
1905	1	6.5	657	\N	\N	moyen	1250000.00	Recalcul automatique	\N	\N	2025-10-08 13:15:48.865274
1433	24	8.7	778	8.5	0.2	bas	1134000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.91	stable	2025-10-08 13:10:20.103562
1434	25	7.4	707	7.2	0.2	moyen	595000.00	Nouveau crÃ©dit accordÃ©	0.87	stable	2024-11-27 13:10:20.103562
1435	25	7.5	712	7.4	0.1	moyen	595000.00	Nouveau crÃ©dit accordÃ©	0.88	stable	2025-01-11 13:10:20.103562
1436	25	7.6	718	7.5	0.1	moyen	595000.00	Paiement Ã  temps	0.88	stable	2025-02-25 13:10:20.103562
1437	25	7.6	718	7.6	0.0	moyen	595000.00	Paiement Ã  temps	0.88	stable	2025-04-11 13:10:20.103562
1438	25	7.7	723	7.6	0.1	moyen	595000.00	Paiement Ã  temps	0.88	stable	2025-05-26 13:10:20.103562
1439	25	7.8	729	7.7	0.1	moyen	595000.00	Paiement Ã  temps	0.88	stable	2025-07-10 13:10:20.103562
1440	25	8.2	751	7.8	0.4	bas	833000.00	Paiement Ã  temps	0.90	amelioration	2025-08-24 13:10:20.103562
1441	25	8.3	756	8.2	0.1	bas	833000.00	Nouveau crÃ©dit accordÃ©	0.90	stable	2025-10-08 13:10:20.103562
1442	26	5.9	624	5.6	0.3	eleve	315000.00	Paiement Ã  temps	0.83	amelioration	2025-02-25 13:10:20.103562
1443	26	6.5	657	5.9	0.6	moyen	525000.00	Paiement Ã  temps	0.85	amelioration	2025-04-11 13:10:20.103562
1444	26	7.1	690	6.5	0.6	moyen	525000.00	Nouveau crÃ©dit accordÃ©	0.86	amelioration	2025-05-26 13:10:20.103562
1445	26	7.5	712	7.1	0.4	moyen	525000.00	Nouveau crÃ©dit accordÃ©	0.88	amelioration	2025-07-10 13:10:20.103562
1446	26	7.7	723	7.5	0.2	moyen	525000.00	Nouveau crÃ©dit accordÃ©	0.88	stable	2025-08-24 13:10:20.103562
1447	26	8.1	745	7.7	0.4	bas	735000.00	Paiement Ã  temps	0.89	amelioration	2025-10-08 13:10:20.103562
1448	27	6.5	657	6.2	0.3	moyen	675000.00	Nouveau crÃ©dit accordÃ©	0.85	amelioration	2025-04-11 13:10:20.103562
1449	27	6.9	679	6.5	0.4	moyen	675000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.86	amelioration	2025-05-26 13:10:20.103562
1450	27	7.4	707	6.9	0.5	moyen	675000.00	Paiement en retard	0.87	amelioration	2025-07-10 13:10:20.103562
1451	27	7.9	734	7.4	0.5	moyen	675000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.89	amelioration	2025-08-24 13:10:20.103562
1452	27	8.0	740	7.9	0.1	bas	945000.00	Nouveau crÃ©dit accordÃ©	0.89	stable	2025-10-08 13:10:20.103562
1453	28	7.4	707	7.0	0.4	moyen	790000.00	Paiement en retard	0.87	amelioration	2025-07-10 13:10:20.103562
1454	28	8.1	745	7.4	0.7	bas	1106000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.89	amelioration	2025-08-24 13:10:20.103562
1455	28	8.6	773	8.1	0.5	bas	1106000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.91	amelioration	2025-10-08 13:10:20.103562
1456	29	6.9	679	6.6	0.3	moyen	710000.00	Paiement Ã  temps	0.86	amelioration	2024-11-27 13:10:20.103562
1457	29	7.1	690	6.9	0.2	moyen	710000.00	Nouveau crÃ©dit accordÃ©	0.86	stable	2025-01-11 13:10:20.103562
1458	29	7.2	696	7.1	0.1	moyen	710000.00	Nouveau crÃ©dit accordÃ©	0.87	stable	2025-02-25 13:10:20.103562
1459	29	7.5	712	7.2	0.3	moyen	710000.00	Paiement en retard	0.88	amelioration	2025-04-11 13:10:20.103562
1460	29	7.7	723	7.5	0.2	moyen	710000.00	Paiement Ã  temps	0.88	stable	2025-05-26 13:10:20.103562
1461	29	8.0	740	7.7	0.3	bas	994000.00	Nouveau crÃ©dit accordÃ©	0.89	amelioration	2025-07-10 13:10:20.103562
1462	29	8.3	756	8.0	0.3	bas	994000.00	Paiement Ã  temps	0.90	amelioration	2025-08-24 13:10:20.103562
1463	29	8.5	767	8.3	0.2	bas	994000.00	Nouveau crÃ©dit accordÃ©	0.91	stable	2025-10-08 13:10:20.103562
1464	30	7.1	690	6.7	0.4	moyen	640000.00	Nouveau crÃ©dit accordÃ©	0.86	amelioration	2025-01-11 13:10:20.103562
1465	30	7.2	696	7.1	0.1	moyen	640000.00	Nouveau crÃ©dit accordÃ©	0.87	stable	2025-02-25 13:10:20.103562
1466	30	7.6	718	7.2	0.4	moyen	640000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.88	amelioration	2025-04-11 13:10:20.103562
1467	30	7.7	723	7.6	0.1	moyen	640000.00	Nouveau crÃ©dit accordÃ©	0.88	stable	2025-05-26 13:10:20.103562
1468	30	8.1	745	7.7	0.4	bas	896000.00	Nouveau crÃ©dit accordÃ©	0.89	amelioration	2025-07-10 13:10:20.103562
1469	30	8.3	756	8.1	0.2	bas	896000.00	Paiement Ã  temps	0.90	stable	2025-08-24 13:10:20.103562
1470	30	8.5	767	8.3	0.2	bas	896000.00	Paiement Ã  temps	0.91	stable	2025-10-08 13:10:20.103562
1471	31	5.8	619	5.8	0.0	eleve	204000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.82	stable	2024-10-13 13:10:20.103562
1472	31	6.0	630	5.8	0.2	moyen	340000.00	Nouveau crÃ©dit accordÃ©	0.83	stable	2024-11-27 13:10:20.103562
1473	31	6.2	641	6.0	0.2	moyen	340000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.84	stable	2025-01-11 13:10:20.103562
1474	31	6.4	652	6.2	0.2	moyen	340000.00	Paiement Ã  temps	0.84	stable	2025-02-25 13:10:20.103562
1475	31	6.6	663	6.4	0.2	moyen	340000.00	Nouveau crÃ©dit accordÃ©	0.85	stable	2025-04-11 13:10:20.103562
1476	31	6.8	674	6.6	0.2	moyen	340000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.85	stable	2025-05-26 13:10:20.103562
1477	31	7.1	690	6.8	0.3	moyen	340000.00	Paiement Ã  temps	0.86	amelioration	2025-07-10 13:10:20.103562
1478	31	7.0	685	7.1	-0.1	moyen	340000.00	Nouveau crÃ©dit accordÃ©	0.86	stable	2025-08-24 13:10:20.103562
1479	31	7.2	696	7.0	0.2	moyen	340000.00	Nouveau crÃ©dit accordÃ©	0.87	stable	2025-10-08 13:10:20.103562
1480	32	5.3	591	5.1	0.2	eleve	156000.00	Nouveau crÃ©dit accordÃ©	0.81	stable	2025-01-11 13:10:20.103562
1481	32	5.6	608	5.3	0.3	eleve	156000.00	Nouveau crÃ©dit accordÃ©	0.82	amelioration	2025-02-25 13:10:20.103562
1482	32	5.7	613	5.6	0.1	eleve	156000.00	Nouveau crÃ©dit accordÃ©	0.82	stable	2025-04-11 13:10:20.103562
1483	32	6.0	630	5.7	0.3	moyen	260000.00	Nouveau crÃ©dit accordÃ©	0.83	amelioration	2025-05-26 13:10:20.103562
1484	32	6.3	646	6.0	0.3	moyen	260000.00	Paiement Ã  temps	0.84	amelioration	2025-07-10 13:10:20.103562
1485	32	6.6	663	6.3	0.3	moyen	260000.00	Nouveau crÃ©dit accordÃ©	0.85	amelioration	2025-08-24 13:10:20.103562
1486	32	6.9	679	6.6	0.3	moyen	260000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.86	amelioration	2025-10-08 13:10:20.103562
1487	33	5.9	624	5.9	0.0	eleve	225000.00	Paiement Ã  temps	0.83	stable	2024-10-13 13:10:20.103562
1488	33	6.2	641	5.9	0.3	moyen	375000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.84	amelioration	2024-11-27 13:10:20.103562
1489	33	6.2	641	6.2	0.0	moyen	375000.00	Nouveau crÃ©dit accordÃ©	0.84	stable	2025-01-11 13:10:20.103562
1490	33	6.2	641	6.2	0.0	moyen	375000.00	Nouveau crÃ©dit accordÃ©	0.84	stable	2025-02-25 13:10:20.103562
1491	33	6.2	641	6.2	0.0	moyen	375000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.84	stable	2025-04-11 13:10:20.103562
1492	33	6.3	646	6.2	0.1	moyen	375000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.84	stable	2025-05-26 13:10:20.103562
1493	33	6.6	663	6.3	0.3	moyen	375000.00	Paiement Ã  temps	0.85	amelioration	2025-07-10 13:10:20.103562
1494	33	6.9	679	6.6	0.3	moyen	375000.00	Nouveau crÃ©dit accordÃ©	0.86	amelioration	2025-08-24 13:10:20.103562
1495	33	7.1	690	6.9	0.2	moyen	375000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.86	stable	2025-10-08 13:10:20.103562
1496	34	5.4	597	5.2	0.2	eleve	144000.00	Nouveau crÃ©dit accordÃ©	0.81	stable	2025-04-11 13:10:20.103562
1497	34	5.8	619	5.4	0.4	eleve	144000.00	Paiement Ã  temps	0.82	amelioration	2025-05-26 13:10:20.103562
1498	34	6.0	630	5.8	0.2	moyen	240000.00	Paiement en retard	0.83	stable	2025-07-10 13:10:20.103562
1499	34	6.3	646	6.0	0.3	moyen	240000.00	Paiement Ã  temps	0.84	amelioration	2025-08-24 13:10:20.103562
1500	34	6.8	674	6.3	0.5	moyen	240000.00	Paiement Ã  temps	0.85	amelioration	2025-10-08 13:10:20.103562
1501	35	4.7	558	4.1	0.6	eleve	186000.00	Nouveau crÃ©dit accordÃ©	0.79	amelioration	2025-05-26 13:10:20.103562
1502	35	5.4	597	4.7	0.7	eleve	186000.00	Nouveau crÃ©dit accordÃ©	0.81	amelioration	2025-07-10 13:10:20.103562
1503	35	6.1	635	5.4	0.7	moyen	310000.00	Nouveau crÃ©dit accordÃ©	0.83	amelioration	2025-08-24 13:10:20.103562
1504	35	7.0	685	6.1	0.9	moyen	310000.00	Nouveau crÃ©dit accordÃ©	0.86	amelioration	2025-10-08 13:10:20.103562
1505	36	5.5	602	4.9	0.6	eleve	192000.00	Nouveau crÃ©dit accordÃ©	0.82	amelioration	2025-07-10 13:10:20.103562
1506	36	6.3	646	5.5	0.8	moyen	320000.00	Paiement Ã  temps	0.84	amelioration	2025-08-24 13:10:20.103562
1507	36	7.0	685	6.3	0.7	moyen	320000.00	Paiement en retard	0.86	amelioration	2025-10-08 13:10:20.103562
1508	37	5.3	591	4.9	0.4	eleve	165000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.81	amelioration	2025-05-26 13:10:20.103562
1509	37	5.9	624	5.3	0.6	eleve	165000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.83	amelioration	2025-07-10 13:10:20.103562
1510	37	6.4	652	5.9	0.5	moyen	275000.00	Paiement Ã  temps	0.84	amelioration	2025-08-24 13:10:20.103562
1511	37	6.6	663	6.4	0.2	moyen	275000.00	Paiement Ã  temps	0.85	stable	2025-10-08 13:10:20.103562
1512	38	6.1	635	5.8	0.3	moyen	360000.00	Paiement Ã  temps	0.83	amelioration	2025-04-11 13:10:20.103562
1513	38	6.5	657	6.1	0.4	moyen	360000.00	Nouveau crÃ©dit accordÃ©	0.85	amelioration	2025-05-26 13:10:20.103562
1514	38	6.7	668	6.5	0.2	moyen	360000.00	Paiement Ã  temps	0.85	stable	2025-07-10 13:10:20.103562
1515	38	6.9	679	6.7	0.2	moyen	360000.00	Paiement Ã  temps	0.86	stable	2025-08-24 13:10:20.103562
1516	38	7.3	701	6.9	0.4	moyen	360000.00	Paiement Ã  temps	0.87	amelioration	2025-10-08 13:10:20.103562
1517	39	4.7	558	4.4	0.3	eleve	144000.00	Nouveau crÃ©dit accordÃ©	0.79	amelioration	2024-10-13 13:10:20.103562
1518	39	4.9	569	4.7	0.2	eleve	144000.00	Paiement Ã  temps	0.80	stable	2024-11-27 13:10:20.103562
1519	39	5.1	580	4.9	0.2	eleve	144000.00	Nouveau crÃ©dit accordÃ©	0.80	stable	2025-01-11 13:10:20.103562
1520	39	5.4	597	5.1	0.3	eleve	144000.00	Nouveau crÃ©dit accordÃ©	0.81	amelioration	2025-02-25 13:10:20.103562
1521	39	5.7	613	5.4	0.3	eleve	144000.00	Nouveau crÃ©dit accordÃ©	0.82	amelioration	2025-04-11 13:10:20.103562
1522	39	5.9	624	5.7	0.2	eleve	144000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.83	stable	2025-05-26 13:10:20.103562
1523	39	6.3	646	5.9	0.4	moyen	240000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.84	amelioration	2025-07-10 13:10:20.103562
1524	39	6.6	663	6.3	0.3	moyen	240000.00	Paiement en retard	0.85	amelioration	2025-08-24 13:10:20.103562
1525	39	6.5	657	6.6	-0.1	moyen	240000.00	Paiement Ã  temps	0.85	stable	2025-10-08 13:10:20.103562
1526	40	4.7	558	4.2	0.5	eleve	177000.00	Paiement Ã  temps	0.79	amelioration	2025-04-11 13:10:20.103562
1527	40	5.1	580	4.7	0.4	eleve	177000.00	Nouveau crÃ©dit accordÃ©	0.80	amelioration	2025-05-26 13:10:20.103562
1528	40	5.7	613	5.1	0.6	eleve	177000.00	Paiement Ã  temps	0.82	amelioration	2025-07-10 13:10:20.103562
1529	40	6.4	652	5.7	0.7	moyen	295000.00	Nouveau crÃ©dit accordÃ©	0.84	amelioration	2025-08-24 13:10:20.103562
1530	40	7.0	685	6.4	0.6	moyen	295000.00	Nouveau crÃ©dit accordÃ©	0.86	amelioration	2025-10-08 13:10:20.103562
1531	41	5.7	613	5.5	0.2	eleve	195000.00	Nouveau crÃ©dit accordÃ©	0.82	stable	2025-02-25 13:10:20.103562
1532	41	6.0	630	5.7	0.3	moyen	325000.00	Nouveau crÃ©dit accordÃ©	0.83	amelioration	2025-04-11 13:10:20.103562
1533	41	6.5	657	6.0	0.5	moyen	325000.00	Paiement en retard	0.85	amelioration	2025-05-26 13:10:20.103562
1534	41	6.8	674	6.5	0.3	moyen	325000.00	Paiement Ã  temps	0.85	amelioration	2025-07-10 13:10:20.103562
1535	41	7.2	696	6.8	0.4	moyen	325000.00	Paiement Ã  temps	0.87	amelioration	2025-08-24 13:10:20.103562
1536	41	7.2	696	7.2	0.0	moyen	325000.00	Nouveau crÃ©dit accordÃ©	0.87	stable	2025-10-08 13:10:20.103562
1537	42	5.3	591	5.2	0.1	eleve	168000.00	Paiement en retard	0.81	stable	2025-01-11 13:10:20.103562
1538	42	5.6	608	5.3	0.3	eleve	168000.00	Paiement Ã  temps	0.82	amelioration	2025-02-25 13:10:20.103562
1539	42	5.9	624	5.6	0.3	eleve	168000.00	Paiement en retard	0.83	amelioration	2025-04-11 13:10:20.103562
1540	42	6.2	641	5.9	0.3	moyen	280000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.84	amelioration	2025-05-26 13:10:20.103562
1541	42	6.4	652	6.2	0.2	moyen	280000.00	Nouveau crÃ©dit accordÃ©	0.84	stable	2025-07-10 13:10:20.103562
1542	42	6.5	657	6.4	0.1	moyen	280000.00	Paiement Ã  temps	0.85	stable	2025-08-24 13:10:20.103562
1543	42	6.7	668	6.5	0.2	moyen	280000.00	Paiement Ã  temps	0.85	stable	2025-10-08 13:10:20.103562
1544	43	4.6	553	4.5	0.1	eleve	126000.00	Paiement Ã  temps	0.79	stable	2024-11-27 13:10:20.103562
1545	43	4.8	564	4.6	0.2	eleve	126000.00	Paiement Ã  temps	0.79	stable	2025-01-11 13:10:20.103562
1546	43	4.9	569	4.8	0.1	eleve	126000.00	Paiement Ã  temps	0.80	stable	2025-02-25 13:10:20.103562
1547	43	5.2	586	4.9	0.3	eleve	126000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.81	amelioration	2025-04-11 13:10:20.103562
1548	43	5.4	597	5.2	0.2	eleve	126000.00	Paiement Ã  temps	0.81	stable	2025-05-26 13:10:20.103562
1549	43	5.8	619	5.4	0.4	eleve	126000.00	Mise Ã  jour automatique	0.82	amelioration	2025-07-10 13:10:20.103562
1550	43	6.1	635	5.8	0.3	moyen	210000.00	Nouveau crÃ©dit accordÃ©	0.83	amelioration	2025-08-24 13:10:20.103562
1551	43	6.6	663	6.1	0.5	moyen	210000.00	Paiement Ã  temps	0.85	amelioration	2025-10-08 13:10:20.103562
1552	44	4.2	531	3.9	0.3	eleve	135000.00	Nouveau crÃ©dit accordÃ©	0.78	amelioration	2024-08-29 13:10:20.103562
1553	44	4.5	547	4.2	0.3	eleve	135000.00	Nouveau crÃ©dit accordÃ©	0.79	amelioration	2024-10-13 13:10:20.103562
1554	44	4.9	569	4.5	0.4	eleve	135000.00	Paiement Ã  temps	0.80	amelioration	2024-11-27 13:10:20.103562
1555	44	5.2	586	4.9	0.3	eleve	135000.00	Nouveau crÃ©dit accordÃ©	0.81	amelioration	2025-01-11 13:10:20.103562
1556	44	5.3	591	5.2	0.1	eleve	135000.00	Paiement Ã  temps	0.81	stable	2025-02-25 13:10:20.103562
1557	44	5.7	613	5.3	0.4	eleve	135000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.82	amelioration	2025-04-11 13:10:20.103562
1558	44	6.0	630	5.7	0.3	moyen	225000.00	Paiement Ã  temps	0.83	amelioration	2025-05-26 13:10:20.103562
1559	44	6.3	646	6.0	0.3	moyen	225000.00	Paiement Ã  temps	0.84	amelioration	2025-07-10 13:10:20.103562
1560	44	6.6	663	6.3	0.3	moyen	225000.00	Nouveau crÃ©dit accordÃ©	0.85	amelioration	2025-08-24 13:10:20.103562
1561	44	6.7	668	6.6	0.1	moyen	225000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.85	stable	2025-10-08 13:10:20.103562
1562	45	4.6	553	4.3	0.3	eleve	114000.00	Nouveau crÃ©dit accordÃ©	0.79	amelioration	2024-11-27 13:10:20.103562
1563	45	5.0	575	4.6	0.4	eleve	114000.00	Mise Ã  jour automatique	0.80	amelioration	2025-01-11 13:10:20.103562
1564	45	5.3	591	5.0	0.3	eleve	114000.00	Paiement en retard	0.81	amelioration	2025-02-25 13:10:20.103562
1565	45	5.4	597	5.3	0.1	eleve	114000.00	Paiement Ã  temps	0.81	stable	2025-04-11 13:10:20.103562
1566	45	5.6	608	5.4	0.2	eleve	114000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.82	stable	2025-05-26 13:10:20.103562
1567	45	5.8	619	5.6	0.2	eleve	114000.00	Paiement en retard	0.82	stable	2025-07-10 13:10:20.103562
1568	45	6.1	635	5.8	0.3	moyen	190000.00	Paiement Ã  temps	0.83	amelioration	2025-08-24 13:10:20.103562
1569	45	6.3	646	6.1	0.2	moyen	190000.00	Nouveau crÃ©dit accordÃ©	0.84	stable	2025-10-08 13:10:20.103562
1570	46	5.5	602	4.5	1.0	eleve	201000.00	Nouveau crÃ©dit accordÃ©	0.82	amelioration	2025-07-10 13:10:20.103562
1571	46	6.4	652	5.5	0.9	moyen	335000.00	Nouveau crÃ©dit accordÃ©	0.84	amelioration	2025-08-24 13:10:20.103562
1572	46	7.1	690	6.4	0.7	moyen	335000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.86	amelioration	2025-10-08 13:10:20.103562
1573	47	5.5	602	5.1	0.4	eleve	138000.00	Nouveau crÃ©dit accordÃ©	0.82	amelioration	2025-04-11 13:10:20.103562
1574	47	5.7	613	5.5	0.2	eleve	138000.00	Paiement Ã  temps	0.82	stable	2025-05-26 13:10:20.103562
1575	47	6.0	630	5.7	0.3	moyen	230000.00	Nouveau crÃ©dit accordÃ©	0.83	amelioration	2025-07-10 13:10:20.103562
1576	47	6.4	652	6.0	0.4	moyen	230000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.84	amelioration	2025-08-24 13:10:20.103562
1577	47	6.5	657	6.4	0.1	moyen	230000.00	Paiement Ã  temps	0.85	stable	2025-10-08 13:10:20.103562
1578	48	5.4	597	5.3	0.1	eleve	156000.00	Paiement Ã  temps	0.81	stable	2024-11-27 13:10:20.103562
1579	48	5.5	602	5.4	0.1	eleve	156000.00	Paiement Ã  temps	0.82	stable	2025-01-11 13:10:20.103562
1580	48	5.9	624	5.5	0.4	eleve	156000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.83	amelioration	2025-02-25 13:10:20.103562
1581	48	6.0	630	5.9	0.1	moyen	260000.00	Nouveau crÃ©dit accordÃ©	0.83	stable	2025-04-11 13:10:20.103562
1582	48	6.2	641	6.0	0.2	moyen	260000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.84	stable	2025-05-26 13:10:20.103562
1583	48	6.4	652	6.2	0.2	moyen	260000.00	Nouveau crÃ©dit accordÃ©	0.84	stable	2025-07-10 13:10:20.103562
1584	48	6.5	657	6.4	0.1	moyen	260000.00	Paiement en retard	0.85	stable	2025-08-24 13:10:20.103562
1585	48	6.7	668	6.5	0.2	moyen	260000.00	Paiement Ã  temps	0.85	stable	2025-10-08 13:10:20.103562
1586	49	3.4	487	3.2	0.2	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.75	stable	2024-08-29 13:10:20.103562
1587	49	3.7	503	3.4	0.3	tres_eleve	0.00	Paiement Ã  temps	0.76	amelioration	2024-10-13 13:10:20.103562
1588	49	3.9	514	3.7	0.2	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.77	stable	2024-11-27 13:10:20.103562
1589	49	4.4	542	3.9	0.5	eleve	102000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.78	amelioration	2025-01-11 13:10:20.103562
1590	49	4.6	553	4.4	0.2	eleve	102000.00	Paiement Ã  temps	0.79	stable	2025-02-25 13:10:20.103562
1591	49	4.9	569	4.6	0.3	eleve	102000.00	Paiement Ã  temps	0.80	amelioration	2025-04-11 13:10:20.103562
1592	49	5.2	586	4.9	0.3	eleve	102000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.81	amelioration	2025-05-26 13:10:20.103562
1593	49	5.7	613	5.2	0.5	eleve	102000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.82	amelioration	2025-07-10 13:10:20.103562
1594	49	6.0	630	5.7	0.3	moyen	170000.00	Nouveau crÃ©dit accordÃ©	0.83	amelioration	2025-08-24 13:10:20.103562
1595	49	6.3	646	6.0	0.3	moyen	170000.00	Nouveau crÃ©dit accordÃ©	0.84	amelioration	2025-10-08 13:10:20.103562
1596	50	4.9	569	4.2	0.7	eleve	147000.00	Paiement Ã  temps	0.80	amelioration	2025-07-10 13:10:20.103562
1597	50	5.6	608	4.9	0.7	eleve	147000.00	Nouveau crÃ©dit accordÃ©	0.82	amelioration	2025-08-24 13:10:20.103562
1598	50	6.5	657	5.6	0.9	moyen	245000.00	Nouveau crÃ©dit accordÃ©	0.85	amelioration	2025-10-08 13:10:20.103562
1599	51	4.9	569	4.4	0.5	eleve	162000.00	Paiement Ã  temps	0.80	amelioration	2025-02-25 13:10:20.103562
1600	51	5.4	597	4.9	0.5	eleve	162000.00	Paiement Ã  temps	0.81	amelioration	2025-04-11 13:10:20.103562
1601	51	5.8	619	5.4	0.4	eleve	162000.00	Nouveau crÃ©dit accordÃ©	0.82	amelioration	2025-05-26 13:10:20.103562
1602	51	6.2	641	5.8	0.4	moyen	270000.00	Paiement Ã  temps	0.84	amelioration	2025-07-10 13:10:20.103562
1603	51	6.5	657	6.2	0.3	moyen	270000.00	Nouveau crÃ©dit accordÃ©	0.85	amelioration	2025-08-24 13:10:20.103562
1604	51	6.9	679	6.5	0.4	moyen	270000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.86	amelioration	2025-10-08 13:10:20.103562
1605	52	4.0	520	3.9	0.1	eleve	108000.00	Paiement Ã  temps	0.77	stable	2024-08-29 13:10:20.103562
1606	52	4.1	525	4.0	0.1	eleve	108000.00	Paiement Ã  temps	0.77	stable	2024-10-13 13:10:20.103562
1607	52	4.3	536	4.1	0.2	eleve	108000.00	Paiement Ã  temps	0.78	stable	2024-11-27 13:10:20.103562
1608	52	4.7	558	4.3	0.4	eleve	108000.00	Nouveau crÃ©dit accordÃ©	0.79	amelioration	2025-01-11 13:10:20.103562
1609	52	4.9	569	4.7	0.2	eleve	108000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.80	stable	2025-02-25 13:10:20.103562
1610	52	5.2	586	4.9	0.3	eleve	108000.00	Paiement Ã  temps	0.81	amelioration	2025-04-11 13:10:20.103562
1611	52	5.3	591	5.2	0.1	eleve	108000.00	Paiement Ã  temps	0.81	stable	2025-05-26 13:10:20.103562
1612	52	5.8	619	5.3	0.5	eleve	108000.00	Nouveau crÃ©dit accordÃ©	0.82	amelioration	2025-07-10 13:10:20.103562
1613	52	6.1	635	5.8	0.3	moyen	180000.00	Nouveau crÃ©dit accordÃ©	0.83	amelioration	2025-08-24 13:10:20.103562
1614	52	6.2	641	6.1	0.1	moyen	180000.00	Paiement Ã  temps	0.84	stable	2025-10-08 13:10:20.103562
1615	53	4.9	569	3.8	1.1	eleve	141000.00	Nouveau crÃ©dit accordÃ©	0.80	amelioration	2025-07-10 13:10:20.103562
1616	53	5.8	619	4.9	0.9	eleve	141000.00	Paiement Ã  temps	0.82	amelioration	2025-08-24 13:10:20.103562
1617	53	6.7	668	5.8	0.9	moyen	235000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.85	amelioration	2025-10-08 13:10:20.103562
1618	54	4.8	564	4.6	0.2	eleve	165000.00	Paiement Ã  temps	0.79	stable	2025-02-25 13:10:20.103562
1619	54	5.3	591	4.8	0.5	eleve	165000.00	Paiement Ã  temps	0.81	amelioration	2025-04-11 13:10:20.103562
1620	54	5.7	613	5.3	0.4	eleve	165000.00	Paiement Ã  temps	0.82	amelioration	2025-05-26 13:10:20.103562
1621	54	6.2	641	5.7	0.5	moyen	275000.00	Paiement Ã  temps	0.84	amelioration	2025-07-10 13:10:20.103562
1622	54	6.7	668	6.2	0.5	moyen	275000.00	Nouveau crÃ©dit accordÃ©	0.85	amelioration	2025-08-24 13:10:20.103562
1623	54	6.8	674	6.7	0.1	moyen	275000.00	Nouveau crÃ©dit accordÃ©	0.85	stable	2025-10-08 13:10:20.103562
1624	55	4.1	525	3.9	0.2	eleve	105000.00	Paiement Ã  temps	0.77	stable	2024-10-13 13:10:20.103562
1625	55	4.4	542	4.1	0.3	eleve	105000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.78	amelioration	2024-11-27 13:10:20.103562
1626	55	4.6	553	4.4	0.2	eleve	105000.00	Nouveau crÃ©dit accordÃ©	0.79	stable	2025-01-11 13:10:20.103562
1627	55	4.7	558	4.6	0.1	eleve	105000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.79	stable	2025-02-25 13:10:20.103562
1628	55	4.9	569	4.7	0.2	eleve	105000.00	Paiement Ã  temps	0.80	stable	2025-04-11 13:10:20.103562
1629	55	5.2	586	4.9	0.3	eleve	105000.00	Nouveau crÃ©dit accordÃ©	0.81	amelioration	2025-05-26 13:10:20.103562
1630	55	5.7	613	5.2	0.5	eleve	105000.00	Paiement Ã  temps	0.82	amelioration	2025-07-10 13:10:20.103562
1631	55	5.9	624	5.7	0.2	eleve	105000.00	Paiement Ã  temps	0.83	stable	2025-08-24 13:10:20.103562
1632	55	6.2	641	5.9	0.3	moyen	175000.00	Nouveau crÃ©dit accordÃ©	0.84	amelioration	2025-10-08 13:10:20.103562
1633	56	6.0	630	5.5	0.5	moyen	290000.00	Paiement Ã  temps	0.83	amelioration	2025-07-10 13:10:20.103562
1634	56	6.5	657	6.0	0.5	moyen	290000.00	Nouveau crÃ©dit accordÃ©	0.85	amelioration	2025-08-24 13:10:20.103562
1635	56	7.0	685	6.5	0.5	moyen	290000.00	Paiement Ã  temps	0.86	amelioration	2025-10-08 13:10:20.103562
1636	57	4.3	536	4.0	0.3	eleve	126000.00	Paiement Ã  temps	0.78	amelioration	2025-01-11 13:10:20.103562
1637	57	4.6	553	4.3	0.3	eleve	126000.00	Paiement Ã  temps	0.79	amelioration	2025-02-25 13:10:20.103562
1638	57	4.9	569	4.6	0.3	eleve	126000.00	Paiement Ã  temps	0.80	amelioration	2025-04-11 13:10:20.103562
1639	57	5.3	591	4.9	0.4	eleve	126000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.81	amelioration	2025-05-26 13:10:20.103562
1640	57	5.6	608	5.3	0.3	eleve	126000.00	Nouveau crÃ©dit accordÃ©	0.82	amelioration	2025-07-10 13:10:20.103562
1641	57	6.1	635	5.6	0.5	moyen	210000.00	Paiement Ã  temps	0.83	amelioration	2025-08-24 13:10:20.103562
1642	57	6.4	652	6.1	0.3	moyen	210000.00	Nouveau crÃ©dit accordÃ©	0.84	amelioration	2025-10-08 13:10:20.103562
1643	58	4.1	525	4.0	0.1	eleve	153000.00	Mise Ã  jour automatique	0.77	stable	2024-08-29 13:10:20.103562
1644	58	4.4	542	4.1	0.3	eleve	153000.00	Paiement Ã  temps	0.78	amelioration	2024-10-13 13:10:20.103562
1645	58	4.7	558	4.4	0.3	eleve	153000.00	Paiement Ã  temps	0.79	amelioration	2024-11-27 13:10:20.103562
1646	58	4.9	569	4.7	0.2	eleve	153000.00	Nouveau crÃ©dit accordÃ©	0.80	stable	2025-01-11 13:10:20.103562
1647	58	5.2	586	4.9	0.3	eleve	153000.00	Paiement Ã  temps	0.81	amelioration	2025-02-25 13:10:20.103562
1648	58	5.5	602	5.2	0.3	eleve	153000.00	Nouveau crÃ©dit accordÃ©	0.82	amelioration	2025-04-11 13:10:20.103562
1649	58	5.7	613	5.5	0.2	eleve	153000.00	Paiement Ã  temps	0.82	stable	2025-05-26 13:10:20.103562
1650	58	6.0	630	5.7	0.3	moyen	255000.00	Paiement Ã  temps	0.83	amelioration	2025-07-10 13:10:20.103562
1651	58	6.4	652	6.0	0.4	moyen	255000.00	Paiement en retard	0.84	amelioration	2025-08-24 13:10:20.103562
1652	58	6.7	668	6.4	0.3	moyen	255000.00	Nouveau crÃ©dit accordÃ©	0.85	amelioration	2025-10-08 13:10:20.103562
1653	59	5.0	575	4.7	0.3	eleve	117000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.80	amelioration	2025-02-25 13:10:20.103562
1654	59	5.3	591	5.0	0.3	eleve	117000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.81	amelioration	2025-04-11 13:10:20.103562
1655	59	5.7	613	5.3	0.4	eleve	117000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.82	amelioration	2025-05-26 13:10:20.103562
1656	59	5.9	624	5.7	0.2	eleve	117000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.83	stable	2025-07-10 13:10:20.103562
1657	59	6.2	641	5.9	0.3	moyen	195000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.84	amelioration	2025-08-24 13:10:20.103562
1658	59	6.5	657	6.2	0.3	moyen	195000.00	Nouveau crÃ©dit accordÃ©	0.85	amelioration	2025-10-08 13:10:20.103562
1659	60	5.5	602	5.4	0.1	eleve	156000.00	Nouveau crÃ©dit accordÃ©	0.82	stable	2025-01-11 13:10:20.103562
1660	60	5.7	613	5.5	0.2	eleve	156000.00	Paiement Ã  temps	0.82	stable	2025-02-25 13:10:20.103562
1661	60	5.9	624	5.7	0.2	eleve	156000.00	Paiement en retard	0.83	stable	2025-04-11 13:10:20.103562
1662	60	6.1	635	5.9	0.2	moyen	260000.00	Nouveau crÃ©dit accordÃ©	0.83	stable	2025-05-26 13:10:20.103562
1663	60	6.4	652	6.1	0.3	moyen	260000.00	Paiement Ã  temps	0.84	amelioration	2025-07-10 13:10:20.103562
1664	60	6.5	657	6.4	0.1	moyen	260000.00	Nouveau crÃ©dit accordÃ©	0.85	stable	2025-08-24 13:10:20.103562
1665	60	6.8	674	6.5	0.3	moyen	260000.00	Paiement Ã  temps	0.85	amelioration	2025-10-08 13:10:20.103562
1666	61	6.0	630	5.9	0.1	moyen	300000.00	Paiement Ã  temps	0.83	stable	2025-04-11 13:10:20.103562
1667	61	6.4	652	6.0	0.4	moyen	300000.00	Paiement Ã  temps	0.84	amelioration	2025-05-26 13:10:20.103562
1668	61	6.6	663	6.4	0.2	moyen	300000.00	Nouveau crÃ©dit accordÃ©	0.85	stable	2025-07-10 13:10:20.103562
1669	61	6.9	679	6.6	0.3	moyen	300000.00	Nouveau crÃ©dit accordÃ©	0.86	amelioration	2025-08-24 13:10:20.103562
1670	61	7.1	690	6.9	0.2	moyen	300000.00	Paiement Ã  temps	0.86	stable	2025-10-08 13:10:20.103562
1671	62	5.8	619	5.5	0.3	eleve	204000.00	Nouveau crÃ©dit accordÃ©	0.82	amelioration	2025-04-11 13:10:20.103562
1672	62	6.2	641	5.8	0.4	moyen	340000.00	Paiement Ã  temps	0.84	amelioration	2025-05-26 13:10:20.103562
1673	62	6.5	657	6.2	0.3	moyen	340000.00	Paiement en retard	0.85	amelioration	2025-07-10 13:10:20.103562
1674	62	6.7	668	6.5	0.2	moyen	340000.00	Nouveau crÃ©dit accordÃ©	0.85	stable	2025-08-24 13:10:20.103562
1675	62	7.1	690	6.7	0.4	moyen	340000.00	Nouveau crÃ©dit accordÃ©	0.86	amelioration	2025-10-08 13:10:20.103562
1676	63	5.5	602	5.4	0.1	eleve	186000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.82	stable	2024-11-27 13:10:20.103562
1677	63	5.7	613	5.5	0.2	eleve	186000.00	Paiement Ã  temps	0.82	stable	2025-01-11 13:10:20.103562
1678	63	6.0	630	5.7	0.3	moyen	310000.00	Paiement Ã  temps	0.83	amelioration	2025-02-25 13:10:20.103562
1679	63	6.2	641	6.0	0.2	moyen	310000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.84	stable	2025-04-11 13:10:20.103562
1680	63	6.5	657	6.2	0.3	moyen	310000.00	Nouveau crÃ©dit accordÃ©	0.85	amelioration	2025-05-26 13:10:20.103562
1681	63	6.7	668	6.5	0.2	moyen	310000.00	Nouveau crÃ©dit accordÃ©	0.85	stable	2025-07-10 13:10:20.103562
1682	63	6.9	679	6.7	0.2	moyen	310000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.86	stable	2025-08-24 13:10:20.103562
1683	63	6.9	679	6.9	0.0	moyen	310000.00	Paiement Ã  temps	0.86	stable	2025-10-08 13:10:20.103562
1684	64	4.6	553	4.2	0.4	eleve	132000.00	Nouveau crÃ©dit accordÃ©	0.79	amelioration	2024-08-29 13:10:20.103562
1685	64	4.9	569	4.6	0.3	eleve	132000.00	Nouveau crÃ©dit accordÃ©	0.80	amelioration	2024-10-13 13:10:20.103562
1686	64	5.1	580	4.9	0.2	eleve	132000.00	Paiement Ã  temps	0.80	stable	2024-11-27 13:10:20.103562
1687	64	5.3	591	5.1	0.2	eleve	132000.00	Nouveau crÃ©dit accordÃ©	0.81	stable	2025-01-11 13:10:20.103562
1688	64	5.5	602	5.3	0.2	eleve	132000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.82	stable	2025-02-25 13:10:20.103562
1689	64	5.9	624	5.5	0.4	eleve	132000.00	Nouveau crÃ©dit accordÃ©	0.83	amelioration	2025-04-11 13:10:20.103562
1690	64	6.0	630	5.9	0.1	moyen	220000.00	Nouveau crÃ©dit accordÃ©	0.83	stable	2025-05-26 13:10:20.103562
1691	64	6.3	646	6.0	0.3	moyen	220000.00	Paiement Ã  temps	0.84	amelioration	2025-07-10 13:10:20.103562
1692	64	6.4	652	6.3	0.1	moyen	220000.00	Nouveau crÃ©dit accordÃ©	0.84	stable	2025-08-24 13:10:20.103562
1693	64	6.5	657	6.4	0.1	moyen	220000.00	Paiement Ã  temps	0.85	stable	2025-10-08 13:10:20.103562
1694	65	4.8	564	4.3	0.5	eleve	150000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.79	amelioration	2025-05-26 13:10:20.103562
1695	65	5.4	597	4.8	0.6	eleve	150000.00	Paiement Ã  temps	0.81	amelioration	2025-07-10 13:10:20.103562
1696	65	6.1	635	5.4	0.7	moyen	250000.00	Paiement Ã  temps	0.83	amelioration	2025-08-24 13:10:20.103562
1697	65	6.7	668	6.1	0.6	moyen	250000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.85	amelioration	2025-10-08 13:10:20.103562
1698	66	5.5	602	4.9	0.6	eleve	186000.00	Paiement Ã  temps	0.82	amelioration	2025-07-10 13:10:20.103562
1699	66	6.3	646	5.5	0.8	moyen	310000.00	Nouveau crÃ©dit accordÃ©	0.84	amelioration	2025-08-24 13:10:20.103562
1700	66	7.2	696	6.3	0.9	moyen	310000.00	Paiement Ã  temps	0.87	amelioration	2025-10-08 13:10:20.103562
1701	67	5.4	597	5.3	0.1	eleve	165000.00	Nouveau crÃ©dit accordÃ©	0.81	stable	2025-01-11 13:10:20.103562
1702	67	5.6	608	5.4	0.2	eleve	165000.00	Paiement Ã  temps	0.82	stable	2025-02-25 13:10:20.103562
1703	67	5.8	619	5.6	0.2	eleve	165000.00	Nouveau crÃ©dit accordÃ©	0.82	stable	2025-04-11 13:10:20.103562
1704	67	6.1	635	5.8	0.3	moyen	275000.00	Paiement Ã  temps	0.83	amelioration	2025-05-26 13:10:20.103562
1705	67	6.5	657	6.1	0.4	moyen	275000.00	Nouveau crÃ©dit accordÃ©	0.85	amelioration	2025-07-10 13:10:20.103562
1706	67	6.8	674	6.5	0.3	moyen	275000.00	Paiement Ã  temps	0.85	amelioration	2025-08-24 13:10:20.103562
1707	67	6.9	679	6.8	0.1	moyen	275000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.86	stable	2025-10-08 13:10:20.103562
1708	68	4.4	542	4.1	0.3	eleve	114000.00	Paiement Ã  temps	0.78	amelioration	2025-02-25 13:10:20.103562
1709	68	4.9	569	4.4	0.5	eleve	114000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.80	amelioration	2025-04-11 13:10:20.103562
1710	68	5.3	591	4.9	0.4	eleve	114000.00	Nouveau crÃ©dit accordÃ©	0.81	amelioration	2025-05-26 13:10:20.103562
1711	68	5.7	613	5.3	0.4	eleve	114000.00	Nouveau crÃ©dit accordÃ©	0.82	amelioration	2025-07-10 13:10:20.103562
1712	68	5.9	624	5.7	0.2	eleve	114000.00	Paiement Ã  temps	0.83	stable	2025-08-24 13:10:20.103562
1713	68	6.3	646	5.9	0.4	moyen	190000.00	Nouveau crÃ©dit accordÃ©	0.84	amelioration	2025-10-08 13:10:20.103562
1714	69	5.6	608	5.4	0.2	eleve	138000.00	Nouveau crÃ©dit accordÃ©	0.82	stable	2025-04-11 13:10:20.103562
1715	69	5.8	619	5.6	0.2	eleve	138000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.82	stable	2025-05-26 13:10:20.103562
1716	69	6.2	641	5.8	0.4	moyen	230000.00	Paiement Ã  temps	0.84	amelioration	2025-07-10 13:10:20.103562
1717	69	6.3	646	6.2	0.1	moyen	230000.00	Paiement Ã  temps	0.84	stable	2025-08-24 13:10:20.103562
1718	69	6.8	674	6.3	0.5	moyen	230000.00	Paiement Ã  temps	0.85	amelioration	2025-10-08 13:10:20.103562
1719	70	3.4	487	2.4	1.0	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.75	amelioration	2025-07-10 13:10:20.103562
1720	70	4.4	542	3.4	1.0	eleve	84000.00	Paiement en retard	0.78	amelioration	2025-08-24 13:10:20.103562
1721	70	5.3	591	4.4	0.9	eleve	84000.00	Nouveau crÃ©dit accordÃ©	0.81	amelioration	2025-10-08 13:10:20.103562
1722	71	3.2	476	3.0	0.2	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.75	stable	2024-11-27 13:10:20.103562
1723	71	3.5	492	3.2	0.3	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.76	amelioration	2025-01-11 13:10:20.103562
1724	71	3.8	509	3.5	0.3	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.76	amelioration	2025-02-25 13:10:20.103562
1725	71	3.9	514	3.8	0.1	tres_eleve	0.00	Paiement Ã  temps	0.77	stable	2025-04-11 13:10:20.103562
1726	71	4.2	531	3.9	0.3	eleve	54000.00	Nouveau crÃ©dit accordÃ©	0.78	amelioration	2025-05-26 13:10:20.103562
1727	71	4.4	542	4.2	0.2	eleve	54000.00	Paiement Ã  temps	0.78	stable	2025-07-10 13:10:20.103562
1728	71	4.7	558	4.4	0.3	eleve	54000.00	Paiement en retard	0.79	amelioration	2025-08-24 13:10:20.103562
1729	71	4.9	569	4.7	0.2	eleve	54000.00	Nouveau crÃ©dit accordÃ©	0.80	stable	2025-10-08 13:10:20.103562
1730	72	3.1	470	2.8	0.3	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.74	amelioration	2024-10-13 13:10:20.103562
1731	72	3.2	476	3.1	0.1	tres_eleve	0.00	Paiement Ã  temps	0.75	stable	2024-11-27 13:10:20.103562
1732	72	3.4	487	3.2	0.2	tres_eleve	0.00	Paiement Ã  temps	0.75	stable	2025-01-11 13:10:20.103562
1733	72	3.7	503	3.4	0.3	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.76	amelioration	2025-02-25 13:10:20.103562
1734	72	3.7	503	3.7	0.0	tres_eleve	0.00	Paiement Ã  temps	0.76	stable	2025-04-11 13:10:20.103562
1735	72	3.9	514	3.7	0.2	tres_eleve	0.00	Paiement Ã  temps	0.77	stable	2025-05-26 13:10:20.103562
1736	72	4.2	531	3.9	0.3	eleve	66000.00	Paiement Ã  temps	0.78	amelioration	2025-07-10 13:10:20.103562
1737	72	4.3	536	4.2	0.1	eleve	66000.00	Paiement Ã  temps	0.78	stable	2025-08-24 13:10:20.103562
1738	72	4.5	547	4.3	0.2	eleve	66000.00	Nouveau crÃ©dit accordÃ©	0.79	stable	2025-10-08 13:10:20.103562
1739	73	3.2	476	2.4	0.8	tres_eleve	0.00	Paiement Ã  temps	0.75	amelioration	2025-07-10 13:10:20.103562
1740	73	3.8	509	3.2	0.6	tres_eleve	0.00	Paiement Ã  temps	0.76	amelioration	2025-08-24 13:10:20.103562
1741	73	4.6	553	3.8	0.8	eleve	57000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.79	amelioration	2025-10-08 13:10:20.103562
1742	74	3.6	498	3.2	0.4	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.76	amelioration	2025-02-25 13:10:20.103562
1743	74	3.8	509	3.6	0.2	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.76	stable	2025-04-11 13:10:20.103562
1744	74	4.0	520	3.8	0.2	eleve	72000.00	Nouveau crÃ©dit accordÃ©	0.77	stable	2025-05-26 13:10:20.103562
1745	74	4.3	536	4.0	0.3	eleve	72000.00	Nouveau crÃ©dit accordÃ©	0.78	amelioration	2025-07-10 13:10:20.103562
1746	74	4.5	547	4.3	0.2	eleve	72000.00	Paiement Ã  temps	0.79	stable	2025-08-24 13:10:20.103562
1747	74	4.9	569	4.5	0.4	eleve	72000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.80	amelioration	2025-10-08 13:10:20.103562
1748	75	4.0	520	3.8	0.2	eleve	63000.00	Nouveau crÃ©dit accordÃ©	0.77	stable	2025-04-11 13:10:20.103562
1749	75	4.2	531	4.0	0.2	eleve	63000.00	Paiement Ã  temps	0.78	stable	2025-05-26 13:10:20.103562
1750	75	4.5	547	4.2	0.3	eleve	63000.00	Paiement en retard	0.79	amelioration	2025-07-10 13:10:20.103562
1751	75	4.8	564	4.5	0.3	eleve	63000.00	Paiement Ã  temps	0.79	amelioration	2025-08-24 13:10:20.103562
1752	75	5.1	580	4.8	0.3	eleve	63000.00	Paiement Ã  temps	0.80	amelioration	2025-10-08 13:10:20.103562
1753	76	2.9	459	2.8	0.1	tres_eleve	0.00	Paiement Ã  temps	0.74	stable	2025-01-11 13:10:20.103562
1754	76	3.2	476	2.9	0.3	tres_eleve	0.00	Paiement Ã  temps	0.75	amelioration	2025-02-25 13:10:20.103562
1755	76	3.3	481	3.2	0.1	tres_eleve	0.00	Paiement Ã  temps	0.75	stable	2025-04-11 13:10:20.103562
1756	76	3.6	498	3.3	0.3	tres_eleve	0.00	Paiement Ã  temps	0.76	amelioration	2025-05-26 13:10:20.103562
1757	76	3.9	514	3.6	0.3	tres_eleve	0.00	Paiement Ã  temps	0.77	amelioration	2025-07-10 13:10:20.103562
1758	76	4.0	520	3.9	0.1	eleve	48000.00	Paiement Ã  temps	0.77	stable	2025-08-24 13:10:20.103562
1759	76	4.2	531	4.0	0.2	eleve	48000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.78	stable	2025-10-08 13:10:20.103562
1760	77	3.8	509	3.3	0.5	tres_eleve	0.00	Paiement Ã  temps	0.76	amelioration	2025-05-26 13:10:20.103562
1761	77	4.2	531	3.8	0.4	eleve	60000.00	Paiement Ã  temps	0.78	amelioration	2025-07-10 13:10:20.103562
1762	77	4.4	542	4.2	0.2	eleve	60000.00	Nouveau crÃ©dit accordÃ©	0.78	stable	2025-08-24 13:10:20.103562
1763	77	4.7	558	4.4	0.3	eleve	60000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.79	amelioration	2025-10-08 13:10:20.103562
1764	78	3.5	492	3.3	0.2	tres_eleve	0.00	Paiement Ã  temps	0.76	stable	2025-02-25 13:10:20.103562
1765	78	3.9	514	3.5	0.4	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.77	amelioration	2025-04-11 13:10:20.103562
1766	78	4.2	531	3.9	0.3	eleve	75000.00	Nouveau crÃ©dit accordÃ©	0.78	amelioration	2025-05-26 13:10:20.103562
1767	78	4.5	547	4.2	0.3	eleve	75000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.79	amelioration	2025-07-10 13:10:20.103562
1768	78	4.7	558	4.5	0.2	eleve	75000.00	Paiement Ã  temps	0.79	stable	2025-08-24 13:10:20.103562
1769	78	5.2	586	4.7	0.5	eleve	75000.00	Paiement Ã  temps	0.81	amelioration	2025-10-08 13:10:20.103562
1770	79	4.2	531	3.7	0.5	eleve	69000.00	Nouveau crÃ©dit accordÃ©	0.78	amelioration	2025-07-10 13:10:20.103562
1771	79	4.7	558	4.2	0.5	eleve	69000.00	Paiement Ã  temps	0.79	amelioration	2025-08-24 13:10:20.103562
1772	79	4.9	569	4.7	0.2	eleve	69000.00	Paiement Ã  temps	0.80	stable	2025-10-08 13:10:20.103562
1773	80	3.1	470	3.1	0.0	tres_eleve	0.00	Paiement Ã  temps	0.74	stable	2024-08-29 13:10:20.103562
1774	80	3.3	481	3.1	0.2	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.75	stable	2024-10-13 13:10:20.103562
1775	80	3.5	492	3.3	0.2	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.76	stable	2024-11-27 13:10:20.103562
1776	80	3.6	498	3.5	0.1	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.76	stable	2025-01-11 13:10:20.103562
1777	80	3.7	503	3.6	0.1	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.76	stable	2025-02-25 13:10:20.103562
1778	80	4.0	520	3.7	0.3	eleve	51000.00	Paiement Ã  temps	0.77	amelioration	2025-04-11 13:10:20.103562
1779	80	4.0	520	4.0	0.0	eleve	51000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.77	stable	2025-05-26 13:10:20.103562
1780	80	4.1	525	4.0	0.1	eleve	51000.00	Nouveau crÃ©dit accordÃ©	0.77	stable	2025-07-10 13:10:20.103562
1781	80	4.2	531	4.1	0.1	eleve	51000.00	Nouveau crÃ©dit accordÃ©	0.78	stable	2025-08-24 13:10:20.103562
1782	80	4.5	547	4.2	0.3	eleve	51000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.79	amelioration	2025-10-08 13:10:20.103562
1783	81	4.3	536	3.7	0.6	eleve	78000.00	Paiement Ã  temps	0.78	amelioration	2025-07-10 13:10:20.103562
1784	81	4.7	558	4.3	0.4	eleve	78000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.79	amelioration	2025-08-24 13:10:20.103562
1785	81	5.4	597	4.7	0.7	eleve	78000.00	Paiement Ã  temps	0.81	amelioration	2025-10-08 13:10:20.103562
1786	82	2.8	454	2.3	0.5	tres_eleve	0.00	Paiement en retard	0.73	amelioration	2025-05-26 13:10:20.103562
1787	82	3.4	487	2.8	0.6	tres_eleve	0.00	Paiement Ã  temps	0.75	amelioration	2025-07-10 13:10:20.103562
1788	82	4.1	525	3.4	0.7	eleve	55500.00	Paiement Ã  temps	0.77	amelioration	2025-08-24 13:10:20.103562
1789	82	4.6	553	4.1	0.5	eleve	55500.00	Paiement Ã  temps	0.79	amelioration	2025-10-08 13:10:20.103562
1790	83	2.9	459	2.5	0.4	tres_eleve	0.00	Paiement Ã  temps	0.74	amelioration	2025-04-11 13:10:20.103562
1791	83	3.4	487	2.9	0.5	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.75	amelioration	2025-05-26 13:10:20.103562
1792	83	3.8	509	3.4	0.4	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.76	amelioration	2025-07-10 13:10:20.103562
1793	83	4.2	531	3.8	0.4	eleve	58500.00	CrÃ©dit remboursÃ© intÃ©gralement	0.78	amelioration	2025-08-24 13:10:20.103562
1794	83	4.6	553	4.2	0.4	eleve	58500.00	Paiement Ã  temps	0.79	amelioration	2025-10-08 13:10:20.103562
1795	84	4.5	547	4.3	0.2	eleve	81000.00	Paiement Ã  temps	0.79	stable	2024-08-29 13:10:20.103562
1796	84	4.5	547	4.5	0.0	eleve	81000.00	Nouveau crÃ©dit accordÃ©	0.79	stable	2024-10-13 13:10:20.103562
1797	84	4.6	553	4.5	0.1	eleve	81000.00	Paiement Ã  temps	0.79	stable	2024-11-27 13:10:20.103562
1798	84	4.7	558	4.6	0.1	eleve	81000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.79	stable	2025-01-11 13:10:20.103562
1799	84	4.8	564	4.7	0.1	eleve	81000.00	Nouveau crÃ©dit accordÃ©	0.79	stable	2025-02-25 13:10:20.103562
1800	84	4.9	569	4.8	0.1	eleve	81000.00	Nouveau crÃ©dit accordÃ©	0.80	stable	2025-04-11 13:10:20.103562
1801	84	5.1	580	4.9	0.2	eleve	81000.00	Nouveau crÃ©dit accordÃ©	0.80	stable	2025-05-26 13:10:20.103562
1802	84	5.2	586	5.1	0.1	eleve	81000.00	Paiement Ã  temps	0.81	stable	2025-07-10 13:10:20.103562
1803	84	5.4	597	5.2	0.2	eleve	81000.00	Nouveau crÃ©dit accordÃ©	0.81	stable	2025-08-24 13:10:20.103562
1804	84	5.3	591	5.4	-0.1	eleve	81000.00	Paiement Ã  temps	0.81	stable	2025-10-08 13:10:20.103562
1805	85	3.2	476	3.1	0.1	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.75	stable	2024-11-27 13:10:20.103562
1806	85	3.5	492	3.2	0.3	tres_eleve	0.00	Paiement en retard	0.76	amelioration	2025-01-11 13:10:20.103562
1807	85	3.7	503	3.5	0.2	tres_eleve	0.00	Paiement en retard	0.76	stable	2025-02-25 13:10:20.103562
1808	85	3.9	514	3.7	0.2	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.77	stable	2025-04-11 13:10:20.103562
1809	85	4.2	531	3.9	0.3	eleve	52500.00	Nouveau crÃ©dit accordÃ©	0.78	amelioration	2025-05-26 13:10:20.103562
1810	85	4.2	531	4.2	0.0	eleve	52500.00	Nouveau crÃ©dit accordÃ©	0.78	stable	2025-07-10 13:10:20.103562
1811	85	4.5	547	4.2	0.3	eleve	52500.00	Paiement Ã  temps	0.79	amelioration	2025-08-24 13:10:20.103562
1812	85	4.6	553	4.5	0.1	eleve	52500.00	Nouveau crÃ©dit accordÃ©	0.79	stable	2025-10-08 13:10:20.103562
1813	86	3.4	487	3.0	0.4	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.75	amelioration	2025-05-26 13:10:20.103562
1814	86	3.5	492	3.4	0.1	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.76	stable	2025-07-10 13:10:20.103562
1815	86	3.9	514	3.5	0.4	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.77	amelioration	2025-08-24 13:10:20.103562
1816	86	4.3	536	3.9	0.4	eleve	46500.00	CrÃ©dit remboursÃ© intÃ©gralement	0.78	amelioration	2025-10-08 13:10:20.103562
1817	87	2.7	448	2.4	0.3	tres_eleve	0.00	Paiement Ã  temps	0.73	amelioration	2024-11-27 13:10:20.103562
1818	87	3.0	465	2.7	0.3	tres_eleve	0.00	Paiement en retard	0.74	amelioration	2025-01-11 13:10:20.103562
1819	87	3.2	476	3.0	0.2	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.75	stable	2025-02-25 13:10:20.103562
1820	87	3.4	487	3.2	0.2	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.75	stable	2025-04-11 13:10:20.103562
1821	87	3.9	514	3.4	0.5	tres_eleve	0.00	Paiement Ã  temps	0.77	amelioration	2025-05-26 13:10:20.103562
1822	87	4.3	536	3.9	0.4	eleve	61500.00	CrÃ©dit remboursÃ© intÃ©gralement	0.78	amelioration	2025-07-10 13:10:20.103562
1823	87	4.6	553	4.3	0.3	eleve	61500.00	Nouveau crÃ©dit accordÃ©	0.79	amelioration	2025-08-24 13:10:20.103562
1824	87	4.8	564	4.6	0.2	eleve	61500.00	Paiement Ã  temps	0.79	stable	2025-10-08 13:10:20.103562
1825	88	4.5	547	4.2	0.3	eleve	87000.00	Nouveau crÃ©dit accordÃ©	0.79	amelioration	2025-04-11 13:10:20.103562
1826	88	4.8	564	4.5	0.3	eleve	87000.00	Paiement Ã  temps	0.79	amelioration	2025-05-26 13:10:20.103562
1827	88	5.1	580	4.8	0.3	eleve	87000.00	Paiement Ã  temps	0.80	amelioration	2025-07-10 13:10:20.103562
1828	88	5.4	597	5.1	0.3	eleve	87000.00	Nouveau crÃ©dit accordÃ©	0.81	amelioration	2025-08-24 13:10:20.103562
1829	88	5.6	608	5.4	0.2	eleve	87000.00	Nouveau crÃ©dit accordÃ©	0.82	stable	2025-10-08 13:10:20.103562
1830	89	3.8	509	3.3	0.5	tres_eleve	0.00	Paiement Ã  temps	0.76	amelioration	2025-07-10 13:10:20.103562
1831	89	4.5	547	3.8	0.7	eleve	66000.00	Paiement en retard	0.79	amelioration	2025-08-24 13:10:20.103562
1832	89	5.0	575	4.5	0.5	eleve	66000.00	CrÃ©dit remboursÃ© intÃ©gralement	0.80	amelioration	2025-10-08 13:10:20.103562
1833	90	1.5	382	1.2	0.3	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.70	amelioration	2025-02-25 13:10:20.103562
1834	90	1.9	404	1.5	0.4	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.71	amelioration	2025-04-11 13:10:20.103562
1835	90	2.2	421	1.9	0.3	tres_eleve	0.00	Paiement Ã  temps	0.72	amelioration	2025-05-26 13:10:20.103562
1836	90	2.6	443	2.2	0.4	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.73	amelioration	2025-07-10 13:10:20.103562
1837	90	2.8	454	2.6	0.2	tres_eleve	0.00	Paiement en retard	0.73	stable	2025-08-24 13:10:20.103562
1838	90	3.1	470	2.8	0.3	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.74	amelioration	2025-10-08 13:10:20.103562
1839	91	0.7	338	0.4	0.3	tres_eleve	0.00	Paiement Ã  temps	0.67	amelioration	2025-02-25 13:10:20.103562
1840	91	1.2	366	0.7	0.5	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.69	amelioration	2025-04-11 13:10:20.103562
1841	91	1.7	393	1.2	0.5	tres_eleve	0.00	Paiement Ã  temps	0.70	amelioration	2025-05-26 13:10:20.103562
1842	91	2.0	410	1.7	0.3	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.71	amelioration	2025-07-10 13:10:20.103562
1843	91	2.3	426	2.0	0.3	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.72	amelioration	2025-08-24 13:10:20.103562
1844	91	2.7	448	2.3	0.4	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.73	amelioration	2025-10-08 13:10:20.103562
1845	92	1.4	377	1.3	0.1	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.69	stable	2025-01-11 13:10:20.103562
1846	92	1.7	393	1.4	0.3	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.70	amelioration	2025-02-25 13:10:20.103562
1847	92	1.9	404	1.7	0.2	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.71	stable	2025-04-11 13:10:20.103562
1848	92	2.0	410	1.9	0.1	tres_eleve	0.00	Paiement Ã  temps	0.71	stable	2025-05-26 13:10:20.103562
1849	92	2.1	415	2.0	0.1	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.71	stable	2025-07-10 13:10:20.103562
1850	92	2.2	421	2.1	0.1	tres_eleve	0.00	Paiement Ã  temps	0.72	stable	2025-08-24 13:10:20.103562
1851	92	2.4	432	2.2	0.2	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.72	stable	2025-10-08 13:10:20.103562
1852	93	1.6	388	1.2	0.4	tres_eleve	0.00	Paiement Ã  temps	0.70	amelioration	2024-11-27 13:10:20.103562
1853	93	1.8	399	1.6	0.2	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.70	stable	2025-01-11 13:10:20.103562
1854	93	1.9	404	1.8	0.1	tres_eleve	0.00	Paiement Ã  temps	0.71	stable	2025-02-25 13:10:20.103562
1855	93	2.2	421	1.9	0.3	tres_eleve	0.00	Paiement en retard	0.72	amelioration	2025-04-11 13:10:20.103562
1856	93	2.3	426	2.2	0.1	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.72	stable	2025-05-26 13:10:20.103562
1857	93	2.5	437	2.3	0.2	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.73	stable	2025-07-10 13:10:20.103562
1858	93	2.8	454	2.5	0.3	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.73	amelioration	2025-08-24 13:10:20.103562
1859	93	3.0	465	2.8	0.2	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.74	stable	2025-10-08 13:10:20.103562
1860	94	2.2	421	2.2	0.0	tres_eleve	0.00	Paiement Ã  temps	0.72	stable	2024-10-13 13:10:20.103562
1861	94	2.4	432	2.2	0.2	tres_eleve	0.00	Paiement Ã  temps	0.72	stable	2024-11-27 13:10:20.103562
1862	94	2.7	448	2.4	0.3	tres_eleve	0.00	Paiement Ã  temps	0.73	amelioration	2025-01-11 13:10:20.103562
1863	94	2.7	448	2.7	0.0	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.73	stable	2025-02-25 13:10:20.103562
1864	94	2.8	454	2.7	0.1	tres_eleve	0.00	Paiement en retard	0.73	stable	2025-04-11 13:10:20.103562
1865	94	2.9	459	2.8	0.1	tres_eleve	0.00	Paiement Ã  temps	0.74	stable	2025-05-26 13:10:20.103562
1866	94	3.1	470	2.9	0.2	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.74	stable	2025-07-10 13:10:20.103562
1867	94	3.2	476	3.1	0.1	tres_eleve	0.00	Paiement Ã  temps	0.75	stable	2025-08-24 13:10:20.103562
1868	94	3.3	481	3.2	0.1	tres_eleve	0.00	Paiement Ã  temps	0.75	stable	2025-10-08 13:10:20.103562
1869	95	1.5	382	1.3	0.2	tres_eleve	0.00	Paiement Ã  temps	0.70	stable	2024-10-13 13:10:20.103562
1870	95	1.6	388	1.5	0.1	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.70	stable	2024-11-27 13:10:20.103562
1871	95	1.8	399	1.6	0.2	tres_eleve	0.00	Paiement Ã  temps	0.70	stable	2025-01-11 13:10:20.103562
1872	95	1.9	404	1.8	0.1	tres_eleve	0.00	Paiement Ã  temps	0.71	stable	2025-02-25 13:10:20.103562
1873	95	2.0	410	1.9	0.1	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.71	stable	2025-04-11 13:10:20.103562
1874	95	2.1	415	2.0	0.1	tres_eleve	0.00	Paiement Ã  temps	0.71	stable	2025-05-26 13:10:20.103562
1875	95	2.2	421	2.1	0.1	tres_eleve	0.00	Paiement Ã  temps	0.72	stable	2025-07-10 13:10:20.103562
1876	95	2.4	432	2.2	0.2	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.72	stable	2025-08-24 13:10:20.103562
1877	95	2.8	454	2.4	0.4	tres_eleve	0.00	Paiement Ã  temps	0.73	amelioration	2025-10-08 13:10:20.103562
1878	96	1.7	393	1.5	0.2	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.70	stable	2024-10-13 13:10:20.103562
1879	96	1.9	404	1.7	0.2	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.71	stable	2024-11-27 13:10:20.103562
1880	96	2.2	421	1.9	0.3	tres_eleve	0.00	Paiement Ã  temps	0.72	amelioration	2025-01-11 13:10:20.103562
1881	96	2.5	437	2.2	0.3	tres_eleve	0.00	Paiement Ã  temps	0.73	amelioration	2025-02-25 13:10:20.103562
1882	96	2.6	443	2.5	0.1	tres_eleve	0.00	Paiement Ã  temps	0.73	stable	2025-04-11 13:10:20.103562
1883	96	2.8	454	2.6	0.2	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.73	stable	2025-05-26 13:10:20.103562
1884	96	3.0	465	2.8	0.2	tres_eleve	0.00	Paiement Ã  temps	0.74	stable	2025-07-10 13:10:20.103562
1885	96	3.1	470	3.0	0.1	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.74	stable	2025-08-24 13:10:20.103562
1886	96	3.4	487	3.1	0.3	tres_eleve	0.00	Paiement Ã  temps	0.75	amelioration	2025-10-08 13:10:20.103562
1887	97	2.3	426	1.9	0.4	tres_eleve	0.00	Paiement en retard	0.72	amelioration	2025-07-10 13:10:20.103562
1888	97	2.8	454	2.3	0.5	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.73	amelioration	2025-08-24 13:10:20.103562
1889	97	3.0	465	2.8	0.2	tres_eleve	0.00	Paiement en retard	0.74	stable	2025-10-08 13:10:20.103562
1890	98	0.6	333	0.1	0.5	tres_eleve	0.00	Paiement Ã  temps	0.67	amelioration	2025-04-11 13:10:20.103562
1891	98	0.9	349	0.6	0.3	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.68	amelioration	2025-05-26 13:10:20.103562
1892	98	1.3	371	0.9	0.4	tres_eleve	0.00	Paiement Ã  temps	0.69	amelioration	2025-07-10 13:10:20.103562
1893	98	1.8	399	1.3	0.5	tres_eleve	0.00	Paiement Ã  temps	0.70	amelioration	2025-08-24 13:10:20.103562
1894	98	2.2	421	1.8	0.4	tres_eleve	0.00	Paiement Ã  temps	0.72	amelioration	2025-10-08 13:10:20.103562
1895	99	1.7	393	1.6	0.1	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.70	stable	2024-08-29 13:10:20.103562
1896	99	1.9	404	1.7	0.2	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.71	stable	2024-10-13 13:10:20.103562
1897	99	2.0	410	1.9	0.1	tres_eleve	0.00	Paiement Ã  temps	0.71	stable	2024-11-27 13:10:20.103562
1898	99	2.1	415	2.0	0.1	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.71	stable	2025-01-11 13:10:20.103562
1899	99	2.1	415	2.1	0.0	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.71	stable	2025-02-25 13:10:20.103562
1900	99	2.1	415	2.1	0.0	tres_eleve	0.00	CrÃ©dit remboursÃ© intÃ©gralement	0.71	stable	2025-04-11 13:10:20.103562
1901	99	2.2	421	2.1	0.1	tres_eleve	0.00	Paiement Ã  temps	0.72	stable	2025-05-26 13:10:20.103562
1902	99	2.2	421	2.2	0.0	tres_eleve	0.00	Paiement Ã  temps	0.72	stable	2025-07-10 13:10:20.103562
1903	99	2.5	437	2.2	0.3	tres_eleve	0.00	Nouveau crÃ©dit accordÃ©	0.73	amelioration	2025-08-24 13:10:20.103562
1904	99	2.6	443	2.5	0.1	tres_eleve	0.00	Paiement Ã  temps	0.73	stable	2025-10-08 13:10:20.103562
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
96	76	t	1	2	94106.36	58.82	2025-08-23 07:07:40.219977	2025-09-22 07:07:40.219977	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
97	5	t	1	2	192233.84	9.61	2025-09-05 18:31:54.933348	2025-10-05 18:31:54.933348	4	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
98	18	t	1	2	409245.28	28.82	2025-03-12 11:49:05.173728	2025-04-11 11:49:05.173728	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
99	64	t	1	2	266211.55	60.50	2025-05-30 00:57:53.455338	2025-06-29 00:57:53.455338	0	\N	2025-10-02 08:01:52.901077	2025-10-02 08:01:52.901077
95	1	f	10	2	5114296.41	204.57	2025-10-09 16:52:11.569	\N	0	Maximum de 2 crédits actifs atteint	2025-10-02 08:01:52.901077	2025-10-09 16:52:11.573738
\.


--
-- Data for Name: utilisateurs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.utilisateurs (id, uuid, nom, prenom, email, telephone, mot_de_passe_hash, ville, quartier, province, profession, employeur, statut_emploi, revenu_mensuel, anciennete_mois, charges_mensuelles, dettes_existantes, score_credit, score_850, niveau_risque, montant_eligible, statut, date_creation, date_modification, derniere_connexion) FROM stdin;
2	aa9b39ba-405d-42ac-b504-cdff5b697ced	NGUEMA	Marie-Claire	mc.nguema@email.ga	077111002	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	NombakÃ©LÃ©	Estuaire	Directrice RH	Banque Gabonaise	cdi	1800000.00	96	600000.00	0.00	8.9	750	tres_bas	1500000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
13	b40bc845-2b44-4820-8b95-e1677b99af1c	KOMBILA	Serge	s.kombila@email.ga	077111013	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Oyem	Centre-Ville	Woleu-Ntem	Directeur Ã‰cole	Ã‰ducation Nationale	fonctionnaire	850000.00	108	290000.00	50000.00	8.0	690	bas	680000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
14	507bf1f0-e825-43cb-be26-d51193adeb2c	BOUNDA	Jacqueline	j.bounda@email.ga	077111014	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	AkÃ©bÃ©	Estuaire	Responsable Achats	BGFI Bank	cdi	1280000.00	60	420000.00	180000.00	8.3	708	bas	1020000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
92	0a26149f-8c29-43b3-84df-d9526766e336	PAMBOU	ThÃ©odore	t.pambou@email.ga	077444003	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	PK8	Estuaire	Aide Familial	Sans Revenu Fixe	autre	80000.00	6	55000.00	75000.00	2.5	305	tres_eleve	0.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
93	25316627-304c-48eb-b55f-903224741d65	QUEMBO	IrÃ¨ne	i.quembo@email.ga	077444004	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Port-Gentil	Quartier	OgoouÃ©-Maritime	Vendeuse Rue	Informel	independant	105000.00	12	70000.00	90000.00	3.0	330	tres_eleve	0.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
94	2035721a-b3bb-4198-8ab0-737087dee45c	RETENO	Bruno	b.reteno@email.ga	077444005	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Okala	Estuaire	Apprenti	Sans Contrat	autre	130000.00	4	80000.00	105000.00	3.4	365	tres_eleve	100000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
95	95efd385-5e1c-40dc-a967-dc78de328199	SAMBA	FÃ©licitÃ©	f.samba@email.ga	077444006	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Sibang	Estuaire	Aide MÃ©nagÃ¨re	Occasionnel	autre	90000.00	8	62000.00	85000.00	2.7	315	tres_eleve	0.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
96	ef7e57b3-45b0-4a7c-8c0d-fd559f12f56f	TCHIBINTA	Gaston	g.tchibinta@email.ga	077444007	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Alibandeng	Estuaire	Gardien Nuit	Sans Contrat	autre	140000.00	10	85000.00	115000.00	3.5	370	tres_eleve	110000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
24	d084c834-b19a-436d-9e14-492238601dfd	OKOMO	VÃ©ronique	v.okomo@email.ga	077111024	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Nzeng-Ayong	Estuaire	Consultante Finance	Cabinet Conseil	independant	1620000.00	48	540000.00	0.00	8.6	735	bas	1300000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
25	34f86d3d-b287-4061-813c-8b3462efeae4	PAMBOU	GÃ©rard	g.pambou@email.ga	077111025	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Franceville	BangombÃ©	Haut-OgoouÃ©	Chef Comptable	Comilog	cdi	1190000.00	90	390000.00	100000.00	8.3	712	bas	950000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
26	81408af2-6458-44c2-a7d7-b3315b583ddf	TCHOUMBA	AgnÃ¨s	a.tchoumba@email.ga	077111026	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Toulon	Estuaire	Responsable Formation	CNSS	fonctionnaire	1050000.00	84	350000.00	0.00	8.2	705	bas	840000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
27	ee4e17d5-fe6a-4c53-a2a6-c1b5f2e07baf	YEMBIT	Daniel	d.yembit@email.ga	077111027	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Bellevue	Estuaire	GÃ©rant Restaurant	Auto-entrepreneur	independant	1350000.00	60	450000.00	200000.00	8.1	698	bas	1080000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
28	5bc7c195-2f71-45fa-a90f-57aea22a430b	ZOMO	Mireille	m.zomo@email.ga	077111028	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Akanda II	Estuaire	Chef de Mission Audit	KPMG Gabon	cdi	1580000.00	66	520000.00	0.00	8.7	740	tres_bas	1260000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
29	a26a8ee8-a61a-4132-a680-12c2358e6595	BEKALE	Olivier	o.bekale@email.ga	077111029	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Port-Gentil	Cap Lopez	OgoouÃ©-Maritime	Cadre Bancaire	BICIG	cdi	1420000.00	78	470000.00	120000.00	8.4	720	bas	1140000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
30	64118787-0217-4a2c-9de8-72f505465fe0	NDEMBI	Clarisse	c.ndembi@email.ga	077111030	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	SabliÃ¨re	Estuaire	Responsable QualitÃ©	Ceca-Gadis	cdi	1280000.00	54	420000.00	0.00	8.6	733	bas	1020000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
32	9aef0417-ebef-4980-99d3-678d80dfc4a6	DITEEKE	Albertine	a.diteeke@email.ga	077222002	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	PK8	Estuaire	SecrÃ©taire Direction	MinistÃ¨re SantÃ©	fonctionnaire	520000.00	48	200000.00	100000.00	6.8	610	moyen	420000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
42	2aab8e7f-cd10-4c3a-8638-a41923b3aeec	PAMBOU	Christian	c.pambou@email.ga	077222013	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Port-Gentil	Boulingui	OgoouÃ©-Maritime	MÃ©canicien Auto	Garage PrivÃ©	cdi	560000.00	42	220000.00	140000.00	6.8	612	moyen	450000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
43	dbfd2839-8ce0-47b3-b049-7f90b7ab90ad	QUEMBO	AngÃ©lique	a.quembo@email.ga	077222014	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	PK5	Estuaire	Coiffeuse	Salon de BeautÃ©	independant	420000.00	36	170000.00	90000.00	6.5	590	moyen	340000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
44	2ce57a7b-d93d-481f-baa2-6e97e492633d	RETENO	Faustin	f.reteno@email.ga	077222015	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Ancien Chantier	Estuaire	Agent de SÃ©curitÃ©	SociÃ©tÃ© SÃ©curitÃ©	cdi	450000.00	48	180000.00	100000.00	6.7	608	moyen	360000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
45	1ebb9341-e528-476d-97c7-3726f41ddb91	SAMBA	GisÃ¨le	g.samba@email.ga	077222016	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Nzeng-Ayong	Estuaire	CaissiÃ¨re	Station Service	cdi	380000.00	24	160000.00	80000.00	6.4	585	moyen	300000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
46	b3759999-ee18-41b4-9a14-492d8ec15ee3	TCHIBINTA	Armand	a.tchibinta@email.ga	077222017	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Akanda	Estuaire	Technicien Maintenance	SEEG	cdi	670000.00	54	260000.00	180000.00	7.1	635	moyen	540000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
31	5516e7ff-5006-4118-a034-d2abca25f2c9	BOUYOU	Michel	m.bouyou@email.ga	077222001	$2a$06$HE9F7IkjqbzDjpG2Ktd6nectOyAaTvH0hDVE3WHcwt7TShWiXtGOO	Libreville	Lalala	Estuaire	Technicien Informatique	SOBRAGA	cdi	680000.00	36	250000.00	180000.00	7.2	640	moyen	550000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:33:58.33664	2025-10-06 18:33:58.33664
1	8eea411c-d0aa-4528-b3c7-6bcf21378f0a	OBAME	Jean-Pierre	jp.obame@email.ga	077111001	$2a$06$wQ0WHmHbugusnY8j6SH9Kus8K5sFIzYNk3SBINCdRsh3NZ5j9S.2i	Libreville	Glass	Estuaire	IngÃ©nieur PÃ©trole	Total Gabon	cdi	2500000.00	72	800000.00	5114296.41	6.5	657	moyen	1250000.00	actif	2025-10-02 08:01:52.723422	2025-10-09 16:52:11.548844	2025-10-09 16:32:14.48865
47	c34ec8c3-7c91-4985-92e3-19d2f429e453	UROBO	ValÃ©rie	v.urobo@email.ga	077222018	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Alibandeng	Estuaire	Aide-Soignante	Clinique PrivÃ©e	cdd	460000.00	18	185000.00	105000.00	6.5	592	moyen	370000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
3	5afcfa17-1b47-4cdc-b99b-317c548bfcd0	MBOUMBA	Patrick	p.mboumba@email.ga	077111003	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Batterie IV	Estuaire	Manager IT	Gabon Telecom	cdi	1500000.00	60	500000.00	200000.00	8.5	720	bas	1200000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
97	933cbc6a-c91d-4725-87c3-d2e78d62a160	UROBO	Denise	d.urobo@email.ga	077444008	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Ancien Chantier	Estuaire	Revendeuse	Informel	independant	110000.00	15	72000.00	95000.00	3.1	340	tres_eleve	90000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
98	f3c23690-214c-41a4-b05e-f5f0483a415d	VIDJABO	Firmin	f.vidjabo@email.ga	077444009	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Charbonnages	Estuaire	ChÃ´meur	Sans Emploi	autre	75000.00	0	50000.00	80000.00	2.3	300	tres_eleve	0.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
49	aa98cf82-5eba-4d59-8353-f2c6149509e6	WORA	Brigitte	b.wora@email.ga	077222020	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Sibang	Estuaire	Serveuse Restaurant	Restaurant Local	autre	340000.00	12	150000.00	70000.00	6.2	575	moyen	270000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
50	f570916b-84e9-4c76-b2d8-4c0f6f3df559	YEMBA	Gilbert	g.yemba@email.ga	077222021	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Charbonnages	Estuaire	Ouvrier BTP	Entreprise Construction	cdd	490000.00	30	200000.00	120000.00	6.6	600	moyen	390000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
51	7ff37ae1-b16e-4119-9e12-6751a6f6cf59	ZINGA	Martine	m.zinga@email.ga	077222022	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	AkÃ©bÃ©	Estuaire	EmployÃ©e Bureau	Cabinet Avocat	cdi	540000.00	36	215000.00	135000.00	6.9	622	moyen	430000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
52	6fcc6b63-0f71-40b7-8b76-3966975c0397	ALLOGO	HervÃ©	h.allogo@email.ga	077222023	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Atong Abe	Estuaire	Gardien Immeuble	CopropriÃ©tÃ©	cdi	360000.00	60	155000.00	75000.00	6.3	580	moyen	290000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
53	d33081f1-f410-427a-a839-d726cc2b9954	BINET	StÃ©phanie	s.binet@email.ga	077222024	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Port-Gentil	Grand Village	OgoouÃ©-Maritime	RÃ©ceptionniste	HÃ´tel Atlantique	cdi	470000.00	42	190000.00	110000.00	6.7	610	moyen	380000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
54	fd646a76-6253-4e20-8922-87f406c3a176	COMBO	Ã‰douard	e.combo@email.ga	077222025	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Oloumi	Estuaire	MaÃ§on	Auto-entrepreneur	independant	550000.00	48	220000.00	145000.00	6.9	618	moyen	440000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
55	3989a64f-bc83-4601-b23c-d4aeec9754b4	DIKAMONA	Lydie	l.dikamona@email.ga	077222026	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Louis	Estuaire	Agent Entretien	Entreprise Nettoyage	cdi	350000.00	36	150000.00	72000.00	6.2	578	moyen	280000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
56	1c60bf24-b2d4-43c9-884e-c7d73d67e429	EBANG	Robert	r.ebang@email.ga	077222027	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	PK9	Estuaire	Menuisier	Atelier PrivÃ©	independant	580000.00	54	230000.00	155000.00	7.0	625	moyen	460000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
57	d8e6ebba-0446-4a83-8296-bd1e431a2f26	FILA	Annette	a.fila@email.ga	077222028	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Nzeng-Ayong	Estuaire	Standardiste	SociÃ©tÃ© PrivÃ©e	cdi	420000.00	30	175000.00	95000.00	6.5	595	moyen	340000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
58	b7a9d400-8647-4068-b23f-c0eda90c5dd4	GASSAMA	LÃ©onard	l.gassama@email.ga	077222029	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Batterie IV	Estuaire	Cuisinier	Restaurant Touristique	cdi	510000.00	36	205000.00	125000.00	6.8	612	moyen	410000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
59	b5dba3b0-c8ba-4dc4-ac81-871a26663e0d	HONGUI	Sophie	s.hongui@email.ga	077222030	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Sotega	Estuaire	Vendeuse Boutique	Commerce Local	cdi	390000.00	24	165000.00	85000.00	6.4	588	moyen	310000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
60	5aa235dd-d828-40a6-b159-a88a9f1d8323	ITSOUA	Maxime	m.itsoua@email.ga	077222031	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Akanda II	Estuaire	Magasinier	SociÃ©tÃ© Import	cdi	520000.00	48	210000.00	130000.00	6.9	620	moyen	420000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
61	225a7f0e-d4b9-479b-91b4-8348ac383a34	JIBIA	Rachel	r.jibia@email.ga	077222032	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Bellevue	Estuaire	Animatrice Radio	Radio Locale	cdd	600000.00	30	240000.00	160000.00	7.1	630	moyen	480000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
62	b2ccbad8-20fa-48ec-ac1b-bb1be79c5c3e	KOUMOU	Alphonse	a.koumou@email.ga	077222033	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Franceville	Bel-Air	Haut-OgoouÃ©	Agent Logistique	SociÃ©tÃ© MiniÃ¨re	cdi	680000.00	42	265000.00	185000.00	7.2	640	moyen	540000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
63	0e199d4c-9b0d-4279-90b1-deeba53a3b35	LIBALA	Martine	m.libala@email.ga	077222034	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Toulon	Estuaire	Agent Commercial	Assurance GAB	cdi	620000.00	36	245000.00	155000.00	7.0	628	moyen	500000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
64	75f390e2-820c-4d99-bc91-84d3e4818400	MABIALA	Jacques	j.mabiala@email.ga	077222035	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Port-Gentil	Aviation	OgoouÃ©-Maritime	ContrÃ´leur Bus	SociÃ©tÃ© Transport	cdi	440000.00	48	180000.00	100000.00	6.6	602	moyen	350000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
65	beead6a7-37b7-4ae1-b82e-272892d00c3e	NDAMBA	CÃ©cile	c.ndamba@email.ga	077222036	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	AkÃ©bÃ© Plaine	Estuaire	SecrÃ©taire MÃ©dicale	Cabinet MÃ©dical	cdi	500000.00	42	200000.00	120000.00	6.8	615	moyen	400000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
66	a21752f1-74b5-4e5d-b569-038ac592a2ed	OBANDA	Justin	j.obanda@email.ga	077222037	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	SabliÃ¨re	Estuaire	Technicien Froid	SociÃ©tÃ© Climatisation	independant	620000.00	54	245000.00	165000.00	7.1	632	moyen	500000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
67	393a0528-d6d7-42f1-9c94-5d79ee7cb30c	PAMBOU	Delphine	d.pambou2@email.ga	077222038	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Mont-BouÃ«t	Estuaire	GÃ©rante Boutique	Auto-entrepreneur	independant	550000.00	36	225000.00	140000.00	6.9	620	moyen	440000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
68	83ac54eb-9f61-4475-b2b5-0a07dd074637	QUILLARD	Thomas	t.quillard@email.ga	077222039	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Lalala	Estuaire	Livreur	SociÃ©tÃ© Livraison	cdd	380000.00	18	160000.00	80000.00	6.3	582	moyen	300000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
69	5faa61e8-00a3-4e54-8ece-b6336b8ca27a	ROGOMBE	Jeanne	j.rogombe@email.ga	077222040	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	PK12	Estuaire	Agent Accueil	Clinique PrivÃ©e	cdi	460000.00	30	185000.00	105000.00	6.7	608	moyen	370000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
70	7ee1f98a-98d7-4757-9c4d-6d9eccad2e85	SAMBA BIYO	AndrÃ©	a.sambabiyo@email.ga	077333001	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	AwendjÃ©	Estuaire	Vendeur MarchÃ©	Auto-entrepreneur	independant	280000.00	24	140000.00	120000.00	5.2	480	moyen	220000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
88	6050a3b4-0bdc-4c9a-8f83-67149678b0c8	LOUBAKI	Norbert	n.loubaki@email.ga	077333019	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Mont-BouÃ«t	Estuaire	Chauffeur Moto-Taxi	Auto-entrepreneur	independant	290000.00	36	150000.00	125000.00	5.5	500	moyen	230000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
15	4900b124-e873-40c9-8bcc-990da98fc811	KOUMBA	Ernest	e.koumba@email.ga	077111015	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	PK9	Estuaire	Chef de Service	Gabon Oil	cdi	1550000.00	90	510000.00	0.00	8.6	733	tres_bas	1240000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
16	b562730b-045a-46b9-a1af-e31f168f3f0d	LEKOGO	Sandrine	s.lekogo@email.ga	077111016	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Oloumi	Estuaire	Analyste CrÃ©dit	UGB Gabon	cdi	1150000.00	48	380000.00	120000.00	8.2	703	bas	920000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
17	0f41941e-b303-48ce-a233-95e5f57f892a	MOUNDOUNGA	Victor	v.moundounga@email.ga	077111017	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Mouila	Sangatanga	NgouniÃ©	Entrepreneur BTP	Auto-entrepreneur	independant	1680000.00	72	560000.00	400000.00	8.0	692	bas	1340000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
18	4f7ba791-b2d9-4df0-a178-c29e179fdc91	NZIENGUI	Diane	d.nziengui@email.ga	077111018	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Louis	Estuaire	DRH Adjointe	BGFIBank	cdi	1420000.00	66	470000.00	0.00	8.5	725	bas	1140000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
19	f33d5621-abc2-4d26-8044-16318b6755cc	MAGANGA	Jules	j.maganga@email.ga	077111019	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Charbonnages	Estuaire	Pilote HÃ©licoptÃ¨re	Air Services	cdi	2100000.00	84	700000.00	500000.00	8.1	695	bas	1680000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
72	888fde5c-470e-4af4-b46f-456613ff4660	UROBO	Francis	f.urobo@email.ga	077333003	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	PK8	Estuaire	Aide MaÃ§on	Chantiers	autre	220000.00	18	115000.00	85000.00	4.5	430	eleve	180000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
73	1613cbb6-d2fa-42d4-ae1e-80dae4b134de	VIEIRA	Lucie	l.vieira@email.ga	077333004	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Port-Gentil	CitÃ© Nouvelle	OgoouÃ©-Maritime	Vendeuse Ambulante	Auto-entrepreneur	independant	190000.00	36	100000.00	70000.00	4.6	435	eleve	150000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
74	d51f218a-ad0d-48b9-a7fa-345a5a8f6a61	WAMBA	Pierre	p.wamba@email.ga	077333005	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Okala	Estuaire	Gardien	Immeuble PrivÃ©	autre	240000.00	30	125000.00	95000.00	4.9	455	eleve	190000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
75	de498184-e122-4a6a-b57d-69bef906179c	YAYI	Georgette	g.yayi@email.ga	077333006	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Alibandeng	Estuaire	Vendeuse Poisson	MarchÃ© Local	independant	210000.00	48	110000.00	80000.00	5.0	460	moyen	170000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
91	af9d28ce-4959-47b7-9142-370625fd580e	OBAME	Marguerite	m.obame2@email.ga	077444002	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	AwendjÃ©	Estuaire	Petits Boulots	Occasionnel	autre	95000.00	3	65000.00	110000.00	2.8	320	tres_eleve	0.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
71	7296a9cc-08d1-4249-b819-628159ef093a	TCHOUMBA	Marie	m.tchoumba@email.ga	077333002	$2a$06$ypNlITeuSLCZL6Ro3m1Jr.S9LcKnI0lGjh6jk.NxarZt4GrwQabnG	Libreville	Nzeng-Ayong	Estuaire	MÃ©nagÃ¨re	Particuliers	autre	180000.00	12	95000.00	60000.00	4.8	450	eleve	140000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:30:48.773926	\N
20	0a1469a4-d13d-46db-a289-9f7bed82e37b	OVONO	Laurence	l.ovono@email.ga	077111020	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Centre-Ville	Estuaire	Notaire	Ã‰tude Notariale	independant	1750000.00	96	580000.00	0.00	8.8	748	tres_bas	1400000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
21	19013eda-1a4e-47a0-bc4f-c3ad58eafb07	BOUASSA	Raymond	r.bouassa@email.ga	077111021	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Port-Gentil	Nouveau Port	OgoouÃ©-Maritime	Superviseur Offshore	Schlumberger	cdi	1880000.00	72	620000.00	280000.00	8.4	718	bas	1500000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
22	7c52a721-210c-4450-872a-672c4f785f87	LENDOYE	Odette	o.lendoye@email.ga	077111022	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Atong Abe	Estuaire	Responsable Marketing	Total Gabon	cdi	1320000.00	54	440000.00	0.00	8.3	710	bas	1060000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
23	11e6fd36-0b76-46b5-b242-e846667c5fca	NGOMA	Thierry	t.ngoma@email.ga	077111023	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Sotega	Estuaire	IngÃ©nieur RÃ©seau	Airtel Gabon	cdi	1480000.00	60	490000.00	150000.00	8.5	728	bas	1180000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
48	3e5f44d4-e112-41a6-82a9-e5900af2c308	VIDJABO	Paul	p.vidjabo@email.ga	077222019	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Oyem	Centre	Woleu-Ntem	Chauffeur Taxi	Auto-entrepreneur	independant	520000.00	48	210000.00	130000.00	6.8	615	moyen	420000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
89	3595035e-f82a-4642-9302-5bb369dcaa79	MABIKA	Colette	c.mabika@email.ga	077333020	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Bellevue	Estuaire	Vendeuse Tissu	MarchÃ©	independant	220000.00	42	115000.00	88000.00	5.1	472	moyen	175000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
90	7f2d2604-4149-426d-a751-c7424dacbdd2	NDOUMBA	Jacques	j.ndoumba@email.ga	077444001	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Nzeng-Ayong	Estuaire	Sans Emploi	Aucun	autre	120000.00	0	75000.00	95000.00	3.2	350	tres_eleve	0.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
4	434fc68d-b4ba-415e-a357-b2831d4cdc3a	MINTSA	Sylvie	s.mintsa@email.ga	077111004	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Port-Gentil	CitÃ©	OgoouÃ©-Maritime	Comptable Senior	Perenco	cdi	1200000.00	84	400000.00	0.00	8.7	740	tres_bas	1000000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
5	c87286b2-bbb4-475b-91e3-8d206dfb270a	ONDO	FranÃ§ois	f.ondo@email.ga	077111005	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Lalala	Estuaire	MÃ©decin	Centre Hospitalier	fonctionnaire	2000000.00	120	700000.00	300000.00	8.3	710	bas	1600000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
6	deaf0d6c-d2ae-46dc-bfca-e80038b79a42	MOUSSAVOU	Georgette	g.moussavou@email.ga	077111006	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Franceville	Potos	Haut-OgoouÃ©	Pharmacienne	Pharmacie Centrale	independant	1400000.00	48	450000.00	150000.00	8.6	730	bas	1100000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
7	4689618f-5f91-4b45-8f94-5a529706b185	BOULINGUI	Marcel	m.boulingui@email.ga	077111007	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Akanda	Estuaire	Avocat	Cabinet Juridique	independant	1900000.00	60	650000.00	0.00	8.8	745	tres_bas	1550000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
8	495650e4-a831-443e-a4f0-bd2e5385faf3	NZAMBA	Christelle	c.nzamba@email.ga	077111008	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Mont-BouÃ«t	Estuaire	Chef de Projet	MinistÃ¨re Ã‰conomie	fonctionnaire	1100000.00	72	380000.00	100000.00	8.4	715	bas	900000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
9	202759cd-28f9-40a2-8397-43b654235e88	EYEGHE	Antoine	a.eyeghe@email.ga	077111009	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Okala	Estuaire	Architecte	Bureau Ã‰tudes	cdi	1600000.00	54	520000.00	250000.00	8.2	705	bas	1300000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
10	41b10cfc-e34d-4539-909c-ff2ab60e89f3	NDONG BEKALE	Pauline	p.ndongbekale@email.ga	077111010	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Port-Gentil	Quartier Basse	OgoouÃ©-Maritime	IngÃ©nieur Logistique	BollorÃ©	cdi	1350000.00	66	440000.00	0.00	8.7	738	tres_bas	1080000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
11	327e4b62-8190-42d3-bebd-4aba3e5b84e7	IVANGA	Rodrigue	r.ivanga@email.ga	077111011	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Nzeng-Ayong	Estuaire	ContrÃ´leur Financier	Assala Energy	cdi	1450000.00	78	480000.00	0.00	8.9	752	tres_bas	1160000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
12	c8e0f660-b369-4796-87bb-9fa6903ff8c2	MASSALA	Henriette	h.massala@email.ga	077111012	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Alibandeng	Estuaire	Professeur UniversitÃ©	UniversitÃ© Omar Bongo	fonctionnaire	950000.00	144	320000.00	0.00	8.1	698	bas	760000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
33	189444ee-debe-4784-bdae-af2de06d7518	ENGONE	LÃ©on	l.engone@email.ga	077222003	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Mont-BouÃ«t	Estuaire	Commercial	Orange Gabon	cdi	750000.00	30	280000.00	220000.00	7.0	625	moyen	600000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
34	0acf9a99-9efc-4a1b-9793-e825b20272f6	FOGUE	Roseline	r.fogue@email.ga	077222004	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Port-Gentil	Madagascar	OgoouÃ©-Maritime	Agent Administratif	Mairie Port-Gentil	fonctionnaire	480000.00	60	190000.00	120000.00	6.9	618	moyen	380000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
35	024a91ca-1be3-4848-873e-6b15bc44375d	GANDZIAMI	Prosper	p.gandziami@email.ga	077222005	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Sibang	Estuaire	Chauffeur Poids Lourds	SETRAG	cdi	620000.00	42	240000.00	150000.00	7.1	632	moyen	500000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
36	6a828c4e-2475-416b-a5da-84d511456e71	IKAPI	Blaise	b.ikapi@email.ga	077222007	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Okala	Estuaire	Ã‰lectricien	Gabon Ã‰lectricitÃ©	cdi	640000.00	36	240000.00	160000.00	6.9	620	moyen	510000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
37	c2500423-12e8-43a7-aba4-b22dbc4de280	KAYA	Ã‰lise	e.kaya@email.ga	077222008	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	NombakÃ©LÃ©	Estuaire	Assistante Comptable	PME Locale	cdd	550000.00	24	210000.00	130000.00	6.7	605	moyen	440000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
38	4d971ae3-3510-495c-9b4d-43c2bc173c33	LEBIGUI	ArsÃ¨ne	a.lebigui@email.ga	077222009	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Franceville	Ogoua	Haut-OgoouÃ©	Agent de MaÃ®trise	Comilog	cdi	720000.00	48	270000.00	190000.00	7.2	638	moyen	580000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
39	f9535327-658b-426c-aa0b-2f266f856a8d	MAKOSSO	JosÃ©phine	j.makosso@email.ga	077222010	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Batterie IV	Estuaire	Vendeuse	SupermarchÃ© Score	cdi	480000.00	30	190000.00	110000.00	6.6	598	moyen	380000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
40	84f80da2-c509-4609-aa7e-ead6f06272e4	NANG	Bernard	b.nang@email.ga	077222011	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	AwendjÃ©	Estuaire	Plombier	Auto-entrepreneur	independant	590000.00	60	230000.00	150000.00	7.0	628	moyen	470000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
41	10f26ff8-56ce-4c52-b66b-9a2b58d42e08	OBIANG	Fernande	f.obiang@email.ga	077222012	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Glass	Estuaire	Enseignante Primaire	Ã‰ducation Nationale	fonctionnaire	650000.00	72	250000.00	170000.00	7.3	642	moyen	520000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
99	fab13cf6-dae0-48cb-8ed7-0e09a8764e05	WORA	Lucie	l.wora@email.ga	077444010	$2a$06$OUnRmNePFa14LDzMj/h6q.mxyVGcdBeQf98F6MBOJIqbvEJeBNrXC	Libreville	Batterie IV	Estuaire	Aide Occasionnelle	Sans Revenu	autre	85000.00	5	58000.00	88000.00	2.6	310	tres_eleve	0.00	actif	2025-10-02 08:01:52.723422	2025-10-08 23:03:13.60093	2025-10-08 23:03:13.60093
76	0a99aff2-11b8-475d-b4a2-34de12b18d1c	ZIGHA	Samuel	s.zigha@email.ga	077333007	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Sibang	Estuaire	Apprenti Ã‰lectricien	Formation	autre	160000.00	6	90000.00	50000.00	4.3	415	eleve	130000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
77	8a2a8760-3f88-40d4-b9c1-7d8450288440	ABAGA	Solange	s.abaga@email.ga	077333008	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Ancien Chantier	Estuaire	Revendeuse	Commerce Informel	independant	200000.00	24	105000.00	75000.00	4.7	440	eleve	160000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
78	f6e15fef-c385-43e6-b942-2c96093faae1	BIVIGOU	Ã‰tienne	e.bivigou@email.ga	077333009	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Charbonnages	Estuaire	ManÅ“uvre	SociÃ©tÃ© BTP	cdd	250000.00	12	130000.00	100000.00	5.1	470	moyen	200000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
79	0528ce7e-bf0b-487d-a21e-1874b338eebd	COMLAN	Ã‰milienne	e.comlan@email.ga	077333010	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Batterie IV	Estuaire	CouturiÃ¨re	Atelier Couture	independant	230000.00	36	120000.00	90000.00	5.0	465	moyen	180000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
80	0d95cb46-35cb-4854-a26a-7409c8e15bc2	DEMBA	Julien	j.demba@email.ga	077333011	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	AkÃ©bÃ©	Estuaire	Apprenti MÃ©canicien	Garage Local	autre	170000.00	8	92000.00	55000.00	4.4	420	eleve	140000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
81	bb786a4e-d216-4797-8f27-94b730ca0523	ESSONE	Paulette	p.essone@email.ga	077333012	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Oloumi	Estuaire	Agent Entretien	SociÃ©tÃ© Nettoyage	cdd	260000.00	18	135000.00	105000.00	5.3	485	moyen	210000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
82	0b1588d4-5120-46e5-b431-81cec7ddc905	FOUNDOU	CÃ©sar	c.foundou@email.ga	077333013	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Louis	Estuaire	Laveur Voitures	Auto-entrepreneur	independant	185000.00	30	98000.00	68000.00	4.6	438	eleve	150000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
83	f861daed-bae7-4b05-89db-6c5b51115eed	GOMA	Sylvie	s.goma@email.ga	077333014	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Sotega	Estuaire	Aide CuisiniÃ¨re	Restaurant	autre	195000.00	12	102000.00	72000.00	4.7	442	eleve	155000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
84	a12dd9fb-69c0-4565-a960-3d4a1e639205	HOUSSOU	Raoul	r.houssou@email.ga	077333015	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Port-Gentil	Basse-Pointe	OgoouÃ©-Maritime	PÃªcheur	Auto-entrepreneur	independant	270000.00	48	140000.00	110000.00	5.4	495	moyen	220000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
85	1d8d2f75-f3d6-4096-9fcc-62fcf9d579dc	IBAKA	Nadine	n.ibaka@email.ga	077333016	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Akanda	Estuaire	CaissiÃ¨re Buvette	Petit Commerce	autre	175000.00	18	93000.00	58000.00	4.5	428	eleve	140000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
86	009b9b4e-0ab9-4b3d-ba21-6f6d1a06246e	JOCKTANE	Albert	a.jocktane@email.ga	077333017	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	PK5	Estuaire	Plongeur Restaurant	Restaurant Local	autre	155000.00	10	88000.00	48000.00	4.2	410	eleve	125000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
87	495d0b46-9f60-4de1-95b0-1513d5840eb5	KOUMBA	Hortense	h.koumba@email.ga	077333018	$2b$10$rBV2uGjHv3vQvRtEZ2H.O.7L7V7WQV2.fPXGPcH2WXdPXY.3BZY4W	Libreville	Nzeng-Ayong	Estuaire	Repasseuse	Pressing Quartier	independant	205000.00	24	108000.00	78000.00	4.8	448	eleve	165000.00	actif	2025-10-02 08:01:52.723422	2025-10-06 18:24:02.653148	\N
\.


--
-- Name: credits_enregistres_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.credits_enregistres_id_seq', 455, true);


--
-- Name: demandes_credit_longues_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.demandes_credit_longues_id_seq', 92, true);


--
-- Name: historique_paiements_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.historique_paiements_id_seq', 898, true);


--
-- Name: historique_scores_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.historique_scores_id_seq', 1906, true);


--
-- Name: restrictions_credit_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.restrictions_credit_id_seq', 106, true);


--
-- Name: utilisateurs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.utilisateurs_id_seq', 101, true);


--
-- Name: credits_enregistres credits_enregistres_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.credits_enregistres
    ADD CONSTRAINT credits_enregistres_pkey PRIMARY KEY (id);


--
-- Name: demandes_credit_longues_comments demandes_credit_longues_comments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.demandes_credit_longues_comments
    ADD CONSTRAINT demandes_credit_longues_comments_pkey PRIMARY KEY (id);


--
-- Name: demandes_credit_longues_documents demandes_credit_longues_documents_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.demandes_credit_longues_documents
    ADD CONSTRAINT demandes_credit_longues_documents_pkey PRIMARY KEY (id);


--
-- Name: demandes_credit_longues_history demandes_credit_longues_history_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.demandes_credit_longues_history
    ADD CONSTRAINT demandes_credit_longues_history_pkey PRIMARY KEY (id);


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
-- Name: idx_comments_longues_request; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_comments_longues_request ON public.demandes_credit_longues_comments USING btree (long_credit_request_id);


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
-- Name: idx_demandes_longues_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_demandes_longues_date ON public.demandes_credit_longues USING btree (date_soumission);


--
-- Name: idx_demandes_longues_statut; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_demandes_longues_statut ON public.demandes_credit_longues USING btree (statut);


--
-- Name: idx_demandes_longues_utilisateur; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_demandes_longues_utilisateur ON public.demandes_credit_longues USING btree (utilisateur_id);


--
-- Name: idx_documents_longues_request; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_documents_longues_request ON public.demandes_credit_longues_documents USING btree (long_credit_request_id);


--
-- Name: idx_history_longues_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_history_longues_date ON public.demandes_credit_longues_history USING btree (action_date DESC);


--
-- Name: idx_history_longues_request; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_history_longues_request ON public.demandes_credit_longues_history USING btree (long_credit_request_id);


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
-- Name: demandes_credit_longues trigger_update_demande_longue; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_update_demande_longue BEFORE UPDATE ON public.demandes_credit_longues FOR EACH ROW EXECUTE FUNCTION public.update_demande_longue_modification();


--
-- Name: credits_enregistres credits_enregistres_utilisateur_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.credits_enregistres
    ADD CONSTRAINT credits_enregistres_utilisateur_id_fkey FOREIGN KEY (utilisateur_id) REFERENCES public.utilisateurs(id) ON DELETE CASCADE;


--
-- Name: demandes_credit_longues_comments demandes_credit_longues_comments_long_credit_request_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.demandes_credit_longues_comments
    ADD CONSTRAINT demandes_credit_longues_comments_long_credit_request_id_fkey FOREIGN KEY (long_credit_request_id) REFERENCES public.demandes_credit_longues(id) ON DELETE CASCADE;


--
-- Name: demandes_credit_longues demandes_credit_longues_decideur_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.demandes_credit_longues
    ADD CONSTRAINT demandes_credit_longues_decideur_id_fkey FOREIGN KEY (decideur_id) REFERENCES public.utilisateurs(id);


--
-- Name: demandes_credit_longues_documents demandes_credit_longues_documents_long_credit_request_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.demandes_credit_longues_documents
    ADD CONSTRAINT demandes_credit_longues_documents_long_credit_request_id_fkey FOREIGN KEY (long_credit_request_id) REFERENCES public.demandes_credit_longues(id) ON DELETE CASCADE;


--
-- Name: demandes_credit_longues_history demandes_credit_longues_history_long_credit_request_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.demandes_credit_longues_history
    ADD CONSTRAINT demandes_credit_longues_history_long_credit_request_id_fkey FOREIGN KEY (long_credit_request_id) REFERENCES public.demandes_credit_longues(id) ON DELETE CASCADE;


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

