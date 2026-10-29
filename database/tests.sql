-- =============================================================================
-- Marketplace Freelance  |  Constraint / business-rule tests
-- Run AFTER schema.sql + seed.sql:
--   psql -U <user> -d lab_freelance -f database/tests.sql
--
-- * Everything runs inside ONE transaction that is rolled back at the end, so
--   the sample data stays untouched.
-- * "expect_error" runs a statement and PASSES when it is rejected with the
--   expected SQLSTATE (23505 unique, 23503 foreign key, 23514 check/trigger rule,
--   23502 not null, 22P02 invalid enum value).
-- * "expect_state" runs a (valid) change and PASSES when the check query is true.
-- =============================================================================

BEGIN;

CREATE TEMP TABLE test_results (
    id       SERIAL PRIMARY KEY,
    outcome  TEXT NOT NULL,
    test     TEXT NOT NULL,
    detail   TEXT
);

-- helpers ----------------------------------------------------------------------
CREATE FUNCTION pg_temp.uid(p_email TEXT) RETURNS BIGINT
LANGUAGE sql AS $f$ SELECT id FROM users WHERE email = p_email $f$;

CREATE FUNCTION pg_temp.pid(p_keyword TEXT) RETURNS BIGINT
LANGUAGE sql AS $f$ SELECT id FROM projects WHERE title LIKE '%' || p_keyword || '%' $f$;

CREATE FUNCTION pg_temp.expect_error(p_name TEXT, p_sql TEXT, p_sqlstate TEXT) RETURNS VOID
LANGUAGE plpgsql AS $f$
DECLARE
    v_state TEXT;
    v_msg   TEXT;
BEGIN
    BEGIN
        EXECUTE p_sql;
    EXCEPTION WHEN OTHERS THEN
        v_state := SQLSTATE;
        v_msg   := SQLERRM;
    END;

    IF v_state IS NULL THEN
        INSERT INTO test_results (outcome, test, detail)
        VALUES ('FAIL', p_name, 'statement was ACCEPTED (expected ' || p_sqlstate || ')');
    ELSIF v_state = p_sqlstate THEN
        INSERT INTO test_results (outcome, test, detail)
        VALUES ('PASS', p_name, v_state || ' ' || v_msg);
    ELSE
        INSERT INTO test_results (outcome, test, detail)
        VALUES ('FAIL', p_name, 'wrong error ' || v_state || ' (expected ' || p_sqlstate || '): ' || v_msg);
    END IF;
END;
$f$;

CREATE FUNCTION pg_temp.expect_state(p_name TEXT, p_setup TEXT, p_check TEXT) RETURNS VOID
LANGUAGE plpgsql AS $f$
DECLARE
    v_ok      BOOLEAN;
    v_outcome TEXT;
    v_detail  TEXT;
BEGIN
    BEGIN
        EXECUTE p_setup;
        EXECUTE p_check INTO v_ok;
        IF v_ok THEN
            v_outcome := 'PASS'; v_detail := 'state is as expected';
        ELSE
            v_outcome := 'FAIL'; v_detail := 'check query returned false';
        END IF;
        RAISE EXCEPTION 'undo' USING ERRCODE = 'ZZ001';   -- undo the change
    EXCEPTION
        WHEN SQLSTATE 'ZZ001' THEN NULL;
        WHEN OTHERS THEN
            v_outcome := 'FAIL'; v_detail := 'unexpected error ' || SQLSTATE || ': ' || SQLERRM;
    END;
    INSERT INTO test_results (outcome, test, detail) VALUES (v_outcome, p_name, v_detail);
END;
$f$;

-- =============================================================================
-- A. Users: unique e-mail, formats, plain-text password, NOT NULL, enum
-- =============================================================================
SELECT pg_temp.expect_error('T01 duplicate e-mail', $t$
    INSERT INTO users (first_name, last_name, email, password_hash)
    VALUES ('تست', 'یک', 'ali.rezaei@example.com', '$2b$12$abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXY')
$t$, '23505');

