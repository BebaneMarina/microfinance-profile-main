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
-- Name: credit_type; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.credit_type AS ENUM (
    'consommation_generale',
    'avance_salaire',
    'depannage',
    'investissement',
    'avance_facture',
    'avance_commande',
    'tontine',
    'retraite',
    'spot'
);


ALTER TYPE public.credit_type OWNER TO postgres;

--
-- Name: document_type; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.document_type AS ENUM (
    'identity',
    'salary_slip',
    'employment_certificate',
    'bank_statement',
    'utility_bill',
    'debt_certificate',
    'other'
);


ALTER TYPE public.document_type OWNER TO postgres;

--
-- Name: payment_status; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.payment_status AS ENUM (
    'pending',
    'paid',
    'partial',
    'overdue',
    'defaulted'
);


ALTER TYPE public.payment_status OWNER TO postgres;

--
-- Name: request_status; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.request_status AS ENUM (
    'draft',
    'submitted',
    'in_review',
    'approved',
    'rejected',
    'cancelled',
    'disbursed',
    'completed'
);


ALTER TYPE public.request_status OWNER TO postgres;

--
-- Name: risk_level; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.risk_level AS ENUM (
    'very_low',
    'low',
    'medium',
    'high',
    'very_high'
);


ALTER TYPE public.risk_level OWNER TO postgres;

--
-- Name: user_role; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.user_role AS ENUM (
    'admin',
    'agent',
    'client',
    'super_admin'
);


ALTER TYPE public.user_role OWNER TO postgres;

--
-- Name: user_status; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.user_status AS ENUM (
    'active',
    'inactive',
    'suspended',
    'deleted'
);


ALTER TYPE public.user_status OWNER TO postgres;

