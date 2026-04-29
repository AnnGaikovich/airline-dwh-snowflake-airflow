USE DATABASE AIRLINE_DWH;
USE SCHEMA core;

-- Drop old procedures to avoid conflicts
DROP PROCEDURE IF EXISTS core.load_dimensions();
DROP PROCEDURE IF EXISTS core.load_fact_flight();
DROP PROCEDURE IF EXISTS mart.refresh_mart();

-- 1. load_dimensions (without SQLROWCOUNT)
CREATE OR REPLACE PROCEDURE core.load_dimensions()
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
    -- Passengers
    INSERT INTO dim_passenger (passenger_id, first_name, last_name, gender, age, nationality)
    SELECT DISTINCT passenger_id, first_name, last_name, gender, age, nationality
    FROM staging.stg_airline_typed
    WHERE passenger_id IS NOT NULL;

    -- Airports (from both airport_name and arrival_airport columns)
    INSERT INTO dim_airport (airport_name, airport_country_code, country_name, airport_continent, continents)
    SELECT DISTINCT airport_name, NULL, NULL, NULL, NULL
    FROM staging.stg_airline_typed
    WHERE airport_name IS NOT NULL
    UNION
    SELECT DISTINCT arrival_airport, NULL, NULL, NULL, NULL
    FROM staging.stg_airline_typed
    WHERE arrival_airport IS NOT NULL;

    -- Dates
    INSERT INTO dim_date (date_sk, full_date, year, month, day, quarter, day_of_week)
    SELECT DISTINCT
        TO_NUMBER(TO_CHAR(departure_date, 'YYYYMMDD')),
        departure_date,
        EXTRACT(YEAR FROM departure_date),
        EXTRACT(MONTH FROM departure_date),
        EXTRACT(DAY FROM departure_date),
        EXTRACT(QUARTER FROM departure_date),
        DAYOFWEEK(departure_date)
    FROM staging.stg_airline_typed
    WHERE departure_date IS NOT NULL;

    -- Flight statuses
    INSERT INTO dim_flight_status (flight_status, ticket_type, passenger_status)
    SELECT DISTINCT flight_status, ticket_type, passenger_status
    FROM staging.stg_airline_typed
    WHERE flight_status IS NOT NULL;

    -- Audit log
    INSERT INTO audit.audit_etl_log (procedure_name, start_time, end_time, rows_affected, status)
    VALUES ('load_dimensions', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP(), 0, 'SUCCESS');

    RETURN 'Dimensions loaded successfully';
END;
$$;

-- 2. load_fact_flight (without SQLROWCOUNT)
CREATE OR REPLACE PROCEDURE core.load_fact_flight()
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
    INSERT INTO fact_flight (
        passenger_sk,
        departure_airport_sk,
        arrival_airport_sk,
        departure_date_sk,
        flight_status_sk,
        pilot_name,
        departure_date,
        flight_status,
        ticket_type
    )
    SELECT
        dp.passenger_sk,
        da_dep.airport_sk,
        da_arr.airport_sk,
        dd.date_sk,
        dfs.status_sk,
        src.pilot_name,
        src.departure_date,
        src.flight_status,
        src.ticket_type
    FROM staging.stg_airline_typed src
    JOIN dim_passenger dp ON src.passenger_id = dp.passenger_id
    JOIN dim_airport da_dep ON src.airport_name = da_dep.airport_name
    JOIN dim_airport da_arr ON src.arrival_airport = da_arr.airport_name
    JOIN dim_date dd ON src.departure_date = dd.full_date
    JOIN dim_flight_status dfs ON src.flight_status = dfs.flight_status AND src.ticket_type = dfs.ticket_type
    WHERE NOT EXISTS (
        SELECT 1 FROM fact_flight ff
        WHERE ff.passenger_sk = dp.passenger_sk
        AND ff.departure_date = src.departure_date
    );

    INSERT INTO audit.audit_etl_log (procedure_name, start_time, end_time, rows_affected, status)
    VALUES ('load_fact_flight', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP(), 0, 'SUCCESS');

    RETURN 'Fact table loaded successfully';
END;
$$;

-- 3. refresh_mart (without SQLROWCOUNT)
CREATE OR REPLACE PROCEDURE mart.refresh_mart()
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
    MERGE INTO mart.mart_flight_summary AS tgt
    USING (
        SELECT
            da.continents AS continent,
            f.flight_status,
            COUNT(*) AS flight_count
        FROM core.fact_flight f
        JOIN core.dim_airport da ON f.departure_airport_sk = da.airport_sk
        GROUP BY da.continents, f.flight_status
    ) src
    ON tgt.continent = src.continent AND tgt.flight_status = src.flight_status
    WHEN MATCHED THEN UPDATE SET tgt.flight_count = src.flight_count, tgt.last_updated = CURRENT_TIMESTAMP()
    WHEN NOT MATCHED THEN INSERT (continent, flight_status, flight_count)
         VALUES (src.continent, src.flight_status, src.flight_count);

    INSERT INTO audit.audit_etl_log (procedure_name, start_time, end_time, rows_affected, status)
    VALUES ('refresh_mart', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP(), 0, 'SUCCESS');

    RETURN 'Mart refreshed';
END;
$$;

-- =====================================================
-- Additional: Insert missing airports (if fact table remains empty)
-- =====================================================
-- These INSERTs ensure that all departure and arrival airports from staging
-- are present in dim_airport, allowing the load_fact_flight procedure to
-- successfully join and insert all rows.
-- Run them once after the initial staging load if fact_flight stays empty.
INSERT INTO dim_airport (airport_name, airport_country_code, country_name, airport_continent, continents)
SELECT DISTINCT src.airport_name, src.airport_country_code, src.country_name, src.airport_continent, src.continents
FROM staging.stg_airline_typed src
WHERE src.airport_name IS NOT NULL
AND NOT EXISTS (SELECT 1 FROM dim_airport da WHERE da.airport_name = src.airport_name);

INSERT INTO dim_airport (airport_name, airport_country_code, country_name, airport_continent, continents)
SELECT DISTINCT src.arrival_airport, NULL, NULL, NULL, NULL
FROM staging.stg_airline_typed src
WHERE src.arrival_airport IS NOT NULL
AND NOT EXISTS (SELECT 1 FROM dim_airport da WHERE da.airport_name = src.arrival_airport);