SELECT pg_temp.expect_error('T02 duplicate e-mail with different letter case', $t$
    INSERT INTO users (first_name, last_name, email, password_hash)
    VALUES ('تست', 'دو', 'ALI.Rezaei@Example.com', '$2b$12$abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXY')
$t$, '23505');

SELECT pg_temp.expect_error('T03 malformed e-mail', $t$
    INSERT INTO users (first_name, last_name, email, password_hash)
    VALUES ('تست', 'سه', 'not-an-email', '$2b$12$abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXY')
$t$, '23514');

SELECT pg_temp.expect_error('T04 plain-text password (too short to be a hash)', $t$
    INSERT INTO users (first_name, last_name, email, password_hash)
    VALUES ('تست', 'چهار', 'plain@example.com', 'MyPlainPass1')
$t$, '23514');

SELECT pg_temp.expect_error('T05 malformed phone number', $t$
    INSERT INTO users (first_name, last_name, email, phone, password_hash)
    VALUES ('تست', 'پنج', 'phone@example.com', '12345', '$2b$12$abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXY')
$t$, '23514');

SELECT pg_temp.expect_error('T06 NULL last name (NOT NULL)', $t$
    INSERT INTO users (first_name, last_name, email, password_hash)
    VALUES ('تست', NULL, 'null@example.com', '$2b$12$abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXY')
$t$, '23502');

SELECT pg_temp.expect_error('T07 invalid account status value', $t$
    INSERT INTO users (first_name, last_name, email, password_hash, status)
    VALUES ('تست', 'هفت', 'status@example.com', '$2b$12$abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXY', 'banned')
$t$, '22P02');

-- =============================================================================
-- B. Foreign keys
-- =============================================================================
SELECT pg_temp.expect_error('T08 proposal for a non-existent project (invalid FK)', format($t$
    INSERT INTO proposals (project_id, freelancer_id, amount, cover_letter)
    VALUES (999999, %s, 1000000, 'پیشنهاد آزمایشی')
$t$, pg_temp.uid('reza.mohammadi@example.com')), '23503');

SELECT pg_temp.expect_error('T09 proposal by a non-existent freelancer (invalid FK)', format($t$
    INSERT INTO proposals (project_id, freelancer_id, amount, cover_letter)
    VALUES (%s, 999999, 1000000, 'پیشنهاد آزمایشی')
$t$, pg_temp.pid('لوگو')), '23503');

SELECT pg_temp.expect_error('T10 project with a non-existent employer (invalid FK)', $t$
    INSERT INTO projects (employer_id, title, description, pricing_type, budget)
    VALUES (999999, 'پروژه آزمایشی', 'توضیحات', 'fixed', 1000000)
$t$, '23503');

SELECT pg_temp.expect_error('T11 project_skills with a non-existent skill (invalid FK)', format($t$
    INSERT INTO project_skills (project_id, skill_id) VALUES (%s, 999999)
$t$, pg_temp.pid('لوگو')), '23503');

-- =============================================================================
-- C. Duplicate proposal
-- =============================================================================
SELECT pg_temp.expect_error('T12 same freelancer sends a second proposal for the same project', format($t$
    INSERT INTO proposals (project_id, freelancer_id, amount, cover_letter)
    VALUES (%s, %s, 40000000, 'پیشنهاد تکراری')
$t$, pg_temp.pid('فروشگاه'), pg_temp.uid('reza.mohammadi@example.com')), '23505');

-- =============================================================================
-- D. Invalid (zero / negative) budget, amount, rate, hours, days
-- =============================================================================
SELECT pg_temp.expect_error('T13 project budget = 0', format($t$
    INSERT INTO projects (employer_id, title, description, pricing_type, budget)
    VALUES (%s, 'بودجه صفر', 'توضیحات', 'fixed', 0)
$t$, pg_temp.uid('sara.karimi@example.com')), '23514');

SELECT pg_temp.expect_error('T14 project budget < 0', format($t$
    INSERT INTO projects (employer_id, title, description, pricing_type, budget)
    VALUES (%s, 'بودجه منفی', 'توضیحات', 'fixed', -5000)
$t$, pg_temp.uid('sara.karimi@example.com')), '23514');

