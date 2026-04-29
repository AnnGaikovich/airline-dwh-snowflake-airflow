-- =====================================================
-- 1. Warehouse, Database, Schema
-- =====================================================
CREATE WAREHOUSE IF NOT EXISTS dwh_wh WITH WAREHOUSE_SIZE = 'XSMALL';
CREATE DATABASE IF NOT EXISTS airline_dwh;
CREATE SCHEMA IF NOT EXISTS airline_dwh.staging;
CREATE SCHEMA IF NOT EXISTS airline_dwh.core;
CREATE SCHEMA IF NOT EXISTS airline_dwh.mart;
CREATE SCHEMA IF NOT EXISTS airline_dwh.audit;

USE WAREHOUSE dwh_wh;
USE DATABASE airline_dwh;
USE SCHEMA staging;

-- =====================================================
-- 2. Staging Table (raw CSV data)
-- =====================================================
CREATE OR REPLACE TABLE stg_airline_raw (
    raw_data VARIANT,                     -- store whole JSON/CSV row, easier for initial load
    loaded_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Alternatively, a typed staging table (showing main columns)
CREATE OR REPLACE TABLE stg_airline_typed (
    passenger_id      STRING,
    first_name        STRING,
    last_name         STRING,
    gender            STRING,
    age               NUMBER,
    nationality       STRING,
    airport_name      STRING,
    airport_country_code STRING,
    country_name      STRING,
    airport_continent STRING,
    continents        STRING,
    departure_date    DATE,
    arrival_airport   STRING,
    pilot_name        STRING,
    flight_status     STRING,
    ticket_type       STRING,
    passenger_status  STRING,
    loaded_at         TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- For simplicity we use the typed table. We'll assume the CSV is loaded into it via Airflow.

-- =====================================================
-- 3. Core Layer (Dimensions & Fact)
-- =====================================================
USE SCHEMA core;

-- Dimension: Passenger
CREATE OR REPLACE TABLE dim_passenger (
    passenger_sk      NUMBER IDENTITY(1,1) PRIMARY KEY,
    passenger_id      STRING NOT NULL UNIQUE,
    first_name        STRING,
    last_name         STRING,
    gender            STRING,
    age               NUMBER,
    nationality       STRING,
    valid_from        TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    valid_to          TIMESTAMP_NTZ DEFAULT '9999-12-31'::TIMESTAMP_NTZ,
    is_current        BOOLEAN DEFAULT TRUE
);

-- Dimension: Airport
CREATE OR REPLACE TABLE dim_airport (
    airport_sk        NUMBER IDENTITY(1,1) PRIMARY KEY,
    airport_name      STRING NOT NULL,
    airport_country_code STRING,
    country_name      STRING,
    airport_continent STRING,
    continents        STRING
);

-- Dimension: Date (departure dates)
CREATE OR REPLACE TABLE dim_date (
    date_sk           NUMBER PRIMARY KEY,
    full_date         DATE NOT NULL,
    year              NUMBER,
    month             NUMBER,
    day               NUMBER,
    quarter           NUMBER,
    day_of_week       NUMBER
);

-- Dimension: Flight Status (status + ticket type)
CREATE OR REPLACE TABLE dim_flight_status (
    status_sk         NUMBER IDENTITY(1,1) PRIMARY KEY,
    flight_status     STRING,
    ticket_type       STRING,
    passenger_status  STRING
);

-- Fact: Flight
CREATE OR REPLACE TABLE fact_flight (
    flight_sk         NUMBER IDENTITY(1,1) PRIMARY KEY,
    passenger_sk      NUMBER REFERENCES dim_passenger(passenger_sk),
    departure_airport_sk NUMBER REFERENCES dim_airport(airport_sk),
    arrival_airport_sk   NUMBER REFERENCES dim_airport(airport_sk),
    departure_date_sk    NUMBER REFERENCES dim_date(date_sk),
    flight_status_sk     NUMBER REFERENCES dim_flight_status(status_sk),
    pilot_name        STRING,
    departure_date    DATE,                -- denormalized for convenience
    flight_status     STRING,
    ticket_type       STRING
);

-- =====================================================
-- 4. Mart Layer (aggregated summary)
-- =====================================================
USE SCHEMA mart;

CREATE OR REPLACE TABLE mart_flight_summary (
    continent        STRING,
    flight_status    STRING,
    flight_count     NUMBER,
    last_updated     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- =====================================================
-- 5. Audit Table
-- =====================================================
USE SCHEMA audit;

CREATE OR REPLACE TABLE audit_etl_log (
    log_id           NUMBER IDENTITY(1,1) PRIMARY KEY,
    procedure_name   STRING,
    start_time       TIMESTAMP_NTZ,
    end_time         TIMESTAMP_NTZ,
    rows_affected    NUMBER,
    status           STRING,
    error_message    STRING
);

SELECT * FROM AIRLINE_DWH.AUDIT.AUDIT_ETL_LOG;
