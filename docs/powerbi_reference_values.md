# Power BI Reference Values (computed by SQL against analytics)

Every figure below is the raw output of the SQL shown with it. Counts are labeled as order lines (fact rows) or distinct orders. Delivery metrics are computed over delivered orders only unless stated otherwise.

## Totals (order lines vs distinct orders)

```sql
SELECT SUM(total_amount) AS total_sales_lines, SUM(price) AS price_only_lines, COUNT(*) AS order_lines, COUNT(DISTINCT order_id) AS distinct_orders FROM analytics.fact_sales;
```

| total_sales_lines | price_only_lines | order_lines | distinct_orders |
|---|---|---|---|
| 15843553.24 | 13591643.70 | 112650 | 98666 |

Total Sales is SUM(total_amount) where total_amount = price + freight_value. Price-only revenue is 13591643.70.

## Average Order Value (distinct orders)

```sql
SELECT SUM(total_amount) / COUNT(DISTINCT order_id) AS average_order_value FROM analytics.fact_sales;
```

| average_order_value |
|---|
| 160.5776380921492713 |

## Delivered vs undelivered orders (distinct orders)

```sql
SELECT COUNT(DISTINCT order_id) AS delivered_orders FROM analytics.fact_sales WHERE order_delivered_date_key IS NOT NULL;
SELECT COUNT(DISTINCT order_id) AS undelivered_orders FROM analytics.fact_sales WHERE order_delivered_date_key IS NULL;
```

| delivered_orders | undelivered_orders |
|---|---|
| 96476 | 2190 |

96476 + 2190 = 98666. Source-data note: 8 orders have status delivered but a NULL delivered date, and 6 orders with a non-delivered status have a non-NULL delivered date:

```sql
SELECT COUNT(*) AS delivered_status_null_date_orders FROM production.orders WHERE order_status = 'delivered' AND order_delivered_customer_date IS NULL;
SELECT COUNT(*) AS nondelivered_status_with_date FROM production.orders WHERE order_status <> 'delivered' AND order_delivered_customer_date IS NOT NULL;
```

| delivered_status_null_date_orders | nondelivered_status_with_date |
|---|---|
| 8 | 6 |

## Delivery averages, naive line level (order lines, NULLs ignored by AVG)

```sql
SELECT AVG(delivery_time_days) AS naive_avg_time_lines, AVG(delivery_delay_days) AS naive_avg_delay_lines FROM analytics.fact_sales;
```

| naive_avg_time_lines | naive_avg_delay_lines |
|---|---|
| 12.4109586554865875 | -12.0302007332389560 |

## Delivery averages, order level (delivered orders only)

```sql
SELECT AVG(t) AS order_avg_time, AVG(d) AS order_avg_delay, COUNT(*) AS delivered_orders_n FROM (SELECT MAX(delivery_time_days) AS t, MAX(delivery_delay_days) AS d FROM analytics.fact_sales WHERE order_delivered_date_key IS NOT NULL GROUP BY order_id) s;
```

| order_avg_time | order_avg_delay | delivered_orders_n |
|---|---|---|
| 12.4973361250466437 | -11.8768812969028567 | 96476 |

The line-level figures overweight multi-item orders (one 21-line order repeats 15/3/t on every line). Power BI must show the order-level figures.

## Late order rate, order level

Delivered orders only:

```sql
SELECT COUNT(*) FILTER (WHERE l) AS late_orders, COUNT(*) AS delivered_n, (COUNT(*) FILTER (WHERE l))::float / COUNT(*) AS late_rate_delivered FROM (SELECT BOOL_OR(is_late) AS l FROM analytics.fact_sales WHERE order_delivered_date_key IS NOT NULL GROUP BY order_id) s;
```

| late_orders | delivered_n | late_rate_delivered |
|---|---|---|
| 6535 | 96476 | 0.06773705377503213 |

DAX-mirror (denominator is all distinct orders including undelivered, exactly what the Late Order Rate measure divides by):

```sql
SELECT COUNT(*) FILTER (WHERE l) AS late_orders_mirror, (SELECT COUNT(DISTINCT order_id) FROM analytics.fact_sales) AS all_orders_n, (COUNT(*) FILTER (WHERE l))::float / (SELECT COUNT(DISTINCT order_id) FROM analytics.fact_sales) AS late_rate_all_mirror FROM (SELECT BOOL_OR(is_late) AS l FROM analytics.fact_sales GROUP BY order_id) s;
```

| late_orders_mirror | all_orders_n | late_rate_all_mirror |
|---|---|---|
| 6535 | 98666 | 0.06623355563213265 |

## Holiday vs non-holiday delivery days (by purchase-date flag, delivered orders only)

```sql
SELECT s.flag AS holiday_purchase_flag, AVG(s.t) AS avg_delivery_days, COUNT(*) AS delivered_orders_n FROM (SELECT f.order_id, MAX(f.delivery_time_days) AS t, BOOL_OR(dd.is_national_holiday) AS flag FROM analytics.fact_sales f JOIN analytics.dim_date dd ON dd.date_key = f.order_purchase_date_key WHERE f.order_delivered_date_key IS NOT NULL GROUP BY f.order_id) s GROUP BY s.flag ORDER BY s.flag;
```

| holiday_purchase_flag | avg_delivery_days | delivered_orders_n |
|---|---|---|
| f | 12.4753433839410156 | 93991 |
| t | 13.3291750503018109 | 2485 |

93991 + 2485 = 96476.

## Top 5 categories by revenue (total_amount, not price-only)

```sql
SELECT p.product_category_name AS category, SUM(f.total_amount) AS revenue, COUNT(*) AS order_lines, COUNT(DISTINCT f.order_id) AS distinct_orders FROM analytics.fact_sales f JOIN analytics.dim_products p ON p.product_key = f.product_key GROUP BY p.product_category_name ORDER BY revenue DESC LIMIT 5;
```

| category | revenue | order_lines | distinct_orders |
|---|---|---|---|
| beleza_saude | 1441248.07 | 9670 | 8836 |
| relogios_presentes | 1305541.61 | 5991 | 5624 |
| cama_mesa_banho | 1241681.72 | 11115 | 9417 |
| esporte_lazer | 1156656.48 | 8641 | 7720 |
| informatica_acessorios | 1059272.40 | 7827 | 6689 |

## Revenue by order_status (no filter applied)

```sql
SELECT o.order_status AS status, COUNT(*) AS order_lines, COUNT(DISTINCT f.order_id) AS distinct_orders, SUM(f.total_amount) AS revenue FROM analytics.fact_sales f JOIN production.orders o ON o.order_id = f.order_id GROUP BY o.order_status ORDER BY revenue DESC;
```

| status | order_lines | distinct_orders | revenue |
|---|---|---|---|
| delivered | 110197 | 96478 | 15419773.75 |
| shipped | 1185 | 1106 | 177129.34 |
| canceled | 542 | 461 | 105885.72 |
| processing | 357 | 301 | 69394.11 |
| invoiced | 359 | 312 | 68988.75 |
| unavailable | 7 | 6 | 2140.49 |
| approved | 3 | 2 | 241.08 |

fact_sales has no order_status filter, so Total Sales includes canceled and unavailable orders by design.