--
-- Name: generate_contract_number(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.generate_contract_number() RETURNS character varying
    LANGUAGE plpgsql
    AS $$
DECLARE
    new_number VARCHAR;
BEGIN
    new_number := 'CTR-' || TO_CHAR(CURRENT_DATE, 'YYYYMMDD') || '-' || 
                  LPAD(nextval('loan_contracts_id_seq')::text, 6, '0');
    RETURN new_number;
END;
$$;


ALTER FUNCTION public.generate_contract_number() OWNER TO postgres;

--
-- Name: generate_request_number(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.generate_request_number() RETURNS character varying
    LANGUAGE plpgsql
    AS $$
DECLARE
    new_number VARCHAR;
BEGIN
    new_number := 'REQ-' || TO_CHAR(CURRENT_DATE, 'YYYYMMDD') || '-' || 
                  LPAD(nextval('credit_requests_id_seq')::text, 6, '0');
    RETURN new_number;
END;
$$;


ALTER FUNCTION public.generate_request_number() OWNER TO postgres;

--
-- Name: get_user_id(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_user_id(p_email character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_id INTEGER;
BEGIN
    SELECT id INTO v_id FROM users WHERE email = p_email;
    RETURN v_id;
END;
$$;


ALTER FUNCTION public.get_user_id(p_email character varying) OWNER TO postgres;

--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_updated_at_column() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: audit_logs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.audit_logs (
    id integer NOT NULL,
    user_id integer,
    action character varying(100) NOT NULL,
    module character varying(50) NOT NULL,
    entity_type character varying(50),
    entity_id integer,
    changes jsonb,
    ip_address inet,
    user_agent text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.audit_logs OWNER TO postgres;

--
-- Name: audit_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.audit_logs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.audit_logs_id_seq OWNER TO postgres;

--
-- Name: audit_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.audit_logs_id_seq OWNED BY public.audit_logs.id;


--
-- Name: credit_requests; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.credit_requests (
    id integer NOT NULL,
    request_number character varying(50) NOT NULL,
    user_id integer NOT NULL,
    credit_type public.credit_type NOT NULL,
    status public.request_status DEFAULT 'draft'::public.request_status,
    requested_amount numeric(12,2) NOT NULL,
    approved_amount numeric(12,2),
    duration_months integer NOT NULL,
    interest_rate numeric(5,2),
    purpose text NOT NULL,
    repayment_mode character varying(50),
    repayment_frequency character varying(50),
    liquidity_problem text,
    urgency_justification text,
    solutions_envisaged text,
    cash_flow_status character varying(50),
    credit_score integer,
    risk_level public.risk_level,
    probability numeric(5,2),
    decision character varying(50),
    decision_date timestamp without time zone,
    decision_by integer,
    decision_notes text,
    kyc_verified boolean DEFAULT false,
    kyc_verified_date timestamp without time zone,
    kyc_verified_by integer,
    disbursement_date timestamp without time zone,
    disbursement_method character varying(50),
    disbursement_reference character varying(100),
    submission_date timestamp without time zone,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_amounts CHECK ((requested_amount > (0)::numeric)),
    CONSTRAINT chk_duration CHECK ((duration_months > 0))
);


ALTER TABLE public.credit_requests OWNER TO postgres;

--
-- Name: credit_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.credit_requests_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.credit_requests_id_seq OWNER TO postgres;

--
-- Name: credit_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.credit_requests_id_seq OWNED BY public.credit_requests.id;


--
-- Name: credit_scoring; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.credit_scoring (
    id integer NOT NULL,
    credit_request_id integer,
    user_id integer NOT NULL,
    total_score integer NOT NULL,
    risk_level public.risk_level NOT NULL,
    probability numeric(5,2),
    decision character varying(50),
    income_score integer,
    employment_score integer,
    debt_ratio_score integer,
    credit_history_score integer,
    behavioral_score integer,
    factors jsonb,
    recommendations text[],
    model_version character varying(50),
    processing_time numeric(5,2),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    created_by integer
);


ALTER TABLE public.credit_scoring OWNER TO postgres;

--
-- Name: credit_scoring_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.credit_scoring_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.credit_scoring_id_seq OWNER TO postgres;

--
-- Name: credit_scoring_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.credit_scoring_id_seq OWNED BY public.credit_scoring.id;


--
-- Name: credit_simulations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.credit_simulations (
    id integer NOT NULL,
    user_id integer,
    client_type character varying(50),
    credit_type character varying(50),
    monthly_income numeric(12,2),
    requested_amount numeric(12,2),
    duration_months integer,
    monthly_payment numeric(12,2),
    total_amount numeric(12,2),
    interest_rate numeric(5,2),
    total_interest numeric(12,2),
    is_eligible boolean,
    max_borrowing_capacity numeric(12,2),
    recommendations jsonb,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    ip_address inet,
    user_agent text
);


ALTER TABLE public.credit_simulations OWNER TO postgres;

--
-- Name: credit_simulations_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.credit_simulations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.credit_simulations_id_seq OWNER TO postgres;

--
-- Name: credit_simulations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.credit_simulations_id_seq OWNED BY public.credit_simulations.id;


--
-- Name: loan_contracts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.loan_contracts (
    id integer NOT NULL,
    contract_number character varying(50) NOT NULL,
    credit_request_id integer,
    user_id integer NOT NULL,
    loan_amount numeric(12,2) NOT NULL,
    interest_rate numeric(5,2) NOT NULL,
    duration_months integer NOT NULL,
    monthly_payment numeric(12,2) NOT NULL,
    total_amount numeric(12,2) NOT NULL,
    total_interest numeric(12,2) NOT NULL,
    start_date date NOT NULL,
    end_date date NOT NULL,
    first_payment_date date NOT NULL,
    status character varying(50) DEFAULT 'active'::character varying,
    early_settlement_date date,
    early_settlement_amount numeric(12,2),
    signed_date timestamp without time zone,
    signature_method character varying(50),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.loan_contracts OWNER TO postgres;

--
-- Name: loan_contracts_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.loan_contracts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.loan_contracts_id_seq OWNER TO postgres;

--
-- Name: loan_contracts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.loan_contracts_id_seq OWNED BY public.loan_contracts.id;


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.notifications (
    id integer NOT NULL,
    user_id integer NOT NULL,
    type character varying(50) NOT NULL,
    title character varying(255) NOT NULL,
    message text NOT NULL,
    channel character varying(50) DEFAULT 'in_app'::character varying,
    is_read boolean DEFAULT false,
    read_at timestamp without time zone,
    reference_type character varying(50),
    reference_id integer,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    sent_at timestamp without time zone
);


ALTER TABLE public.notifications OWNER TO postgres;

--
-- Name: notifications_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.notifications_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.notifications_id_seq OWNER TO postgres;

--
-- Name: notifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.notifications_id_seq OWNED BY public.notifications.id;


--
-- Name: payments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.payments (
    id integer NOT NULL,
    payment_reference character varying(100) NOT NULL,
    loan_contract_id integer NOT NULL,
    repayment_schedule_id integer,
    user_id integer NOT NULL,
    amount numeric(12,2) NOT NULL,
    payment_date timestamp without time zone NOT NULL,
    payment_method character varying(50) NOT NULL,
    principal_paid numeric(12,2),
    interest_paid numeric(12,2),
    late_fee_paid numeric(12,2),
    transaction_id character varying(100),
    transaction_status character varying(50),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    created_by integer
);


ALTER TABLE public.payments OWNER TO postgres;

--
-- Name: payments_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.payments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.payments_id_seq OWNER TO postgres;

--
-- Name: payments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.payments_id_seq OWNED BY public.payments.id;


--
-- Name: repayment_schedule; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.repayment_schedule (
    id integer NOT NULL,
    loan_contract_id integer NOT NULL,
    payment_number integer NOT NULL,
    due_date date NOT NULL,
    principal_amount numeric(12,2) NOT NULL,
    interest_amount numeric(12,2) NOT NULL,
    total_amount numeric(12,2) NOT NULL,
    remaining_balance numeric(12,2) NOT NULL,
    status public.payment_status DEFAULT 'pending'::public.payment_status,
    paid_date timestamp without time zone,
    paid_amount numeric(12,2),
    days_overdue integer DEFAULT 0,
    late_fee numeric(12,2) DEFAULT 0,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.repayment_schedule OWNER TO postgres;

--
-- Name: repayment_schedule_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.repayment_schedule_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.repayment_schedule_id_seq OWNER TO postgres;

--
-- Name: repayment_schedule_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.repayment_schedule_id_seq OWNED BY public.repayment_schedule.id;


--
-- Name: user_sessions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_sessions (
    id integer NOT NULL,
    user_id integer NOT NULL,
    session_token character varying(255) NOT NULL,
    refresh_token character varying(255),
    ip_address inet,
    user_agent text,
    device_info jsonb,
    expires_at timestamp without time zone NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    last_activity timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.user_sessions OWNER TO postgres;

--
-- Name: user_sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.user_sessions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.user_sessions_id_seq OWNER TO postgres;

--
-- Name: user_sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.user_sessions_id_seq OWNED BY public.user_sessions.id;


--
-- Name: user_settings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_settings (
    id integer NOT NULL,
    user_id integer NOT NULL,
    notification_preferences jsonb DEFAULT '{"credits": {"sms": false, "push": true, "email": true}, "security": {"sms": true, "push": true, "email": true}, "marketing": {"sms": false, "push": false, "email": false}, "transactions": {"sms": true, "push": true, "email": true}}'::jsonb,
    theme character varying(20) DEFAULT 'light'::character varying,
    date_format character varying(20) DEFAULT 'DD/MM/YYYY'::character varying,
    session_timeout integer DEFAULT 30,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.user_settings OWNER TO postgres;

--
-- Name: user_settings_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.user_settings_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.user_settings_id_seq OWNER TO postgres;

--
-- Name: user_settings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.user_settings_id_seq OWNED BY public.user_settings.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id integer NOT NULL,
    uuid uuid DEFAULT public.uuid_generate_v4(),
    email character varying(255) NOT NULL,
    password_hash character varying(255) NOT NULL,
    first_name character varying(100) NOT NULL,
    last_name character varying(100) NOT NULL,
    middle_name character varying(100),
    phone_number character varying(20),
    phone_number2 character varying(20),
    role public.user_role DEFAULT 'client'::public.user_role,
    status public.user_status DEFAULT 'active'::public.user_status,
    birth_date date,
    birth_place character varying(255),
    nationality character varying(100),
    gender character varying(10),
    marital_status character varying(20),
    dependents integer DEFAULT 0,
    address text,
    city character varying(100),
    district character varying(100),
    country character varying(100) DEFAULT 'Gabon'::character varying,
    identity_type character varying(50),
    identity_number character varying(100),
    identity_issue_date date,
    identity_expiry_date date,
    profession character varying(255),
    employer_name character varying(255),
    employment_status character varying(50),
    monthly_income numeric(12,2),
    work_experience integer,
    language character varying(10) DEFAULT 'fr'::character varying,
    currency character varying(10) DEFAULT 'XAF'::character varying,
    two_factor_enabled boolean DEFAULT false,
    biometric_enabled boolean DEFAULT false,
    last_login_at timestamp without time zone,
    last_login_ip inet,
    failed_login_attempts integer DEFAULT 0,
    locked_until timestamp without time zone,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    created_by integer,
    updated_by integer
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.users_id_seq OWNER TO postgres;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: v_credit_requests_dashboard; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_credit_requests_dashboard AS
 SELECT cr.id,
    cr.request_number,
    cr.credit_type,
    cr.status,
    cr.requested_amount,
    cr.approved_amount,
    cr.duration_months,
    cr.credit_score,
    cr.risk_level,
    cr.submission_date,
    u.id AS user_id,
    (((u.first_name)::text || ' '::text) || (u.last_name)::text) AS full_name,
    u.email,
    u.phone_number
   FROM (public.credit_requests cr
     JOIN public.users u ON ((cr.user_id = u.id)));


ALTER VIEW public.v_credit_requests_dashboard OWNER TO postgres;

--
-- Name: v_repayment_tracking; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_repayment_tracking AS
 SELECT rs.id,
    rs.loan_contract_id,
    rs.payment_number,
    rs.due_date,
    rs.total_amount,
    rs.status,
    rs.days_overdue,
    lc.contract_number,
    u.id AS user_id,
    (((u.first_name)::text || ' '::text) || (u.last_name)::text) AS full_name,
    u.email,
    u.phone_number
   FROM ((public.repayment_schedule rs
     JOIN public.loan_contracts lc ON ((rs.loan_contract_id = lc.id)))
     JOIN public.users u ON ((lc.user_id = u.id)))
  WHERE (rs.status <> 'paid'::public.payment_status);


ALTER VIEW public.v_repayment_tracking OWNER TO postgres;

--
-- Name: audit_logs id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.audit_logs ALTER COLUMN id SET DEFAULT nextval('public.audit_logs_id_seq'::regclass);


--
-- Name: credit_requests id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.credit_requests ALTER COLUMN id SET DEFAULT nextval('public.credit_requests_id_seq'::regclass);


--
-- Name: credit_scoring id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.credit_scoring ALTER COLUMN id SET DEFAULT nextval('public.credit_scoring_id_seq'::regclass);


--
-- Name: credit_simulations id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.credit_simulations ALTER COLUMN id SET DEFAULT nextval('public.credit_simulations_id_seq'::regclass);


--
-- Name: loan_contracts id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loan_contracts ALTER COLUMN id SET DEFAULT nextval('public.loan_contracts_id_seq'::regclass);


--
-- Name: notifications id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notifications ALTER COLUMN id SET DEFAULT nextval('public.notifications_id_seq'::regclass);


--
-- Name: payments id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payments ALTER COLUMN id SET DEFAULT nextval('public.payments_id_seq'::regclass);


--
-- Name: repayment_schedule id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.repayment_schedule ALTER COLUMN id SET DEFAULT nextval('public.repayment_schedule_id_seq'::regclass);


--
-- Name: user_sessions id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_sessions ALTER COLUMN id SET DEFAULT nextval('public.user_sessions_id_seq'::regclass);


--
-- Name: user_settings id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_settings ALTER COLUMN id SET DEFAULT nextval('public.user_settings_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Data for Name: audit_logs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.audit_logs (id, user_id, action, module, entity_type, entity_id, changes, ip_address, user_agent, created_at) FROM stdin;
\.


--
-- Data for Name: credit_requests; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.credit_requests (id, request_number, user_id, credit_type, status, requested_amount, approved_amount, duration_months, interest_rate, purpose, repayment_mode, repayment_frequency, liquidity_problem, urgency_justification, solutions_envisaged, cash_flow_status, credit_score, risk_level, probability, decision, decision_date, decision_by, decision_notes, kyc_verified, kyc_verified_date, kyc_verified_by, disbursement_date, disbursement_method, disbursement_reference, submission_date, created_at, updated_at) FROM stdin;
6	REQ-20240715-000001	3	consommation_generale	approved	500000.00	500000.00	12	0.05	Achat d'Ã©quipement Ã©lectromÃ©nager	mensuel	mensuel	\N	\N	\N	\N	8	low	0.85	approuvÃ©	\N	\N	\N	f	\N	\N	\N	\N	\N	2024-07-15 10:30:00	2024-07-15 10:30:00	2025-07-25 13:01:23.209457
7	REQ-20240720-000002	5	avance_salaire	in_review	200000.00	\N	1	0.03	Avance sur salaire pour frais mÃ©dicaux	fin_du_mois	fin_du_mois	\N	\N	\N	\N	5	medium	0.65	Ã  Ã©tudier	\N	\N	\N	f	\N	\N	\N	\N	\N	2024-07-20 14:45:00	2024-07-20 14:45:00	2025-07-25 13:01:23.209457
8	REQ-20240710-000003	6	depannage	rejected	300000.00	\N	1	0.04	DÃ©pannage pour paiement de loyer	fin_du_mois	fin_du_mois	\N	\N	\N	\N	3	high	0.35	refusÃ©	\N	\N	\N	f	\N	\N	\N	\N	\N	2024-07-10 09:15:00	2024-07-10 09:15:00	2025-07-25 13:01:23.209457
9	REQ-20240705-000004	7	consommation_generale	approved	1000000.00	1000000.00	24	0.05	Achat de mobilier pour la maison	mensuel	mensuel	\N	\N	\N	\N	9	very_low	0.95	approuvÃ©	\N	\N	\N	f	\N	\N	\N	\N	\N	2024-07-05 11:20:00	2024-07-05 11:20:00	2025-07-25 13:01:23.209457
10	REQ-20240718-000005	8	avance_salaire	rejected	100000.00	\N	1	0.03	Avance sur salaire pour frais scolaires	fin_du_mois	fin_du_mois	\N	\N	\N	\N	2	very_high	0.25	refusÃ©	\N	\N	\N	f	\N	\N	\N	\N	\N	2024-07-18 16:30:00	2024-07-18 16:30:00	2025-07-25 13:01:23.209457
\.


--
-- Data for Name: credit_scoring; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.credit_scoring (id, credit_request_id, user_id, total_score, risk_level, probability, decision, income_score, employment_score, debt_ratio_score, credit_history_score, behavioral_score, factors, recommendations, model_version, processing_time, created_at, created_by) FROM stdin;
6	6	3	8	low	0.85	approuvÃ©	9	8	8	7	\N	[{"name": "monthly_income", "value": 90, "impact": 3}, {"name": "employment_status", "value": 90, "impact": 2}, {"name": "job_seniority", "value": 80, "impact": 2}, {"name": "debt_ratio", "value": 85, "impact": 3}]	{"Excellent profil ! Vous Ãªtes Ã©ligible aux meilleures conditions","Votre quotitÃ© cessible vous permet d'emprunter jusqu'Ã  3 600 000 FCFA"}	quotite_cessible_v1.0	0.35	2025-07-25 13:01:23.209457	\N
7	7	5	5	medium	0.65	Ã  Ã©tudier	6	7	5	5	\N	[{"name": "monthly_income", "value": 60, "impact": 2}, {"name": "employment_status", "value": 70, "impact": 2}, {"name": "job_seniority", "value": 50, "impact": 1}, {"name": "debt_ratio", "value": 50, "impact": 1}]	{"Bon profil. Maintenir votre situation actuelle","Votre quotitÃ© cessible vous permet d'emprunter jusqu'Ã  900 000 FCFA"}	quotite_cessible_v1.0	0.42	2025-07-25 13:01:23.209457	\N
8	8	6	3	high	0.35	refusÃ©	4	5	2	3	\N	[{"name": "monthly_income", "value": 40, "impact": 1}, {"name": "employment_status", "value": 50, "impact": 1}, {"name": "job_seniority", "value": 60, "impact": 1}, {"name": "debt_ratio", "value": 20, "impact": -2}]	{"RÃ©duire vos dettes existantes pour amÃ©liorer votre quotitÃ© cessible disponible","Augmenter vos revenus mensuels amÃ©liorerait votre score"}	quotite_cessible_v1.0	0.38	2025-07-25 13:01:23.209457	\N
9	9	7	9	very_low	0.95	approuvÃ©	10	9	9	8	\N	[{"name": "monthly_income", "value": 100, "impact": 3}, {"name": "employment_status", "value": 90, "impact": 2}, {"name": "job_seniority", "value": 90, "impact": 2}, {"name": "debt_ratio", "value": 90, "impact": 3}]	{"Excellent profil ! Vous Ãªtes Ã©ligible aux meilleures conditions","Votre quotitÃ© cessible vous permet d'emprunter jusqu'Ã  6 000 000 FCFA"}	quotite_cessible_v1.0	0.30	2025-07-25 13:01:23.209457	\N
10	10	8	2	very_high	0.25	refusÃ©	3	3	1	2	\N	[{"name": "monthly_income", "value": 30, "impact": 1}, {"name": "employment_status", "value": 30, "impact": -1}, {"name": "job_seniority", "value": 20, "impact": -1}, {"name": "debt_ratio", "value": 10, "impact": -3}]	{"RÃ©duire vos dettes existantes pour amÃ©liorer votre quotitÃ© cessible disponible","Augmenter vos revenus mensuels amÃ©liorerait votre score","Un contrat CDI ou CDD amÃ©liorerait significativement votre profil"}	quotite_cessible_v1.0	0.33	2025-07-25 13:01:23.209457	\N
\.


--
-- Data for Name: credit_simulations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.credit_simulations (id, user_id, client_type, credit_type, monthly_income, requested_amount, duration_months, monthly_payment, total_amount, interest_rate, total_interest, is_eligible, max_borrowing_capacity, recommendations, created_at, ip_address, user_agent) FROM stdin;
\.


--
-- Data for Name: loan_contracts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.loan_contracts (id, contract_number, credit_request_id, user_id, loan_amount, interest_rate, duration_months, monthly_payment, total_amount, total_interest, start_date, end_date, first_payment_date, status, early_settlement_date, early_settlement_amount, signed_date, signature_method, created_at, updated_at) FROM stdin;
3	CTR-20240716-000001	6	3	500000.00	0.05	12	43750.00	525000.00	25000.00	2024-07-16	2025-07-15	2024-08-15	active	\N	\N	2024-07-16 14:30:00	\N	2025-07-25 13:01:23.209457	2025-07-25 13:01:23.209457
4	CTR-20240706-000002	9	7	1000000.00	0.05	24	45833.00	1100000.00	100000.00	2024-07-06	2026-07-05	2024-08-05	active	\N	\N	2024-07-06 15:45:00	\N	2025-07-25 13:01:23.209457	2025-07-25 13:01:23.209457
\.


--
-- Data for Name: notifications; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.notifications (id, user_id, type, title, message, channel, is_read, read_at, reference_type, reference_id, created_at, sent_at) FROM stdin;
\.


--
-- Data for Name: payments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.payments (id, payment_reference, loan_contract_id, repayment_schedule_id, user_id, amount, payment_date, payment_method, principal_paid, interest_paid, late_fee_paid, transaction_id, transaction_status, created_at, created_by) FROM stdin;
7	PAY-20240815-000001	3	19	3	43750.00	2024-08-15 10:15:00	virement_bancaire	39583.00	4167.00	0.00	TRX123456	completed	2025-07-25 13:01:23.209457	\N
8	PAY-20240915-000002	3	20	3	43750.00	2024-09-15 09:30:00	virement_bancaire	39913.00	3837.00	0.00	TRX234567	completed	2025-07-25 13:01:23.209457	\N
9	PAY-20241015-000003	3	21	3	43750.00	2024-10-15 11:20:00	virement_bancaire	40245.00	3505.00	0.00	TRX345678	completed	2025-07-25 13:01:23.209457	\N
10	PAY-20240805-000004	4	31	7	45834.00	2024-08-05 14:30:00	virement_bancaire	41667.00	4167.00	0.00	TRX456789	completed	2025-07-25 13:01:23.209457	\N
11	PAY-20240905-000005	4	32	7	45833.00	2024-09-05 16:15:00	virement_bancaire	41840.00	3993.00	0.00	TRX567890	completed	2025-07-25 13:01:23.209457	\N
12	PAY-20241005-000006	4	33	7	45833.00	2024-10-05 15:45:00	virement_bancaire	42015.00	3818.00	0.00	TRX678901	completed	2025-07-25 13:01:23.209457	\N
\.


--
-- Data for Name: repayment_schedule; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.repayment_schedule (id, loan_contract_id, payment_number, due_date, principal_amount, interest_amount, total_amount, remaining_balance, status, paid_date, paid_amount, days_overdue, late_fee, created_at, updated_at) FROM stdin;
19	3	1	2024-08-15	39583.00	4167.00	43750.00	460417.00	paid	\N	\N	0	0.00	2025-07-25 13:01:23.209457	2025-07-25 13:01:23.209457
20	3	2	2024-09-15	39913.00	3837.00	43750.00	420504.00	paid	\N	\N	0	0.00	2025-07-25 13:01:23.209457	2025-07-25 13:01:23.209457
21	3	3	2024-10-15	40245.00	3505.00	43750.00	380259.00	paid	\N	\N	0	0.00	2025-07-25 13:01:23.209457	2025-07-25 13:01:23.209457
22	3	4	2024-11-15	40581.00	3169.00	43750.00	339678.00	pending	\N	\N	0	0.00	2025-07-25 13:01:23.209457	2025-07-25 13:01:23.209457
23	3	5	2024-12-15	40919.00	2831.00	43750.00	298759.00	pending	\N	\N	0	0.00	2025-07-25 13:01:23.209457	2025-07-25 13:01:23.209457
24	3	6	2025-01-15	41260.00	2490.00	43750.00	257499.00	pending	\N	\N	0	0.00	2025-07-25 13:01:23.209457	2025-07-25 13:01:23.209457
25	3	7	2025-02-15	41604.00	2146.00	43750.00	215895.00	pending	\N	\N	0	0.00	2025-07-25 13:01:23.209457	2025-07-25 13:01:23.209457
26	3	8	2025-03-15	41950.00	1800.00	43750.00	173945.00	pending	\N	\N	0	0.00	2025-07-25 13:01:23.209457	2025-07-25 13:01:23.209457
27	3	9	2025-04-15	42300.00	1450.00	43750.00	131645.00	pending	\N	\N	0	0.00	2025-07-25 13:01:23.209457	2025-07-25 13:01:23.209457
28	3	10	2025-05-15	42652.00	1098.00	43750.00	88993.00	pending	\N	\N	0	0.00	2025-07-25 13:01:23.209457	2025-07-25 13:01:23.209457
29	3	11	2025-06-15	43007.00	743.00	43750.00	45986.00	pending	\N	\N	0	0.00	2025-07-25 13:01:23.209457	2025-07-25 13:01:23.209457
30	3	12	2025-07-15	45986.00	383.00	46369.00	0.00	pending	\N	\N	0	0.00	2025-07-25 13:01:23.209457	2025-07-25 13:01:23.209457
31	4	1	2024-08-05	41667.00	4167.00	45834.00	958333.00	paid	\N	\N	0	0.00	2025-07-25 13:01:23.209457	2025-07-25 13:01:23.209457
32	4	2	2024-09-05	41840.00	3993.00	45833.00	916493.00	paid	\N	\N	0	0.00	2025-07-25 13:01:23.209457	2025-07-25 13:01:23.209457
33	4	3	2024-10-05	42015.00	3818.00	45833.00	874478.00	paid	\N	\N	0	0.00	2025-07-25 13:01:23.209457	2025-07-25 13:01:23.209457
34	4	4	2024-11-05	42190.00	3643.00	45833.00	832288.00	pending	\N	\N	0	0.00	2025-07-25 13:01:23.209457	2025-07-25 13:01:23.209457
35	4	5	2024-12-05	42366.00	3467.00	45833.00	789922.00	pending	\N	\N	0	0.00	2025-07-25 13:01:23.209457	2025-07-25 13:01:23.209457
36	4	6	2025-01-05	42542.00	3291.00	45833.00	747380.00	pending	\N	\N	0	0.00	2025-07-25 13:01:23.209457	2025-07-25 13:01:23.209457
\.


--
-- Data for Name: user_sessions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_sessions (id, user_id, session_token, refresh_token, ip_address, user_agent, device_info, expires_at, is_active, created_at, last_activity) FROM stdin;
\.


--
-- Data for Name: user_settings; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_settings (id, user_id, notification_preferences, theme, date_format, session_timeout, created_at, updated_at) FROM stdin;
1	1	{"credits": {"sms": false, "push": true, "email": true}, "security": {"sms": true, "push": true, "email": true}, "marketing": {"sms": false, "push": false, "email": false}, "transactions": {"sms": true, "push": true, "email": true}}	light	DD/MM/YYYY	30	2025-07-23 18:04:46.17199	2025-07-23 18:04:46.17199
2	2	{"credits": {"sms": false, "push": true, "email": true}, "security": {"sms": true, "push": true, "email": true}, "marketing": {"sms": false, "push": false, "email": false}, "transactions": {"sms": true, "push": true, "email": true}}	light	DD/MM/YYYY	30	2025-07-23 18:04:46.17199	2025-07-23 18:04:46.17199
3	3	{"credits": {"sms": false, "push": true, "email": true}, "security": {"sms": true, "push": true, "email": true}, "marketing": {"sms": false, "push": false, "email": false}, "transactions": {"sms": true, "push": true, "email": true}}	light	DD/MM/YYYY	30	2025-07-23 18:04:46.17199	2025-07-23 18:04:46.17199
4	5	{"credits": {"sms": false, "push": true, "email": true}, "security": {"sms": true, "push": true, "email": true}, "marketing": {"sms": false, "push": false, "email": false}, "transactions": {"sms": true, "push": true, "email": true}}	light	DD/MM/YYYY	30	2025-07-25 13:01:23.209457	2025-07-25 13:01:23.209457
5	6	{"credits": {"sms": false, "push": true, "email": true}, "security": {"sms": true, "push": true, "email": true}, "marketing": {"sms": false, "push": false, "email": false}, "transactions": {"sms": true, "push": true, "email": true}}	light	DD/MM/YYYY	30	2025-07-25 13:01:23.209457	2025-07-25 13:01:23.209457
6	7	{"credits": {"sms": false, "push": true, "email": true}, "security": {"sms": true, "push": true, "email": true}, "marketing": {"sms": false, "push": false, "email": false}, "transactions": {"sms": true, "push": true, "email": true}}	light	DD/MM/YYYY	30	2025-07-25 13:01:23.209457	2025-07-25 13:01:23.209457
7	8	{"credits": {"sms": false, "push": true, "email": true}, "security": {"sms": true, "push": true, "email": true}, "marketing": {"sms": false, "push": false, "email": false}, "transactions": {"sms": true, "push": true, "email": true}}	light	DD/MM/YYYY	30	2025-07-25 13:01:23.209457	2025-07-25 13:01:23.209457
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (id, uuid, email, password_hash, first_name, last_name, middle_name, phone_number, phone_number2, role, status, birth_date, birth_place, nationality, gender, marital_status, dependents, address, city, district, country, identity_type, identity_number, identity_issue_date, identity_expiry_date, profession, employer_name, employment_status, monthly_income, work_experience, language, currency, two_factor_enabled, biometric_enabled, last_login_at, last_login_ip, failed_login_attempts, locked_until, created_at, updated_at, created_by, updated_by) FROM stdin;
2	9ea6aaca-d055-47e3-9052-49878726be1f	agent@bamboo.ci	$2b$10$a.qvNFRpj1/ym62gn0E2S.LsRfIuYsrIAiWFa6P22QV8EjdUNoWnG	Agent	Commercial	\N	0766666666	\N	agent	active	\N	\N	\N	\N	\N	0	\N	\N	\N	Gabon	\N	\N	\N	\N	\N	\N	\N	0.00	\N	fr	XAF	f	f	\N	\N	0	\N	2025-07-23 18:04:46.159191	2025-07-24 09:40:58.331626	\N	\N
1	5ef6ac65-f71f-444b-b25b-c64eb8b243b1	admin@bamboo.ci	$2b$10$z309sD9F1iUyPruF8ecE7.lNeBEhpCsB9LHNFQIQZoTlPdU.YPKyO	Admin	System	\N	0777777777	\N	admin	active	\N	\N	\N	\N	\N	0	\N	\N	\N	Gabon	\N	\N	\N	\N	\N	\N	\N	0.00	\N	fr	XAF	f	f	\N	\N	0	\N	2025-07-23 18:04:46.159191	2025-07-24 09:40:58.333177	\N	\N
3	238129ec-ee5c-4626-a177-f987fc8bc6d7	marina@email.com	$2b$10$fnEK0WXcC6gG1g0OOq/gqeCMGqrN2Y1VWjzMa89OLBigKonXafflS	Marina	Brunelle	\N	077123456	\N	client	active	\N	\N	\N	\N	\N	0	\N	\N	\N	Gabon	\N	\N	\N	\N	\N	\N	cdi	900000.00	36	fr	XAF	f	f	\N	\N	0	\N	2025-07-23 18:04:46.159191	2025-07-25 13:01:23.209457	\N	\N
5	f11d4276-ac93-465d-ac05-2f825f6d2995	jean@exemple.com	$2b$10$FGdP8.kFYU3K3T2Q0Xd5AuFzZoY6DZU5dXV.N5yW6L5nQ5TQEjH3a	Jean	Ndong	\N	074567890	\N	client	active	1985-03-22	\N	gabonaise	M	marie	3	Quartier Batterie IV, Port-Gentil	Port-Gentil	OgoouÃ©-Maritime	Gabon	passeport	A0123456	2019-12-01	2029-11-30	Technicien	Petro Services	cdd	450000.00	18	fr	XAF	f	f	\N	\N	0	\N	2025-07-25 13:01:23.209457	2025-07-25 13:01:23.209457	\N	\N
6	d20a612d-cf3e-4c9c-bf33-40856cc3b0fa	sophie@test.com	$2b$10$FGdP8.kFYU3K3T2Q0Xd5AuFzZoY6DZU5dXV.N5yW6L5nQ5TQEjH3a	Sophie	Mfoubou	\N	066789012	\N	client	active	1995-11-08	\N	gabonaise	F	celibataire	1	Quartier AkÃ©bÃ©, Libreville	Libreville	Estuaire	Gabon	cni	95MI56789	2020-02-15	2030-02-14	CommerÃ§ante	Auto-entrepreneur	independant	180000.00	24	fr	XAF	f	f	\N	\N	0	\N	2025-07-25 13:01:23.209457	2025-07-25 13:01:23.209457	\N	\N
7	2cd1b1a6-cf1e-42e9-b661-db062f3a1b95	pierre@mail.com	$2b$10$FGdP8.kFYU3K3T2Q0Xd5AuFzZoY6DZU5dXV.N5yW6L5nQ5TQEjH3a	Pierre	Moussavou	\N	077234567	\N	client	active	1982-07-30	\N	gabonaise	M	marie	2	Quartier SabliÃ¨re, Libreville	Libreville	Estuaire	Gabon	cni	82MO45678	2017-09-20	2027-09-19	IngÃ©nieur	Total Energies	cdi	1500000.00	72	fr	XAF	f	f	\N	\N	0	\N	2025-07-25 13:01:23.209457	2025-07-25 13:01:23.209457	\N	\N
8	793a8a08-213d-4c09-8f17-9f89c524dd8b	carole@test.ga	$2b$10$FGdP8.kFYU3K3T2Q0Xd5AuFzZoY6DZU5dXV.N5yW6L5nQ5TQEjH3a	Carole	Nguema	\N	066123456	\N	client	active	1992-04-12	\N	gabonaise	F	celibataire	0	Quartier PK8, Libreville	Libreville	Estuaire	Gabon	cni	92NG78901	2019-06-05	2029-06-04	Agent d'accueil	SociÃ©tÃ© X	autre	120000.00	6	fr	XAF	f	f	\N	\N	0	\N	2025-07-25 13:01:23.209457	2025-07-25 13:01:23.209457	\N	\N
\.


--
-- Name: audit_logs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.audit_logs_id_seq', 1, false);


--
-- Name: credit_requests_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.credit_requests_id_seq', 10, true);


--
-- Name: credit_scoring_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.credit_scoring_id_seq', 10, true);


--
-- Name: credit_simulations_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.credit_simulations_id_seq', 1, false);


--
-- Name: loan_contracts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.loan_contracts_id_seq', 4, true);


--
-- Name: notifications_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.notifications_id_seq', 1, false);


--
-- Name: payments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.payments_id_seq', 12, true);


--
-- Name: repayment_schedule_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.repayment_schedule_id_seq', 36, true);


--
-- Name: user_sessions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.user_sessions_id_seq', 1, false);


--
-- Name: user_settings_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.user_settings_id_seq', 7, true);


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.users_id_seq', 8, true);


--
-- Name: audit_logs audit_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_pkey PRIMARY KEY (id);


--
-- Name: credit_requests credit_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.credit_requests
    ADD CONSTRAINT credit_requests_pkey PRIMARY KEY (id);


--
-- Name: credit_requests credit_requests_request_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.credit_requests
    ADD CONSTRAINT credit_requests_request_number_key UNIQUE (request_number);


--
-- Name: credit_scoring credit_scoring_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.credit_scoring
    ADD CONSTRAINT credit_scoring_pkey PRIMARY KEY (id);


--
-- Name: credit_simulations credit_simulations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.credit_simulations
    ADD CONSTRAINT credit_simulations_pkey PRIMARY KEY (id);


--
-- Name: loan_contracts loan_contracts_contract_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loan_contracts
    ADD CONSTRAINT loan_contracts_contract_number_key UNIQUE (contract_number);


--
-- Name: loan_contracts loan_contracts_credit_request_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loan_contracts
    ADD CONSTRAINT loan_contracts_credit_request_id_key UNIQUE (credit_request_id);


--
-- Name: loan_contracts loan_contracts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loan_contracts
    ADD CONSTRAINT loan_contracts_pkey PRIMARY KEY (id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: payments payments_payment_reference_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_payment_reference_key UNIQUE (payment_reference);


--
-- Name: payments payments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_pkey PRIMARY KEY (id);


--
-- Name: repayment_schedule repayment_schedule_loan_contract_id_payment_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.repayment_schedule
    ADD CONSTRAINT repayment_schedule_loan_contract_id_payment_number_key UNIQUE (loan_contract_id, payment_number);


--
-- Name: repayment_schedule repayment_schedule_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.repayment_schedule
    ADD CONSTRAINT repayment_schedule_pkey PRIMARY KEY (id);


--
-- Name: user_sessions user_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_sessions
    ADD CONSTRAINT user_sessions_pkey PRIMARY KEY (id);


--
-- Name: user_sessions user_sessions_refresh_token_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_sessions
    ADD CONSTRAINT user_sessions_refresh_token_key UNIQUE (refresh_token);


--
-- Name: user_sessions user_sessions_session_token_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_sessions
    ADD CONSTRAINT user_sessions_session_token_key UNIQUE (session_token);


--
-- Name: user_settings user_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_settings
    ADD CONSTRAINT user_settings_pkey PRIMARY KEY (id);


--
-- Name: user_settings user_settings_user_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_settings
    ADD CONSTRAINT user_settings_user_id_key UNIQUE (user_id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_identity_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_identity_number_key UNIQUE (identity_number);


--
-- Name: users users_phone_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_phone_number_key UNIQUE (phone_number);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users users_uuid_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_uuid_key UNIQUE (uuid);


--
-- Name: idx_audit_logs_action; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_audit_logs_action ON public.audit_logs USING btree (action);


--
-- Name: idx_audit_logs_created_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_audit_logs_created_at ON public.audit_logs USING btree (created_at);


--
-- Name: idx_audit_logs_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_audit_logs_user_id ON public.audit_logs USING btree (user_id);


--
-- Name: idx_credit_requests_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_credit_requests_status ON public.credit_requests USING btree (status);


--
-- Name: idx_credit_requests_submission_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_credit_requests_submission_date ON public.credit_requests USING btree (submission_date);


--
-- Name: idx_credit_requests_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_credit_requests_type ON public.credit_requests USING btree (credit_type);


--
-- Name: idx_credit_requests_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_credit_requests_user_id ON public.credit_requests USING btree (user_id);


--
-- Name: idx_loan_contracts_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_loan_contracts_status ON public.loan_contracts USING btree (status);


--
-- Name: idx_loan_contracts_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_loan_contracts_user_id ON public.loan_contracts USING btree (user_id);


--
-- Name: idx_notifications_read; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_notifications_read ON public.notifications USING btree (is_read);


--
-- Name: idx_notifications_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_notifications_user_id ON public.notifications USING btree (user_id);


--
-- Name: idx_payments_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_payments_date ON public.payments USING btree (payment_date);


--
-- Name: idx_payments_loan_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_payments_loan_id ON public.payments USING btree (loan_contract_id);


--
-- Name: idx_payments_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_payments_user_id ON public.payments USING btree (user_id);


--
-- Name: idx_repayment_schedule_due_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_repayment_schedule_due_date ON public.repayment_schedule USING btree (due_date);


--
-- Name: idx_repayment_schedule_loan_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_repayment_schedule_loan_id ON public.repayment_schedule USING btree (loan_contract_id);


--
-- Name: idx_repayment_schedule_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_repayment_schedule_status ON public.repayment_schedule USING btree (status);


--
-- Name: idx_users_email; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_users_email ON public.users USING btree (email);


--
-- Name: idx_users_phone; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_users_phone ON public.users USING btree (phone_number);


--
-- Name: idx_users_role; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_users_role ON public.users USING btree (role);


--
-- Name: idx_users_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_users_status ON public.users USING btree (status);


--
-- Name: credit_requests update_credit_requests_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_credit_requests_updated_at BEFORE UPDATE ON public.credit_requests FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: loan_contracts update_loan_contracts_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_loan_contracts_updated_at BEFORE UPDATE ON public.loan_contracts FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: repayment_schedule update_repayment_schedule_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_repayment_schedule_updated_at BEFORE UPDATE ON public.repayment_schedule FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: user_settings update_user_settings_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_user_settings_updated_at BEFORE UPDATE ON public.user_settings FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: users update_users_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: audit_logs audit_logs_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: credit_requests credit_requests_decision_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.credit_requests
    ADD CONSTRAINT credit_requests_decision_by_fkey FOREIGN KEY (decision_by) REFERENCES public.users(id);


--
-- Name: credit_requests credit_requests_kyc_verified_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.credit_requests
    ADD CONSTRAINT credit_requests_kyc_verified_by_fkey FOREIGN KEY (kyc_verified_by) REFERENCES public.users(id);


--
-- Name: credit_requests credit_requests_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.credit_requests
    ADD CONSTRAINT credit_requests_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: credit_scoring credit_scoring_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.credit_scoring
    ADD CONSTRAINT credit_scoring_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: credit_scoring credit_scoring_credit_request_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.credit_scoring
    ADD CONSTRAINT credit_scoring_credit_request_id_fkey FOREIGN KEY (credit_request_id) REFERENCES public.credit_requests(id);


--
-- Name: credit_scoring credit_scoring_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.credit_scoring
    ADD CONSTRAINT credit_scoring_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: credit_simulations credit_simulations_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.credit_simulations
    ADD CONSTRAINT credit_simulations_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: loan_contracts loan_contracts_credit_request_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loan_contracts
    ADD CONSTRAINT loan_contracts_credit_request_id_fkey FOREIGN KEY (credit_request_id) REFERENCES public.credit_requests(id);


--
-- Name: loan_contracts loan_contracts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loan_contracts
    ADD CONSTRAINT loan_contracts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: notifications notifications_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: payments payments_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: payments payments_loan_contract_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_loan_contract_id_fkey FOREIGN KEY (loan_contract_id) REFERENCES public.loan_contracts(id);


--
-- Name: payments payments_repayment_schedule_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_repayment_schedule_id_fkey FOREIGN KEY (repayment_schedule_id) REFERENCES public.repayment_schedule(id);


--
-- Name: payments payments_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: repayment_schedule repayment_schedule_loan_contract_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.repayment_schedule
    ADD CONSTRAINT repayment_schedule_loan_contract_id_fkey FOREIGN KEY (loan_contract_id) REFERENCES public.loan_contracts(id);


--
-- Name: user_sessions user_sessions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_sessions
    ADD CONSTRAINT user_sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: user_settings user_settings_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_settings
    ADD CONSTRAINT user_settings_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: users users_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: users users_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(id);


--
-- PostgreSQL database dump complete
--

