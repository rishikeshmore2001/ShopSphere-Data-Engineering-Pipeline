-- ============================================================
-- SHOPSPHERE CAPSTONE
-- FILE: 02_preprocessing.sql
-- PURPOSE: Clean, standardize, deduplicate and validate raw data
-- ============================================================


-- ============================================================
-- 1. PREPROCESS CUSTOMERS
-- ============================================================

DROP TABLE IF EXISTS shopsphere_staging.stg_customers;

CREATE TABLE shopsphere_staging.stg_customers AS

WITH customer_cleaning AS
(
    SELECT
        customer_id,

        -- Remove spaces from beginning/end of names
        TRIM(first_name) AS first_name,
        TRIM(last_name) AS last_name,

        -- Remove spaces and standardize email to lowercase
        LOWER(TRIM(email)) AS email,

        -- Clean phone
        TRIM(phone) AS phone,

        signup_date,

        -- Standardize status
        UPPER(TRIM(customer_status)) AS customer_status,

        updated_at,

        -- Check email quality
        CASE
            WHEN email IS NULL
                 OR TRIM(email) = ''
                THEN 'MISSING'

            WHEN TRIM(email) NOT LIKE '%@%.%'
                THEN 'INVALID'

            ELSE 'VALID'
        END AS email_quality,

        -- Deduplication
        ROW_NUMBER() OVER
        (
            PARTITION BY customer_id
            ORDER BY updated_at DESC
        ) AS row_num

    FROM shopsphere_raw.customers
)

SELECT
    customer_id,
    first_name,
    last_name,
    email,
    phone,
    signup_date,
    customer_status,
    email_quality,
    updated_at

FROM customer_cleaning

WHERE row_num = 1
  AND customer_id IS NOT NULL;


-- Validate staged customers

SELECT *
FROM shopsphere_staging.stg_customers
ORDER BY customer_id;


-- Check that duplicate customer IDs do not remain

SELECT
    customer_id,
    COUNT(*) AS record_count
FROM shopsphere_staging.stg_customers
GROUP BY customer_id
HAVING COUNT(*) > 1;


SELECT
    r.customer_id,

    r.email AS raw_email,

    s.email AS cleaned_email,

    s.email_quality

FROM shopsphere_raw.customers r

JOIN shopsphere_staging.stg_customers s
    ON r.customer_id = s.customer_id

ORDER BY r.customer_id;


-- ============================================================
-- 2. PREPROCESS ORDERS
-- Deduplicate orders and standardize order status
-- ============================================================

DROP TABLE IF EXISTS shopsphere_staging.stg_orders;

CREATE TABLE shopsphere_staging.stg_orders AS

WITH order_cleaning AS
(
    SELECT
        order_id,
        customer_id,
        order_date,

        -- Standardize order status
        UPPER(TRIM(order_status)) AS order_status,

        shipping_address_id,
        order_total,
        updated_at,

        -- Keep latest record if duplicate order_id exists
        ROW_NUMBER() OVER
        (
            PARTITION BY order_id
            ORDER BY updated_at DESC
        ) AS row_num

    FROM shopsphere_raw.orders
)

SELECT
    order_id,
    customer_id,
    order_date,
    order_status,
    shipping_address_id,
    order_total,
    updated_at

FROM order_cleaning

WHERE row_num = 1
  AND order_id IS NOT NULL;


SELECT *
FROM shopsphere_staging.stg_orders
ORDER BY order_id;


SELECT COUNT(*) AS staged_order_count
FROM shopsphere_staging.stg_orders;\

SELECT
    order_id,
    COUNT(*) AS record_count
FROM shopsphere_staging.stg_orders
GROUP BY order_id
HAVING COUNT(*) > 1;

-- ============================================================
-- 3. PREPROCESS ORDER ITEMS
-- Validate quantities, prices, discounts and order references
-- ============================================================

DROP TABLE IF EXISTS shopsphere_staging.stg_order_items;

CREATE TABLE shopsphere_staging.stg_order_items AS

