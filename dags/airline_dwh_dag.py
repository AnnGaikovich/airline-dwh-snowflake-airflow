from airflow.decorators import dag, task
from airflow.providers.common.sql.operators.sql import SQLExecuteQueryOperator
from config import DEFAULT_ARGS, SNOWFLAKE_CONN_ID, CSV_PATH

@dag(
    dag_id='airline_dwh_pipeline',
    default_args=DEFAULT_ARGS,
    schedule='@daily',
    catchup=False,
    tags=['snowflake', 'dwh']
)
def airline_dwh_pipeline():

    @task
    def load_csv_to_staging():
        from airflow.providers.snowflake.hooks.snowflake import SnowflakeHook
        hook = SnowflakeHook(snowflake_conn_id=SNOWFLAKE_CONN_ID)
        conn = hook.get_conn()
        cursor = conn.cursor()

        cursor.execute("USE SCHEMA AIRLINE_DWH.STAGING")
        cursor.execute("CREATE OR REPLACE TEMPORARY STAGE airflow_stage")
        cursor.execute(f"PUT file://{CSV_PATH} @airflow_stage AUTO_COMPRESS=FALSE OVERWRITE=TRUE")
        cursor.execute("""
            COPY INTO AIRLINE_DWH.STAGING.STG_AIRLINE_TYPED (
                passenger_id, first_name, last_name, gender, age, nationality,
                airport_name, airport_country_code, country_name, airport_continent,
                continents, departure_date, arrival_airport, pilot_name,
                flight_status, ticket_type, passenger_status
            )
            FROM @airflow_stage
            FILE_FORMAT = (TYPE = CSV SKIP_HEADER = 1 FIELD_OPTIONALLY_ENCLOSED_BY = '"' NULL_IF = ('NULL', ''))
            ON_ERROR = 'CONTINUE'
        """)
        conn.commit()
        cursor.close()
        conn.close()

    load_dims = SQLExecuteQueryOperator(
        task_id='call_load_dimensions',
        sql="BEGIN; CALL core.load_dimensions(); COMMIT;",
        conn_id=SNOWFLAKE_CONN_ID
    )

    load_fact = SQLExecuteQueryOperator(
        task_id='call_load_fact',
        sql="BEGIN; CALL core.load_fact_flight(); COMMIT;",
        conn_id=SNOWFLAKE_CONN_ID
    )

    refresh_mart = SQLExecuteQueryOperator(
        task_id='call_refresh_mart',
        sql="BEGIN; CALL mart.refresh_mart(); COMMIT;",
        conn_id=SNOWFLAKE_CONN_ID
    )

    load_staging = load_csv_to_staging()
    load_staging >> load_dims >> load_fact >> refresh_mart

dag = airline_dwh_pipeline()