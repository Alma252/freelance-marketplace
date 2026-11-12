-- =============================================================================
-- Marketplace Freelance  |  Migration 002: users.last_login
-- Assignment 3 (Django needs a last_login column to track sign-ins)
--
-- Run AFTER database/schema.sql:
--   psql -d lab_freelance -v ON_ERROR_STOP=1 -f database/migrations/002_users_last_login.sql
-- Safe to run more than once. If schema.sql is re-run, run this file again.
-- =============================================================================

BEGIN;

ALTER TABLE users ADD COLUMN IF NOT EXISTS last_login TIMESTAMPTZ;   -- NULL = never signed in

COMMENT ON COLUMN users.last_login IS 'Time of the last successful sign-in (maintained by the web application)';

COMMIT;
