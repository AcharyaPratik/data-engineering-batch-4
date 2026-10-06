
-- ════════════════════════════════════════════════════════════════════════════
-- Part 1 — Audit the class warehouse (run the class etl.py TWICE first)
-- ════════════════════════════════════════════════════════════════════════════

-- Q1 — Run it twice, get twice the drivers (Intermediate · GROUP BY / HAVING + constraints)
-- Row counts: dim_driver, dim_passenger, dim_location, fact_trips vs ride_prod source tables
-- Duplicated driver_ids with copy count + every driver_key (STRING_AGG / ARRAY_AGG)
-- One duplicated driver: fact_trips rows per driver_key
-- Comment: why ON CONFLICT DO NOTHING didn't help; why dim_location / fact_trips didn't duplicate;
--          what a COUNT(*) "active drivers" report would say after a week

SELECT
	'dim_driver' AS table_name,
	COUNT(*) AS row_count
FROM
	dim_driver
UNION ALL
SELECT
	'dim_passenger',
	COUNT(*)
FROM
	dim_passenger
UNION ALL
SELECT
	'dim_location',
	COUNT(*)
FROM
	dim_location
UNION ALL
SELECT
	'fact_trips',
	COUNT(*)
FROM
	fact_trips;

SELECT
	driver_id,
	COUNT(*) AS copy_count,
	STRING_AGG(driver_key::TEXT, ', ' ORDER BY driver_key) AS driver_keys
FROM
	dim_driver
GROUP BY
	driver_id
HAVING
	COUNT(*) > 1
ORDER BY
	driver_id;

SELECT
	d.driver_id,
	d.driver_key,
	COUNT(f.source_trip_id) AS fact_rows
FROM
	dim_driver AS d
LEFT JOIN fact_trips AS f
    ON
	f.driver_key = d.driver_key
WHERE
	d.driver_id = 1
GROUP BY
	d.driver_id,
	d.driver_key
ORDER BY
	d.driver_key;

/*
For driver_id 1, all 394 fact rows reference driver_key 51. The other duplicate dimension rows 
have no fact rows.

load_lookup_dim() creates a dictionary mapping each natural driver_id to one driver_key. 
Because duplicate driver_id values exist, later rows overwrite earlier dictionary values. 
The final mapping is used when fact rows are loaded or updated.

The original dim_driver table has a primary key on driver_key, but driver_id is not UNIQUE. 
ON CONFLICT DO NOTHING only works when an inserted row violates a primary-key or UNIQUE constraint. 
Each duplicate driver receives a new driver_key, so no conflict occurs.

dim_location does not duplicate because warehouse.sql defines:
    location_id INTEGER NOT NULL UNIQUE

fact_trips does not duplicate because source_trip_id has a UNIQUE constraint. The repeated ETL runs 
therefore skip or update the existing fact rows instead of inserting duplicate facts.

The warehouse currently contains 100 driver rows for only 25 source drivers. A report using 
SELECT COUNT(*) FROM dim_driver would report 100 drivers, although the actual number of distinct 
drivers is 25.
*/


-- Q2 — What the fact table can't answer (Design)
-- Comment: grain of fact_trips; why cancellation rate by month is impossible
--          (show the duration_minutes IS NULL attempt + its flaw); why rush hour is impossible;
--          what happens to cancelled_by in etl.py

SELECT
	d.year,
	d.month,
	COUNT(*) AS trips_without_duration
FROM
	fact_trips f
JOIN dim_date d
    ON
	d.date_key = f.date_key
WHERE
	f.duration_minutes IS NULL
GROUP BY
	d.year,
	d.month
ORDER BY
	d.year,
	d.month;

/*
The grain of fact_trips is one row per trip.

This query cannot calculate the true cancellation rate because duration_minutes IS NULL includes 
both cancelled trips and no-show trips. Those are different business statuses, but the warehouse 
currently has no trip_status column to distinguish them.

The warehouse also cannot properly answer whether fares are higher during rush hour. dim_time 
contains time_of_day and is_rush_hour, but fact_trips does not contain a time_key foreign key 
connecting each trip to dim_time.

Although fact_trips has requested_at, the original star schema does not load the corresponding 
time_key. Therefore, the time dimension cannot be used directly for the intended warehouse analysis.

etl.py extracts cancelled_by from trip_cancellations, but the original fact table has no 
cancelled_by column and the original fact INSERT does not load that value. 
Therefore, cancelled_by is discarded during the ETL.
*/


