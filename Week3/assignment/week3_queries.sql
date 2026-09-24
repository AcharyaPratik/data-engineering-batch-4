-- Week 3 Queries — Answers
-- Fill in each query below. See sql_assignment.md for the full scenario text.
-- Rename this file to week3_queries.sql before committing.
-- Q1 — A bulk update that must not partially apply (Basic–Intermediate · transactions + CHECK)
-- Transaction: valid 10% fare correction + one deliberately bad UPDATE -> whole batch rejected
-- Then: correction run alone, COMMIT, verified
-- Comment: why does all-or-nothing matter for a finance-facing bulk update?

SELECT
	COUNT(*) AS completed_trips,
	SUM(fare_amount) AS total_revenue
FROM
	trips
WHERE
	driver_id = 12
	AND status = 'completed';

BEGIN ;

UPDATE
	trips
SET
	fare_amount = fare_amount * 1.1
WHERE
	driver_id = 12
	AND status = 'completed';

UPDATE
	trips
SET
	fare_amount = -100
WHERE
	trip_id = 93134;

ROLLBACK;
BEGIN
	;

UPDATE
	trips
SET
	fare_amount = fare_amount * 1.1
WHERE
	driver_id = 12
	AND status = 'completed';

COMMIT;

SELECT
	COUNT(*) AS completed_trips,
	SUM(fare_amount) AS total_revenue
FROM
	trips
WHERE
	driver_id = 12
	AND status = 'completed';

/*
Atomicity guarantees that a transaction is all-or-nothing. After increasing completed-trip 
fares by 10%, I intentionally violated the CHECK constraint (fare_amount > 0) by setting one
fare_amount to a negative value. PostgreSQL rejected the second UPDATE and the transaction was 
rolled back.

After ROLLBACK, the total fares were unchanged, proving that none of the 10% corrections were applied. 
When the correction was run again without the invalid UPDATE and COMMIT was executed, 
all fare changes were successfully saved.

This behavior is important for finance operations because partial updates could result in 
incorrect revenue calculations, driver payouts, invoices, and reports. 
Atomic transactions guarantee that either all fare corrections are applied or none are applied.
 */
-- Q2 — FK delete-rule audit (Intermediate · introspection + design)
-- \d trips or information_schema query -> paste actual ON DELETE rules found
-- Your own driver + trip -> DELETE driver -> verify result
-- Your own payment method + trip -> DELETE payment method -> verify result
-- Comment: is CASCADE on driver_id safe for a real company? what would you use instead?

SELECT
	tc.constraint_name,
	rc.delete_rule
FROM
	information_schema.table_constraints tc
JOIN information_schema.referential_constraints rc
    ON
	tc.constraint_name = rc.constraint_name
WHERE
	tc.table_name = 'trips'
	AND tc.constraint_type = 'FOREIGN KEY';

INSERT
	INTO
	drivers(name)
VALUES ('Test Driver 2')
RETURNING driver_id;

INSERT
	INTO
	trips (
    driver_id,
	passenger_id,
	pickup_location_id,
	dropoff_location_id,
	fare_amount,
	distance_km,
	status,
	requested_at
)
VALUES (
    31,
    1,
    1,
    2,
    777,
    10,
    'completed',
    NOW()
);

SELECT
	*
FROM
	trips
WHERE
	driver_id = 31;

DELETE
FROM
	drivers
WHERE
	driver_id = 31;

SELECT
	*
FROM
	trips
WHERE
	driver_id = 31;

INSERT
	INTO
	payment_methods(name)
VALUES ('PayPal')
RETURNING payment_method_id;

INSERT
	INTO
	trips (
    driver_id,
	passenger_id,
	pickup_location_id,
	dropoff_location_id,
	fare_amount,
	distance_km,
	status,
	requested_at,
	payment_method_id
)
VALUES (
    1,
    1,
    1,
    2,
    100,
    10,
    'completed',
    NOW(),
    8
);

SELECT
	trip_id,
	payment_method_id
FROM
	trips
WHERE
	trip_id = 1093033;

DELETE
FROM
	payment_methods
