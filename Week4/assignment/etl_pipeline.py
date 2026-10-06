import logging
import os
import sys
from decimal import Decimal, ROUND_HALF_UP

import psycopg2
from psycopg2 import sql
from psycopg2.extras import RealDictCursor
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)s  %(message)s"
)
logger = logging.getLogger(__name__)


SOURCE_DB_CONFIG = dict(
    host=    os.getenv("SRC_DB_HOST"),
    port=    os.getenv("SRC_DB_PORT"),
    dbname=  os.getenv("SRC_DB_NAME"),
    user=    os.getenv("SRC_DB_USER"),
    password=os.getenv("SRC_DB_PASSWORD")
)

DEST_DB_CONFIG = dict(
    host=    os.getenv("DB_HOST"),
    port=    os.getenv("DB_PORT"),
    dbname=  os.getenv("DB_NAME"),
    user=    os.getenv("DB_USER"),
    password=os.getenv("DB_PASSWORD")
)


# ─────────────────────────────────────────────────────────────────────────────
# EXTRACT  (provided — same queries as class)
# ─────────────────────────────────────────────────────────────────────────────

def extract(conn, query):
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as curr:
            curr.execute(query)
            rows = curr.fetchall()
            logger.info(f"Extracted {len(rows)} rows")
        return rows
    except Exception as e:
        logger.error(str(e))
        raise


def extract_driver(conn):
    return extract(conn, """
    SELECT
        driver_id,
        name,
        status,
        joined_at,
        CASE
            WHEN joined_at >= NOW() - INTERVAL '6 months'  THEN '0-6 months'
            WHEN joined_at >= NOW() - INTERVAL '1 year'    THEN '6-12 months'
            WHEN joined_at >= NOW() - INTERVAL '2 years'   THEN '1-2 years'
            ELSE '2+ years'
        END AS tenure_bucket
    FROM drivers d;
    """)


def extract_passenger(conn):
    return extract(conn, """
    SELECT
        passenger_id,
        name,
        status,
        created_at,
        TO_CHAR(created_at, 'YYYY-MM') AS cohort_month
    FROM passengers p;
    """)


def extract_location(conn):
    return extract(conn, """
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
    FROM locations l;
    """)


def extract_payment_method(conn):
    return extract(conn, """
    SELECT payment_method_id, name, type, is_active
    FROM payment_methods pm;
    """)


def extract_promo_code(conn):
    return extract(conn, """
    SELECT promo_code_id, code, discount_type, discount_value, is_active
    FROM promo_codes pc;
    """)


# ─────────────────────────────────────────────────────────────────────────────
# LOAD DIMENSIONS  (provided — same ON CONFLICT DO NOTHING as class, but one
# generic function instead of five copies; works once your migration adds UNIQUE)
# ─────────────────────────────────────────────────────────────────────────────

def load_dim(conn, table, natural_key, columns, rows):
    insert_sql = sql.SQL("""
    INSERT INTO {table} ({cols})
    VALUES ({vals})
    ON CONFLICT ({nk}) DO NOTHING
    """).format(
        table=sql.Identifier(table),
        cols=sql.SQL(", ").join(map(sql.Identifier, columns)),
        vals=sql.SQL(", ").join(map(sql.Placeholder, columns)),
        nk=sql.Identifier(natural_key),
    )
    try:
        with conn.cursor() as curr:
            curr.executemany(insert_sql, rows)
            logger.info(f"{curr.rowcount} inserted to {table}")
        conn.commit()
    except Exception as e:
        conn.rollback()
        logger.error(f"{table}: {e}")
        raise


def load_dimensions(src_conn, dst_conn):
    """Provided — loads all five dimensions."""
    load_dim(dst_conn, "dim_driver", "driver_id",
             ["driver_id", "name", "status", "joined_at", "tenure_bucket"],
             extract_driver(src_conn))
    load_dim(dst_conn, "dim_passenger", "passenger_id",
             ["passenger_id", "name", "status", "cohort_month", "created_at"],
             extract_passenger(src_conn))
    load_dim(dst_conn, "dim_location", "location_id",
             ["location_id", "city_name", "state_province", "country",
              "region", "latitude", "longitude"],
             extract_location(src_conn))
    load_dim(dst_conn, "dim_payment_method", "payment_method_id",
             ["payment_method_id", "name", "type", "is_active"],
             extract_payment_method(src_conn))
    load_dim(dst_conn, "dim_promo_code", "promo_code_id",
             ["promo_code_id", "code", "discount_type", "discount_value", "is_active"],
             extract_promo_code(src_conn))


