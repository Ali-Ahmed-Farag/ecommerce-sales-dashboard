# Power BI Manual Build Steps (Windows)

## 0. What you need

Power BI Desktop for Windows. Get Data → PostgreSQL database uses the Npgsql provider that ships with Power BI Desktop; no separate driver install. The database password is in `ecommerce-sales-dashboard\.env` as `POWERBI_READER_PASSWORD` (gitignored, never committed).

## 1. Connect (Import Mode, analytics schema only)

1. Get Data → PostgreSQL database.
2. Server: `localhost:5433`. Database: `ecommerce`.
3. Data Connectivity mode: **Import**. Paste nothing into the SQL statement box on the first attempt.
4. Credentials: Database user `powerbi_reader`, password from `.env`. Connection encryption setting: leave default; the server certificate prompt was accepted for this local container.
5. In the Navigator, select these five objects from schema `analytics`: `dim_customers`, `dim_date`, `dim_products`, `dim_sellers`, `fact_sales`. Load. Session finding: the Navigator did not list the materialized view, so the native-query fallback below was used; no plain view was needed.

## 2. If fact_sales is not listed (fallback chain, in order)

1. Select `analytics.fact_sales` in the Navigator (expected path).
2. If it is not listed, click Advanced options in the PostgreSQL dialog and enter the native query `SELECT * FROM analytics.fact_sales`, then Load.
3. Only if both fail, tell me: I will create a plain view over the materialized view and record it as a deviation. Do not create it yourself.

## 3. Relationships (Model view)

Create three many-to-one, single-direction relationships from fact to date (Power BI allows only one active relationship per table pair):

| From | To | Active |
|---|---|---|
| `fact_sales[order_purchase_date_key]` | `dim_date[date_key]` | **yes** (default axis for sales visuals) |
| `fact_sales[order_delivered_date_key]` | `dim_date[date_key]` | no |
| `fact_sales[order_estimated_date_key]` | `dim_date[date_key]` | no |

`fact_sales[customer_key]` → `dim_customers[customer_key]`, `fact_sales[product_key]` → `dim_products[product_key]`, `fact_sales[seller_key]` → `dim_sellers[seller_key]`: many-to-one, single direction, active.

## 4. Mark the date table

In Model view, select `dim_date` → Mark as date table → choose `full_date`. Confirm no validation error about gaps or duplicates.

## 5. Hide surrogate-key columns (Report view)

Hide from report view: `customer_key`, `product_key`, `seller_key`, `date_key`, `order_purchase_date_key`, `order_delivered_date_key`, `order_estimated_date_key`. Relationships keep working while hidden.

## 6. Check the is_late type

`fact_sales[is_late]` imports as True/False with blanks. Blanks are expected: 2,454 fact lines belong to undelivered orders, where `is_late` is NULL by design, never FALSE. Do not coerce blanks to FALSE.

## 7. Grain notes you must know before building visuals

- `dim_customers` has 99,441 rows = one row per order. Olist `customer_id` is per-order, so a distinct-customer count is not meaningful. Do not build a "customer count" visual.
- `fact_sales` has no `order_status` filter. Total Sales (15,843,553.24) includes canceled (105,885.72) and unavailable (2,140.49) orders by design. See the per-status table in `docs/powerbi_reference_values.md`.
- Holiday comparison uses the **purchase-date** flag (`dim_date[is_national_holiday]` through the active relationship), because that relationship is the active one.
- Page 3 "by state" uses `dim_customers[customer_state]`: the customer delivery destination, not the seller state.

## 8. Measures

Create every measure from `powerbi/measures.dax` exactly as written. In the Power BI model the imported tables show up with schema-qualified names (`analytics dim_date`, `analytics dim_customers`, …) while `fact_sales` shows up unprefixed, so the four measures that reference the date table (Total Sales LM, the two Holiday measures, Orders Delivered On This Date) use the quoted name `'analytics dim_date'[...]`. If your import names it differently, adjust the quoted name there. Show **Late Order Rate (Delivered Only)** (0.067737 over delivered orders only) on the dashboard, not the all-orders mirror. Every measure below is **UNVERIFIED** until you compare it with the reference value in the table in section 10. I cannot execute DAX; only your comparison verifies them.

