\set ON_ERROR_STOP on
-- Execute as the Cloud SQL administrative role against the application database.
-- Passwords are deliberately absent. Set them interactively with psql \password.
-- Aligned with bodyvision-infra-compose postgres/init/00_roles_schemas.sh (SCRUM-112).
BEGIN;
DO $bootstrap$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'bv_utilisateurs') THEN
    CREATE ROLE bv_utilisateurs LOGIN;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'bv_analytique') THEN
    CREATE ROLE bv_analytique LOGIN;
  END IF;
END
$bootstrap$;

-- Cloud SQL administrators are not PostgreSQL superusers. Membership is needed
-- before assigning schema ownership (including on the first execution).
GRANT bv_utilisateurs, bv_analytique TO CURRENT_USER;
CREATE SCHEMA IF NOT EXISTS utilisateurs AUTHORIZATION bv_utilisateurs;
CREATE SCHEMA IF NOT EXISTS analytique AUTHORIZATION bv_analytique;

-- Fail rather than silently changing ownership of a pre-existing schema.
DO $verify$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_namespace n JOIN pg_roles r ON r.oid = n.nspowner
    WHERE (n.nspname = 'utilisateurs' AND r.rolname <> 'bv_utilisateurs')
       OR (n.nspname = 'analytique' AND r.rolname <> 'bv_analytique')
  ) THEN
    RAISE EXCEPTION 'Unexpected schema ownership; inspect before changing owners';
  END IF;
END
$verify$;

-- Only schema owners have access; PostgreSQL 15+ grants PUBLIC usage on public.
REVOKE ALL ON SCHEMA utilisateurs FROM PUBLIC;
REVOKE ALL ON SCHEMA analytique FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM PUBLIC;

ALTER ROLE bv_utilisateurs SET search_path = utilisateurs;
ALTER ROLE bv_analytique SET search_path = analytique;
COMMIT;

SELECT n.nspname AS schema, r.rolname AS owner
FROM pg_namespace n JOIN pg_roles r ON r.oid = n.nspowner
WHERE n.nspname IN ('utilisateurs', 'analytique') ORDER BY n.nspname;