-- Q3 — Averages of averages (Intermediate · semi-additive measures)
-- Per year: true_avg_rating, avg_of_monthly_avgs, rated_trips, total_trips — one query
-- Comment: biggest gap + why; AVG and NULL ratings; one SUM-able column, one never-SUM column

WITH monthly AS (
SELECT
	d.year,
	d.month,
	AVG(f.driver_rating) AS monthly_avg_rating
FROM
	fact_trips f
JOIN dim_date d
        ON
	d.date_key = f.date_key
WHERE
	f.driver_rating IS NOT NULL
GROUP BY
	d.year,
	d.month
),
yearly AS (
SELECT
	d.year,
	AVG(f.driver_rating) AS true_avg_rating,
	COUNT(f.driver_rating) AS rated_trips,
	COUNT(*) AS total_trips
FROM
	fact_trips f
JOIN dim_date d
        ON
	d.date_key = f.date_key
GROUP BY
	d.year
)
SELECT
	y.year,
	y.true_avg_rating,
	AVG(m.monthly_avg_rating) AS avg_of_monthly_avgs,
	y.rated_trips,
	y.total_trips
FROM
	yearly y
JOIN monthly m
    ON
	m.year = y.year
GROUP BY
	y.year,
	y.true_avg_rating,
	y.rated_trips,
	y.total_trips
ORDER BY
	y.year;

/*
The biggest gap in these results is in 2025, although it is very close to 2024. The 2025 difference 
is approximately 0.000735, while the 2024 difference is approximately 0.000733.

true_avg_rating gives every rated trip equal weight. avg_of_monthly_avgs gives every month equal 
weight. These values differ because months do not necessarily contain the same number of rated trips. 
A month with very few rated trips has the same influence as a month with many rated trips when
monthly averages are averaged together.

For example, in 2023 there are 1,946 rated trips but 2,808 total trips. AVG(driver_rating) ignores 
NULL ratings, so true_avg_rating uses only the 1,946 trips that have ratings. COUNT(driver_rating) 
also ignores NULLs, while COUNT(*) includes every trip.

fare_amount is an additive measure and can safely be summed. driver_rating is a numeric score, 
but it is not additive and should not be summed.
*/


-- ════════════════════════════════════════════════════════════════════════════
-- Part 2 — Q4 post-backfill checks
-- (the migration itself goes in warehouse_migration.sql;
--  run these AFTER `python etl_pipeline.py` has backfilled the new columns)
-- ════════════════════════════════════════════════════════════════════════════

-- Q4 — Verify zero NULL trip_status / time_key, then SET NOT NULL on both
-- Comment: why couldn't SET NOT NULL go in the migration itself?

SELECT
	COUNT(*) FILTER (
	WHERE trip_status IS NULL) AS null_trip_status,
	COUNT(*) FILTER (
	WHERE time_key IS NULL) AS null_time_key
FROM
	fact_trips;

/*
The expected result is zero for both columns.

time_key was populated during the warehouse migration from requested_at. trip_status could not be 
populated during the migration because the warehouse did not contain enough information to 
distinguish completed, cancelled, and no_show trips. The ETL must load trip_status from ride_prod.
*/

ALTER TABLE fact_trips
    ALTER COLUMN trip_status SET NOT NULL;

ALTER TABLE fact_trips
    ALTER COLUMN time_key SET NOT NULL;

/*
SET NOT NULL could not be added in the migration before the ETL because trip_status was still NULL 
for the existing fact rows. The constraint must be added only after the ETL has populated trip_status 
and the verification query confirms that there are no NULL values.
*/


-- ════════════════════════════════════════════════════════════════════════════
-- Part 4 — Query the star schema
-- ════════════════════════════════════════════════════════════════════════════

-- Q5 — Monthly revenue by region, with share of month (Intermediate · star join + window)
-- 2025, completed: month, month_name, region, trips, revenue, pct_of_month
-- pct_of_month via SUM(SUM(fare_amount)) OVER (PARTITION BY ...)
-- Comment: why filter on dim_date.year instead of EXTRACT(YEAR FROM requested_at)?

SELECT
	d.month,
	d.month_name,
	l.region,
	COUNT(*) AS trips,
	ROUND(SUM(f.fare_amount), 2) AS revenue,
	ROUND(
        100.0 * SUM(f.fare_amount)
        / SUM(SUM(f.fare_amount)) OVER (
            PARTITION BY d.year, d.month
        ),
        1
    ) AS pct_of_month
