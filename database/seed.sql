-- =============================================================================
-- Marketplace Freelance  |  Sample data
-- Run AFTER schema.sql on an empty database:
--   psql -U <user> -d lab_freelance -v ON_ERROR_STOP=1 -f database/seed.sql
--
-- Contents: 5 accounts (1 admin + 4 normal users), 3 categories, 5 skills,
--           3 projects, 4 proposals (1 accepted), profiles, portfolio items
--           and certificates.
-- Rows are linked by natural keys (email, skill name, project title), so the
-- script does not depend on the generated ids.
-- All password hashes below are fake placeholders in bcrypt format.
-- =============================================================================

BEGIN;

-- 1. Users: 1 admin + 4 normal users --------------------------------------------
INSERT INTO users (first_name, last_name, email, phone, password_hash, status) VALUES
 ('مریم',  'احمدی',  'admin@marketplace.test',      NULL,          '$2b$12$hQIjQWZacl2AQi9OZx3tA1Yx0KHAY6qLK6WkTpFrPgWsZ05IrNyH/', 'active'),
 ('علی',   'رضایی',  'ali.rezaei@example.com',      '09121234567', '$2b$12$aXZp1rJ/edLn.fc/ru3TBgbwE9aowmtcUAxyDOB.mEMBZfNYJsIYm', 'active'),
 ('سارا',  'کریمی',  'sara.karimi@example.com',     '09351234567', '$2b$12$1eUY9bNVprtQ6XjNx6d2AB3uPtuc4e5LelKBMAmwtxlEMS/rTwB1A', 'active'),
 ('رضا',   'محمدی',  'reza.mohammadi@example.com',  NULL,          '$2b$12$EEPMW5KymshEhlAyodHSMgIlPZSnSInQoua2BMz1yzX2UfxD4RMJz', 'active'),
 ('نگار',  'حسینی',  'negar.hosseini@example.com',  '09171234567', '$2b$12$EBByDDy6Kdl0q/GPWLgDjdmKutUMr5smSrbdXsY.jW0wMxlEHaiPH', 'active');

-- 2. Admin ------------------------------------------------------------------------
INSERT INTO admins (user_id)
SELECT id FROM users WHERE email = 'admin@marketplace.test';

-- 3. Skills (5) and categories (3) ------------------------------------------------
INSERT INTO skills (name) VALUES
 ('Python'), ('React'), ('SQL'), ('UX/UI Design'), ('Content Writing');

INSERT INTO categories (title) VALUES
 ('طراحی و توسعه وب'), ('تحلیل داده'), ('طراحی گرافیک');

-- 4. Profiles (normal users only; some columns are optional) ---------------------
INSERT INTO profiles_user (user_id, professional_title, bio, location)
SELECT u.id, v.title, v.bio, v.location
FROM (VALUES
 ('ali.rezaei@example.com',     'مهندس نرم‌افزار',               'چند سال تجربه در توسعه نرم‌افزار و کار با داده.',   'تهران'),
 ('sara.karimi@example.com',    'مدیر محصول',                    'کارفرمای پروژه‌های وب و برندینگ.',                   'اصفهان'),
 ('reza.mohammadi@example.com', 'توسعه‌دهنده فول‌استک',          NULL,                                                 'شیراز'),
 ('negar.hosseini@example.com', 'تحلیلگر داده و طراح داشبورد',   'علاقه‌مند به تصویرسازی داده و طراحی تجربه کاربری.',  NULL)
) AS v(email, title, bio, location)
JOIN users u ON u.email = v.email;

-- 5. Skills of users (profile <-> skill) ------------------------------------------
INSERT INTO user_skills (profile_id, skill_id)
SELECT pr.id, s.id
FROM (VALUES
 ('ali.rezaei@example.com',     'Python'),
 ('ali.rezaei@example.com',     'React'),
 ('reza.mohammadi@example.com', 'Python'),
 ('reza.mohammadi@example.com', 'React'),
 ('reza.mohammadi@example.com', 'SQL'),
 ('negar.hosseini@example.com', 'Python'),
 ('negar.hosseini@example.com', 'SQL'),
 ('negar.hosseini@example.com', 'UX/UI Design')
) AS v(email, skill)
JOIN users         u  ON u.email  = v.email
JOIN profiles_user pr ON pr.user_id = u.id
JOIN skills        s  ON s.name   = v.skill;

