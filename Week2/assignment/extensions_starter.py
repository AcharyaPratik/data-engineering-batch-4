"""
extensions.py
─────────────
P1: parameterized query function
P2: generic table printer (cursor.description)
P3: handle a bad insert gracefully (FK violation + rollback)
"""

import os

import psycopg2
from dotenv import load_dotenv


def get_connection():
    load_dotenv()
    return psycopg2.connect(
        host=os.getenv("DB_HOST"),
        port=os.getenv("DB_PORT"),
        dbname=os.getenv("DB_NAME"),
        user=os.getenv("DB_USER"),
        password=os.getenv("DB_PASSWORD"),
    )


# ── P1: parameterized query function ──────────────────────────────────────
def get_rides_for_driver(cur, driver_name):
    """Return every trip for the given driver name (case-insensitive)."""
    # TODO: use a parameterized query (%s placeholder + tuple), not an f-string.
    # Comment: explain what could go wrong with string concatenation here.
    raise NotImplementedError


# ── P2: generic table printer ─────────────────────────────────────────────
def run_and_print(cur, sql):
    """Run any SELECT query and print an aligned table using cur.description."""
    # TODO: cur.execute(sql), then use cur.description to get column names
    # dynamically, then print an aligned table.
    raise NotImplementedError


# ── P3: handle a bad insert gracefully ────────────────────────────────────
def insert_trip_with_bad_driver(conn):
    """Attempt an INSERT with a driver_id that doesn't exist; recover cleanly."""
    # TODO: try the INSERT inside a try/except, catch the psycopg2 error,
    # print a friendly message, call conn.rollback(), then prove the
    # connection still works with a normal SELECT.
    raise NotImplementedError


def main():
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            # TODO: exercise get_rides_for_driver, run_and_print (on at least
            # 3 different queries), and insert_trip_with_bad_driver here.
            pass
    finally:
        conn.close()


if __name__ == "__main__":
    main()
