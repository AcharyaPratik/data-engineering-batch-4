import psycopg2
from psycopg2.extras import RealDictCursor
import logging

import os 
from dotenv import load_dotenv

load_dotenv()
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)s  %(message)s"
)
logger = logging.getLogger(__name__)


SOURCE_DB_CONFIG = dict(
    host=    os.getenv("SRC_DB_HOST"),
    port =   os.getenv("SRC_DB_PORT"),
    dbname = os.getenv("SRC_DB_NAME"),
    user=    os.getenv("SRC_DB_USER"),
    password=os.getenv("SRC_DB_PASSWORD")
)

DEST_DB_CONFIG = dict(
    host=    os.getenv("DEST_DB_HOST"),
    port =   os.getenv("DEST_DB_PORT"),
    dbname = os.getenv("DEST_DB_NAME"),
    user=    os.getenv("DEST_DB_USER"),
    password=os.getenv("DEST_DB_PASSWORD")
)



def extract(conn,sql):
    try:
        with conn.cursor(cursor_factory =RealDictCursor ) as curr:
            curr.execute(sql)
            rows = curr.fetchall()
            logger.info(f"Extracted {len(rows)} from the table")
        return rows
    except Exception as e:
        logger.error(str(e))
        raise 
    
def extract_driver(conn):
     extract_driver_sql = """
    SELECT
        driver_id ,
        name,
        status ,
        joined_at,
        CASE
            WHEN joined_at >= NOW() - INTERVAL '6 months'  THEN '0-6 months'
            WHEN joined_at >= NOW() - INTERVAL '1 year'    THEN '6-12 months'
            WHEN joined_at >= NOW() - INTERVAL '2 years'   THEN '1-2 years'
        ELSE '2+ years'
        END  AS tenure_bucket
    FROM
        drivers d ;
    """
     return extract(conn,extract_driver_sql)


def load_dim_driver(conn,driver_data):
    insert_dim_driver_sql = """
 INSERT INTO dim_driver
    (driver_id, name, status, joined_at,tenure_bucket)
    VALUES ( %(driver_id)s ,
             %(name)s,
             %(status)s,
            %(joined_at)s,
            %(tenure_bucket)s
            )
    ON CONFLICT DO NOTHING
"""
    try:
        with conn.cursor() as curr:
            curr.executemany(insert_dim_driver_sql, driver_data)
            logger.info(f"{curr.rowcount} inserted to dim_driver")
        conn.commit()
    except Exception as e:
        conn.rollback()
        logger.error(str(e))
        raise


def extract_passenger(conn):
    extract_passenger_sql = """
    SELECT
        passenger_id,
        name,
        status,
        created_at,
        TO_CHAR(created_at, 'YYYY-MM') AS cohort_month
    FROM
        passengers p;
    """
    return extract(conn, extract_passenger_sql)


def load_dim_passenger(conn, passenger_data):
    insert_dim_passenger_sql = """
 INSERT INTO dim_passenger
    (passenger_id, name, status, cohort_month, created_at)
    VALUES ( %(passenger_id)s,
             %(name)s,
             %(status)s,
             %(cohort_month)s,
             %(created_at)s
            )
    ON CONFLICT DO NOTHING
"""
    try:
        with conn.cursor() as curr:
            curr.executemany(insert_dim_passenger_sql, passenger_data)
            logger.info(f"{curr.rowcount} inserted to dim_passenger")
        conn.commit()
    except Exception as e:
        conn.rollback()
        logger.error(str(e))
        raise


