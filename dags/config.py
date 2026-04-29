from datetime import datetime, timedelta

DEFAULT_ARGS = {
    'owner': 'airflow',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

SNOWFLAKE_CONN_ID = 'snowflake_default'
CSV_PATH = '/opt/airflow/data/Airline_Dataset.csv'