WHERE
	payment_method_id = 8;

SELECT
	trip_id,
	payment_method_id
FROM
	trips
WHERE
	trip_id = 1093033;

/*
Foreign key delete rules found in trips:

trips_driver_id_fkey           -> ON DELETE CASCADE
trips_payment_method_id_fkey   -> ON DELETE SET NULL
trips_passenger_id_fkey        -> ON DELETE NO ACTION
trips_pickup_location_id_fkey  -> ON DELETE NO ACTION
trips_dropoff_location_id_fkey -> ON DELETE NO ACTION

Deleting a driver automatically deleted the driver's trips, proving ON DELETE CASCADE. 
Deleting a payment method kept the trip record but changed payment_method_id to NULL, proving
ON DELETE SET NULL.

ON DELETE CASCADE on driver_id is generally unsafe for a real ride-sharing company because 
deleting a driver would also delete historical trip records, fare amounts, ratings, revenue data, 
and audit information. This could affect financial reporting and compliance.

A safer design would be ON DELETE RESTRICT or a soft-delete approach using a deleted_at column. 
This preserves historical trip data while preventing the driver from appearing in normal
application queries.
 */
-- Q3 — Anti-join shootout: drivers with no trips (Intermediate–Advanced · EXPLAIN ANALYZE)
-- (a) NOT IN, (b) LEFT JOIN ... IS NULL, (c) NOT EXISTS -- EXPLAIN ANALYZE all three, paste plans
-- Comment: plan shape of each, which was fastest
-- NULL trap: NOT IN on payment_method_id (nullable) -> reproduce, fix with LEFT JOIN/NOT EXISTS
-- Comment: why does NOT IN break when its subquery can return NULL?

EXPLAIN ANALYZE
SELECT
	*
FROM
	drivers
WHERE
	driver_id NOT IN (
	SELECT
		driver_id
	FROM
		trips
);
--Seq Scan on drivers  (cost=0.00..5804496.80 rows=160 width=222) (actual time=299.845..299.846 rows=1.00 loops=1)
--  Filter: (NOT (ANY (driver_id = (SubPlan 1).col1)))
--  Rows Removed by Filter: 16
--  Buffers: shared hit=14872, temp written=1708
--  SubPlan 1
--    ->  Materialize  (cost=0.00..33778.01 rows=1000001 width=4) (actual time=0.001..14.320 rows=58841.06 loops=17)
--          Storage: Disk  Maximum Storage: 13664kB
--          Buffers: shared hit=14871, temp written=1708
--          ->  Seq Scan on trips  (cost=0.00..24871.01 rows=1000001 width=4) (actual time=0.007..93.515 rows=1000001.00 loops=1)
--                Buffers: shared hit=14871
--Planning Time: 0.107 ms
--Execution Time: 307.593 ms

EXPLAIN ANALYZE
SELECT
	d.*
FROM
	drivers d
LEFT JOIN trips t
    ON
	d.driver_id = t.driver_id
WHERE
	t.trip_id IS NULL;
--Hash Right Join  (cost=17.20..27547.98 rows=1 width=222) (actual time=176.051..176.054 rows=1.00 loops=1)
--  Hash Cond: (t.driver_id = d.driver_id)
--  Filter: (t.trip_id IS NULL)
--  Rows Removed by Filter: 1000001
--  Buffers: shared hit=14872
--  ->  Seq Scan on trips t  (cost=0.00..24871.01 rows=1000001 width=8) (actual time=0.012..56.118 rows=1000001.00 loops=1)
--        Buffers: shared hit=14871
--  ->  Hash  (cost=13.20..13.20 rows=320 width=222) (actual time=0.036..0.037 rows=17.00 loops=1)
--        Buckets: 1024  Batches: 1  Memory Usage: 9kB
--        Buffers: shared hit=1
--        ->  Seq Scan on drivers d  (cost=0.00..13.20 rows=320 width=222) (actual time=0.025..0.028 rows=17.00 loops=1)
--              Buffers: shared hit=1
--Planning Time: 0.282 ms
--Execution Time: 176.109 ms