SELECT pg_temp.expect_error('T15 hourly project with hourly rate = 0', format($t$
    INSERT INTO projects (employer_id, title, description, pricing_type, budget)
    VALUES (%s, 'نرخ ساعتی صفر', 'توضیحات', 'hourly', 0)
$t$, pg_temp.uid('sara.karimi@example.com')), '23514');

SELECT pg_temp.expect_error('T16 proposal amount = 0', format($t$
    INSERT INTO proposals (project_id, freelancer_id, amount, cover_letter)
    VALUES (%s, %s, 0, 'مبلغ صفر')
$t$, pg_temp.pid('لوگو'), pg_temp.uid('negar.hosseini@example.com')), '23514');

SELECT pg_temp.expect_error('T17 proposal amount < 0', format($t$
    INSERT INTO proposals (project_id, freelancer_id, amount, cover_letter)
    VALUES (%s, %s, -100, 'مبلغ منفی')
$t$, pg_temp.pid('لوگو'), pg_temp.uid('negar.hosseini@example.com')), '23514');

SELECT pg_temp.expect_error('T18 estimated hours = 0 (hourly project)', format($t$
    INSERT INTO projects (employer_id, title, description, pricing_type, budget, status)
    VALUES (%s, 'پروژه ساعتی آزمایشی', 'توضیحات', 'hourly', 500000, 'open');
    INSERT INTO proposals (project_id, freelancer_id, amount, cover_letter, estimated_hours)
    VALUES ((SELECT id FROM projects WHERE title = 'پروژه ساعتی آزمایشی'), %s, 400000, 'ساعت صفر', 0)
$t$, pg_temp.uid('sara.karimi@example.com'), pg_temp.uid('negar.hosseini@example.com')), '23514');

SELECT pg_temp.expect_error('T19 estimated days = 0', format($t$
    INSERT INTO proposals (project_id, freelancer_id, amount, cover_letter, estimated_days)
    VALUES (%s, %s, 5000000, 'روز صفر', 0)
$t$, pg_temp.pid('لوگو'), pg_temp.uid('negar.hosseini@example.com')), '23514');

SELECT pg_temp.expect_error('T20 estimated hours on a fixed-price project', format($t$
    INSERT INTO proposals (project_id, freelancer_id, amount, cover_letter, estimated_hours)
    VALUES (%s, %s, 5000000, 'ساعت برای پروژه ثابت', 40)
$t$, pg_temp.pid('لوگو'), pg_temp.uid('negar.hosseini@example.com')), '23514');

-- =============================================================================
-- E. Who may send proposals / create projects
-- =============================================================================
SELECT pg_temp.expect_error('T21 employer sends a proposal for his/her own project', format($t$
    INSERT INTO proposals (project_id, freelancer_id, amount, cover_letter)
    VALUES (%s, %s, 40000000, 'پیشنهاد به پروژه خودم')
$t$, pg_temp.pid('فروشگاه'), pg_temp.uid('sara.karimi@example.com')), '23514');

SELECT pg_temp.expect_error('T22 proposal for a project that is not open (in_progress)', format($t$
    INSERT INTO proposals (project_id, freelancer_id, amount, cover_letter)
    VALUES (%s, %s, 700000, 'پروژه در حال انجام است')
$t$, pg_temp.pid('داشبورد'), pg_temp.uid('sara.karimi@example.com')), '23514');

SELECT pg_temp.expect_error('T23 proposal for a draft project', format($t$
    INSERT INTO projects (employer_id, title, description, pricing_type, budget, status)
    VALUES (%s, 'پیش‌نویس آزمایشی', 'توضیحات', 'fixed', 1000000, 'draft');
    INSERT INTO proposals (project_id, freelancer_id, amount, cover_letter)
    VALUES ((SELECT id FROM projects WHERE title = 'پیش‌نویس آزمایشی'), %s, 900000, 'پیشنهاد به پیش‌نویس')
$t$, pg_temp.uid('sara.karimi@example.com'), pg_temp.uid('negar.hosseini@example.com')), '23514');