# ─────────────────────────────────────────────────────────────────────────────
# EXTRACT TRIPS  (provided — same query as class)
# ─────────────────────────────────────────────────────────────────────────────

def extract_trips(src_conn):
    return extract(src_conn, """
    SELECT
        t.trip_id,
        t.driver_id,
        t.passenger_id,
        t.pickup_location_id,
        t.dropoff_location_id,
        t.payment_method_id,
        t.promo_code_id,
        t.base_fare,
        t.tip_amount,
        t.discount_amount,
        t.surge_multiplier,
        t.distance_km,
        t.status,
        t.requested_at,
        t.completed_at,
        t.driver_rating,
        t.passenger_rating,
        tc.cancelled_by
    FROM trips t
    LEFT JOIN trip_cancellations tc ON t.trip_id = tc.trip_id
    ORDER BY t.requested_at
    """)


# ─────────────────────────────────────────────────────────────────────────────
# TRANSFORM
# ─────────────────────────────────────────────────────────────────────────────

def load_lookup_dim(conn):
    """Provided — natural key -> surrogate key maps for every dimension."""
    logger.info("Loading lookup tables into memory")
    lookup = {}
    with conn.cursor() as curr:
        curr.execute("SELECT driver_id, driver_key FROM dim_driver")
        lookup["driver"] = {r[0]: r[1] for r in curr.fetchall()}

        curr.execute("SELECT passenger_id, passenger_key FROM dim_passenger")
        lookup["passenger"] = {r[0]: r[1] for r in curr.fetchall()}

        curr.execute("SELECT location_id, location_key FROM dim_location")
        lookup["location"] = {r[0]: r[1] for r in curr.fetchall()}

        curr.execute("SELECT payment_method_id, payment_method_key FROM dim_payment_method")
        lookup["payment_method"] = {r[0]: r[1] for r in curr.fetchall()}

        curr.execute("SELECT promo_code_id, promo_code_key FROM dim_promo_code")
        lookup["promo_code"] = {r[0]: r[1] for r in curr.fetchall()}

        curr.execute("SELECT date_key FROM dim_date")
        lookup["date"] = {r[0] for r in curr.fetchall()}

        curr.execute("SELECT time_key FROM dim_time")
        lookup["time"] = {r[0] for r in curr.fetchall()}
    return lookup


