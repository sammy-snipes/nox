-- 001_initial.sql
-- Nox schema -- requires PostgreSQL 13+ (gen_random_uuid)

BEGIN;

-- --------------------------------------------------------
-- devices (root entity -- each device self-registers with a token)
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS devices (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_token TEXT NOT NULL UNIQUE,
    udid        TEXT UNIQUE,
    push_magic  TEXT,
    push_token  TEXT,
    enrolled    BOOLEAN NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- --------------------------------------------------------
-- blocked_domains
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS blocked_domains (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id   UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    domain      TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(device_id, domain)
);

CREATE INDEX IF NOT EXISTS idx_blocked_domains_device_id ON blocked_domains(device_id);

-- --------------------------------------------------------
-- blocked_apps
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS blocked_apps (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id   UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    bundle_id   TEXT NOT NULL,
    display_name TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(device_id, bundle_id)
);

CREATE INDEX IF NOT EXISTS idx_blocked_apps_device_id ON blocked_apps(device_id);

-- --------------------------------------------------------
-- block_sessions
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS block_sessions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id       UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    started_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    ends_at         TIMESTAMPTZ,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    unlock_method   TEXT NOT NULL DEFAULT 'type_to_unlock'
);

CREATE INDEX IF NOT EXISTS idx_block_sessions_device_id ON block_sessions(device_id);
CREATE INDEX IF NOT EXISTS idx_block_sessions_active ON block_sessions(device_id, is_active) WHERE is_active = TRUE;

-- --------------------------------------------------------
-- unblock_requests
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS unblock_requests (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id       UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    session_id      UUID NOT NULL REFERENCES block_sessions(id) ON DELETE CASCADE,
    requested_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at    TIMESTAMPTZ,
    unlock_text     TEXT,
    status          TEXT NOT NULL DEFAULT 'pending'
);

CREATE INDEX IF NOT EXISTS idx_unblock_requests_session_id ON unblock_requests(session_id);

COMMIT;
