--- =====================================================================
-- analysis.sql (final, CTE-first style)
-- Venue Ops – Core KPIs, Monthly Rollups, MoM deltas, and Leaderboards
-- NOTE: Dataset is synthetic and for practice; insights are illustrative.
-- Guiding principle: keep everything **CTE-based** for clarity.
-- =====================================================================

SET search_path TO public;

-- =====================================================================
-- 1) DAILY BUILDING BLOCKS (CTEs only)
-- Goal: produce one row per (venue_id, dt) for revenue, labor cost, labor hours
-- Output columns:
--   daily_revenue:      venue_id, dt, revenue
--   daily_labor_cost:   venue_id, dt, labor_cost
--   daily_labor_hours:  venue_id, dt, labor_hours
--   daily_kpis:         venue_id, dt, revenue, labor_cost, labor_hours, labor_pct, rev_per_labor_hour
-- =====================================================================
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
),
daily_kpis AS (
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
JOIN daily_labor_hours h USING (venue_id, dt)
)
SELECT *
FROM daily_kpis
ORDER BY venue_id, dt;
-- RESULT SAMPLE
-- venue_id | dt         | revenue | labor_cost | labor_hours | labor_pct | rev_per_labor_hour
-- 1        | 2024-01-01 |  5423.0 |    910.0   |    28.0     |   16.78   |   193.68
-- 1        | 2024-01-02 |  4980.0 |    865.0   |    27.0     |   17.37   |   184.44

-- =====================================================================
-- 2) MONTHLY ROLLUPS (built from daily_kpis CTE)
-- Goal: aggregate daily KPIs to month per venue
-- Output columns (monthly_kpis):
--   venue_id, month, monthly_revenue, monthly_labor_cost, monthly_labor_hours,
--   monthly_labor_pct, monthly_rev_per_labor_hr
-- =====================================================================
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
),
daily_kpis AS (
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
JOIN daily_labor_hours h USING (venue_id, dt)
),
monthly_kpis AS (
SELECT
venue_id,
date_trunc('month', dt)::date AS month,
SUM(revenue)      AS monthly_revenue,
SUM(labor_cost)   AS monthly_labor_cost,
SUM(labor_hours)  AS monthly_labor_hours,
(SUM(labor_cost) / NULLIF(SUM(revenue), 0)) * 100 AS monthly_labor_pct,
(SUM(revenue)     / NULLIF(SUM(labor_hours), 0))   AS monthly_rev_per_labor_hr
FROM daily_kpis
GROUP BY venue_id, date_trunc('month', dt)::date
)
SELECT *
FROM monthly_kpis
ORDER BY venue_id, month;

-- RESULT SAMPLE
-- venue_id | month      | monthly_revenue | monthly_labor_cost | monthly_labor_hours | monthly_labor_pct | monthly_rev_per_labor_hr
-- 1        | 2024-01-01 |    162,340.00   |     28,750.00      |       820.0         |       17.7        |         198.0

-- =====================================================================
-- 3) MONTH-OVER-MONTH (MoM) DELTAS (from monthly_kpis CTE)
-- Goal: compute MoM deltas per venue using window functions
-- Output columns: venue_id, month, monthly_revenue, monthly_labor_pct, monthly_rev_per_labor_hr,
--                 revenue_mom, labor_pct_mom, rplh_mom
-- =====================================================================
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
),
daily_kpis AS (
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
JOIN daily_labor_hours h USING (venue_id, dt)
),
monthly_kpis AS (
SELECT
venue_id,
date_trunc('month', dt)::date AS month,
SUM(revenue)      AS monthly_revenue,
SUM(labor_cost)   AS monthly_labor_cost,
SUM(labor_hours)  AS monthly_labor_hours,
(SUM(labor_cost) / NULLIF(SUM(revenue), 0)) * 100 AS monthly_labor_pct,
(SUM(revenue)     / NULLIF(SUM(labor_hours), 0))   AS monthly_rev_per_labor_hr
FROM daily_kpis
GROUP BY venue_id, date_trunc('month', dt)::date
)
SELECT
venue_id,
month,
monthly_revenue,
monthly_labor_pct,
monthly_rev_per_labor_hr,
monthly_revenue
- LAG(monthly_revenue)          OVER (PARTITION BY venue_id ORDER BY month) AS revenue_mom,
monthly_labor_pct
- LAG(monthly_labor_pct)        OVER (PARTITION BY venue_id ORDER BY month) AS labor_pct_mom,
monthly_rev_per_labor_hr
- LAG(monthly_rev_per_labor_hr) OVER (PARTITION BY venue_id ORDER BY month) AS rplh_mom
FROM monthly_kpis
ORDER BY venue_id, month;
-- RESULT SAMPLE
-- venue_id | month      | monthly_revenue | revenue_mom | monthly_labor_pct | labor_pct_mom | monthly_rev_per_labor_hr | rplh_mom
-- 1        | 2024-01-01 |    162,340.00   |    NULL     |       17.7        |    NULL       |           198.0          |  NULL
-- 1        | 2024-02-01 |    158,900.00   |  -3,440.00  |       17.9        |    +0.2       |           196.5          |  -1.5

