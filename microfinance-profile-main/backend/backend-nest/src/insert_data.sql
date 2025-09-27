-- Créer les tables pour les crédits utilisateurs
CREATE TABLE IF NOT EXISTS user_credits (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(255) NOT NULL,
    type VARCHAR(100) NOT NULL,
    amount DECIMAL(12,2) NOT NULL,
    total_amount DECIMAL(12,2) NOT NULL,
    remaining_amount DECIMAL(12,2) NOT NULL,
    interest_rate DECIMAL(5,2) NOT NULL,
    status VARCHAR(50) DEFAULT 'active',
    approved_date TIMESTAMP NOT NULL,
    due_date TIMESTAMP NOT NULL,
    next_payment_date TIMESTAMP,
    next_payment_amount DECIMAL(12,2),
    payments_history JSONB DEFAULT '[]',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_user_credits_username ON user_credits(username);
CREATE INDEX idx_user_credits_status ON user_credits(username, status);

-- Table des restrictions
CREATE TABLE IF NOT EXISTS credit_restrictions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(255) UNIQUE NOT NULL,
    can_apply_for_credit BOOLEAN DEFAULT true,
    max_credits_allowed INTEGER DEFAULT 2,
    active_credit_count INTEGER DEFAULT 0,
    total_active_debt DECIMAL(12,2) DEFAULT 0,
    debt_ratio DECIMAL(5,2) DEFAULT 0,
    next_eligible_date TIMESTAMP,
    last_application_date TIMESTAMP,
    blocking_reason TEXT,
    days_until_next_application INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_restrictions_username ON credit_restrictions(username);

-- Table des scores temps réel
CREATE TABLE IF NOT EXISTS realtime_scores (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(255) NOT NULL,
    score DECIMAL(3,1) NOT NULL,
    previous_score DECIMAL(3,1),
    risk_level VARCHAR(50) NOT NULL,
    factors JSONB DEFAULT '[]',
    recommendations TEXT[],
    is_real_time BOOLEAN DEFAULT true,
    score_change DECIMAL(3,1) DEFAULT 0,
    payment_analysis JSONB,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_realtime_scores_username ON realtime_scores(username);