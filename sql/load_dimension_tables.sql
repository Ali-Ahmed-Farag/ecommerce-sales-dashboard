INSERT INTO analytics.dim_date (full_date, day, month, quarter, year, day_name)
SELECT d, EXTRACT(DAY FROM d), EXTRACT(MONTH FROM d), EXTRACT(QUARTER FROM d),
       EXTRACT(YEAR FROM d), TO_CHAR(d, 'FMDay')
FROM (
    SELECT LEAST(MIN(order_purchase_timestamp)::date,
                 MIN(order_delivered_customer_date)::date,
                 MIN(order_estimated_delivery_date)::date) - INTERVAL '30 days' AS range_start,
           GREATEST(MAX(order_purchase_timestamp)::date,
                    MAX(order_delivered_customer_date)::date,
                    MAX(order_estimated_delivery_date)::date) + INTERVAL '30 days' AS range_end
    FROM production.orders
) bounds,
LATERAL generate_series(bounds.range_start, bounds.range_end, '1 day') AS d
ON CONFLICT (full_date) DO NOTHING;

UPDATE analytics.dim_date dd SET
    year_month = date_trunc('month', dd.full_date)::date,
    is_national_holiday = EXISTS (
        SELECT 1 FROM production.holidays h
        WHERE h.holiday_date = dd.full_date AND h.state IS NULL
    ),
    is_holiday_week = EXISTS (
        SELECT 1 FROM production.holidays h
        WHERE h.state IS NULL
          AND date_trunc('week', h.holiday_date::timestamp) = date_trunc('week', dd.full_date::timestamp)
    );

INSERT INTO analytics.dim_customers (customer_id, customer_city, customer_state)
SELECT customer_id, customer_city, customer_state FROM production.customers
ON CONFLICT (customer_id) DO UPDATE SET
    customer_city = EXCLUDED.customer_city,
    customer_state = EXCLUDED.customer_state
WHERE analytics.dim_customers.customer_city IS DISTINCT FROM EXCLUDED.customer_city
   OR analytics.dim_customers.customer_state IS DISTINCT FROM EXCLUDED.customer_state;

INSERT INTO analytics.dim_products (product_id, product_category_name)
SELECT product_id, product_category_name FROM production.products
ON CONFLICT (product_id) DO UPDATE SET
    product_category_name = EXCLUDED.product_category_name
WHERE analytics.dim_products.product_category_name IS DISTINCT FROM EXCLUDED.product_category_name;

INSERT INTO analytics.dim_sellers (seller_id, seller_city, seller_state)
SELECT seller_id, seller_city, seller_state FROM production.sellers
ON CONFLICT (seller_id) DO UPDATE SET
    seller_city = EXCLUDED.seller_city,
    seller_state = EXCLUDED.seller_state
WHERE analytics.dim_sellers.seller_city IS DISTINCT FROM EXCLUDED.seller_city
   OR analytics.dim_sellers.seller_state IS DISTINCT FROM EXCLUDED.seller_state;