def extract_location(conn):
    extract_location_sql = """
    SELECT
        location_id,
        city_name,
        state_province,
        country,
        latitude,
        longitude,
        CASE
            WHEN country <> 'USA' THEN 'International'
            WHEN state_province IN (
                'Connecticut','Maine','Massachusetts','New Hampshire','New Jersey',
                'New York','Pennsylvania','Rhode Island','Vermont'
            ) THEN 'Northeast'
            WHEN state_province IN (
                'Illinois','Indiana','Iowa','Kansas','Michigan','Minnesota',
                'Missouri','Nebraska','North Dakota','Ohio','South Dakota','Wisconsin'
            ) THEN 'Midwest'
            WHEN state_province IN (
                'Alabama','Arkansas','Delaware','Florida','Georgia','Kentucky',
                'Louisiana','Maryland','Mississippi','North Carolina','Oklahoma',
                'South Carolina','Tennessee','Texas','Virginia','West Virginia'
            ) THEN 'South'
            WHEN state_province IN (
                'Alaska','Arizona','California','Colorado','Hawaii','Idaho',
                'Montana','Nevada','New Mexico','Oregon','Utah','Washington','Wyoming'
            ) THEN 'West'
            ELSE 'International'
        END AS region
    FROM
        locations l;
    """
    return extract(conn, extract_location_sql)


def load_dim_location(conn, location_data):
    insert_dim_location_sql = """
 INSERT INTO dim_location
    (location_id, city_name, state_province, country, region, latitude, longitude)
    VALUES ( %(location_id)s,
             %(city_name)s,
             %(state_province)s,
             %(country)s,
             %(region)s,
             %(latitude)s,
             %(longitude)s
            )
    ON CONFLICT (location_id) DO NOTHING
"""
    try:
        with conn.cursor() as curr:
            curr.executemany(insert_dim_location_sql, location_data)
            logger.info(f"{curr.rowcount} inserted to dim_location")
        conn.commit()
    except Exception as e:
        conn.rollback()
        logger.error(str(e))
        raise


def extract_payment_method(conn):
    extract_payment_method_sql = """
    SELECT
        payment_method_id,
        name,
        type,
        is_active
    FROM
        payment_methods pm;
    """
    return extract(conn, extract_payment_method_sql)


def load_dim_payment_method(conn, payment_method_data):
    insert_dim_payment_method_sql = """
 INSERT INTO dim_payment_method
    (payment_method_id, name, type, is_active)
    VALUES ( %(payment_method_id)s,
             %(name)s,
             %(type)s,
             %(is_active)s
            )
    ON CONFLICT (payment_method_id) DO NOTHING
"""
    try:
        with conn.cursor() as curr:
            curr.executemany(insert_dim_payment_method_sql, payment_method_data)
            logger.info(f"{curr.rowcount} inserted to dim_payment_method")
        conn.commit()
    except Exception as e:
        conn.rollback()
        logger.error(str(e))
        raise


def extract_promo_code(conn):
    extract_promo_code_sql = """
    SELECT
        promo_code_id,
        code,
        discount_type,
        discount_value,
        is_active
    FROM
        promo_codes pc;
    """
    return extract(conn, extract_promo_code_sql)


def load_dim_promo_code(conn, promo_code_data):
    insert_dim_promo_code_sql = """
 INSERT INTO dim_promo_code
    (promo_code_id, code, discount_type, discount_value, is_active)
    VALUES ( %(promo_code_id)s,
             %(code)s,
             %(discount_type)s,
             %(discount_value)s,
             %(is_active)s
            )
    ON CONFLICT (promo_code_id) DO NOTHING
"""
    try:
        with conn.cursor() as curr:
            curr.executemany(insert_dim_promo_code_sql, promo_code_data)
            logger.info(f"{curr.rowcount} inserted to dim_promo_code")
        conn.commit()
    except Exception as e:
        conn.rollback()
        logger.error(str(e))
        raise


# TODO: research on arg vs kwarg
def main():
    src_conn = psycopg2.connect(**SOURCE_DB_CONFIG)
    dst_conn = psycopg2.connect(**DEST_DB_CONFIG)

    driver_data = extract_driver(src_conn)
    load_dim_driver(dst_conn, driver_data)

    passenger_data = extract_passenger(src_conn)
    load_dim_passenger(dst_conn, passenger_data)

    location_data = extract_location(src_conn)
    load_dim_location(dst_conn, location_data)

    payment_method_data = extract_payment_method(src_conn)
    load_dim_payment_method(dst_conn, payment_method_data)
    
    promo_code_data = extract_promo_code(src_conn)
    load_dim_promo_code(dst_conn, promo_code_data)

if __name__ == '__main__':
    main()