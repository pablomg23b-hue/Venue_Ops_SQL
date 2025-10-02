-- Venue Ops – Data Quality Checks
SET search_path TO public;

-- ========================================================================

-- 1A) sales duplicates
SELECT venue_id, sale_date, COUNT(*) AS row_count
FROM public.sales
GROUP BY venue_id, sale_date
HAVING COUNT(*) > 1;
-- RESULT: PASS (0 rows)

-- 1B) shifts duplicates
SELECT venue_id, shift_date, role, COUNT(*) AS row_count
FROM public.shifts
GROUP BY venue_id, shift_date, role
HAVING COUNT(*) > 1;
-- RESULT: PASS (0 rows)

-- 1C) inventory_costs duplicates
SELECT venue_id, period_start, period_end, cost_category, COUNT(*) AS row_count
FROM public.inventory_costs
GROUP BY venue_id, period_start, period_end, cost_category
HAVING COUNT(*) > 1;
-- RESULT: PASS (0 rows)

-- ========================================================================

-- 2A) sales orphans
SELECT s.venue_id, COUNT(*) AS orphan_rows
FROM public.sales s
LEFT JOIN public.venues v ON v.venue_id = s.venue_id
WHERE v.venue_id IS NULL
GROUP BY s.venue_id;
-- RESULT: PASS (0 rows)

-- 2B) shifts orphans
SELECT s.venue_id, COUNT(*) AS orphan_rows
FROM public.shifts s
LEFT JOIN public.venues v ON v.venue_id = s.venue_id
WHERE v.venue_id IS NULL
GROUP BY s.venue_id;
-- RESULT: PASS (0 rows)

-- 2C) inventory_costs orphans
SELECT i.venue_id, COUNT(*) AS orphan_rows
FROM public.inventory_costs i
LEFT JOIN public.venues v ON v.venue_id = i.venue_id
WHERE v.venue_id IS NULL
GROUP BY i.venue_id;
-- RESULT: PASS (0 rows)

-- ========================================================================

-- 3A) sales nulls
SELECT
  SUM(CASE WHEN venue_id    IS NULL THEN 1 ELSE 0 END) AS null_venue_id,
  SUM(CASE WHEN sale_date   IS NULL THEN 1 ELSE 0 END) AS null_sale_date,
  SUM(CASE WHEN covers      IS NULL THEN 1 ELSE 0 END) AS null_covers,
  SUM(CASE WHEN gross_sales IS NULL THEN 1 ELSE 0 END) AS null_gross_sales
FROM public.sales;
-- RESULT: PASS (All 0)

-- 3B) shifts nulls
SELECT
  SUM(CASE WHEN shift_id    IS NULL THEN 1 ELSE 0 END) AS null_shift_id,
  SUM(CASE WHEN venue_id   IS NULL THEN 1 ELSE 0 END) AS null_venue_id,
  SUM(CASE WHEN shift_date      IS NULL THEN 1 ELSE 0 END) AS null_shift_date,
  SUM(CASE WHEN role IS NULL THEN 1 ELSE 0 END) AS null_role,
  SUM(CASE WHEN hours_worked IS NULL THEN 1 ELSE 0 END) AS null_hours_worked,
  SUM(CASE WHEN hourly_rate IS NULL THEN 1 ELSE 0 END) AS null_hourly_rate
FROM public.shifts;
-- RESULT: PASS (All 0)

-- 3C) inventory_costs nulls
SELECT
  SUM(CASE WHEN venue_id   IS NULL THEN 1 ELSE 0 END) AS null_venue_id,
  SUM(CASE WHEN period_start     IS NULL THEN 1 ELSE 0 END) AS null_period_start,
  SUM(CASE WHEN period_end IS NULL THEN 1 ELSE 0 END) AS null_period_end,
  SUM(CASE WHEN cost_category IS NULL THEN 1 ELSE 0 END) AS null_cost_category,
  SUM(CASE WHEN amount IS NULL THEN 1 ELSE 0 END) AS null_amount
FROM public.inventory_costs;
-- RESULT: PASS (All 0)

-- 3D) sales negatives
SELECT
  SUM(CASE WHEN covers      < 0 THEN 1 ELSE 0 END) AS neg_covers,
  SUM(CASE WHEN gross_sales < 0 THEN 1 ELSE 0 END) AS neg_gross_sales
FROM public.sales;
-- RESULT: PASS (All 0)

-- 3E) shifts negatives
SELECT
  SUM(CASE WHEN hours_worked      < 0 THEN 1 ELSE 0 END) AS neg_hours_worked,
  SUM(CASE WHEN hourly_rate < 0 THEN 1 ELSE 0 END) AS neg_hourly_rate