FROM
	fact_trips AS f
JOIN dim_date AS d
    ON
	d.date_key = f.date_key
JOIN dim_location AS l
    ON
	l.location_key = f.pickup_location_key
WHERE
	d.year = 2025
	AND f.trip_status = 'completed'
GROUP BY
	d.year,
	d.month,
	d.month_name,
	l.region
ORDER BY
	d.month,
	revenue DESC;

/*
The query filters on dim_date.year = 2025 instead of extracting the year from requested_at because 
dim_date is the warehouse calendar dimension. It contains reusable reporting attributes 
such as year, quarter, month_name, week, day_name, and is_weekend.

Using dim_date keeps calendar filtering and grouping consistent with the star schema. 
EXTRACT(YEAR FROM requested_at) could produce the same rows here, but it bypasses the date dimension.
*/


-- Q6 — Role-playing dimension: routes (Intermediate · same dim joined twice)
-- (1) Top 10 'pickup → dropoff' routes by completed trips, with revenue + avg distance_km
-- (2) Cross-country trips / total trips / percentage
-- Comment: what is a role-playing dimension, why alias one table twice instead of two tables?

SELECT
	pickup.city_name || ' -> ' || dropoff.city_name AS route,
	COUNT(*) AS trips,
	ROUND(SUM(f.fare_amount), 2) AS revenue,
	ROUND(AVG(f.distance_km), 2) AS avg_distance_km
FROM
	fact_trips AS f
JOIN dim_location AS pickup
    ON
	pickup.location_key = f.pickup_location_key
JOIN dim_location AS dropoff
    ON
	dropoff.location_key = f.dropoff_location_key
WHERE
	f.trip_status = 'completed'
GROUP BY
	pickup.city_name,
	dropoff.city_name
ORDER BY
	trips DESC,
	revenue DESC
LIMIT 10;

SELECT
	COUNT(*) FILTER (
WHERE
	pickup.country <> dropoff.country) AS cross_country_trips,
	COUNT(*) AS total_trips,
	ROUND(100.0 * COUNT(*) FILTER (WHERE pickup.country <> dropoff.country) / NULLIF(COUNT(*), 0), 1 ) AS pct_cross_country
FROM
	fact_trips AS f
JOIN dim_location AS pickup ON
	pickup.location_key = f.pickup_location_key
JOIN dim_location AS dropoff ON
	dropoff.location_key = f.dropoff_location_key;

/*
A role-playing dimension is one dimension table used for multiple purposes. dim_location is joined 
twice with different aliases: pickup and dropoff. This lets us compare the starting and ending 
locations without creating separate pickup and dropoff tables, avoiding duplicate location data.
*/


-- Q7 — When do people ride, and when do they cancel? (Intermediate–Advanced · two dims + FILTER)
-- is_weekend x time_of_day: trips, avg_fare (completed), avg_surge, cancellation_rate_pct
-- Cancelled only: cancelled_by share, rush hour vs not
-- Comment: are rush-hour fares higher? why does Night have the most trips?

SELECT
	d.is_weekend,
	t.time_of_day,
	COUNT(*) AS total_trips,
	ROUND(AVG(f.fare_amount) FILTER (WHERE f.trip_status = 'completed'), 2) AS avg_completed_fare,
	ROUND(AVG(f.surge_multiplier), 2) AS avg_surge_multiplier,
	ROUND(100.0 * COUNT(*) FILTER (WHERE f.trip_status = 'cancelled') / NULLIF(COUNT(*), 0), 1) AS cancellation_rate
FROM
	fact_trips AS f
JOIN dim_date AS d
    ON
	d.date_key = f.date_key
JOIN dim_time AS t
    ON
	t.time_key = f.time_key
GROUP BY
	d.is_weekend,
	t.time_of_day
ORDER BY
	d.is_weekend,
	t.time_of_day;

SELECT
	CASE
		WHEN t.is_rush_hour THEN 'Rush hour'
		ELSE 'Non-rush hour'
	END AS PERIOD,
	f.cancelled_by,
	COUNT(*) AS cancelled_trips,
	ROUND(
        100.0 * COUNT(*)
        / SUM(COUNT(*)) OVER (
            PARTITION BY
                CASE
                    WHEN t.is_rush_hour THEN 'Rush hour'
                    ELSE 'Non-rush hour'
                END
        ),
        1
    ) AS cancelled_share_pct
FROM
	fact_trips AS f
