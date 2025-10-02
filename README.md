# Venue Ops – SQL Portfolio Project

**Purpose:** Demonstrate end-to-end SQL skills (schema, load, data quality, KPIs, MoM trends, rankings) on a multi-venue operations dataset.

> **Note:** The dataset is synthetic and for practice only; insights are illustrative, not real business conclusions.

## Quickstart
```bash
docker compose up -d
# create tables and helpers
docker exec -i venue_ops_pg psql -U postgres -d venue_ops -f /scripts/schema.sql
# load synthetic data
docker exec -i venue_ops_pg psql -U postgres -d venue_ops -f /scripts/load.sql
# optional: run data quality checks
docker exec -i venue_ops_pg psql -U postgres -d venue_ops -f /scripts/dq_checks.sql
# run analysis (daily → monthly → MoM → rankings)
docker exec -i venue_ops_pg psql -U postgres -d venue_ops -f /scripts/analysis.sql
```

## Optional: Convenience Views
Create simple (non‑materialized) views so you can explore results without scrolling through CTEs.
```bash
docker exec -i venue_ops_pg psql -U postgres -d venue_ops -f /scripts/views.sql
```
**Example usage**
```sql
SELECT * FROM public.daily_kpis_view;
SELECT * FROM public.monthly_kpis_view        ORDER BY venue_id, month;
SELECT * FROM public.monthly_efficiency_leaderboard ORDER BY month, efficiency_rank;
```

## Project Structure
- `schema.sql` – Tables + constraints + safe-delete helpers  
- `load.sql` – Server-side CSV imports  
- `dq_checks.sql` – Data quality assertions + summary  
- `analysis.sql` – Daily KPIs → monthly rollups → MoM deltas → efficiency rankings  
- `views.sql` – Optional convenience views (`daily_kpis_view`, `monthly_kpis_view`, `monthly_efficiency_leaderboard`)  
- `insights.md` – Descriptive findings; MoM highlights patterns/seasonality/trends  
- `drop_and_recreate.sql` / `drop_project_objects.sql` – Reset options

## Resetting / Wiping
**A) Full reset (drops entire `public` schema in this container)**
```bash
docker exec -i venue_ops_pg psql -U postgres -d venue_ops -f /scripts/drop_and_recreate.sql
```

**B) Project-only reset (drops just this project’s objects)**
```bash
docker exec -i venue_ops_pg psql -U postgres -d venue_ops -f /scripts/drop_project_objects.sql
```

*If you want to keep working after a reset, run `load.sql` again; otherwise leave it clean.*

## Where to look for results
- **SQL outputs:** `analysis.sql` (daily/monthly KPIs, MoM, rankings)  
- **Narrative:** `insights.md` (descriptive, hypothesis-driven takeaways)

## Next Steps (possible extensions)
- Add a visualization layer (e.g., Tableau, Power BI, Excel).
- Extend KPIs (profitability, per-seat or per-transaction metrics).
- Parameterize month selection for efficiency rankings.