SELECT pg_temp.expect_error('T24 proposal inserted directly as accepted', format($t$
    INSERT INTO proposals (project_id, freelancer_id, amount, cover_letter, status)
    VALUES (%s, %s, 5000000, 'مستقیم پذیرفته‌شده', 'accepted')
$t$, pg_temp.pid('لوگو'), pg_temp.uid('negar.hosseini@example.com')), '23514');

SELECT pg_temp.expect_error('T25 admin sends a proposal', format($t$
    INSERT INTO proposals (project_id, freelancer_id, amount, cover_letter)
    VALUES (%s, %s, 5000000, 'پیشنهاد مدیر')
$t$, pg_temp.pid('لوگو'), pg_temp.uid('admin@marketplace.test')), '23514');

SELECT pg_temp.expect_error('T26 admin creates a project', format($t$
    INSERT INTO projects (employer_id, title, description, pricing_type, budget)
    VALUES (%s, 'پروژه مدیر', 'توضیحات', 'fixed', 1000000)
$t$, pg_temp.uid('admin@marketplace.test')), '23514');

SELECT pg_temp.expect_error('T27 admin gets a user profile', format($t$
    INSERT INTO profiles_user (user_id, professional_title) VALUES (%s, 'مدیر')
$t$, pg_temp.uid('admin@marketplace.test')), '23514');

SELECT pg_temp.expect_error('T28 grant admin access to an account that already owns projects', format($t$
    INSERT INTO admins (user_id) VALUES (%s)
$t$, pg_temp.uid('ali.rezaei@example.com')), '23514');

SELECT pg_temp.expect_error('T29 second profile for the same user', format($t$
    INSERT INTO profiles_user (user_id, professional_title) VALUES (%s, 'پروفایل دوم')
$t$, pg_temp.uid('reza.mohammadi@example.com')), '23505');

-- =============================================================================
-- F. At most ONE accepted proposal per project
-- =============================================================================
-- F1: business flow. The project of the web shop has two pending proposals;
--     accepting the first one rejects the other, so a second acceptance fails.
SELECT pg_temp.expect_error('T30 accept a second proposal of the same project (workflow rule)', format($t$
    UPDATE proposals SET status = 'accepted'
     WHERE project_id = %1$s AND freelancer_id = %2$s;
    UPDATE proposals SET status = 'accepted'
     WHERE project_id = %1$s AND freelancer_id = %3$s;
$t$, pg_temp.pid('فروشگاه'),
     pg_temp.uid('ali.rezaei@example.com'),
     pg_temp.uid('reza.mohammadi@example.com')), '23514');

-- F2: last line of defence. Even with the validation trigger switched off, the
--     partial unique index refuses a second accepted proposal for a project.
SELECT pg_temp.expect_error('T31 second accepted proposal blocked by the partial unique index', format($t$
    ALTER TABLE proposals DISABLE TRIGGER trg_proposals_validate;
    UPDATE proposals SET status = 'accepted'
     WHERE project_id = %s AND freelancer_id = %s;
    ALTER TABLE proposals ENABLE TRIGGER trg_proposals_validate;
$t$, pg_temp.pid('داشبورد'), pg_temp.uid('reza.mohammadi@example.com')), '23505');

-- =============================================================================
-- G. Status machines
-- =============================================================================
SELECT pg_temp.expect_error('T32 illegal project transition open -> completed', format($t$
    UPDATE projects SET status = 'completed' WHERE id = %s
$t$, pg_temp.pid('فروشگاه')), '23514');

SELECT pg_temp.expect_error('T33 project -> in_progress without an accepted proposal', format($t$
    UPDATE projects SET status = 'in_progress' WHERE id = %s
$t$, pg_temp.pid('لوگو')), '23514');

SELECT pg_temp.expect_error('T34 reopen a completed project', format($t$
    UPDATE projects SET status = 'completed' WHERE id = %1$s;
    UPDATE projects SET status = 'open'      WHERE id = %1$s;
$t$, pg_temp.pid('داشبورد')), '23514');

