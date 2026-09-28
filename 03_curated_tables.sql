-- ============================================================
-- SHOPSPHERE CAPSTONE
-- FILE: 03_curated_tables.sql
-- PURPOSE: Build trusted dimensional and fact tables
-- ============================================================


-- ============================================================
-- 1. CUSTOMER DIMENSION
-- ============================================================

DROP TABLE IF EXISTS shopsphere_curated.dim_customer CASCADE;

CREATE TABLE shopsphere_curated.dim_customer
(
    customer_key BIGSERIAL PRIMARY KEY,
    customer_id INT NOT NULL UNIQUE,
    full_name VARCHAR(201),
    email VARCHAR(255),
    phone VARCHAR(50),
    signup_date DATE,
    customer_status VARCHAR(30),
    updated_at TIMESTAMP
);

INSERT INTO shopsphere_curated.dim_customer
(
    customer_id,
    full_name,
    email,
    phone,
    signup_date,
    customer_status,
    updated_at
)

SELECT
    customer_id,
    CONCAT(first_name, ' ', last_name),
    email,
    phone,
    signup_date,
    customer_status,
    updated_at

FROM shopsphere_staging.stg_customers

WHERE email_quality = 'VALID';