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
    """Return every trip for the given driver name, case-insensitively."""

    # Parameterized SQL prevents SQL injection. Building the query with an f-string or string 
    # concatenation could allow user input to modify the SQL statement or execute unintended commands.
    cur.execute(
        """
        SELECT t.trip_id, d.name as driver_name, t.status, t.fare_amount
        FROM trips t
        JOIN drivers d ON t.driver_id = d.driver_id
        WHERE d.name ILIKE %s
        ORDER BY t.trip_id
        """,
        (driver_name,)
    )
    return cur.fetchall()


# ── P2: generic table printer ─────────────────────────────────────────────
def run_and_print(cur, sql):
    """Run any SELECT query and print an aligned table using cur.description."""
    
    cur.execute(sql)
    rows = cur.fetchall()
    col_names = [desc[0] for desc in cur.description]
    
    print(" | ".join(f"{name:20}" for name in col_names))
    print("-" * (len(col_names)*22))
    
    for row in rows:
        print(" | ".join(f"{str(val):20}" for val in row))


# ── P3: handle a bad insert gracefully ────────────────────────────────────
def insert_trip_with_bad_driver(conn):
    # TODO: try the INSERT inside a try/except, catch the psycopg2 error,
    # print a friendly message, call conn.rollback(), then prove the
    # connection still works with a normal SELECT.
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO trips (driver_id, passenger_id, pickup_location_id, 
                    dropoff_location_id, fare_amount, distance_km,
                    status, requested_at)
                VALUES (77777, 1, 1, 2, 500, 10, 'completed', NOW())
                """
            )   
            conn.commit()          
    except psycopg2.Error as e:
        print("Insert failed due to foreign key violation:", e.pgerror.strip())
        conn.rollback()
        
        with conn.cursor() as cur:
            cur.execute("SELECT trip_id, status FROM trips LIMIT 5;")
            print("Rollback successful. Connection is still usable.")

            for trip_id, status in cur.fetchall():
                print(f"Trip ID: {trip_id} | Status: {status}")

def main():
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            print("\nP1: Parameterized query function\n------------------------")
            rides = get_rides_for_driver(cur, "Sita Tamang")
            for rows in rides:
                print(rows)
                
            print("\nP2: Q1 — Rides per driver\n------------------------")
            run_and_print(cur, """
                SELECT
                    d.name,
                    COUNT(t.trip_id) AS total_rides
                FROM drivers AS d
                LEFT JOIN trips AS t
                    ON t.driver_id = d.driver_id
                AND t.status = 'completed'
                GROUP BY d.driver_id, d.name
                ORDER BY total_rides DESC, d.name
            """)

            print("\nP2: Q3 — Average fare per pickup city\n------------------------")
            run_and_print(cur, """
                SELECT
                    l.city_name,
                    ROUND(AVG(t.fare_amount), 2) AS avg_fare
                FROM trips AS t
                JOIN locations AS l
                    ON l.location_id = t.pickup_location_id
                GROUP BY l.location_id, l.city_name
                ORDER BY avg_fare DESC, l.city_name
            """)

            print("\nP2: Q6 — High-performing drivers\n------------------------")
            run_and_print(cur, """
                SELECT
                    d.name,
                    COUNT(t.trip_id) AS completed_rides,
                    SUM(t.fare_amount) AS total_revenue
                FROM drivers AS d
                JOIN trips AS t
                    ON t.driver_id = d.driver_id
                WHERE t.status = 'completed'
                GROUP BY d.driver_id, d.name
                HAVING COUNT(t.trip_id) > 280
                AND SUM(t.fare_amount) > 140000
                ORDER BY total_revenue DESC, d.name
            """)
            
        print("\nP3: Handle a bad insert gracefully\n------------------------")
        insert_trip_with_bad_driver(conn)
    finally:
        conn.close()

if __name__ == "__main__":
    main()