JOIN dim_time AS t
    ON
	t.time_key = f.time_key
WHERE
	f.trip_status = 'cancelled'
GROUP BY
	CASE
		WHEN t.is_rush_hour THEN 'Rush hour'
		ELSE 'Non-rush hour'
	END,
	f.cancelled_by
ORDER BY
	PERIOD,
	cancelled_trips DESC;

/*
This compares fares and cancellation behavior by weekend status and time of day. The query output 
determines whether rush-hour fares are higher. If they are, higher demand and surge pricing may 
explain the difference. Night may have the most trips because of evening travel, entertainment, 
and late-hour transport.
*/


-- Q8 — The tenure bucket that never changes (Advanced · dimension design)
-- Revenue by dim_driver.tenure_bucket (expect one bucket) — explain why
-- Revenue / trips / distinct drivers by tenure AT TRIP TIME (requested_at - joined_at)
-- Comment: why NOW()-relative attributes are bad, DO UPDATE vs DO NOTHING effect,
--          where tenure-at-trip should live in the model

SELECT
	d.tenure_bucket,
	COUNT(*) AS trips,
	ROUND(SUM(f.fare_amount), 2) AS revenue
FROM
	fact_trips AS f
JOIN dim_driver AS d
    ON
	d.driver_key = f.driver_key
WHERE
	f.trip_status = 'completed'
GROUP BY
	d.tenure_bucket
ORDER BY
	d.tenure_bucket;

WITH trip_tenure AS (
SELECT
	f.fare_amount,
	f.driver_key,
	CASE
		WHEN f.requested_at < d.joined_at + INTERVAL '1 year'
                THEN '0-1 yr'
		WHEN f.requested_at < d.joined_at + INTERVAL '2 years'
                THEN '1-2 yrs'
		WHEN f.requested_at < d.joined_at + INTERVAL '3 years'
                THEN '2-3 yrs'
		ELSE '3+ yrs'
	END AS tenure_at_trip
FROM
	fact_trips f
JOIN dim_driver d
        ON
	f.driver_key = d.driver_key
WHERE
	f.trip_status = 'completed'
)
SELECT
	tenure_at_trip,
	COUNT(*) AS trips,
	ROUND(SUM(fare_amount), 2) AS revenue,
	COUNT(DISTINCT driver_key) AS distinct_drivers
FROM
	trip_tenure
GROUP BY
	tenure_at_trip
ORDER BY
	tenure_at_trip;

/*
This shows why NOW()-relative attributes are unstable. A tenure_bucket calculated with NOW() changes 
as time passes, so historical trips can appear under a different bucket later. DO NOTHING preserves 
the original dimension value, while DO UPDATE recalculates and overwrites it.

Tenure at trip time should be calculated from requested_at and joined_at, then stored as a historical 
fact attribute or periodic snapshot if it is needed for repeatable reporting.
*/


-- ════════════════════════════════════════════════════════════════════════════
-- Stretch — Slowly changing dimensions (Design · optional SQL)
-- ════════════════════════════════════════════════════════════════════════════
-- 1. After suspending driver 3, dim_driver still says active — bug? who is misled?

--Yes, if dim_driver is supposed to show the current status. After suspending driver 3, showing active 
--is incorrect and can mislead analysts, operations, and compliance reports.

-- 2. SCD Type 1 (DO UPDATE): what does "2023 revenue by driver status" say about driver 3?

--With SCD Type 1, DO UPDATE changes driver 3’s status from active to suspended.
--A report for 2023 revenue by driver status would show driver 3’s 2023 revenue under: suspended
--This is historically misleading because driver 3 may have been active during 2023. 
--The old status was overwritten.

-- 3. SCD Type 2: columns to add, driver 3's rows + surrogate keys after the change

--Add these columns: effective_from, effective_to, is_current

--Driver 3 would have two rows:
--driver_key	driver_id	status		is_current
--101			3			active		false
--205			3			suspended	true

--The old active row is closed, and a new suspended row is inserted with a new driver_key.

-- 4. Is UNIQUE (driver_id) still valid? What must a trip's driver lookup match on instead?

--No. SCD Type 2 allows multiple rows for the same driver: driver_id = 3

--The trip lookup must match the driver and the date when that version was valid:
/*
f.driver_id = d.driver_id AND f.requested_at >= d.effective_from 
AND (f.requested_at < d.effective_to OR d.effective_to IS NULL)
 */

--The trip should ultimately store the correct historical driver_key, not just driver_id.
