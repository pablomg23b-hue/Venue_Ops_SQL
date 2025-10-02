-- =====================================================================
-- Venue Ops Schema
-- Enforces business rules & data integrity at the DB level
-- Includes ON DELETE CASCADE with preview/delete helper functions
-- =====================================================================

SET search_path TO public;

-- ==============================================================
-- Venues
-- Each venue is uniquely identified by venue_id
-- ==============================================================
CREATE TABLE IF NOT EXISTS public.venues (
  venue_id     SERIAL PRIMARY KEY,
  city         VARCHAR(100) NOT NULL,
  capacity     INT NOT NULL CHECK (capacity > 0),
  opened_date  DATE NOT NULL
);

-- ==============================================================
-- Sales
-- One record per venue per day
-- ==============================================================
CREATE TABLE IF NOT EXISTS public.sales (
  venue_id     INT NOT NULL REFERENCES public.venues(venue_id) ON DELETE CASCADE,
  sale_date    DATE NOT NULL,
  covers       INT NOT NULL CHECK (covers >= 0),
  gross_sales  NUMERIC(12,2) NOT NULL CHECK (gross_sales >= 0),
  CONSTRAINT pk_sales PRIMARY KEY (venue_id, sale_date)
);

-- ==============================================================
-- Shifts
-- One record per venue/date/role (Bartender, Server, Chef)
-- ==============================================================
CREATE TABLE IF NOT EXISTS public.shifts (
  shift_id      SERIAL PRIMARY KEY,
  venue_id      INT NOT NULL REFERENCES public.venues(venue_id) ON DELETE CASCADE,
  shift_date    DATE NOT NULL,
  role          VARCHAR(50) NOT NULL,
  hours_worked  NUMERIC(6,2) NOT NULL CHECK (hours_worked >= 0),
  hourly_rate   NUMERIC(6,2) NOT NULL CHECK (hourly_rate >= 0),
  CONSTRAINT uq_shifts UNIQUE (venue_id, shift_date, role)
);

-- ==============================================================
-- Inventory Costs
-- One record per venue/category/month
-- ==============================================================
CREATE TABLE IF NOT EXISTS public.inventory_costs (
  venue_id      INT NOT NULL REFERENCES public.venues(venue_id) ON DELETE CASCADE,
  period_start  DATE NOT NULL,
  period_end    DATE NOT NULL,
  cost_category VARCHAR(50) NOT NULL,
  amount        NUMERIC(12,2) NOT NULL CHECK (amount >= 0),
  CONSTRAINT uq_inventory UNIQUE (venue_id, period_start, period_end, cost_category)
);

-- ==============================================================
-- Helper Functions for Safe Delete (preview + intentional delete)
-- ==============================================================

CREATE OR REPLACE FUNCTION public.preview_delete_venue(p_venue_id INT)
RETURNS TABLE(obj TEXT, rows BIGINT) AS $$
BEGIN
  RETURN QUERY SELECT 'sales'::text,           COUNT(*)::bigint FROM public.sales            WHERE venue_id = p_venue_id;
  RETURN QUERY SELECT 'shifts'::text,          COUNT(*)::bigint FROM public.shifts           WHERE venue_id = p_venue_id;
  RETURN QUERY SELECT 'inventory_costs'::text, COUNT(*)::bigint FROM public.inventory_costs  WHERE venue_id = p_venue_id;
  RETURN QUERY SELECT 'venues'::text,          1::bigint       WHERE EXISTS (SELECT 1 FROM public.venues WHERE venue_id = p_venue_id);
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.delete_venue(p_venue_id INT)
RETURNS VOID AS $$
BEGIN
  DELETE FROM public.venues WHERE venue_id = p_venue_id;
END; $$ LANGUAGE plpgsql;