-- =====================================================================
-- 4) MONTHLY EFFICIENCY LEADERBOARD (ALL MONTHS) – CTE chain only
-- Goal: rank venues per month by efficiency (higher rev/hr better, tie-break lower labor %)
-- Output columns: month, venue_id, monthly_rev_per_labor_hr, monthly_labor_pct, efficiency_rank
-- =====================================================================
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
),
daily_kpis AS (
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
JOIN daily_labor_hours h USING (venue_id, dt)
),
monthly_kpis AS (
SELECT
venue_id,
date_trunc('month', dt)::date AS month,
SUM(revenue)      AS monthly_revenue,
SUM(labor_cost)   AS monthly_labor_cost,
SUM(labor_hours)  AS monthly_labor_hours,
(SUM(labor_cost) / NULLIF(SUM(revenue), 0)) * 100 AS monthly_labor_pct,
(SUM(revenue)     / NULLIF(SUM(labor_hours), 0))   AS monthly_rev_per_labor_hr
FROM daily_kpis
GROUP BY venue_id, date_trunc('month', dt)::date
),
leaderboard AS (
SELECT
month,
venue_id,
monthly_rev_per_labor_hr,
monthly_labor_pct,
RANK() OVER (
PARTITION BY month
ORDER BY monthly_rev_per_labor_hr DESC, monthly_labor_pct ASC
) AS efficiency_rank
FROM monthly_kpis
)
SELECT *
FROM leaderboard
ORDER BY month, efficiency_rank, venue_id;
-- RESULT SAMPLE
-- month      | venue_id | efficiency_rank | monthly_rev_per_labor_hr | monthly_labor_pct
-- 2024-01-01 |    3     |        1        |           205.1          |       16.9
-- 2024-01-01 |    1     |        2        |           197.4          |       17.6
-- 2024-01-01 |    2     |        3        |           189.0          |       18.2

-- =====================================================================
-- 5) RANK DISTRIBUTION BY VENUE (counts of 1st/2nd/3rd) – CTEs only
-- Goal: summarize consistency — how often each venue ranks 1st/2nd/3rd across months
-- Output columns: venue_id, rank_1_count, rank_2_count, rank_3_count
-- =====================================================================
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
),
daily_kpis AS (
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
JOIN daily_labor_hours h USING (venue_id, dt)
),
monthly_kpis AS (
SELECT
venue_id,
date_trunc('month', dt)::date AS month,
SUM(revenue)      AS monthly_revenue,
SUM(labor_cost)   AS monthly_labor_cost,
SUM(labor_hours)  AS monthly_labor_hours,
(SUM(labor_cost) / NULLIF(SUM(revenue), 0)) * 100 AS monthly_labor_pct,
(SUM(revenue)     / NULLIF(SUM(labor_hours), 0))   AS monthly_rev_per_labor_hr
FROM daily_kpis
GROUP BY venue_id, date_trunc('month', dt)::date
),
leaderboard AS (
SELECT
month,
venue_id,
monthly_rev_per_labor_hr,
monthly_labor_pct,
RANK() OVER (
PARTITION BY month
ORDER BY monthly_rev_per_labor_hr DESC, monthly_labor_pct ASC
) AS efficiency_rank
FROM monthly_kpis
)
SELECT
venue_id,
SUM(CASE WHEN efficiency_rank = 1 THEN 1 ELSE 0 END) AS rank_1_count,
SUM(CASE WHEN efficiency_rank = 2 THEN 1 ELSE 0 END) AS rank_2_count,
SUM(CASE WHEN efficiency_rank = 3 THEN 1 ELSE 0 END) AS rank_3_count
FROM leaderboard
GROUP BY venue_id
ORDER BY rank_1_count DESC, venue_id;
-- RESULT 
-- venue_id | rank_1_count | rank_2_count | rank_3_count
--    3     |      12      |       0      |      0
--    1     |       0      |      12      |      0
--    2     |       0      |       0      |     12