-- 6. Portfolio items and certificates ---------------------------------------------
INSERT INTO portfolio_items (profile_id, title, description, project_url)
SELECT pr.id, v.title, v.description, v.url
FROM (VALUES
 ('ali.rezaei@example.com',     'سامانه مدیریت انبار',        'وب‌اپلیکیشن مدیریت موجودی کالا.',        'https://example.com/portfolio/warehouse'),
 ('reza.mohammadi@example.com', 'فروشگاه آنلاین پوشاک',       'فروشگاه اینترنتی با React و Python.',     'https://example.com/portfolio/shop'),
 ('reza.mohammadi@example.com', 'پنل مدیریت محتوا',           NULL,                                      NULL),
 ('negar.hosseini@example.com', 'داشبورد تحلیل فروش',         'داشبورد تعاملی برای یک شرکت پخش.',        'https://example.com/portfolio/sales-dashboard')
) AS v(email, title, description, url)
JOIN users u         ON u.email = v.email
JOIN profiles_user pr ON pr.user_id = u.id;

INSERT INTO certificates (profile_id, title, issuer, issued_date, expires_date, credential_url)
SELECT pr.id, v.title, v.issuer, v.issued_date::date, v.expires_date::date, v.url
FROM (VALUES
 ('reza.mohammadi@example.com', 'Front-End Developer Certificate', 'Example Academy', '2023-09-01', NULL,         'https://example.com/cert/frontend'),
 ('negar.hosseini@example.com', 'Data Analytics Certificate',      'Example Academy', '2024-03-15', '2027-03-15', 'https://example.com/cert/data')
) AS v(email, title, issuer, issued_date, expires_date, url)
JOIN users u         ON u.email = v.email
JOIN profiles_user pr ON pr.user_id = u.id;

-- 7. Projects (3) -----------------------------------------------------------------
--    P1 fixed price (Sara), P2 hourly (Ali), P3 fixed price (Sara).
--    Ali is an employer (P2) AND a freelancer (he proposes for P1 below).
INSERT INTO projects (employer_id, title, description, pricing_type, budget, status, deadline)
SELECT u.id, v.title, v.description, v.pricing::pricing_type, v.budget, v.status::project_status, v.deadline::date
FROM (VALUES
 ('sara.karimi@example.com', 'توسعه وب‌سایت فروشگاه اینترنتی',
  'طراحی و پیاده‌سازی یک فروشگاه اینترنتی شامل سبد خرید و پرداخت آنلاین.',
  'fixed',  45000000.00, 'open', '2026-12-20'),
 ('ali.rezaei@example.com',  'تحلیل داده‌های فروش و ساخت داشبورد',
  'پاک‌سازی داده‌های فروش دو سال اخیر و ساخت داشبورد مدیریتی. بودجه = نرخ ساعتی.',
  'hourly',   800000.00, 'open', '2026-12-05'),
 ('sara.karimi@example.com', 'طراحی لوگو و هویت بصری برند',
  'طراحی لوگو، پالت رنگی و راهنمای هویت بصری برای یک استارتاپ.',
  'fixed',  12000000.00, 'open', NULL)
) AS v(email, title, description, pricing, budget, status, deadline)
JOIN users u ON u.email = v.email;

-- 8. Project categories (many-to-many) --------------------------------------------
INSERT INTO project_categories (project_id, category_id)
SELECT p.id, c.id
FROM (VALUES
 ('توسعه وب‌سایت فروشگاه اینترنتی',            'طراحی و توسعه وب'),
 ('تحلیل داده‌های فروش و ساخت داشبورد',        'تحلیل داده'),
 ('طراحی لوگو و هویت بصری برند',               'طراحی گرافیک'),
 ('طراحی لوگو و هویت بصری برند',               'طراحی و توسعه وب')
) AS v(project_title, category_title)
JOIN projects   p ON p.title = v.project_title
JOIN categories c ON c.title = v.category_title;