EXPLAIN ANALYZE
SELECT
	*
FROM
	drivers d
WHERE
	NOT EXISTS (
	SELECT
		1
	FROM
		trips t
	WHERE
		t.driver_id = d.driver_id
);
--Nested Loop Anti Join  (cost=0.42..156.42 rows=304 width=222) (actual time=0.238..0.239 rows=1.00 loops=1)
--  Buffers: shared hit=70
--  ->  Seq Scan on drivers d  (cost=0.00..13.20 rows=320 width=222) (actual time=0.021..0.023 rows=17.00 loops=1)
--        Buffers: shared hit=1
--  ->  Index Only Scan using idx_trips_driver_id on trips t  (cost=0.42..1283.58 rows=62500 width=4) (actual time=0.012..0.012 rows=0.94 loops=17)
--        Index Cond: (driver_id = d.driver_id)
--        Heap Fetches: 22
--        Index Searches: 17
--        Buffers: shared hit=69
--Planning Time: 0.209 ms
----Execution Time: 0.271 ms

/*
The NOT IN query used a Sequential Scan with a materialized subquery. 
The LEFT JOIN ... IS NULL query used a Hash Join, while NOT EXISTS was optimized into 
a Nested Loop Anti Join.

NOT EXISTS was the fastest query (0.115 ms). NOT IN was slightly slower (0.163 ms).
LEFT JOIN ... IS NULL was significantly slower at 245.545 ms because PostgreSQL scanned the
complete trips table and performed a hash join.
 */

SELECT
	COUNT(*)
FROM
	trips
WHERE
	payment_method_id IS NULL;

SELECT
	*
FROM
	payment_methods
WHERE
	payment_method_id NOT IN (
	SELECT
		payment_method_id
	FROM
		trips
);

SELECT
	*
FROM
	payment_methods pm
WHERE
	NOT EXISTS (
	SELECT
		1
	FROM
		trips t
	WHERE
		t.payment_method_id = pm.payment_method_id
);

/*
The NOT IN query used a sequential scan with a materialized subquery. The LEFT JOIN ... IS NULL 
query used a hash right join and scanned the trips table. The NOT EXISTS query was optimized into 
a nested loop anti join and used the idx_trips_driver_id index.

On my dataset, NOT EXISTS was the fastest with an execution time of 0.271 ms. The LEFT JOIN query 
took 176.109 ms, while NOT IN took 307.593 ms. Execution times may vary depending on indexes, 
statistics, caching, and data size.
*/
-- Q4 — Index the fix (Intermediate · CREATE INDEX)
-- EXPLAIN ANALYZE baseline on corrected Q3 query, CREATE INDEX on payment_method_id, re-run
-- Paste both plans

DROP INDEX IF EXISTS idx_trips_payment_method_id;

EXPLAIN ANALYZE
SELECT
	*
FROM
	payment_methods pm
WHERE
	NOT EXISTS (
	SELECT
		1
	FROM
		trips t
	WHERE
		t.payment_method_id = pm.payment_method_id
);
--Hash Right Anti Join  (cost=26.65..27582.79 rows=736 width=82) (actual time=182.815..182.818 rows=0.00 loops=1)
--  Hash Cond: (t.payment_method_id = pm.payment_method_id)
--  Buffers: shared hit=14872
--  ->  Seq Scan on trips t  (cost=0.00..24871.01 rows=1000001 width=4) (actual time=0.008..60.065 rows=1000001.00 loops=1)
--        Buffers: shared hit=14871
--  ->  Hash  (cost=17.40..17.40 rows=740 width=82) (actual time=0.016..0.018 rows=4.00 loops=1)
--        Buckets: 1024  Batches: 1  Memory Usage: 9kB
--        Buffers: shared hit=1
--        ->  Seq Scan on payment_methods pm  (cost=0.00..17.40 rows=740 width=82) (actual time=0.013..0.013 rows=4.00 loops=1)
--              Buffers: shared hit=1
--Planning:
--  Buffers: shared hit=22
--Planning Time: 1.174 ms
--Execution Time: 182.840 ms

