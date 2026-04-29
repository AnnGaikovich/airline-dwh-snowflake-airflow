# Airline Data Warehouse on Snowflake with Airflow

## Project Overview
This project implements a complete ETL pipeline that loads airline passenger data from a CSV file into Snowflake, transforms it through staging, core (dimensions and fact), and mart layers, and orchestrates the process using Apache Airflow. It includes auditing, time travel examples, row-level security, and a simple BI report.

## Repository Structure

.
├── dags/
│ ├── airline_dwh_dag.py # Airflow DAG with TaskFlow API
│ └── config.py # Configuration variables
├── sql/
│ ├── 01_create_objects.sql
│ ├── 02_procedures.sql
│ ├── 03_time_travel_examples.sql
│ └── 04_secure_view.sql
├── data/
│ └── Airline_Dataset.csv 
├── BI_report.png # Screenshot of Snowsight chart
└── README.md


## Prerequisites
- Snowflake account (free trial)
- Airflow environment (local or Docker) with Snowflake provider installed
- Python 3.8+

## Setup Instructions

### 1. Snowflake Setup
- Create a warehouse `dwh_wh`, database `airline_dwh`, and schemas `staging`, `core`, `mart`, `audit`.
- Run the SQL scripts in the following order:
  1. `sql/01_create_objects.sql`
  2. `sql/02_procedures.sql`
  3. `sql/03_time_travel_examples.sql` (optional, demonstrates time travel)
  4. `sql/04_secure_view.sql` (creates RLS policy)
  5. `sql/BI_report.sql` (creates chart)

### 2. Airflow Configuration
- Place the `dags/` folder in your Airflow `dags/` directory.
- Configure a Snowflake connection in Airflow with conn_id `snowflake_default`.
- Set the following Airflow Variables (if using default DAG):
  - `snowflake_user`, `snowflake_password`, `snowflake_account` (or use connection extra JSON).

### 3. Run the Pipeline
- Trigger the DAG `airline_dwh_pipeline` manually or wait for daily schedule.
- The DAG will:
  - Load CSV from `/opt/airflow/data/Airline_Dataset.csv` into staging table.
  - Load dimensions (`dim_passenger`, `dim_airport`, `dim_date`, `dim_flight_status`).
  - Load facts (`fact_flight`).
  - Refresh the mart (`mart_flight_summary`).

### 4. Verify Results
- Check audit logs: `SELECT * FROM audit.audit_etl_log;`
- Check mart data: `SELECT * FROM mart.mart_flight_summary;`
- Test secure view as different roles (e.g., `ANALYST_NAM` vs `ANALYST_ALL`).

## Time Travel Examples
- See `sql/03_time_travel_examples.sql` for DDL (drop/undrop) and DML (historical queries).

## BI Report
- A simple chart built in Snowsight (`mart_flight_summary`) is saved as `bi_report.png`.

## Troubleshooting
- If `fact_flight` remains empty, run the additional INSERT statements at the end of `02_procedures.sql` to populate missing airports.



