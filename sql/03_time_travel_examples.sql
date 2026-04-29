-- =====================================================
-- 2 DDL + 2 DML examples with Time Travel
-- =====================================================

USE DATABASE AIRLINE_DWH;
USE SCHEMA core;

-- 1. DDL: Accidentally drop a column
ALTER TABLE dim_passenger DROP COLUMN nationality;

-- Verify column is gone (query will fail if column absent)
SELECT * FROM dim_passenger LIMIT 5;

-- Restore the whole table using UNDROP (Time Travel)
UNDROP TABLE dim_passenger;

-- Alternative: Clone table as it was 5 minutes ago
CREATE TABLE dim_passenger_backup CLONE dim_passenger BEFORE (OFFSET => -300);

-- 2. DML: Query historical data
-- Count rows in fact table 1 hour ago
SELECT COUNT(*) AS cnt_1h_ago FROM fact_flight AT(OFFSET => -3600);

-- Compare current vs 1 hour ago
WITH curr AS (SELECT COUNT(*) AS cnt FROM fact_flight),
     historical AS (SELECT COUNT(*) AS cnt FROM fact_flight AT(OFFSET => -3600))
SELECT curr.cnt AS now, historical.cnt AS one_hour_ago
FROM curr, historical;

-- Query data from a specific timestamp (example: 2024-01-01 00:00:00)
-- SELECT * FROM fact_flight AT(TIMESTAMP => '2024-01-01 00:00:00'::TIMESTAMP_NTZ);