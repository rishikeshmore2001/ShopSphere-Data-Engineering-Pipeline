-- ============================================================
-- SHOPSPHERE CAPSTONE
-- FILE: 05_query_optimization.sql
-- PURPOSE: Query performance analysis and optimization
-- ============================================================


-- ============================================================
-- 1. PERFORMANCE TEST BEFORE INDEXING
-- ============================================================

EXPLAIN (ANALYZE, BUFFERS)

SELECT
    f.order_id,
    f.order_date,
    c.full_name,
    p.product_name,
    f.quantity,
    f.net_revenue

FROM shopsphere_curated.fact_order f

JOIN shopsphere_curated.dim_customer c
    ON f.customer_key = c.customer_key

JOIN shopsphere_curated.dim_product p
    ON f.product_key = p.product_key

WHERE f.order_date >= '2024-03-01'
  AND f.order_date < '2024-04-01';