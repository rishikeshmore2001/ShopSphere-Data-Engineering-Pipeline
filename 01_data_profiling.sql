-- =====================================================
-- SHOPSPHERE CAPSTONE
-- FILE: 01_data_profiling.sql
-- PURPOSE: Analyze raw data before preprocessing
-- =====================================================


-- 1. CHECK ROW COUNTS

SELECT 'customers' AS table_name, COUNT(*) AS total_records
FROM shopsphere_raw.customers

UNION ALL

SELECT 'customer_addresses', COUNT(*)
FROM shopsphere_raw.customer_addresses

UNION ALL

SELECT 'categories', COUNT(*)
FROM shopsphere_raw.categories

UNION ALL

SELECT 'products', COUNT(*)
FROM shopsphere_raw.products

UNION ALL

SELECT 'orders', COUNT(*)
FROM shopsphere_raw.orders

UNION ALL

SELECT 'order_items', COUNT(*)
FROM shopsphere_raw.order_items

UNION ALL

SELECT 'payments', COUNT(*)
FROM shopsphere_raw.payments

UNION ALL

SELECT 'shipments', COUNT(*)
FROM shopsphere_raw.shipments;


-- 2. CHECK DUPLICATE CUSTOMERS

SELECT
    customer_id,
    COUNT(*) AS record_count,
    MIN(updated_at) AS first_updated_at,
    MAX(updated_at) AS latest_updated_at
FROM shopsphere_raw.customers
GROUP BY customer_id
HAVING COUNT(*) > 1;


-- 3. CHECK CUSTOMER EMAIL QUALITY

SELECT
    customer_id,
    first_name,
    last_name,
    email,

    CASE
        WHEN email IS NULL
             OR TRIM(email) = ''
            THEN 'MISSING'

        WHEN TRIM(email) NOT LIKE '%@%.%'
            THEN 'INVALID'

        WHEN email <> TRIM(email)
            THEN 'EXTRA SPACES'

        WHEN email <> LOWER(email)
            THEN 'UPPERCASE'

        ELSE 'VALID'
    END AS email_issue

FROM shopsphere_raw.customers
ORDER BY customer_id;


-- 4. CHECK ORDER ITEMS WITHOUT VALID ORDERS

SELECT
    oi.order_item_id,
    oi.order_id,
    oi.product_id,
    oi.quantity,
    oi.unit_price
FROM shopsphere_raw.order_items oi
LEFT JOIN shopsphere_raw.orders o
    ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;
