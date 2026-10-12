CREATE MATERIALIZED VIEW IF NOT EXISTS analytics.fact_sales AS
SELECT ROW_NUMBER() OVER () AS sales_key,
       oi.order_id, dc.customer_key, dp.product_key, ds.seller_key,
       dd_purchase.date_key   AS order_purchase_date_key,
       dd_delivered.date_key  AS order_delivered_date_key,
       dd_estimated.date_key  AS order_estimated_date_key,
       oi.price, oi.freight_value,
       (oi.price + oi.freight_value) AS total_amount,
       (o.order_delivered_customer_date::date - o.order_purchase_timestamp::date) AS delivery_time_days,
       (o.order_delivered_customer_date::date - o.order_estimated_delivery_date::date) AS delivery_delay_days,
       CASE WHEN o.order_delivered_customer_date IS NULL THEN NULL
            ELSE (o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date)
       END AS is_late
FROM production.order_items oi
JOIN production.orders o ON oi.order_id = o.order_id
JOIN analytics.dim_customers dc ON dc.customer_id = o.customer_id
JOIN analytics.dim_products dp ON dp.product_id = oi.product_id
JOIN analytics.dim_sellers ds ON ds.seller_id = oi.seller_id
LEFT JOIN analytics.dim_date dd_purchase ON dd_purchase.full_date = o.order_purchase_timestamp::date
LEFT JOIN analytics.dim_date dd_delivered ON dd_delivered.full_date = o.order_delivered_customer_date::date
LEFT JOIN analytics.dim_date dd_estimated ON dd_estimated.full_date = o.order_estimated_delivery_date::date;

CREATE INDEX IF NOT EXISTS ix_fact_sales_customer_key ON analytics.fact_sales (customer_key);
CREATE INDEX IF NOT EXISTS ix_fact_sales_purchase_date_key ON analytics.fact_sales (order_purchase_date_key);
CREATE INDEX IF NOT EXISTS ix_fact_sales_delivered_date_key ON analytics.fact_sales (order_delivered_date_key);
