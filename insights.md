# Insights & Findings

## Executive Summary (TL;DR)
- **Venue 3** is the most efficient venue in this dataset, ranking #1 every month.
- **MoM analysis** adds the most insight: it reveals stability, subtle improvements, and potential seasonality that static ranks miss.
- Findings are **descriptive, not causal** given the synthetic dataset.

## Important Note on Data
This dataset is **synthetic and fabricated for practice purposes only**. It should not be considered comparable to real-world operations. The insights below are illustrative of how SQL analysis can be applied, not real business conclusions.

---

## Efficiency Leaderboard (Descriptive)
- **Venue 3** consistently ranked #1 in operational efficiency across all 12 months.
- **Venue 1** maintained a stable #2 position throughout the year.
- **Venue 2** consistently ranked #3.

**Interpretation**
- The ranking pattern is highly stable in this dataset.
- In real-world data, differences in efficiency may be influenced by venue layout/size, demand patterns, or scheduling practices; this project does not attempt causal attribution.

---

## Month-over-Month (MoM) Insights — *Most Valuable*
MoM analysis surfaces **patterns, seasonality, and trends** that rankings alone cannot capture.

- **Venue 3:** Stable efficiency with minimal MoM fluctuation → consistent operational performance.
- **Venue 1:** Generally steady with small seasonal dips → potential sensitivity to demand changes.
- **Venue 2:** Despite ranking #3, exhibits gradual MoM improvement in revenue per labor hour → momentum worth monitoring.

**Why MoM Matters**
- **Patterns:** Tracks operational shifts and consistency over time.
- **Seasonality:** Identifies recurring peaks/dips useful for staffing and planning.
- **Trends:** Distinguishes between consistently strong venues and those improving or declining.
- **Anomalies:** Flags sudden swings that merit investigation (events, promotions, staffing changes).

---

## Methodology Snapshot (for reviewers)
- **Efficiency metric:** `monthly_rev_per_labor_hr` (higher is better).
- **Cost balance:** `monthly_labor_pct` = labor cost / revenue × 100 (lower is better).
- **Ranking logic:** Within each month, rank by efficiency (desc), tie-break by labor % (asc).
- **MoM deltas:** Window functions (`LAG`) over `(PARTITION BY venue_id ORDER BY month)` to compute changes month-to-month.

---

## Business Value
- Demonstrates how SQL converts raw operations data into **comparable KPIs**.
- Supports management decisions to:
  - Benchmark venues on both efficiency **levels** and **momentum**.
  - Identify consistent leaders and persistent laggards.
  - Prioritize deeper reviews where performance shifts unexpectedly.

---

## Optional Extensions
- Add an “anomaly finder” (months where a venue’s rank worsens by ≥2 positions).
- Compare MoM trends to calendar events (closures, promos) if such data exists.
- Introduce YTD aggregates to complement MoM analysis.
