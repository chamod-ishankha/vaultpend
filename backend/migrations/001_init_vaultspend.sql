-- VaultSpend — PostgreSQL schema and baseline tables (Phase 2).
-- Apply against database: bytecub
-- All objects live in schema: vaultspend

CREATE SCHEMA IF NOT EXISTS vaultspend;

-- gen_random_uuid() is built-in on PostgreSQL 13+

CREATE TABLE vaultspend.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    preferred_currency CHAR(3) NOT NULL DEFAULT 'USD',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE vaultspend.categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES vaultspend.users (id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    icon_key TEXT,
    color TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, name)
);

CREATE TABLE vaultspend.transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES vaultspend.users (id) ON DELETE CASCADE,
    category_id UUID REFERENCES vaultspend.categories (id) ON DELETE SET NULL,
    amount NUMERIC(18, 6) NOT NULL,
    currency CHAR(3) NOT NULL,
    occurred_at TIMESTAMPTZ NOT NULL,
    note TEXT,
    is_recurring BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE vaultspend.subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES vaultspend.users (id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    amount NUMERIC(18, 6) NOT NULL,
    currency CHAR(3) NOT NULL,
    cycle TEXT NOT NULL CHECK (cycle IN ('monthly', 'annual', 'custom')),
    next_billing_date DATE NOT NULL,
    is_trial BOOLEAN NOT NULL DEFAULT false,
    trial_ends_at DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_categories_user_id ON vaultspend.categories (user_id);
CREATE INDEX idx_transactions_user_id ON vaultspend.transactions (user_id);
CREATE INDEX idx_transactions_occurred_at ON vaultspend.transactions (user_id, occurred_at DESC);
CREATE INDEX idx_subscriptions_user_id ON vaultspend.subscriptions (user_id);
CREATE INDEX idx_subscriptions_next_billing ON vaultspend.subscriptions (user_id, next_billing_date);