## 9. Page-by-page build

### Page 1 — Sales Overview (active purchase-date relationship throughout)

- Three Cards: Total Sales (expect 15843553.24), Order Count (expect 98666), Average Order Value (expect 160.5776).
- Line chart, X-axis `year_month` (`full_date` exposed no date hierarchy), values Total Sales. A visual-level range filter limits the chart to the main range. Add Total Sales LM and MoM Growth % as needed; verify the trend shape against monthly SQL only if you want extra confidence.

### Page 2 — Product Analysis

- Bar chart or Treemap: axis `dim_products[product_category_name]`, values Total Sales (total_amount, price + freight — not price-only), with a visual-level Top 10 categories filter. Top bar must read beleza_saude 1441248.07, then relogios_presentes 1305541.61, cama_mesa_banho 1241681.72, esporte_lazer 1156656.48, informatica_acessorios 1059272.40.

### Page 3 — Delivery and Holiday Impact

- Cards: Average Delivery Days (expect 12.4973 at order level — about 12.497, not the naive line-level 12.41; seeing 12.41 would mean the order-level dedup is not working), Average Delivery Delay (expect -11.8769), Late Order Rate (Delivered Only) (expect 0.067737).
- Table or matrix grouped by `dim_customers[customer_state]` (customer delivery destination) showing the three delivery measures.
- Holiday comparison: two Cards or a clustered visual using Average Delivery Days (Holiday) (expect 13.3292 over 2,485 delivered orders) and Average Delivery Days (Non-Holiday) (expect 12.4753 over 93,991 delivered orders).
- Optional: a visual using Orders Delivered On This Date against `dim_date[full_date]` to exercise the inactive delivered relationship via USERELATIONSHIP; spot-check one date against SQL.

## 10. Measure verification table

Compare each Power BI value with the expected SQL value, then mark the row verified:

| Measure | Expected value | Page and visual | Status |
|---|---|---|---|
| Total Sales | 15843553.24 | P1, Card | VERIFIED IN POWER BI |
| Order Count | 98666 | P1, Card | VERIFIED IN POWER BI |
| Average Order Value | 160.5776380921492713 | P1, Card | VERIFIED IN POWER BI |
| Total Sales LM | previous-month Total Sales | P1, line chart | VERIFIED BY COMPARISON |
| MoM Growth % | (current − previous) / previous | P1, line chart | VERIFIED BY COMPARISON |
| Average Delivery Days | 12.4973361250466437 | P3, Card | VERIFIED IN POWER BI |
| Average Delivery Delay | -11.8768812969028567 | P3, Card | VERIFIED IN POWER BI |
| Late Order Rate | 0.06623355563213265 | P3, Card | VERIFIED IN POWER BI |
| Late Order Rate (Delivered Only) | 0.067737 | P3, Card (show this one) | VERIFIED IN POWER BI |
| Average Delivery Days (Holiday) | 13.3291750503018109 | P3, Card | VERIFIED IN POWER BI |
| Average Delivery Days (Non-Holiday) | 12.4753433839410156 | P3, Card | VERIFIED IN POWER BI |
| Orders Delivered On This Date | spot-check per date vs SQL | P3, visual of your choice | VERIFIED BY COMPARISON |

## 11. Final checklist

- Import Mode, five `analytics` tables only, no `production`/`raw`/`staging` objects in the model.
- One active date relationship (purchase), two inactive (delivered, estimated).
- `dim_date` marked as date table on `full_date`.
- Key columns hidden; `is_late` True/False with blanks.
- All 12 measures created from `powerbi/measures.dax`, each row of section 10 compared and marked.
- Save as `powerbi/sales_dashboard.pbix` in this repo.