CREATE INDEX idx_trips_payment_method_id
ON
trips(payment_method_id);

EXPLAIN ANALYZE
SELECT
	*
FROM
	payment_methods pm
WHERE
	NOT EXISTS (
	SELECT
		1
	FROM
		trips t
	WHERE
		t.payment_method_id = pm.payment_method_id
);
--Nested Loop Anti Join  (cost=0.42..345.24 rows=736 width=82) (actual time=0.287..0.287 rows=0.00 loops=1)
--  Buffers: shared hit=9 read=9
--  ->  Seq Scan on payment_methods pm  (cost=0.00..17.40 rows=740 width=82) (actual time=0.013..0.015 rows=4.00 loops=1)
--        Buffers: shared hit=1
--  ->  Index Only Scan using idx_trips_payment_method_id on trips t  (cost=0.42..4456.71 rows=250000 width=4) (actual time=0.067..0.067 rows=1.00 loops=4)
--        Index Cond: (payment_method_id = pm.payment_method_id)
--        Heap Fetches: 4
--        Index Searches: 4
--        Buffers: shared hit=8 read=9
--Planning:
--  Buffers: shared hit=33 read=1
--Planning Time: 2.007 ms
--Execution Time: 0.309 ms

/*
Before creating the index, PostgreSQL used a Hash Right Anti Join and scanned the entire trips table. 
The execution time was 182.840 ms.

After creating the index on trips(payment_method_id), PostgreSQL changed to a Nested Loop Anti Join 
and used an Index Only Scan. The execution time decreased to 0.309 ms.

On this dataset, the indexed query was approximately 592 times faster. The actual improvement may 
vary depending on table size, indexes, statistics, and database caching.
*/
-- Q5 — When not to index (Design · no new SQL required)
-- Comment only: cost of an index beyond disk space; would you index rating / drivers.name?

/*
Indexes improve query performance but increase the cost of INSERT, UPDATE, and DELETE operations 
because PostgreSQL must maintain the index whenever data changes.

I would not add an index on trips.rating because it has very few distinct values (1.0 to 5.0), 
making it a low-selectivity column. The index would provide little benefit for filtering.

I would consider adding an index on drivers.name because names typically have many distinct values 
and searches for specific names can benefit from an index.
 */
-- Q6 — Driver performance summary (Intermediate–Advanced · aggregation view)
-- CREATE VIEW driver_performance_summary AS ...
-- driver_id, driver_name, total_rides, total_completed_trips, total_cancelled_trips,
-- completion_rate, cancellation_rate, total_revenue, avg_rating
-- SELECT from it ordered by completion_rate ascending

CREATE
VIEW driver_performance_summary AS
SELECT
	d.driver_id,
	d.name AS driver_name,
	COUNT(t.trip_id) AS total_rides,
	COUNT(CASE WHEN t.status = 'completed' THEN 1 END)
        AS total_completed_trips,
	COUNT(CASE WHEN t.status = 'cancelled' THEN 1 END)
        AS total_cancelled_trips,
	ROUND(
        COUNT(CASE WHEN t.status = 'completed' THEN 1 END)
        * 100.0
        / NULLIF(COUNT(t.trip_id), 0),
        1
    ) AS completion_rate,
	ROUND(
        COUNT(CASE WHEN t.status = 'cancelled' THEN 1 END)
        * 100.0
        / NULLIF(COUNT(t.trip_id), 0),
        1
    ) AS cancellation_rate,
	SUM(
        CASE
            WHEN t.status = 'completed'
            THEN t.fare_amount
        END
    ) AS total_revenue,
	ROUND(
        AVG(
            CASE
                WHEN t.status = 'completed'
                THEN t.rating
            END
        ),
        2
    ) AS avg_rating
FROM
	drivers d
LEFT JOIN trips t
    ON
	d.driver_id = t.driver_id
GROUP BY
	d.driver_id,
	d.name;

SELECT
	*
FROM
	driver_performance_summary
ORDER BY
	completion_rate ASC;