FROM public.shifts;
-- RESULT: PASS (All 0)

-- 3F) inventory_costs negatives
SELECT
  SUM(CASE WHEN amount < 0 THEN 1 ELSE 0 END) AS neg_amount
FROM public.inventory_costs;
-- RESULT: PASS (All 0)

-- 3G-1) sales date range
SELECT SUM(CASE WHEN sale_date < DATE '2024-01-01' OR sale_date > DATE '2024-12-31' THEN 1 ELSE 0 END) AS out_of_range
FROM public.sales;
-- RESULT: PASS (0)

-- 3G-2) shifts date range
SELECT SUM(CASE WHEN shift_date < DATE '2024-01-01' OR shift_date > DATE '2024-12-31' THEN 1 ELSE 0 END) AS out_of_range
FROM public.shifts;
-- RESULT: PASS (0)

-- 3G-3) inventory period logic
SELECT COUNT(*) AS bad_periods
FROM public.inventory_costs
WHERE period_end < period_start;
-- RESULT: PASS (0)

-- 3G-4) inventory category set
SELECT cost_category, COUNT(*) AS cnt
FROM public.inventory_costs
WHERE cost_category NOT IN ('Food','Beverage','Packaging')
GROUP BY cost_category;
-- RESULT: PASS (0)

-- ========================================================================

-- 4A) sale days per venue
SELECT venue_id, COUNT(DISTINCT sale_date) AS sale_days
FROM public.sales
GROUP BY venue_id
ORDER BY venue_id;
-- RESULT: PASS (All 360)

-- NOTE: In real-world ops data, we would expect fewer than 365 days due to
-- closures, holidays, or missing data. Here we check for 360 days per venue
-- because this synthetic dataset was designed to have daily coverage.

-- 4B) roles per day min/max
WITH daily_roles AS (
  SELECT venue_id, shift_date, COUNT(DISTINCT role) AS roles_per_day
  FROM public.shifts
  GROUP BY venue_id, shift_date
)
SELECT venue_id,
       MIN(roles_per_day) AS min_roles_per_day,
       MAX(roles_per_day) AS max_roles_per_day
FROM daily_roles
GROUP BY venue_id
ORDER BY venue_id;
-- RESULT: PASS (min=3 and max=3 for each venue)

-- NOTE: In real operations, it is normal for some days to have missing roles
-- (e.g., a manager covers instead, sickness, seasonal scheduling).
-- This synthetic dataset is designed to always include 3 roles per venue per day,
-- so we check for roles_per_day = 3 as a dataset integrity check,
-- not as a reflection of real-world labor scheduling.

-- 4C) months seen per venue
SELECT venue_id,
       COUNT(DISTINCT DATE_TRUNC('month', sale_date)) AS months_seen
FROM public.sales
GROUP BY venue_id
ORDER BY venue_id;
-- RESULT: PASS (All 12)

-- ========================================================================

-- 5A) labor cost distribution
WITH daily_labor AS (
  SELECT venue_id, shift_date,
         SUM(hours_worked * hourly_rate) AS labor_cost
  FROM public.shifts
  GROUP BY venue_id, shift_date
)
SELECT venue_id,
       MIN(labor_cost) AS min_cost,
       AVG(labor_cost) AS avg_cost,
       MAX(labor_cost) AS max_cost
FROM daily_labor
GROUP BY venue_id
ORDER BY venue_id;
-- RESULT: (Ballpark avg ≈ £250–£400; min/max can vary)

-- RESULT: All 3 venues have identical min/avg/max distributions due to synthetic data generation.
-- This check is to confirm ranges are sensible (labor cost ~£250–£400/day, revenue ~£2k–£12k/day).
-- In real-world data, distributions would vary by venue size and operations.

-- 5B) revenue distribution
WITH daily_sales AS (
  SELECT venue_id, sale_date,
         SUM(gross_sales) AS revenue
  FROM public.sales
  GROUP BY venue_id, sale_date
)
SELECT venue_id,
       MIN(revenue) AS min_rev,
       AVG(revenue) AS avg_rev,
       MAX(revenue) AS max_rev
FROM daily_sales
GROUP BY venue_id
ORDER BY venue_id;
-- RESULT: (Ballpark avg ≈ £2k–£12k depending on venue)

-- ========================================================================
-- FINAL DQ SUMMARY
-- Returns a single row with counts of duplicates/orphans/negatives/etc.
-- ========================================================================

