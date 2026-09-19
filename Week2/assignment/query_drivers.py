"""
query_drivers.py
─────────────────
Connects to the ride_share database and prints Q1 from the Week 2 SQL
assignment (rides per driver) as a formatted table.
"""

import logging
import os

import psycopg2
from dotenv import load_dotenv

# ── Logging setup — same pattern as Week 1 ────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)s  %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
    handlers=[
        logging.FileHandler("pipeline.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# TODO: fill in this query to match Q1 from week2_queries.sql
RIDES_PER_DRIVER_QUERY = """
    SELECT
        d.name,
        count(*) AS total_rides
    FROM
        trips t
    JOIN drivers d ON
        t.driver_id = d.driver_id
    WHERE
        t.status = 'completed'
    GROUP BY
        d.name
    ORDER BY
        total_rides DESC;
"""

def get_connection():
    load_dotenv()
    return psycopg2.connect(
        host=os.getenv("DB_HOST"),
        port=os.getenv("DB_PORT"),
        dbname=os.getenv("DB_NAME"),
        user=os.getenv("DB_USER"),
        password=os.getenv("DB_PASSWORD"),
    )

def run_query(conn, query, label):
    """Run one query, log progress, and return the fetched rows."""
    logger.info(f"Running: {label}")
    try:
        with conn.cursor() as cur:
            cur.execute(query)
            rows = cur.fetchall()
    except Exception as e:
        logger.error(f"{label} failed: {e}")
        raise

    logger.info(f"{label}: {len(rows)} rows returned")
    return rows


def print_rides_per_driver(rows):
    logger.info("\n-- Rides per driver --")
    # TODO: loop over rows and print each one formatted, e.g.
    # f"{name:<15} | completed rides: {total_rides:>4}"
    for name, total_rides in rows:
        print(f"{name:<20} | completed rides : {total_rides:>4}")


def main():
    logger.info("Connecting to database…")
    try:
        conn = get_connection()
    except psycopg2.OperationalError as e:
        logger.critical(f"Cannot connect: {e}")
        raise

    try:
        rows = run_query(conn, RIDES_PER_DRIVER_QUERY, "Rides per driver")
        print_rides_per_driver(rows)
    finally:
        conn.close()
        logger.info("Connection closed. Done.")


if __name__ == "__main__":
    main()
