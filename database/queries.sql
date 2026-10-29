-- =============================================================================
-- Marketplace Freelance  |  Useful queries (run after schema.sql + seed.sql)
--   psql -U <user> -d lab_freelance -f database/queries.sql
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Q1. Open projects with their categories and employer
-- -----------------------------------------------------------------------------
SELECT p.id,
       p.title,
       p.pricing_type,
       p.budget,
       p.deadline,
       u.first_name || ' ' || u.last_name              AS employer,
       string_agg(c.title, ' ، ' ORDER BY c.title)     AS categories
FROM projects p
JOIN users u                   ON u.id = p.employer_id
LEFT JOIN project_categories pc ON pc.project_id = p.id
LEFT JOIN categories c          ON c.id = pc.category_id
WHERE p.status = 'open'
GROUP BY p.id, u.id
ORDER BY p.created_at DESC, p.id;
-- Expected with the sample data: 2 rows (the web-shop project and the logo
-- project); the data-analysis project is in_progress so it is not listed.

-- -----------------------------------------------------------------------------
-- Q2. Proposals of one project together with the freelancer's name
--     (change the keyword, or replace the sub-select with a project id)
-- -----------------------------------------------------------------------------
SELECT pr.id                                        AS proposal_id,
       f.first_name || ' ' || f.last_name           AS freelancer,
       f.email                                      AS freelancer_email,
       pr.amount,
       pr.estimated_days,
       pr.estimated_hours,
       pr.status,
       pr.created_at
FROM proposals pr
JOIN users f ON f.id = pr.freelancer_id
WHERE pr.project_id = (SELECT id FROM projects
                       WHERE title LIKE '%داشبورد%')
ORDER BY pr.created_at, pr.id;
-- Expected: 2 rows -> Negar (accepted), Reza (rejected automatically).

-- -----------------------------------------------------------------------------
-- Q3. Projects of every employer and the number of proposals each one received
--     (LEFT JOIN keeps projects with 0 proposals)
-- -----------------------------------------------------------------------------
SELECT u.id                                  AS employer_id,
       u.first_name || ' ' || u.last_name    AS employer,
       p.id                                  AS project_id,
       p.title,
       p.status,
       count(pr.id)                          AS proposals_count
FROM projects p
JOIN users u               ON u.id = p.employer_id
LEFT JOIN proposals pr     ON pr.project_id = p.id
GROUP BY u.id, p.id
ORDER BY u.id, p.id;
-- Expected: Ali -> 1 project (2 proposals); Sara -> 2 projects (2 and 0).

-- Q3-b. Same idea, one row per employer (total projects / total proposals)
SELECT u.id                                  AS employer_id,
       u.first_name || ' ' || u.last_name    AS employer,
       count(DISTINCT p.id)                  AS projects_count,
       count(pr.id)                          AS proposals_count
FROM users u
JOIN projects p            ON p.employer_id = u.id
LEFT JOIN proposals pr     ON pr.project_id = p.id
GROUP BY u.id
ORDER BY u.id;

-- -----------------------------------------------------------------------------
-- Q4. Required skills of every project
-- -----------------------------------------------------------------------------
SELECT p.id                                           AS project_id,
       p.title,
       string_agg(s.name, ' ، ' ORDER BY s.name)      AS required_skills
FROM projects p
LEFT JOIN project_skills ps ON ps.project_id = p.id
LEFT JOIN skills s          ON s.id = ps.skill_id
GROUP BY p.id
ORDER BY p.id;

-- -----------------------------------------------------------------------------
-- Extra queries (show the many-to-many design and the dual employer/freelancer role)
-- -----------------------------------------------------------------------------

-- Q5. Every proposal with project title, employer and freelancer
SELECT pr.id,
       p.title                                    AS project,
       e.first_name || ' ' || e.last_name         AS employer,
       f.first_name || ' ' || f.last_name         AS freelancer,
       p.pricing_type,
       pr.amount,
       pr.status
FROM proposals pr
JOIN projects p ON p.id = pr.project_id
JOIN users e    ON e.id = p.employer_id
JOIN users f    ON f.id = pr.freelancer_id
ORDER BY pr.id;

-- Q6. A user who is both employer and freelancer (Ali)
SELECT u.first_name || ' ' || u.last_name AS user_name,
       (SELECT count(*) FROM projects  WHERE employer_id   = u.id) AS projects_as_employer,
       (SELECT count(*) FROM proposals WHERE freelancer_id = u.id) AS proposals_as_freelancer
FROM users u
WHERE u.email = 'ali.rezaei@example.com';

-- Q7. Open projects that match the skills of a freelancer (Reza), best match first
SELECT p.id, p.title, count(*) AS matching_skills
FROM users u
JOIN profiles_user pr   ON pr.user_id = u.id
JOIN user_skills us     ON us.profile_id = pr.id
JOIN project_skills ps  ON ps.skill_id = us.skill_id
JOIN projects p         ON p.id = ps.project_id AND p.status = 'open'
WHERE u.email = 'reza.mohammadi@example.com'
GROUP BY p.id
ORDER BY matching_skills DESC, p.id;

-- Q8. Administrators and when they received administrative access
SELECT u.id, u.first_name || ' ' || u.last_name AS admin_name, u.email, a.granted_at
FROM admins a
JOIN users u ON u.id = a.user_id
ORDER BY a.granted_at;