-- 9. Required skills of projects (many-to-many) -----------------------------------
INSERT INTO project_skills (project_id, skill_id)
SELECT p.id, s.id
FROM (VALUES
 ('توسعه وب‌سایت فروشگاه اینترنتی',            'Python'),
 ('توسعه وب‌سایت فروشگاه اینترنتی',            'React'),
 ('توسعه وب‌سایت فروشگاه اینترنتی',            'SQL'),
 ('تحلیل داده‌های فروش و ساخت داشبورد',        'Python'),
 ('تحلیل داده‌های فروش و ساخت داشبورد',        'SQL'),
 ('طراحی لوگو و هویت بصری برند',               'UX/UI Design'),
 ('طراحی لوگو و هویت بصری برند',               'Content Writing')
) AS v(project_title, skill)
JOIN projects p ON p.title = v.project_title
JOIN skills   s ON s.name  = v.skill;

-- 10. Proposals (4, all sent as 'pending') ------------------------------------------
--     amount = total price on fixed projects, hourly rate on hourly projects
INSERT INTO proposals (project_id, freelancer_id, amount, cover_letter, estimated_days, estimated_hours)
SELECT p.id, f.id, v.amount, v.cover_letter, v.days, v.hours
FROM (VALUES
 ('توسعه وب‌سایت فروشگاه اینترنتی',     'ali.rezaei@example.com',      41000000.00, 'می‌توانم کل پروژه را در مدت مشخص تحویل بدهم.',      50, NULL::numeric),
 ('توسعه وب‌سایت فروشگاه اینترنتی',     'reza.mohammadi@example.com',  43000000.00, 'تجربه ساخت چند فروشگاه آنلاین مشابه دارم.',          45, NULL),
 ('تحلیل داده‌های فروش و ساخت داشبورد', 'negar.hosseini@example.com',    750000.00, 'روی داشبوردهای فروش کار کرده‌ام؛ نمونه‌کار پیوست است.', 30, 120),
 ('تحلیل داده‌های فروش و ساخت داشبورد', 'reza.mohammadi@example.com',    800000.00, 'آماده شروع فوری هستم.',                                 25, 100)
) AS v(project_title, email, amount, cover_letter, days, hours)
JOIN projects p ON p.title = v.project_title
JOIN users    f ON f.email = v.email;

-- 11. The employer of the hourly project accepts Negar's proposal -------------------
--     The triggers then (a) move the project to in_progress and
--     (b) reject the other pending proposal (Reza's) of that project.
UPDATE proposals
   SET status = 'accepted'
 WHERE project_id    = (SELECT id FROM projects WHERE title = 'تحلیل داده‌های فروش و ساخت داشبورد')
   AND freelancer_id = (SELECT id FROM users    WHERE email = 'negar.hosseini@example.com');

COMMIT;

-- Quick sanity check of what was loaded -------------------------------------------
SELECT 'users'              AS table_name, count(*) AS rows FROM users
UNION ALL SELECT 'admins',             count(*) FROM admins
UNION ALL SELECT 'profiles_user',      count(*) FROM profiles_user
UNION ALL SELECT 'skills',             count(*) FROM skills
UNION ALL SELECT 'categories',         count(*) FROM categories
UNION ALL SELECT 'user_skills',        count(*) FROM user_skills
UNION ALL SELECT 'portfolio_items',    count(*) FROM portfolio_items
UNION ALL SELECT 'certificates',       count(*) FROM certificates
UNION ALL SELECT 'projects',           count(*) FROM projects
UNION ALL SELECT 'project_categories', count(*) FROM project_categories
UNION ALL SELECT 'project_skills',     count(*) FROM project_skills
UNION ALL SELECT 'proposals',          count(*) FROM proposals;
-- Expected: users 5, admins 1, profiles_user 4, skills 5, categories 3,
--           user_skills 8, portfolio_items 4, certificates 2, projects 3,
--           project_categories 4, project_skills 7, proposals 4
