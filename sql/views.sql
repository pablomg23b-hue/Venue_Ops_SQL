-- =====================================================================
-- views.sql (optional convenience views; non-materialized)
-- NOTE: These are saved SELECTs for easier exploration. They always read
-- from base tables and compute results on the fly (no storage/refresh).
-- =====================================================================

SET search_path TO public;

-- ---------------------------------------------------------------------
-- View: daily_kpis_view
-- Builds daily KPIs by joining daily revenue, labor cost, and labor hours
-- Columns: venue_id, dt, revenue, labor_cost, labor_hours, labor_pct, rev_per_labor_hour
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW public.daily_kpis_view AS
WITH
  daily_revenue AS (
    SELECT venue_id, sale_date AS dt, SUM(gross_sales) AS revenue
    FROM public.sales
    GROUP BY venue_id, sale_date
  ),
  daily_labor_cost AS (
    SELECT venue_id, shift_date AS dt, SUM(hours_worked * hourly_rate) AS labor_cost
    FROM public.shifts
    GROUP BY venue_id, shift_date
  ),
  daily_labor_hours AS (
    SELECT venue_id, shift_date AS dt, SUM(hours_worked) AS labor_hours
    FROM public.shifts
    GROUP BY venue_id, shift_date
  )
SELECT
  r.venue_id,
  r.dt,
  r.revenue,
  c.labor_cost,
  h.labor_hours,
  (c.labor_cost / NULLIF(r.revenue, 0)) * 100 AS labor_pct,
  (r.revenue    / NULLIF(h.labor_hours, 0))    AS rev_per_labor_hour
FROM daily_revenue r
JOIN daily_labor_cost  c USING (venue_id, dt)
JOIN daily_labor_hours h USING (venue_id, dt);

-- ---------------------------------------------------------------------
-- View: monthly_kpis_view
-- Aggregates daily KPIs to month per venue
-- Columns: venue_id, month, monthly_revenue, monthly_labor_cost, monthly_labor_hours,
--          monthly_labor_pct, monthly_rev_per_labor_hr
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW public.monthly_kpis_view AS
SELECT
  venue_id,
  date_trunc('month', dt)::date AS month,
  SUM(revenue)      AS monthly_revenue,
  SUM(labor_cost)   AS monthly_labor_cost,
  SUM(labor_hours)  AS monthly_labor_hours,
  (SUM(labor_cost) / NULLIF(SUM(revenue), 0)) * 100 AS monthly_labor_pct,
  (SUM(revenue)     / NULLIF(SUM(labor_hours), 0))   AS monthly_rev_per_labor_hr
FROM public.daily_kpis_view
GROUP BY venue_id, date_trunc('month', dt)::date;

-- ---------------------------------------------------------------------
-- View: monthly_efficiency_leaderboard
-- Ranks venues within each month by efficiency (rev/hr desc, labor% asc)
-- Columns: month, venue_id, monthly_rev_per_labor_hr, monthly_labor_pct, efficiency_rank
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW public.monthly_efficiency_leaderboard AS
SELECT
  month,
  venue_id,
  monthly_rev_per_labor_hr,
  monthly_labor_pct,
  RANK() OVER (
    PARTITION BY month
    ORDER BY monthly_rev_per_labor_hr DESC, monthly_labor_pct ASC
  ) AS efficiency_rank
FROM public.monthly_kpis_view;

-- Usage examples:
-- SELECT * FROM public.daily_kpis_view LIMIT 5;
-- SELECT * FROM public.monthly_kpis_view ORDER BY venue_id, month;
-- SELECT * FROM public.monthly_efficiency_leaderboard ORDER BY month, efficiency_rank;