SELECT
    oi.order_item_id,
    oi.order_id,
    oi.product_id,
    oi.quantity,

    oi.unit_price AS original_unit_price,

    p.product_price AS master_product_price,

    oi.discount_amount,

    -- Correct price if order-item price differs
    -- from master product price by more than 20%
    CASE
        WHEN p.product_price IS NOT NULL
             AND p.product_price <> 0
             AND ABS(oi.unit_price - p.product_price)
                 / p.product_price > 0.20
        THEN p.product_price

        ELSE oi.unit_price
    END AS corrected_unit_price,

    -- Flag whether price was corrected
    CASE
        WHEN p.product_price IS NOT NULL
             AND p.product_price <> 0
             AND ABS(oi.unit_price - p.product_price)
                 / p.product_price > 0.20
        THEN 'CORRECTED'

        ELSE 'ORIGINAL'
    END AS price_correction_flag,

    -- Validate the entire order item
    CASE
        WHEN o.order_id IS NULL
            THEN 'INVALID_ORDER'

        WHEN p.product_id IS NULL
            THEN 'INVALID_PRODUCT'

        WHEN oi.quantity <= 0
            THEN 'INVALID_QUANTITY'

        WHEN oi.unit_price < 0
            THEN 'INVALID_PRICE'

        WHEN oi.discount_amount < 0
            THEN 'INVALID_DISCOUNT'

        ELSE 'VALID'
    END AS item_quality

FROM shopsphere_raw.order_items oi

LEFT JOIN shopsphere_staging.stg_orders o
    ON oi.order_id = o.order_id

LEFT JOIN shopsphere_raw.products p
    ON oi.product_id = p.product_id;


SELECT *
FROM shopsphere_staging.stg_order_items
ORDER BY order_item_id;


SELECT
    order_item_id,
    order_id,
    product_id,
    quantity,
    original_unit_price,
    master_product_price,
    discount_amount,
    item_quality
FROM shopsphere_staging.stg_order_items
WHERE item_quality <> 'VALID';


-- ============================================================
-- 4. ORDER REVENUE VALIDATION
-- ============================================================

SELECT
    o.order_id,

    o.order_total AS stored_order_total,

    SUM(
        oi.quantity * oi.corrected_unit_price
        - COALESCE(oi.discount_amount, 0)
    ) AS calculated_order_total,

    o.order_total -
    SUM(
        oi.quantity * oi.corrected_unit_price
        - COALESCE(oi.discount_amount, 0)
    ) AS difference,

    CASE
        WHEN ABS(
            o.order_total -
            SUM(
                oi.quantity * oi.corrected_unit_price
                - COALESCE(oi.discount_amount, 0)
            )
        ) < 0.01

        THEN 'MATCH'

        ELSE 'MISMATCH'
    END AS revenue_status

FROM shopsphere_staging.stg_orders o

JOIN shopsphere_staging.stg_order_items oi
    ON o.order_id = oi.order_id

WHERE oi.item_quality = 'VALID'

GROUP BY
    o.order_id,
    o.order_total

ORDER BY o.order_id;


-- ============================================================
-- 5. PREPROCESS PAYMENTS
-- Standardize payment fields and identify duplicate transactions
-- ============================================================

DROP TABLE IF EXISTS shopsphere_staging.stg_payments;

CREATE TABLE shopsphere_staging.stg_payments AS

SELECT
    payment_id,
    order_id,
    payment_date,

    UPPER(TRIM(payment_method)) AS payment_method,
    UPPER(TRIM(payment_status)) AS payment_status,

    amount,

    TRIM(transaction_id) AS transaction_id,

    CASE
        WHEN order_id IS NULL THEN 'MISSING_ORDER_ID'
        WHEN amount < 0 THEN 'INVALID_AMOUNT'
        WHEN transaction_id IS NULL
             OR TRIM(transaction_id) = ''
            THEN 'MISSING_TRANSACTION'
        ELSE 'VALID'
    END AS payment_quality

FROM shopsphere_raw.payments;


SELECT *
FROM shopsphere_staging.stg_payments
ORDER BY payment_id;


-- ============================================================
-- 6. PAYMENT RECONCILIATION
-- Compare orders against payments
-- ============================================================

SELECT
    o.order_id,
    o.order_total,

    COUNT(p.payment_id) AS payment_count,

    COALESCE(
        SUM(p.amount)
        FILTER (WHERE p.payment_status = 'SUCCESS'),
        0
    ) AS successful_payment_amount,

    STRING_AGG(
        DISTINCT p.payment_status,
        ', '
    ) AS payment_status,

    CASE
        WHEN COUNT(p.payment_id) = 0
            THEN 'NO_PAYMENT'

        WHEN COUNT(p.payment_id) > 1
            THEN 'MULTIPLE_PAYMENTS'

        WHEN MAX(p.payment_status) = 'REFUNDED'
            THEN 'REFUNDED'

        WHEN ABS(
            o.order_total -
            COALESCE(
                SUM(p.amount)
                FILTER (WHERE p.payment_status = 'SUCCESS'),
                0
            )
        ) > 0.01
            THEN 'PAYMENT_MISMATCH'

        ELSE 'MATCH'
    END AS reconciliation_status

FROM shopsphere_staging.stg_orders o

