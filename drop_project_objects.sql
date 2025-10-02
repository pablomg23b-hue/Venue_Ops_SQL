-- =====================================================================
-- drop_project_objects.sql
-- ⚠️ WARNING: This will delete ONLY the Venue Ops project objects
-- (tables + functions) from the public schema.
-- Other objects in 'public' will be left untouched.
-- =====================================================================

-- Drop helper functions first
DROP FUNCTION IF EXISTS public.preview_delete_venue(INT);
DROP FUNCTION IF EXISTS public.delete_venue(INT);

-- Drop tables (children first, then parent)
DROP TABLE IF EXISTS public.inventory_costs;
DROP TABLE IF EXISTS public.shifts;
DROP TABLE IF EXISTS public.sales;
DROP TABLE IF EXISTS public.venues;
