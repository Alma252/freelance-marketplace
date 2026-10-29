-- =============================================================================
-- Marketplace Freelance  |  Database schema
-- DBMS   : PostgreSQL 14 or newer (uses IDENTITY columns, partial unique
--          indexes, expression indexes and PL/pgSQL triggers)
-- Usage  : psql -U <user> -d lab_freelance -v ON_ERROR_STOP=1 -f database/schema.sql
-- Note   : the script is re-runnable; it drops the objects it owns first.
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 0. Clean-up (reverse dependency order) so the script can be re-run safely
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS proposals          CASCADE;
DROP TABLE IF EXISTS project_skills     CASCADE;
DROP TABLE IF EXISTS project_categories CASCADE;
DROP TABLE IF EXISTS projects           CASCADE;
DROP TABLE IF EXISTS certificates       CASCADE;
DROP TABLE IF EXISTS portfolio_items    CASCADE;
DROP TABLE IF EXISTS user_skills        CASCADE;
DROP TABLE IF EXISTS profiles_user      CASCADE;
DROP TABLE IF EXISTS categories         CASCADE;
DROP TABLE IF EXISTS skills             CASCADE;
DROP TABLE IF EXISTS admins             CASCADE;
DROP TABLE IF EXISTS users              CASCADE;

DROP TYPE IF EXISTS proposal_status;
DROP TYPE IF EXISTS project_status;
DROP TYPE IF EXISTS pricing_type;
DROP TYPE IF EXISTS user_status;

-- -----------------------------------------------------------------------------
-- 1. Enumerated types (the allowed values of every "status"/"type" column)
-- -----------------------------------------------------------------------------
CREATE TYPE user_status     AS ENUM ('active', 'inactive', 'blocked');
CREATE TYPE pricing_type    AS ENUM ('fixed', 'hourly');
CREATE TYPE project_status  AS ENUM ('draft', 'open', 'in_progress', 'completed', 'cancelled');
CREATE TYPE proposal_status AS ENUM ('pending', 'accepted', 'rejected', 'withdrawn');

-- -----------------------------------------------------------------------------
-- 2. Tables
-- -----------------------------------------------------------------------------