/*
The view summarizes driver performance with one row per driver. A LEFT JOIN is used so drivers 
with no trips can still appear. NULLIF prevents division-by-zero errors when total_rides = 0.
Completion and cancellation rates are displayed as percentages, while revenue and ratings are 
calculated only from completed trips.
 */
-- Q7 — 7-day moving average fare (Advanced · window frame clause)
-- Daily series: one row per day, avg fare_amount for completed trips that day
-- AVG(...) OVER (ORDER BY trip_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)
-- Comment: what happens for the first 6 days of the series, and is that average meaningful?

SELECT
	requested_at::date AS trip_date,
	AVG(fare_amount) AS daily_avg_fare
FROM
	trips
WHERE
	status = 'completed'
GROUP BY
	requested_at::date
ORDER BY
	trip_date;

SELECT
	trip_date,
	round(daily_avg_fare, 2),
	round(AVG(daily_avg_fare) OVER (
	ORDER BY
		trip_date
	        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 2) AS moving_avg_7days
FROM
	(
	SELECT
		requested_at::date AS trip_date,
		AVG(fare_amount) AS daily_avg_fare
	FROM
		trips
	WHERE
		status = 'completed'
	GROUP BY
		requested_at::date
)
ORDER BY
	trip_date;

/*
The query first creates a daily summary of average fares for completed trips. A window function 
is then used to calculate a trailing 7-day moving average.

ROWS BETWEEN 6 PRECEDING AND CURRENT ROW tells PostgreSQL to average the current day together 
with the previous six rows in the result set, creating a 7-day moving average.

During the first six rows of the series, fewer than six previous rows exist. PostgreSQL 
automatically uses all available rows instead of producing an error. The averages are still 
meaningful, although they are based on fewer than seven days of data and may be less stable 
than later values.
*/
-- Q8 — Ranking ties, using your own view (Intermediate · ROW_NUMBER / RANK / DENSE_RANK)
-- From driver_performance_summary, rank by total_revenue with all three functions side by side
-- Comment: how do the three handle a tie differently, what does the next driver get under each?
-- creating own measures
SELECT
	driver_id,
	driver_name,
	total_revenue
FROM
	driver_performance_summary
ORDER BY
	total_revenue DESC;

SELECT
	trip_id,
	fare_amount
FROM
	trips
WHERE
	driver_id = 6
	AND status = 'completed'
LIMIT 1;

UPDATE
	trips
SET
	fare_amount = fare_amount + 7484.55
WHERE
	trip_id = 93038;

SELECT
	driver_id,
	driver_name,
	total_revenue,
	ROW_NUMBER() OVER (
ORDER BY
	total_revenue DESC) AS row_num,
	RANK() OVER (
ORDER BY
	total_revenue DESC) AS rank_num,
	DENSE_RANK() OVER (
ORDER BY
	total_revenue DESC) AS dense_rank_num
FROM
	driver_performance_summary;

/*
ROW_NUMBER() always assigns unique numbers, even for tied revenue.

RANK() assigns the same rank to tied drivers and skips the next rank number. 
For example: 1, 2, 2, 4.

DENSE_RANK() assigns the same rank to tied drivers but does not skip the next rank number. 
For example: 1, 2, 2, 3.
*/
-- Stretch — KPI, Metric, Dimension (Conceptual · no SQL required)
-- Comment only:
-- 1. Define metric, dimension, KPI in your own words
-- 2. Classify every column of driver_performance_summary as metric or dimension
-- 3. Which metrics in that view would you argue are actual KPIs for a ride-share company, and why?

/*
Metric: A number that can be measured, such as revenue, rides, or ratings.

Dimension: A category or label used to group data, such as driver_id or driver_name.

KPI (Key Performance Indicator): An important metric that shows how well the business is performing.

Dimensions:
- driver_id
- driver_name

Metrics:
- total_rides
- total_completed_trips
- total_cancelled_trips
- completion_rate
- cancellation_rate
- total_revenue
- avg_rating

KPIs:
- completion_rate (shows how often drivers successfully complete trips)
- cancellation_rate (shows how often trips are cancelled)
- total_revenue (shows how much money is earned)
- avg_rating (shows service quality and customer satisfaction)
*/
