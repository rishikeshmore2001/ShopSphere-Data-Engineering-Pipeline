-- ============================================================
-- SHOPSPHERE CAPSTONE
-- FILE: 04_analytics.sql
-- PURPOSE: Business analytics using curated data
-- ============================================================


-- ============================================================
-- 1. MONTHLY REVENUE
-- ============================================================

DROP TABLE IF EXISTS shopsphere_analytics.monthly_revenue;

CREATE TABLE shopsphere_analytics.monthly_revenue AS

SELECT
    DATE_TRUNC('month', order_date)::date AS revenue_month,

    COUNT(DISTINCT order_id) AS total_orders,

    SUM(net_revenue) AS total_revenue,

    ROUND(
        SUM(net_revenue) /
        NULLIF(COUNT(DISTINCT order_id), 0),
        2
    ) AS average_order_value

FROM shopsphere_curated.fact_order

WHERE order_status <> 'CANCELLED'

GROUP BY
    DATE_TRUNC('month', order_date)::date

ORDER BY revenue_month;

SELECT *
FROM shopsphere_analytics.monthly_revenue;

-- ============================================================
-- 2. DAILY REVENUE TREND
-- ============================================================

DROP TABLE IF EXISTS shopsphere_analytics.daily_revenue;

CREATE TABLE shopsphere_analytics.daily_revenue AS

SELECT
    order_date::date AS revenue_date,

    COUNT(DISTINCT order_id) AS total_orders,

    SUM(net_revenue) AS daily_revenue

FROM shopsphere_curated.fact_order

WHERE order_status <> 'CANCELLED'

GROUP BY order_date::date

ORDER BY revenue_date;


SELECT *
FROM shopsphere_analytics.daily_revenue;

SELECT
    revenue_date,
    daily_revenue,

    SUM(daily_revenue) OVER
    (
        ORDER BY revenue_date
    ) AS running_revenue

FROM shopsphere_analytics.daily_revenue

ORDER BY revenue_date;

SELECT
    revenue_date,
    daily_revenue,

    SUM(daily_revenue) OVER
    (
        ORDER BY revenue_date

        ROWS BETWEEN 6 PRECEDING
        AND CURRENT ROW

    ) AS seven_day_rolling_revenue

FROM shopsphere_analytics.daily_revenue

ORDER BY revenue_date;

-- ============================================================
-- 3. PRODUCT PERFORMANCE
-- ============================================================

DROP TABLE IF EXISTS shopsphere_analytics.product_performance;

CREATE TABLE shopsphere_analytics.product_performance AS

SELECT
    p.product_id,
    p.product_name,

    c.category_name,

    SUM(f.quantity) AS units_sold,

    COUNT(DISTINCT f.order_id) AS total_orders,

    SUM(f.net_revenue) AS product_revenue

FROM shopsphere_curated.fact_order f

JOIN shopsphere_curated.dim_product p
    ON f.product_key = p.product_key

LEFT JOIN shopsphere_curated.dim_category c
    ON p.category_key = c.category_key

WHERE f.order_status <> 'CANCELLED'

GROUP BY
    p.product_id,
    p.product_name,
    c.category_name

ORDER BY product_revenue DESC;

SELECT *
FROM shopsphere_analytics.product_performance;

-- ============================================================
-- 4. CATEGORY PERFORMANCE
-- ============================================================

SELECT
    c.category_name,

    COUNT(DISTINCT f.order_id) AS total_orders,

    SUM(f.quantity) AS units_sold,

    SUM(f.net_revenue) AS category_revenue

FROM shopsphere_curated.fact_order f

JOIN shopsphere_curated.dim_product p
    ON f.product_key = p.product_key

JOIN shopsphere_curated.dim_category c
    ON p.category_key = c.category_key

WHERE f.order_status <> 'CANCELLED'

GROUP BY c.category_name

ORDER BY category_revenue DESC;

-- ============================================================
-- 5. CUSTOMER LIFETIME VALUE
-- ============================================================

DROP TABLE IF EXISTS shopsphere_analytics.customer_lifetime_value;

CREATE TABLE shopsphere_analytics.customer_lifetime_value AS

SELECT
    c.customer_id,

    c.full_name AS customer_name,

    COUNT(DISTINCT f.order_id) AS number_of_orders,

    SUM(f.net_revenue) AS lifetime_revenue,

    ROUND(
        SUM(f.net_revenue)
        / NULLIF(COUNT(DISTINCT f.order_id), 0),
        2
    ) AS average_order_value

FROM shopsphere_curated.fact_order f

JOIN shopsphere_curated.dim_customer c
    ON f.customer_key = c.customer_key

WHERE f.order_status <> 'CANCELLED'

GROUP BY
    c.customer_id,
    c.full_name

ORDER BY lifetime_revenue DESC;