WITH
-- 1) Uniqueness
sales_dupes AS (
  SELECT COUNT(*) AS n
  FROM (
    SELECT venue_id, sale_date
    FROM public.sales
    GROUP BY 1,2
    HAVING COUNT(*) > 1
  ) d
),
shifts_dupes AS (
  SELECT COUNT(*) AS n
  FROM (
    SELECT venue_id, shift_date, role
    FROM public.shifts
    GROUP BY 1,2,3
    HAVING COUNT(*) > 1
  ) d
),
inv_dupes AS (
  SELECT COUNT(*) AS n
  FROM (
    SELECT venue_id, period_start, period_end, cost_category
    FROM public.inventory_costs
    GROUP BY 1,2,3,4
    HAVING COUNT(*) > 1
  ) d
),

-- 2) Orphans (child rows with no matching venue)
sales_orphans AS (
  SELECT COUNT(*) AS n
  FROM public.sales s
  LEFT JOIN public.venues v USING (venue_id)
  WHERE v.venue_id IS NULL
),
shifts_orphans AS (
  SELECT COUNT(*) AS n
  FROM public.shifts sh
  LEFT JOIN public.venues v USING (venue_id)
  WHERE v.venue_id IS NULL
),
inv_orphans AS (
  SELECT COUNT(*) AS n
  FROM public.inventory_costs i
  LEFT JOIN public.venues v USING (venue_id)
  WHERE v.venue_id IS NULL
),

-- 3) Negatives
sales_neg AS (
  SELECT COUNT(*) AS n
  FROM public.sales
  WHERE covers < 0 OR gross_sales < 0
),
shifts_neg AS (
  SELECT COUNT(*) AS n
  FROM public.shifts
  WHERE hours_worked < 0 OR hourly_rate < 0
),
inv_neg AS (
  SELECT COUNT(*) AS n
  FROM public.inventory_costs
  WHERE amount < 0
),

-- 4) Date sanity / categories
sales_bad_dates AS (
  SELECT COUNT(*) AS n
  FROM public.sales
  WHERE sale_date < DATE '2024-01-01' OR sale_date > DATE '2024-12-31'
),
shifts_bad_dates AS (
  SELECT COUNT(*) AS n
  FROM public.shifts
  WHERE shift_date < DATE '2024-01-01' OR shift_date > DATE '2024-12-31'
),
inv_bad_periods AS (
  SELECT COUNT(*) AS n
  FROM public.inventory_costs
  WHERE period_end < period_start
),
inv_bad_categories AS (
  SELECT COUNT(*) AS n
  FROM public.inventory_costs
  WHERE cost_category NOT IN ('Food','Beverage','Packaging')
)

SELECT
  (SELECT n FROM sales_dupes)           AS sales_dupes,
  (SELECT n FROM shifts_dupes)          AS shifts_dupes,
  (SELECT n FROM inv_dupes)             AS inventory_dupes,
  (SELECT n FROM sales_orphans)         AS sales_orphans,
  (SELECT n FROM shifts_orphans)        AS shifts_orphans,
  (SELECT n FROM inv_orphans)           AS inventory_orphans,
  (SELECT n FROM sales_neg)             AS sales_negatives,
  (SELECT n FROM shifts_neg)            AS shifts_negatives,
  (SELECT n FROM inv_neg)               AS inventory_negatives,
  (SELECT n FROM sales_bad_dates)       AS sales_bad_dates,
  (SELECT n FROM shifts_bad_dates)      AS shifts_bad_dates,
  (SELECT n FROM inv_bad_periods)       AS inventory_bad_periods,
  (SELECT n FROM inv_bad_categories)    AS inventory_bad_categories,
  CASE
    WHEN (SELECT n FROM sales_dupes)            > 0 THEN 'FAIL'
    WHEN (SELECT n FROM shifts_dupes)           > 0 THEN 'FAIL'
    WHEN (SELECT n FROM inv_dupes)              > 0 THEN 'FAIL'
    WHEN (SELECT n FROM sales_orphans)          > 0 THEN 'FAIL'
    WHEN (SELECT n FROM shifts_orphans)         > 0 THEN 'FAIL'
    WHEN (SELECT n FROM inv_orphans)            > 0 THEN 'FAIL'
    WHEN (SELECT n FROM sales_neg)              > 0 THEN 'FAIL'
    WHEN (SELECT n FROM shifts_neg)             > 0 THEN 'FAIL'
    WHEN (SELECT n FROM inv_neg)                > 0 THEN 'FAIL'
    WHEN (SELECT n FROM sales_bad_dates)        > 0 THEN 'FAIL'
    WHEN (SELECT n FROM shifts_bad_dates)       > 0 THEN 'FAIL'
    WHEN (SELECT n FROM inv_bad_periods)        > 0 THEN 'FAIL'
    WHEN (SELECT n FROM inv_bad_categories)     > 0 THEN 'FAIL'
    ELSE 'PASS'
  END AS overall_status;
  