SELECT pg_temp.expect_error('T35 withdraw an already accepted proposal', format($t$
    UPDATE proposals SET status = 'withdrawn'
     WHERE project_id = %s AND freelancer_id = %s
$t$, pg_temp.pid('داشبورد'), pg_temp.uid('negar.hosseini@example.com')), '23514');

SELECT pg_temp.expect_error('T36 edit the amount of a proposal that is no longer pending', format($t$
    UPDATE proposals SET amount = 1
     WHERE project_id = %s AND freelancer_id = %s
$t$, pg_temp.pid('داشبورد'), pg_temp.uid('negar.hosseini@example.com')), '23514');

SELECT pg_temp.expect_error('T37 change the pricing type after proposals were received', format($t$
    UPDATE projects SET pricing_type = 'hourly' WHERE id = %s
$t$, pg_temp.pid('فروشگاه')), '23514');

SELECT pg_temp.expect_error('T38 change the employer of a project', format($t$
    UPDATE projects SET employer_id = %s WHERE id = %s
$t$, pg_temp.uid('reza.mohammadi@example.com'), pg_temp.pid('فروشگاه')), '23514');

-- =============================================================================
-- H. Deleting data (no silent cascade of history)
-- =============================================================================
SELECT pg_temp.expect_error('T39 delete a user who owns projects / proposals', format($t$
    DELETE FROM users WHERE id = %s
$t$, pg_temp.uid('sara.karimi@example.com')), '23503');

SELECT pg_temp.expect_error('T40 delete a project that is not a draft', format($t$
    DELETE FROM projects WHERE id = %s
$t$, pg_temp.pid('فروشگاه')), '23514');

SELECT pg_temp.expect_error('T41 delete a skill that is in use', $t$
    DELETE FROM skills WHERE name = 'Python'
$t$, '23503');

SELECT pg_temp.expect_error('T42 delete a category that is in use', $t$
    DELETE FROM categories WHERE title = 'تحلیل داده'
$t$, '23503');

-- =============================================================================
-- I. Unique names, certificate dates
-- =============================================================================
SELECT pg_temp.expect_error('T43 duplicate skill name (different letter case)', $t$
    INSERT INTO skills (name) VALUES ('python')
$t$, '23505');

SELECT pg_temp.expect_error('T44 duplicate category title', $t$
    INSERT INTO categories (title) VALUES ('تحلیل داده')
$t$, '23505');

SELECT pg_temp.expect_error('T45 certificate that expires before it was issued', format($t$
    INSERT INTO certificates (profile_id, title, issued_date, expires_date)
    VALUES ((SELECT id FROM profiles_user WHERE user_id = %s), 'گواهی نامعتبر', DATE '2025-01-01', DATE '2024-01-01')
$t$, pg_temp.uid('reza.mohammadi@example.com')), '23514');

-- =============================================================================
-- J. Positive scenarios (valid operations must work and keep the data consistent)
-- =============================================================================
SELECT pg_temp.expect_state('S01 accepting a proposal: project -> in_progress, other pending proposals -> rejected',
    format($t$
        UPDATE proposals SET status = 'accepted'
         WHERE project_id = %1$s AND freelancer_id = %2$s
    $t$, pg_temp.pid('فروشگاه'), pg_temp.uid('ali.rezaei@example.com')),
    format($t$
        SELECT (SELECT status FROM projects  WHERE id = %1$s) = 'in_progress'
           AND (SELECT status FROM proposals WHERE project_id = %1$s AND freelancer_id = %2$s) = 'rejected'
           AND (SELECT count(*) FROM proposals WHERE project_id = %1$s AND status = 'accepted') = 1
    $t$, pg_temp.pid('فروشگاه'), pg_temp.uid('reza.mohammadi@example.com')));

SELECT pg_temp.expect_state('S02 cancelling a project rejects its pending proposals',
    format($t$ UPDATE projects SET status = 'cancelled' WHERE id = %s $t$, pg_temp.pid('فروشگاه')),
    format($t$
        SELECT NOT EXISTS (SELECT 1 FROM proposals WHERE project_id = %1$s AND status = 'pending')
           AND (SELECT count(*) FROM proposals WHERE project_id = %1$s AND status = 'rejected') = 2
    $t$, pg_temp.pid('فروشگاه')));

