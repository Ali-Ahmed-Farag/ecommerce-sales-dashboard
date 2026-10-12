CREATE SCHEMA IF NOT EXISTS analytics;

CREATE TABLE IF NOT EXISTS analytics.dim_date (
    date_key SERIAL PRIMARY KEY,
    full_date DATE UNIQUE NOT NULL,
    day INT,
    month INT,
    quarter INT,
    year INT,
    day_name VARCHAR,
    is_national_holiday BOOLEAN DEFAULT FALSE,
    is_holiday_week BOOLEAN DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS analytics.dim_customers (
    customer_key SERIAL PRIMARY KEY,
    customer_id VARCHAR UNIQUE NOT NULL,
    customer_city VARCHAR,
    customer_state VARCHAR
);

CREATE TABLE IF NOT EXISTS analytics.dim_products (
    product_key SERIAL PRIMARY KEY,
    product_id VARCHAR UNIQUE NOT NULL,
    product_category_name VARCHAR
);

CREATE TABLE IF NOT EXISTS analytics.dim_sellers (
    seller_key SERIAL PRIMARY KEY,
    seller_id VARCHAR UNIQUE NOT NULL,
    seller_city VARCHAR,
    seller_state VARCHAR
);
