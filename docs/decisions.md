# Deviations and Additions vs FINAL_IMPLEMENTATION_BLUEPRINT.md

Each item below is a deliberate deviation or addition relative to the Blueprint. Evidence comes from real command output in the stage reports of this repository.

## 1. Read-only analyst role powerbi_reader

**Blueprint said:** Power BI connects to the `analytics` schema only, never `production` directly (Project 3 §23).

**What we do:** A dedicated `powerbi_reader` role (LOGIN, USAGE on schema `analytics`, SELECT on its tables including the materialized view, default privileges for future tables, nothing on `production`/`raw`/`staging`). Random password stored only in `.env` (gitignored); `.env.example` carries a placeholder.

**Reason:** The role enforces "analytics only" at the database level instead of relying on the dashboard author to avoid the wrong schema.

**Evidence (Stage 1):**
```
grantee powerbi_reader SELECT on analytics.dim_customers/dim_date/dim_products/dim_sellers
usage: analytics t, production f, raw f, staging f
as reader: analytics.dim_customers → 99441 ; production.orders → ERROR: permission denied for schema production
reader_select_fact t ; reader count on fact_sales → 112650 (Stage 2, after re-running the idempotent role SQL)
```

## 2. Dimension upserts skip unchanged rows; sequences still advance

**Blueprint said:** `INSERT … ON CONFLICT (natural_key) DO UPDATE SET <attributes>` (Project 3 §10).

**What we do:** Same pattern plus `WHERE … IS DISTINCT FROM …` so unchanged rows are not rewritten (a tampered row still reverts: rerun showed `INSERT 0 1` for exactly the tampered row). Surrogate keys verified stable by checksum across reruns plus a tamper-and-revert test inside `analytics.dim_customers` (key 1 kept, city reverted to the production value).

**Reason:** Avoids rewriting ~100K rows per run; the tamper test doubles as the key-stability proof.

**Evidence (Stage 1):**
```
checksums identical across reruns: date:4bdaf066… cust:26ff82a7… prod:acde25f4… sell:9c62fe04…
tamper key 1 'franca'→'TAMPERED'→rerun→'franca', key 1, checksum unchanged
sequence advance per rerun: +860/+99441/+32951/+3095 (ON CONFLICT consumes nextval even on conflict)
```

## 3. FMDay for day names

**Blueprint said:** `TO_CHAR(d, 'Day')` (Project 3 §11).

**What we do:** `TO_CHAR(d, 'FMDay')`.

**Reason:** `Day` pads names with trailing spaces; `FMDay` does not.

**Evidence (Stage 1):**
```
padded_day_names 0
```

## 4. No estimated-date-key index on fact_sales

**Blueprint said:** Indexes on customer_key, purchase and delivered date keys (Project 3 §11), estimated index only if justified.

**What we do:** Exactly the three listed indexes (`ix_fact_sales_customer_key`, `ix_fact_sales_purchase_date_key`, `ix_fact_sales_delivered_date_key`); no estimated-date index.

**Reason:** Power BI uses Import Mode so no live MV queries occur; symmetry alone did not justify a fourth index.

## 5. DAX safest form, UNVERIFIED

**Blueprint said:** Delivery measures with `SUMMARIZE` + computed columns and `MAX` over a boolean (Project 3 §24).

**What we do:** `ADDCOLUMNS` over `SUMMARIZE`; order-level aggregation uses `CALCULATE ( MAXX ( … , IF ( … , 1, 0 ) ) )` because `MAX` cannot work with Boolean values in Power BI. Extra `Late Order Rate (Delivered Only)` measure (denominator = delivered orders only, 0.067737) alongside the Blueprint-mirror rate (0.066234 over all orders); the delivered-only one is the dashboard measure. Verified in Power BI by the author: Total Sales, Order Count, Average Order Value, Average Delivery Days, Average Delivery Delay, both Late Order Rates, both Holiday measures. Verified by cross-column comparison only: Orders Delivered On This Date, Total Sales LM, MoM Growth %.

**Reason:** `ADDCOLUMNS` over bare `SUMMARIZE` with computed columns is discouraged; the explicit form is the safest equivalent.

## 6. Relative row-count check not implemented

**Blueprint said:** `fact_sales` row count stable or growing versus the previous run (Project 3 §14).

**What we do:** Not implemented.

**Reason:** It needs persisted state the Blueprint does not define. The absolute check (`fact_sales` = `production.order_items`, proven 112650 = 112650) covers the grain guarantee instead.

## 7. dim_date sequence excess unexplained

**What we observe:** `dim_date_date_key_seq` last_value 21,500 (= 25 × 860) against 22 accounted successful loads; the other three sequences reconcile exactly (2,187,702 = 22 × 99,441; 724,922 = 22 × 32,951; 68,090 = 22 × 3,095). The +2,580 (3 × 860) has no identified source. Keys, row counts (860) and checksums are unaffected.

**Evidence (Stage 5):**
```
sequencename last_value: dim_customers 2187702, dim_date 21500, dim_products 724922, dim_sellers 68090
```

## 8. year_month column on dim_date

**What we do:** `year_month DATE` added via `ALTER TABLE … ADD COLUMN IF NOT EXISTS` in the DDL file, recomputed on every load run (`year_month = date_trunc('month', full_date)::date`, same UPDATE as the holiday flags).

**Reason:** Month-level grouping without recomputing the truncation in every query.

**Evidence:**
```
null_ym 0 | min_ym 2016-08-01 | max_ym 2018-12-01 | dim_rows 860
ym_mismatch 0
dim checksums unchanged: cust:26ff82a7… prod:acde25f4… sell:9c62fe04…
```