SELECT pg_temp.expect_state('S03 a freelancer may withdraw a pending proposal',
    format($t$
        UPDATE proposals SET status = 'withdrawn'
         WHERE project_id = %s AND freelancer_id = %s
    $t$, pg_temp.pid('فروشگاه'), pg_temp.uid('reza.mohammadi@example.com')),
    format($t$
        SELECT (SELECT status FROM proposals WHERE project_id = %s AND freelancer_id = %s) = 'withdrawn'
    $t$, pg_temp.pid('فروشگاه'), pg_temp.uid('reza.mohammadi@example.com')));

SELECT pg_temp.expect_state('S04 a valid new proposal on an open project is accepted by the database',
    format($t$
        INSERT INTO proposals (project_id, freelancer_id, amount, cover_letter, estimated_days)
        VALUES (%s, %s, 11000000, 'طراحی لوگو با سه پیشنهاد اولیه', 14)
    $t$, pg_temp.pid('لوگو'), pg_temp.uid('negar.hosseini@example.com')),
    format($t$
        SELECT EXISTS (SELECT 1 FROM proposals
                        WHERE project_id = %s AND freelancer_id = %s AND status = 'pending')
    $t$, pg_temp.pid('لوگو'), pg_temp.uid('negar.hosseini@example.com')));

SELECT pg_temp.expect_state('S05 a draft project can be published (draft -> open) and then receives proposals',
    format($t$
        INSERT INTO projects (employer_id, title, description, pricing_type, budget)
        VALUES (%s, 'پروژه پیش‌نویس آزمایشی', 'توضیحات', 'hourly', 600000);
        UPDATE projects SET status = 'open' WHERE title = 'پروژه پیش‌نویس آزمایشی';
        INSERT INTO proposals (project_id, freelancer_id, amount, cover_letter, estimated_hours)
        VALUES ((SELECT id FROM projects WHERE title = 'پروژه پیش‌نویس آزمایشی'), %s, 550000, 'پیشنهاد ساعتی', 80)
    $t$, pg_temp.uid('sara.karimi@example.com'), pg_temp.uid('reza.mohammadi@example.com')),
    $t$
        SELECT (SELECT status FROM projects WHERE title = 'پروژه پیش‌نویس آزمایشی') = 'open'
           AND EXISTS (SELECT 1 FROM proposals pr JOIN projects p ON p.id = pr.project_id
                        WHERE p.title = 'پروژه پیش‌نویس آزمایشی')
    $t$);

SELECT pg_temp.expect_state('S06 updated_at is refreshed automatically on UPDATE',
    format($t$ UPDATE users SET phone = '09121112233' WHERE id = %s $t$, pg_temp.uid('ali.rezaei@example.com')),
    format($t$ SELECT updated_at > created_at FROM users WHERE id = %s $t$, pg_temp.uid('ali.rezaei@example.com')));

SELECT pg_temp.expect_state('S07 sample data: no project has more than one accepted proposal',
    $t$ SELECT 1 $t$,
    $t$ SELECT NOT EXISTS (SELECT project_id FROM proposals WHERE status = 'accepted'
                            GROUP BY project_id HAVING count(*) > 1) $t$);

SELECT pg_temp.expect_state('S08 sample data: admin accounts own no projects, proposals or profiles',
    $t$ SELECT 1 $t$,
    $t$ SELECT NOT EXISTS (SELECT 1 FROM admins a
                            WHERE EXISTS (SELECT 1 FROM projects      WHERE employer_id   = a.user_id)
                               OR EXISTS (SELECT 1 FROM proposals     WHERE freelancer_id = a.user_id)
                               OR EXISTS (SELECT 1 FROM profiles_user WHERE user_id       = a.user_id)) $t$);

-- =============================================================================
-- Results
-- =============================================================================
SELECT outcome, test, detail FROM test_results ORDER BY id;

SELECT outcome, count(*) AS tests FROM test_results GROUP BY outcome ORDER BY outcome;

ROLLBACK;   -- the sample data is left untouched
