USE WAREHOUSE dwh_wh;
USE DATABASE AIRLINE_DWH;
USE SCHEMA MART;

SELECT continent, flight_status, flight_count
FROM mart_flight_summary
ORDER BY flight_count DESC;