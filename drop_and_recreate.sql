-- =====================================================================
-- drop_and_recreate.sql
-- ⚠️ WARNING: This will delete EVERYTHING in the 'public' schema
-- (all tables, functions, views, etc.), not just this project.
-- Use only inside the dedicated Docker container for this project.
-- =====================================================================

-- Drop the schema and everything inside it
DROP SCHEMA IF EXISTS public CASCADE;

-- Recreate schema
CREATE SCHEMA public;
SET search_path TO public;

-- Rebuild project objects (tables + helper functions)
\i /scripts/schema.sql