def transform_trip(trip_data, lookups):
    """
    Same logic as class, plus the three new fact columns.
    Returns a list of dicts ready for load_fact_trips().
    """
    fact_rows = []
    skipped = 0

    for row in trip_data:
        trip_id = row["trip_id"]

        date_key = int(row["requested_at"].strftime("%Y%m%d"))
        if date_key not in lookups["date"]:
            logger.warning(f"trip {trip_id}: date_key {date_key} outside of dim_date range — skipped")
            skipped += 1
            continue

        # Calculate HHMM, rounding minutes down to the nearest 15-minute bucket.
        # Examples:
        # 14:37 -> 1430
        # 09:05 -> 900
        # 00:59 -> 45
        requested_at = row["requested_at"]

        time_key = (
            requested_at.hour * 100
            + (requested_at.minute // 15) * 15
        )

        if time_key not in lookups["time"]:
            logger.warning(
                f"trip {trip_id}: time_key {time_key} not in dim_time — skipped"
            )
            skipped += 1
            continue

        driver_key = lookups["driver"].get(row["driver_id"])
        if driver_key is None:
            logger.warning(f"trip {trip_id}: driver_id {row['driver_id']} not in dim_driver — skipped")
            skipped += 1
            continue

        passenger_key = lookups["passenger"].get(row["passenger_id"])
        if passenger_key is None:
            logger.warning(f"trip {trip_id}: passenger_id {row['passenger_id']} not in dim_passenger — skipped")
            skipped += 1
            continue

        pickup_location_key = lookups["location"].get(row["pickup_location_id"])
        if pickup_location_key is None:
            logger.warning(f"trip {trip_id}: pickup_location_id {row['pickup_location_id']} not in dim_location — skipped")
            skipped += 1
            continue

        dropoff_location_key = lookups["location"].get(row["dropoff_location_id"])
        if dropoff_location_key is None:
            logger.warning(f"trip {trip_id}: dropoff_location_id {row['dropoff_location_id']} not in dim_location — skipped")
            skipped += 1
            continue

        payment_method_key = None
        if row["payment_method_id"] is not None:
            payment_method_key = lookups["payment_method"].get(row["payment_method_id"])
            if payment_method_key is None:
                logger.warning(f"trip {trip_id}: payment_method_id {row['payment_method_id']} not in dim_payment_method — skipped")
                skipped += 1
                continue

        promo_code_key = None
        if row["promo_code_id"] is not None:
            promo_code_key = lookups["promo_code"].get(row["promo_code_id"])
            if promo_code_key is None:
                logger.warning(f"trip {trip_id}: promo_code_id {row['promo_code_id']} not in dim_promo_code — skipped")
                skipped += 1
                continue

        # computed column
        base_fare = row["base_fare"] or 0
        tip_amount = row["tip_amount"] or 0
        surge_multiplier = row["surge_multiplier"] or 0
        discount_amount = row["discount_amount"] or 0
        fare_amount = (
            Decimal(str(base_fare))
            * Decimal(str(surge_multiplier))
            + Decimal(str(tip_amount))
            - Decimal(str(discount_amount))
        ).quantize(
            Decimal("0.01"),
            rounding=ROUND_HALF_UP
        )

        duration_minutes = None
        if row["status"] == "completed" and row["completed_at"]:
            delta = row["completed_at"] - row["requested_at"]
            duration_minutes = round(delta.total_seconds() / 60, 1)

        fact_rows.append({
            "source_trip_id":       trip_id,
            "date_key":             date_key,
            "time_key":             time_key,
            "driver_key":           driver_key,
            "passenger_key":        passenger_key,
            "pickup_location_key":  pickup_location_key,
            "dropoff_location_key": dropoff_location_key,
            "payment_method_key":   payment_method_key,
            "promo_code_key":       promo_code_key,
            "trip_status":          row["status"],
            "cancelled_by":         row["cancelled_by"],
            "base_fare":            base_fare,
            "tip_amount":           tip_amount,
            "discount_amount":      discount_amount,
            "fare_amount":          fare_amount,
            "distance_km":          row["distance_km"],
            "duration_minutes":     duration_minutes,
            "driver_rating":        row["driver_rating"],
            "passenger_rating":     row["passenger_rating"],
            "surge_multiplier":     surge_multiplier,
            "requested_at":         row["requested_at"],
        })
    logger.info(f"Transformed {len(fact_rows)} rows, skipped {skipped}")
    return fact_rows


# ─────────────────────────────────────────────────────────────────────────────
# LOAD  (provided — upsert on source_trip_id, so re-running backfills the new
# columns on fact rows the class ETL already loaded)
# ─────────────────────────────────────────────────────────────────────────────

FACT_COLUMNS = [
    "source_trip_id", "date_key", "time_key", "driver_key", "passenger_key",
    "pickup_location_key", "dropoff_location_key",
    "payment_method_key", "promo_code_key",
    "trip_status", "cancelled_by",
    "base_fare", "tip_amount", "discount_amount", "fare_amount",
    "distance_km", "duration_minutes",
    "driver_rating", "passenger_rating",
    "surge_multiplier", "requested_at",
]


def load_fact_trips(conn, fact_data):
    if not fact_data:
        logger.info("No fact rows to load — skipping")
        return 0

    insert_fact_trips_sql = sql.SQL("""
    INSERT INTO fact_trips ({cols})
    VALUES ({vals})
    ON CONFLICT (source_trip_id) DO UPDATE SET {updates}
    """).format(
        cols=sql.SQL(", ").join(map(sql.Identifier, FACT_COLUMNS)),
        vals=sql.SQL(", ").join(map(sql.Placeholder, FACT_COLUMNS)),
        updates=sql.SQL(", ").join(
            sql.SQL("{c} = EXCLUDED.{c}").format(c=sql.Identifier(c))
            for c in FACT_COLUMNS if c != "source_trip_id"
        ),
    )
    try:
        with conn.cursor() as curr:
            curr.executemany(insert_fact_trips_sql, fact_data)
            logger.info(f"{curr.rowcount} rows upserted to fact_trips")
        conn.commit()
        return len(fact_data)
    except Exception as e:
        conn.rollback()
        logger.error(str(e))
        raise


# ─────────────────────────────────────────────────────────────────────────────
# P2 — RECONCILIATION
# ─────────────────────────────────────────────────────────────────────────────

def reconcile(src_conn, dst_conn):
    """
    Compare ride_prod against ride_warehouse and log one PASS/FAIL line per
    required reconciliation check.
    """

    all_ok = True

    # Check 1: source and warehouse dimension counts
    with src_conn.cursor() as src_cur, dst_conn.cursor() as dst_cur:
        src_cur.execute("SELECT COUNT(*) FROM drivers")
        source_driver_count = src_cur.fetchone()[0]

        dst_cur.execute("SELECT COUNT(*) FROM dim_driver")
        warehouse_driver_count = dst_cur.fetchone()[0]

        src_cur.execute("SELECT COUNT(*) FROM passengers")
        source_passenger_count = src_cur.fetchone()[0]

        dst_cur.execute("SELECT COUNT(*) FROM dim_passenger")
        warehouse_passenger_count = dst_cur.fetchone()[0]

    dimensions_ok = (
        source_driver_count == warehouse_driver_count
        and source_passenger_count == warehouse_passenger_count
    )

    logger.info(
        "CHECK 1 - dimensions: %s "
        "(drivers source=%s warehouse=%s; "
        "passengers source=%s warehouse=%s)",
        "PASS" if dimensions_ok else "FAIL",
        source_driver_count,
        warehouse_driver_count,
        source_passenger_count,
        warehouse_passenger_count,
    )

    all_ok = all_ok and dimensions_ok

    # Check 2: trip count per status
    with src_conn.cursor() as src_cur, dst_conn.cursor() as dst_cur:
        src_cur.execute("""
            SELECT status, COUNT(*)
            FROM trips
            GROUP BY status
            ORDER BY status
        """)
        source_status_counts = dict(src_cur.fetchall())

        dst_cur.execute("""
            SELECT trip_status, COUNT(*)
            FROM fact_trips
            GROUP BY trip_status
            ORDER BY trip_status
        """)
        warehouse_status_counts = dict(dst_cur.fetchall())

    status_ok = source_status_counts == warehouse_status_counts

    logger.info(
        "CHECK 2 - trip counts by status: %s "
        "(source=%s warehouse=%s)",
        "PASS" if status_ok else "FAIL",
        source_status_counts,
        warehouse_status_counts,
    )

    all_ok = all_ok and status_ok

    # Check 3: completed revenue
    with src_conn.cursor() as src_cur, dst_conn.cursor() as dst_cur:
        src_cur.execute("""
            SELECT COALESCE(SUM(fare_amount), 0)
            FROM v_trips
            WHERE status = 'completed'
        """)
        source_revenue = src_cur.fetchone()[0]

        dst_cur.execute("""
            SELECT COALESCE(SUM(fare_amount), 0)
            FROM fact_trips
            WHERE trip_status = 'completed'
        """)
        warehouse_revenue = dst_cur.fetchone()[0]

    source_revenue = Decimal(str(source_revenue)).quantize(
        Decimal("0.01"),
        rounding=ROUND_HALF_UP
    )
    warehouse_revenue = Decimal(str(warehouse_revenue)).quantize(
        Decimal("0.01"),
        rounding=ROUND_HALF_UP
    )

    revenue_ok = source_revenue == warehouse_revenue

    logger.info(
        "CHECK 3 - completed revenue: %s "
        "(source=%s warehouse=%s)",
        "PASS" if revenue_ok else "FAIL",
        source_revenue,
        warehouse_revenue,
    )

    all_ok = all_ok and revenue_ok

    return all_ok


# ─────────────────────────────────────────────────────────────────────────────
# MAIN  (provided)
# ─────────────────────────────────────────────────────────────────────────────

def main():
    src_conn = psycopg2.connect(**SOURCE_DB_CONFIG)
    dst_conn = psycopg2.connect(**DEST_DB_CONFIG)
    try:
        load_dimensions(src_conn, dst_conn)

        trip_data = extract_trips(src_conn)
        lookups = load_lookup_dim(dst_conn)
        fact_rows = transform_trip(trip_data, lookups)
        load_fact_trips(dst_conn, fact_rows)

        ok = reconcile(src_conn, dst_conn)
    finally:
        src_conn.close()
        dst_conn.close()

    if not ok:
        logger.error("Reconciliation FAILED — warehouse does not match source")
        sys.exit(1)
    logger.info("Reconciliation passed")


if __name__ == "__main__":
    main()