LEFT JOIN shopsphere_staging.stg_payments p
    ON o.order_id = p.order_id

GROUP BY
    o.order_id,
    o.order_total

ORDER BY o.order_id;



-- Check duplicate payment transactions

SELECT
    transaction_id,
    COUNT(*) AS payment_count,
    SUM(amount) AS total_amount,
    MIN(payment_date) AS first_payment_date,
    MAX(payment_date) AS last_payment_date

FROM shopsphere_staging.stg_payments

GROUP BY transaction_id

HAVING COUNT(*) > 1;


-- ============================================================
-- 7. PREPROCESS SHIPMENTS
-- Validate shipment dates and calculate SLA
-- ============================================================

DROP TABLE IF EXISTS shopsphere_staging.stg_shipments;

CREATE TABLE shopsphere_staging.stg_shipments AS

SELECT
    s.shipment_id,
    s.order_id,
    s.shipped_date,
    s.delivered_date,

    UPPER(TRIM(s.carrier)) AS carrier,

    UPPER(TRIM(s.shipping_status)) AS shipping_status,

    -- Days from order to shipment
    (s.shipped_date::date - o.order_date::date)
        AS days_to_ship,

    -- Days from shipment to delivery
    CASE
        WHEN s.delivered_date IS NOT NULL
        THEN s.delivered_date::date - s.shipped_date::date
        ELSE NULL
    END AS days_to_deliver,

    -- Shipment SLA classification
    CASE
        WHEN o.order_id IS NULL
            THEN 'INVALID'

        WHEN s.shipped_date < o.order_date
            THEN 'INVALID'

        WHEN s.delivered_date IS NOT NULL
             AND s.delivered_date < s.shipped_date
            THEN 'INVALID'

        WHEN s.shipped_date::date = o.order_date::date
            THEN 'SAME_DAY_SHIPMENT'

        WHEN (s.shipped_date::date - o.order_date::date)
             BETWEEN 1 AND 3
            THEN 'NORMAL'

        WHEN (s.shipped_date::date - o.order_date::date) > 3
            THEN 'SLOW'

        ELSE 'INVALID'
    END AS shipment_quality

FROM shopsphere_raw.shipments s

LEFT JOIN shopsphere_staging.stg_orders o
    ON s.order_id = o.order_id;


SELECT *
FROM shopsphere_staging.stg_shipments
ORDER BY shipment_id;

SELECT
    shipment_quality,
    COUNT(*) AS shipment_count
FROM shopsphere_staging.stg_shipments
GROUP BY shipment_quality
ORDER BY shipment_quality;

-- ============================================================
-- 8. PREPROCESS PRODUCTS
-- ============================================================

DROP TABLE IF EXISTS shopsphere_staging.stg_products;

CREATE TABLE shopsphere_staging.stg_products AS

SELECT
    product_id,
    TRIM(product_name) AS product_name,
    category_id,
    product_price,
    UPPER(TRIM(product_status)) AS product_status,
    created_at,
    updated_at,

    CASE
        WHEN product_id IS NULL
            THEN 'INVALID_PRODUCT_ID'

        WHEN product_price IS NULL
             OR product_price <= 0
            THEN 'INVALID_PRICE'

        WHEN product_name IS NULL
             OR TRIM(product_name) = ''
            THEN 'INVALID_NAME'

        ELSE 'VALID'
    END AS product_quality

FROM shopsphere_raw.products;


SELECT *
FROM shopsphere_staging.stg_products
ORDER BY product_id;


SELECT COUNT(*)
FROM shopsphere_staging.stg_products;

-- ============================================================
-- 9. PREPROCESS CUSTOMER ADDRESSES
-- ============================================================

DROP TABLE IF EXISTS shopsphere_staging.stg_customer_addresses;

CREATE TABLE shopsphere_staging.stg_customer_addresses AS

SELECT
    address_id,
    customer_id,

    UPPER(TRIM(address_type)) AS address_type,

    TRIM(address_line1) AS address_line1,
    TRIM(city) AS city,

    UPPER(TRIM(state)) AS state,

    TRIM(postal_code) AS postal_code,

    UPPER(TRIM(country)) AS country,

    is_primary,
    updated_at

FROM shopsphere_raw.customer_addresses;

SELECT *
FROM shopsphere_staging.stg_customer_addresses
ORDER BY address_id;

-- ============================================================
-- 10. PREPROCESS CATEGORIES
-- ============================================================

DROP TABLE IF EXISTS shopsphere_staging.stg_categories;

CREATE TABLE shopsphere_staging.stg_categories AS

SELECT
    category_id,
    TRIM(category_name) AS category_name,
    parent_category_id

FROM shopsphere_raw.categories;