SELECT *
FROM shopsphere_analytics.customer_lifetime_value;

SELECT
    customer_id,
    customer_name,
    lifetime_revenue,

    RANK() OVER
    (
        ORDER BY lifetime_revenue DESC
    ) AS revenue_rank,

    DENSE_RANK() OVER
    (
        ORDER BY lifetime_revenue DESC
    ) AS dense_revenue_rank

FROM shopsphere_analytics.customer_lifetime_value

ORDER BY revenue_rank;

-- ============================================================
-- 6. STATE REVENUE
-- ============================================================

SELECT
    a.state,

    COUNT(DISTINCT f.order_id) AS total_orders,

    COUNT(DISTINCT f.customer_key) AS customers,

    SUM(f.net_revenue) AS total_revenue

FROM shopsphere_curated.fact_order f

JOIN shopsphere_curated.dim_address a
    ON f.address_key = a.address_key

WHERE f.order_status <> 'CANCELLED'

GROUP BY a.state

ORDER BY total_revenue DESC;



WITH product_revenue AS
(
    SELECT
        c.category_name,
        p.product_id,
        p.product_name,

        SUM(f.net_revenue) AS revenue

    FROM shopsphere_curated.fact_order f

    JOIN shopsphere_curated.dim_product p
        ON f.product_key = p.product_key

    JOIN shopsphere_curated.dim_category c
        ON p.category_key = c.category_key

    WHERE f.order_status <> 'CANCELLED'

    GROUP BY
        c.category_name,
        p.product_id,
        p.product_name
),

ranked_products AS
(
    SELECT
        *,

        DENSE_RANK() OVER
        (
            PARTITION BY category_name
            ORDER BY revenue DESC
        ) AS category_rank

    FROM product_revenue
)

SELECT *
FROM ranked_products

WHERE category_rank <= 3

ORDER BY
    category_name,
    category_rank;



WITH customer_orders AS
(
    SELECT
        c.customer_id,
        f.order_id,
        f.order_date,

        SUM(f.net_revenue) AS order_total

    FROM shopsphere_curated.fact_order f

    JOIN shopsphere_curated.dim_customer c
        ON f.customer_key = c.customer_key

    WHERE f.order_status <> 'CANCELLED'

    GROUP BY
        c.customer_id,
        f.order_id,
        f.order_date
),

previous_orders AS
(
    SELECT
        *,

        LAG(order_date) OVER
        (
            PARTITION BY customer_id
            ORDER BY order_date
        ) AS previous_order_date

    FROM customer_orders
)

SELECT
    customer_id,
    order_id,
    order_date,
    order_total,
    previous_order_date,

    order_date::date -
    previous_order_date::date
        AS days_since_previous_order

FROM previous_orders

ORDER BY
    customer_id,
    order_date;

-- ============================================================
-- BI GRAPH 1: DAILY REVENUE TREND
-- ============================================================

SELECT
    revenue_date,
    ROUND(daily_revenue, 2) AS daily_revenue

FROM shopsphere_analytics.daily_revenue

ORDER BY revenue_date;

-- ============================================================
-- BI GRAPH 2: PRODUCT REVENUE PERFORMANCE
-- ============================================================

SELECT
    product_name,
    ROUND(product_revenue, 2) AS product_revenue

FROM shopsphere_analytics.product_performance

ORDER BY product_revenue DESC;

-- ============================================================
-- BI GRAPH 3: REVENUE BY CATEGORY
-- ============================================================

SELECT
    c.category_name,

    ROUND(SUM(f.net_revenue), 2) AS category_revenue

FROM shopsphere_curated.fact_order f

JOIN shopsphere_curated.dim_product p
    ON f.product_key = p.product_key

JOIN shopsphere_curated.dim_category c
    ON p.category_key = c.category_key

WHERE f.order_status <> 'CANCELLED'

GROUP BY c.category_name

ORDER BY category_revenue DESC;


-- ============================================================
-- BI GRAPH 4: TOP CUSTOMERS BY LIFETIME REVENUE
-- ============================================================

SELECT
    customer_name,
    number_of_orders,
    ROUND(lifetime_revenue, 2) AS lifetime_revenue

FROM shopsphere_analytics.customer_lifetime_value

ORDER BY lifetime_revenue DESC

LIMIT 10;


-- ============================================================
-- BI GRAPH 5: REVENUE BY STATE
-- ============================================================

SELECT
    a.state,

    COUNT(DISTINCT f.order_id) AS total_orders,

    ROUND(SUM(f.net_revenue), 2) AS total_revenue

FROM shopsphere_curated.fact_order f

JOIN shopsphere_curated.dim_address a
    ON f.address_key = a.address_key

WHERE f.order_status <> 'CANCELLED'

GROUP BY a.state

ORDER BY total_revenue DESC;


