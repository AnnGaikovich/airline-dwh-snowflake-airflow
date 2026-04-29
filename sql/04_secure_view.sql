-- =====================================================
-- Secure View with Row Level Security
-- =====================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE AIRLINE_DWH;
USE SCHEMA core;

-- Create roles if they don't exist
CREATE ROLE IF NOT EXISTS ANALYST_ASIA;
CREATE ROLE IF NOT EXISTS ANALYST_ALL;

-- Узнайте имя вашего пользователя (обычно email)
SHOW USERS;

-- Выдайте созданные роли вашему пользователю (замените 'ваш_email' на реальный)
GRANT ROLE ANALYST_ASIA TO USER HANNAHAIKOVICH;
GRANT ROLE ANALYST_ALL TO USER HANNAHAIKOVICH;

-- Дополнительно: разрешите ACCOUNTADMIN переключаться на эти роли
GRANT ROLE ANALYST_ASIA TO ROLE ACCOUNTADMIN;
GRANT ROLE ANALYST_ALL TO ROLE ACCOUNTADMIN;

-- Drop the policy from the view if it's already attached (idempotent)
ALTER VIEW IF EXISTS secure_flight_fact DROP ROW ACCESS POLICY continent_policy;

-- Create a row access policy that restricts to 'ASIA' continent for ANALYST_ASIA role
CREATE OR REPLACE ROW ACCESS POLICY continent_policy AS (continent_val STRING) RETURNS BOOLEAN ->
    CURRENT_ROLE() = 'ANALYST_ASIA' AND continent_val = 'Asia'
    OR CURRENT_ROLE() = 'ANALYST_ALL';

-- Create a secure view based on fact_flight and dim_airport
CREATE OR REPLACE SECURE VIEW secure_flight_fact AS
SELECT
    f.flight_sk,
    f.pilot_name,
    f.departure_date,
    f.flight_status,
    a.continents AS continent
FROM fact_flight f
JOIN dim_airport a ON f.departure_airport_sk = a.airport_sk;

-- Apply the row access policy to the secure view
ALTER VIEW secure_flight_fact ADD ROW ACCESS POLICY continent_policy ON (continent);

-- Grant SELECT to the roles
GRANT SELECT ON VIEW secure_flight_fact TO ROLE ANALYST_ASIA;
GRANT SELECT ON VIEW secure_flight_fact TO ROLE ANALYST_ALL;

-- Optional: grant usage on database and schema
GRANT USAGE ON DATABASE AIRLINE_DWH TO ROLE ANALYST_ASIA;
GRANT USAGE ON DATABASE AIRLINE_DWH TO ROLE ANALYST_ALL;
GRANT USAGE ON SCHEMA core TO ROLE ANALYST_ASIA;
GRANT USAGE ON SCHEMA core TO ROLE ANALYST_ALL;

-- Test query as different roles (uncomment to test)
-- USE ROLE ANALYST_ASIA;
-- SELECT * FROM secure_flight_fact;  -- should see only rows with continent = 'Asia'

-- USE ROLE ANALYST_ALL;
-- SELECT * FROM secure_flight_fact;  -- should see all rows