-- 2.1 users : every account on the platform (normal users AND admins)
CREATE TABLE users (
    id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name     VARCHAR(100) NOT NULL,
    last_name      VARCHAR(100) NOT NULL,
    email          VARCHAR(255) NOT NULL,
    phone          VARCHAR(20),                         -- optional
    password_hash  VARCHAR(255) NOT NULL,               -- hash only, never plain text
    status         user_status  NOT NULL DEFAULT 'active',
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT users_first_name_not_blank CHECK (btrim(first_name) <> ''),
    CONSTRAINT users_last_name_not_blank  CHECK (btrim(last_name)  <> ''),
    CONSTRAINT users_email_format         CHECK (email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'),
    CONSTRAINT users_phone_format         CHECK (phone IS NULL OR phone ~ '^\+?[0-9]{10,15}$'),
    -- a bcrypt/argon2 hash is always long; short strings are very likely plain text
    CONSTRAINT users_password_hash_length CHECK (length(password_hash) >= 20)
);
-- e-mail must be unique, case-insensitively (Ali@x.com == ali@x.com)
CREATE UNIQUE INDEX users_email_unique_idx ON users (lower(email));

-- 2.2 admins : accounts with administrative access (1:0..1 with users)
CREATE TABLE admins (
    user_id     BIGINT      PRIMARY KEY REFERENCES users (id) ON DELETE RESTRICT,
    granted_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2.3 profiles_user : extra information of a normal user (1:0..1 with users)
CREATE TABLE profiles_user (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id             BIGINT      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    professional_title  VARCHAR(150),                   -- optional
    bio                 TEXT,                           -- optional
    location            VARCHAR(150),                   -- optional
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT profiles_user_one_per_user UNIQUE (user_id)
);

-- 2.4 skills : catalogue of skills
CREATE TABLE skills (
    id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name  VARCHAR(100) NOT NULL,
    CONSTRAINT skills_name_not_blank CHECK (btrim(name) <> '')
);
CREATE UNIQUE INDEX skills_name_unique_idx ON skills (lower(name));

-- 2.5 categories : catalogue of project categories
CREATE TABLE categories (
    id     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title  VARCHAR(150) NOT NULL,
    CONSTRAINT categories_title_not_blank CHECK (btrim(title) <> '')
);
CREATE UNIQUE INDEX categories_title_unique_idx ON categories (lower(title));

-- 2.6 user_skills : profile <-> skill (many-to-many)
CREATE TABLE user_skills (
    profile_id  BIGINT NOT NULL REFERENCES profiles_user (id) ON DELETE CASCADE,
    skill_id    BIGINT NOT NULL REFERENCES skills (id)        ON DELETE RESTRICT,
    PRIMARY KEY (profile_id, skill_id)
);
CREATE INDEX user_skills_skill_idx ON user_skills (skill_id);

-- 2.7 portfolio_items : a profile has many portfolio items (1:N)
CREATE TABLE portfolio_items (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    profile_id   BIGINT       NOT NULL REFERENCES profiles_user (id) ON DELETE CASCADE,
    title        VARCHAR(200) NOT NULL,
    description  TEXT,
    project_url  VARCHAR(500),
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT portfolio_items_title_not_blank CHECK (btrim(title) <> '')
);
CREATE INDEX portfolio_items_profile_idx ON portfolio_items (profile_id);

-- 2.8 certificates : a profile has many certificates (1:N)
CREATE TABLE certificates (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    profile_id      BIGINT       NOT NULL REFERENCES profiles_user (id) ON DELETE CASCADE,
    title           VARCHAR(200) NOT NULL,
    issuer          VARCHAR(200),
    issued_date     DATE,
    expires_date    DATE,
    credential_url  VARCHAR(500),
    CONSTRAINT certificates_title_not_blank CHECK (btrim(title) <> ''),
    CONSTRAINT certificates_dates_order     CHECK (expires_date IS NULL OR issued_date IS NULL OR expires_date >= issued_date)
);
CREATE INDEX certificates_profile_idx ON certificates (profile_id);

-- 2.9 projects : created by an employer (a normal user)
--     budget = total budget      when pricing_type = 'fixed'
--     budget = hourly rate       when pricing_type = 'hourly'
CREATE TABLE projects (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    employer_id   BIGINT         NOT NULL REFERENCES users (id) ON DELETE RESTRICT,
    title         VARCHAR(200)   NOT NULL,
    description   TEXT           NOT NULL,
    pricing_type  pricing_type   NOT NULL,
    budget        NUMERIC(12, 2) NOT NULL,
    status        project_status NOT NULL DEFAULT 'draft',
    deadline      DATE,                                  -- optional
    created_at    TIMESTAMPTZ    NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ    NOT NULL DEFAULT now(),
    CONSTRAINT projects_title_not_blank CHECK (btrim(title) <> ''),
    CONSTRAINT projects_budget_positive CHECK (budget > 0)
);
CREATE INDEX projects_employer_idx ON projects (employer_id);
CREATE INDEX projects_status_idx   ON projects (status);

-- 2.10 project_categories : project <-> category (many-to-many)
CREATE TABLE project_categories (
    project_id   BIGINT NOT NULL REFERENCES projects (id)   ON DELETE CASCADE,
    category_id  BIGINT NOT NULL REFERENCES categories (id) ON DELETE RESTRICT,
    PRIMARY KEY (project_id, category_id)
);
CREATE INDEX project_categories_category_idx ON project_categories (category_id);

-- 2.11 project_skills : project <-> required skill (many-to-many)
CREATE TABLE project_skills (
    project_id  BIGINT NOT NULL REFERENCES projects (id) ON DELETE CASCADE,
    skill_id    BIGINT NOT NULL REFERENCES skills (id)   ON DELETE RESTRICT,
    PRIMARY KEY (project_id, skill_id)
);
CREATE INDEX project_skills_skill_idx ON project_skills (skill_id);

-- 2.12 proposals : sent by a freelancer (a normal user) for a project
--     amount = total price       when the project is 'fixed'
--     amount = hourly rate       when the project is 'hourly'
CREATE TABLE proposals (
    id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    project_id       BIGINT          NOT NULL REFERENCES projects (id) ON DELETE RESTRICT,
    freelancer_id    BIGINT          NOT NULL REFERENCES users (id)    ON DELETE RESTRICT,
    amount           NUMERIC(12, 2)  NOT NULL,
    cover_letter     TEXT            NOT NULL,
    estimated_days   INTEGER,                            -- optional
    estimated_hours  NUMERIC(8, 2),                      -- optional, hourly projects only
    status           proposal_status NOT NULL DEFAULT 'pending',
    created_at       TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT proposals_amount_positive          CHECK (amount > 0),
    CONSTRAINT proposals_estimated_days_positive  CHECK (estimated_days  IS NULL OR estimated_days  > 0),
    CONSTRAINT proposals_estimated_hours_positive CHECK (estimated_hours IS NULL OR estimated_hours > 0),
    CONSTRAINT proposals_cover_letter_not_blank   CHECK (btrim(cover_letter) <> ''),
    -- a freelancer may send at most ONE proposal per project
    CONSTRAINT proposals_one_per_freelancer_per_project UNIQUE (project_id, freelancer_id)
);
CREATE INDEX proposals_freelancer_idx ON proposals (freelancer_id);
-- at most ONE accepted proposal per project (partial unique index)
CREATE UNIQUE INDEX proposals_one_accepted_per_project_idx
    ON proposals (project_id) WHERE status = 'accepted';

-- -----------------------------------------------------------------------------
-- 3. Functions and triggers (business rules that CHECK/UNIQUE cannot express
--    because they need data from other tables)
-- -----------------------------------------------------------------------------

-- 3.1 helper: is this user an admin?
CREATE OR REPLACE FUNCTION is_admin(p_user_id BIGINT)
RETURNS BOOLEAN
LANGUAGE sql STABLE
AS $$
    SELECT EXISTS (SELECT 1 FROM admins WHERE user_id = p_user_id);
$$;

-- 3.2 keep updated_at current on every UPDATE
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_users_set_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_profiles_user_set_updated_at
    BEFORE UPDATE ON profiles_user
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_projects_set_updated_at
    BEFORE UPDATE ON projects
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_proposals_set_updated_at
    BEFORE UPDATE ON proposals
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 3.3 an account that already acts as employer/freelancer/has a profile
--     cannot be turned into an admin (admins are management-only accounts)
CREATE OR REPLACE FUNCTION admins_validate()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM projects      WHERE employer_id   = NEW.user_id)
    OR EXISTS (SELECT 1 FROM proposals     WHERE freelancer_id = NEW.user_id)
    OR EXISTS (SELECT 1 FROM profiles_user WHERE user_id       = NEW.user_id) THEN
        RAISE EXCEPTION 'User % already has projects, proposals or a profile and cannot become an admin', NEW.user_id
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_admins_validate
    BEFORE INSERT ON admins
    FOR EACH ROW EXECUTE FUNCTION admins_validate();

-- 3.4 admins have no profile (profiles belong to normal users only)
CREATE OR REPLACE FUNCTION profiles_user_validate()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF is_admin(NEW.user_id) THEN
        RAISE EXCEPTION 'Admin account % cannot have a user profile', NEW.user_id
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_profiles_user_validate
    BEFORE INSERT OR UPDATE OF user_id ON profiles_user
    FOR EACH ROW EXECUTE FUNCTION profiles_user_validate();

-- 3.5 project rules: employer is not an admin, legal status transitions,
--     employer/pricing type are stable once proposals exist
--
--     Allowed project status transitions
--         draft       -> open | cancelled
--         open        -> in_progress | cancelled
--         in_progress -> completed | cancelled
--         completed, cancelled : final states
--     'in_progress' is only reachable while an accepted proposal exists.
CREATE OR REPLACE FUNCTION projects_validate()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF is_admin(NEW.employer_id) THEN
        RAISE EXCEPTION 'Admin account % cannot create projects', NEW.employer_id
            USING ERRCODE = 'check_violation';
    END IF;

    IF TG_OP = 'INSERT' THEN
        IF NEW.status NOT IN ('draft', 'open') THEN
            RAISE EXCEPTION 'A new project must start as draft or open (got %)', NEW.status
                USING ERRCODE = 'check_violation';
        END IF;
    ELSE  -- UPDATE
        IF NEW.employer_id <> OLD.employer_id THEN
            RAISE EXCEPTION 'The employer of a project cannot be changed'
                USING ERRCODE = 'check_violation';
        END IF;

        IF NEW.pricing_type <> OLD.pricing_type
           AND EXISTS (SELECT 1 FROM proposals WHERE project_id = OLD.id) THEN
            RAISE EXCEPTION 'The pricing type cannot be changed after proposals were received'
                USING ERRCODE = 'check_violation';
        END IF;

        IF NEW.status <> OLD.status THEN
            IF NOT (
                   (OLD.status = 'draft'       AND NEW.status IN ('open', 'cancelled'))
                OR (OLD.status = 'open'        AND NEW.status IN ('in_progress', 'cancelled'))
                OR (OLD.status = 'in_progress' AND NEW.status IN ('completed', 'cancelled'))
            ) THEN
                RAISE EXCEPTION 'Illegal project status change: % -> %', OLD.status, NEW.status
                    USING ERRCODE = 'check_violation';
            END IF;

            IF NEW.status = 'in_progress'
               AND NOT EXISTS (SELECT 1 FROM proposals
                               WHERE project_id = NEW.id AND status = 'accepted') THEN
                RAISE EXCEPTION 'A project can be in_progress only if one of its proposals is accepted'
                    USING ERRCODE = 'check_violation';
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_projects_validate
    BEFORE INSERT OR UPDATE ON projects
    FOR EACH ROW EXECUTE FUNCTION projects_validate();

-- 3.6 only drafts may be physically deleted; everything else is history
CREATE OR REPLACE FUNCTION projects_prevent_delete()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF OLD.status <> 'draft' THEN
        RAISE EXCEPTION 'Only draft projects can be deleted (project % is %); cancel it instead', OLD.id, OLD.status
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN OLD;
END;
$$;

CREATE TRIGGER trg_projects_prevent_delete
    BEFORE DELETE ON projects
    FOR EACH ROW EXECUTE FUNCTION projects_prevent_delete();

-- 3.7 when a project is cancelled, its still-pending proposals are rejected
CREATE OR REPLACE FUNCTION projects_after_status_change()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.status = 'cancelled' AND OLD.status <> 'cancelled' THEN
        UPDATE proposals
           SET status = 'rejected'
         WHERE project_id = NEW.id AND status = 'pending';
    END IF;
    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_projects_after_status_change
    AFTER UPDATE OF status ON projects
    FOR EACH ROW EXECUTE FUNCTION projects_after_status_change();

-- 3.8 proposal rules
--     * only for an 'open' project, only as 'pending'
--     * never by the project's own employer, never by an admin
--     * estimated_hours only for hourly projects
--     * identity (project, freelancer) never changes
--     * status machine:  pending -> accepted | rejected | withdrawn
--                        accepted, rejected, withdrawn : final states
--     * accepting requires the project to be 'open'
--     * only pending proposals can be edited
CREATE OR REPLACE FUNCTION proposals_validate()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_project   projects%ROWTYPE;
    v_accepting BOOLEAN := FALSE;
BEGIN
    -- (OLD only exists on UPDATE, so it is only touched inside this IF)
    IF TG_OP = 'UPDATE' THEN
        IF NEW.project_id <> OLD.project_id OR NEW.freelancer_id <> OLD.freelancer_id THEN
            RAISE EXCEPTION 'The project and the freelancer of a proposal cannot be changed'
                USING ERRCODE = 'check_violation';
        END IF;
        v_accepting := (NEW.status = 'accepted' AND OLD.status <> 'accepted');
    END IF;

    -- lock the project row so its status cannot change under our feet
    IF v_accepting THEN
        SELECT * INTO v_project FROM projects WHERE id = NEW.project_id FOR UPDATE;
    ELSE
        SELECT * INTO v_project FROM projects WHERE id = NEW.project_id FOR SHARE;
    END IF;

    -- unknown project: let the foreign key report the error
    IF NOT FOUND THEN
        RETURN NEW;
    END IF;

    IF is_admin(NEW.freelancer_id) THEN
        RAISE EXCEPTION 'Admin account % cannot send proposals', NEW.freelancer_id
            USING ERRCODE = 'check_violation';
    END IF;

    IF v_project.employer_id = NEW.freelancer_id THEN
        RAISE EXCEPTION 'A user cannot send a proposal for his/her own project'
            USING ERRCODE = 'check_violation';
    END IF;

    IF NEW.estimated_hours IS NOT NULL AND v_project.pricing_type <> 'hourly' THEN
        RAISE EXCEPTION 'estimated_hours is only allowed for hourly projects'
            USING ERRCODE = 'check_violation';
    END IF;

    IF TG_OP = 'INSERT' THEN
        IF NEW.status <> 'pending' THEN
            RAISE EXCEPTION 'A new proposal must be pending (got %)', NEW.status
                USING ERRCODE = 'check_violation';
        END IF;
        IF v_project.status <> 'open' THEN
            RAISE EXCEPTION 'Proposals can only be sent for open projects (project % is %)', v_project.id, v_project.status
                USING ERRCODE = 'check_violation';
        END IF;
    ELSE  -- UPDATE
        IF NEW.status <> OLD.status THEN
            IF OLD.status <> 'pending' THEN
                RAISE EXCEPTION 'Illegal proposal status change: % -> % (% is a final state)', OLD.status, NEW.status, OLD.status
                    USING ERRCODE = 'check_violation';
            END IF;
            IF NEW.status = 'accepted' AND v_project.status <> 'open' THEN
                RAISE EXCEPTION 'A proposal can only be accepted while its project is open (project % is %)', v_project.id, v_project.status
                    USING ERRCODE = 'check_violation';
            END IF;
        ELSIF OLD.status <> 'pending'
              AND (NEW.amount          IS DISTINCT FROM OLD.amount
                OR NEW.cover_letter    IS DISTINCT FROM OLD.cover_letter
                OR NEW.estimated_days  IS DISTINCT FROM OLD.estimated_days
                OR NEW.estimated_hours IS DISTINCT FROM OLD.estimated_hours) THEN
            RAISE EXCEPTION 'Only pending proposals can be edited'
                USING ERRCODE = 'check_violation';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_proposals_validate
    BEFORE INSERT OR UPDATE ON proposals
    FOR EACH ROW EXECUTE FUNCTION proposals_validate();

-- 3.9 accepting a proposal moves the project to in_progress and rejects the
--     other pending proposals of that project
CREATE OR REPLACE FUNCTION proposals_after_accept()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.status = 'accepted' AND OLD.status <> 'accepted' THEN
        UPDATE projects
           SET status = 'in_progress'
         WHERE id = NEW.project_id;

        UPDATE proposals
           SET status = 'rejected'
         WHERE project_id = NEW.project_id
           AND id <> NEW.id
           AND status = 'pending';
    END IF;
    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_proposals_after_accept
    AFTER UPDATE OF status ON proposals
    FOR EACH ROW EXECUTE FUNCTION proposals_after_accept();

-- -----------------------------------------------------------------------------
-- 4. Documentation inside the database
-- -----------------------------------------------------------------------------
COMMENT ON TABLE  admins            IS 'Accounts with administrative access; presence of a row = admin';
COMMENT ON COLUMN admins.granted_at IS 'When administrative access was granted';
COMMENT ON TABLE  profiles_user     IS 'Optional extra information of a normal user (at most one per user)';
COMMENT ON COLUMN projects.budget   IS 'Total budget for fixed projects; hourly rate for hourly projects';
COMMENT ON COLUMN proposals.amount  IS 'Total price for fixed projects; hourly rate for hourly projects';
COMMENT ON COLUMN proposals.estimated_days  IS 'Estimated duration in days (optional)';
COMMENT ON COLUMN proposals.estimated_hours IS 'Estimated working hours (optional, hourly projects only)';

COMMIT;
