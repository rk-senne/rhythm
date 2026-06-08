CREATE TABLE users (
    id TEXT PRIMARY KEY,
    apple_sub TEXT UNIQUE NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE sync_changes (
    user_id TEXT NOT NULL REFERENCES users(id),
    table_name TEXT NOT NULL,
    record_id TEXT NOT NULL,
    data JSONB NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, table_name, record_id)
);

CREATE INDEX idx_sync_changes_updated ON sync_changes(user_id, updated_at);

CREATE TABLE cycles (
    id UUID PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id),
    started_at TIMESTAMPTZ NOT NULL,
    ended_at TIMESTAMPTZ,
    focus_duration INT NOT NULL,
    ritual_completed BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE journal_entries (
    id UUID PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id),
    cycle_id UUID REFERENCES cycles(id),
    text TEXT NOT NULL,
    mood TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE hydration_logs (
    id UUID PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id),
    cycle_id UUID REFERENCES cycles(id),
    amount_ml INT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
