-- =============================================================================
-- Marketplace Freelance  |  Migration 001: password reset tokens
-- Assignment 3 (login / sign-up / password recovery)
--
-- Run AFTER database/schema.sql:
--   psql -d lab_freelance -v ON_ERROR_STOP=1 -f database/migrations/001_password_reset_tokens.sql
--
-- Nothing in the existing tables changes: users.email (unique, case-insensitive)
-- is the login identifier and users.password_hash (VARCHAR 255) is big enough
-- for Argon2id / PBKDF2 hashes.
-- The script is re-runnable (it drops and recreates only this table).
-- If schema.sql is re-run, run this file again afterwards.
-- =============================================================================

BEGIN;

DROP TABLE IF EXISTS password_reset_tokens;

-- One row per "forgot password" request.
--   * The e-mailed link contains a long random token (256 bits). Only the
--     SHA-256 hash of that token is stored, so a leaked database does not leak
--     working reset links. (SHA-256 is fine HERE because the token is random
--     and high-entropy; user PASSWORDS are hashed with Argon2/PBKDF2 instead.)
--   * A link works once and only until expires_at.
CREATE TABLE password_reset_tokens (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id     BIGINT      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    token_hash  CHAR(64)    NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at  TIMESTAMPTZ NOT NULL,
    used_at     TIMESTAMPTZ,                      -- NULL = not used / not revoked yet
    CONSTRAINT password_reset_tokens_hash_unique  UNIQUE (token_hash),
    CONSTRAINT password_reset_tokens_hash_format  CHECK (token_hash ~ '^[0-9a-f]{64}$'),
    CONSTRAINT password_reset_tokens_expiry_after CHECK (expires_at > created_at),
    CONSTRAINT password_reset_tokens_used_order   CHECK (used_at IS NULL OR used_at >= created_at)
);

CREATE INDEX password_reset_tokens_user_idx ON password_reset_tokens (user_id);

-- A user can have at most ONE live (unused) token at a time. When a new reset is
-- requested, the backend first marks the older ones as used (used_at = now())
-- and then inserts the new row, in the same transaction.
CREATE UNIQUE INDEX password_reset_tokens_one_live_per_user_idx
    ON password_reset_tokens (user_id) WHERE used_at IS NULL;

COMMENT ON TABLE  password_reset_tokens            IS 'Password reset requests; one-time, time-limited, stored as SHA-256 of a random token';
COMMENT ON COLUMN password_reset_tokens.token_hash IS 'Hex SHA-256 of the random token sent in the reset link (never the token itself)';
COMMENT ON COLUMN password_reset_tokens.used_at    IS 'Set when the link is used or replaced by a newer request; NULL while still usable';

COMMIT;
