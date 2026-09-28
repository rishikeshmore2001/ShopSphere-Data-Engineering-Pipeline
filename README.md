# ShopSphere Data Engineering Pipeline

## Project Overview

ShopSphere is an end-to-end e-commerce data engineering project built using PostgreSQL, SQL, and Power BI.

The project demonstrates the complete data pipeline lifecycle, including raw data ingestion, data profiling, preprocessing, data quality validation, dimensional modeling, analytics, query optimization, and business intelligence reporting.

## Architecture

RAW → STAGING → CURATED → ANALYTICS → POWER BI

### Raw Layer
Stores the original e-commerce data including customers, products, orders, order items, payments, shipments, categories, and customer addresses.

### Staging Layer
Performs data cleaning and preprocessing, including:
- Duplicate detection
- NULL and missing value handling
- Email standardization
- Invalid record identification
- Data validation

### Curated Layer
Transforms cleaned data into analytics-ready dimensional models, including dimension and fact tables.

### Analytics Layer
Provides business-level analytics such as:
- Daily revenue
- Monthly revenue
- Customer lifetime value
- Product performance
- Category performance

## Technologies Used

- PostgreSQL
- SQL
- Power BI
- Dimensional Modeling
- ETL / Data Pipelines
- Data Quality Validation
- Query Optimization
- GitHub

## SQL Scripts

### 01_data_profiling.sql
Profiles the raw data and identifies duplicates, invalid records, missing values, and data-quality issues.

### 02_preprocessing.sql
Cleans and standardizes raw data and prepares staging tables.

### 03_curated_tables.sql
Creates analytics-ready dimension and fact tables.

### 04_analytics.sql
Performs revenue, customer, product, and business analytics.

### 05_query_optimization.sql
Uses indexes, ANALYZE, and EXPLAIN ANALYZE to evaluate and improve query performance.

## Power BI Dashboard

The Power BI dashboard provides visual analysis of:

- Daily Revenue Trend
- Product Revenue Performance
- Revenue by Category
- Top Customers by Lifetime Revenue
- Revenue by State

## Key Skills Demonstrated

SQL | PostgreSQL | ETL | Data Cleaning | Data Modeling | Data Warehousing | Dimensional Modeling | Data Quality | Query Optimization | Power BI | Data Visualization

## Author

Rishikesh More
