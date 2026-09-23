SELECT * FROM trips;



EXPLAIN ANALYZE 
SELECT * FROM trips WHERE driver_id = 3;

--
--Seq Scan on trips  (cost=0.00..25374.00 rows=102367 width=67) (actual time=0.012..122.936 rows=99827 loops=1)
--  Filter: (driver_id = 3)
--  Rows Removed by Filter: 900173
--Planning Time: 0.066 ms
--Execution Time: 126.334 ms

EXPLAIN ANALYZE
SELECT * FROM trips WHERE status = 'completed';

--
--Seq Scan on trips  (cost=0.00..25374.00 rows=601000 width=67) (actual time=0.010..201.849 rows=600125 loops=1)
--  Filter: ((status)::text = 'completed'::text)
--  Rows Removed by Filter: 399875
--Planning Time: 0.086 ms
--Execution Time: 222.587 ms

  EXPLAIN ANALYZE
SELECT * FROM trips 
WHERE driver_id = 3 AND status = 'completed';

--
--Gather  (cost=1000.00..26276.20 rows=61522 width=67) (actual time=1.253..95.351 rows=59910 loops=1)
--  Workers Planned: 2
--  Workers Launched: 2
--  ->  Parallel Seq Scan on trips  (cost=0.00..19124.00 rows=25634 width=67) (actual time=0.050..79.466 rows=19970 loops=3)
--        Filter: ((driver_id = 3) AND ((status)::text = 'completed'::text))
--        Rows Removed by Filter: 313363
--Planning Time: 0.189 ms
--Execution Time: 99.349 ms

CREATE INDEX idx_trips_driver_id ON trips(driver_id);


EXPLAIN ANALYZE 
SELECT * FROM trips WHERE driver_id = 3;

--Bitmap Heap Scan on trips  (cost=1145.77..15299.36 rows=102367 width=67) (actual time=6.013..39.780 rows=99827 loops=1)
--  Recheck Cond: (driver_id = 3)
--  Heap Blocks: exact=12870
--  ->  Bitmap Index Scan on idx_trips_driver_id  (cost=0.00..1120.18 rows=102367 width=0) (actual time=3.844..3.845 rows=99827 loops=1)
--        Index Cond: (driver_id = 3)
--Planning Time: 0.062 ms
--Execution Time: 43.629 ms

CREATE INDEX idx_trips_status ON trips(status);


EXPLAIN ANALYZE
SELECT * FROM trips WHERE status = 'completed';

--
--Seq Scan on trips  (cost=0.00..25374.00 rows=601000 width=67) (actual time=0.015..163.045 rows=600125 loops=1)
--  Filter: ((status)::text = 'completed'::text)
--  Rows Removed by Filter: 399875
--Planning Time: 0.431 ms
--Execution Time: 182.397 ms


CREATE INDEX idx_trips_driver_status ON trips(driver_id, status);



  EXPLAIN ANALYZE
SELECT * FROM trips 
WHERE driver_id = 3 AND status = 'completed';


--Bitmap Heap Scan on trips  (cost=847.03..14643.86 rows=61522 width=67) (actual time=9.860..44.907 rows=59910 loops=1)
--  Recheck Cond: ((driver_id = 3) AND ((status)::text = 'completed'::text))
--  Heap Blocks: exact=12770
--  ->  Bitmap Index Scan on idx_trips_driver_status  (cost=0.00..831.64 rows=61522 width=0) (actual time=5.616..5.616 rows=59910 loops=1)
--        Index Cond: ((driver_id = 3) AND ((status)::text = 'completed'::text))
--Planning Time: 0.439 ms
--Execution Time: 47.671 ms

--------------------------
CREATE VIEW completed_trips_detail_view AS
SELECT
	d.name driver_name,
	p.name passenger_name,
	pck.city_name AS pickup_city,
	dst.city_name AS dropodd_city,
	t.requested_at
FROM
	trips t
INNER JOIN drivers d
ON
	t.driver_id = d.driver_id
INNER JOIN passengers p 
ON
	t.passenger_id = p.passenger_id
INNER JOIN locations pck
ON
	t.pickup_location_id = pck.location_id
INNER JOIN locations dst 
ON
	t.dropoff_location_id = dst.location_id
WHERE
	t.status = 'completed';



SELECT * FROM completed_trips_detail_view;

SELECT * FROM (
SELECT
	ROW_NUMBER() OVER (
	PARTITION BY t.driver_id 
	ORDER BY requested_at) AS row_num ,
	*
FROM
	trips t ) t
	WHERE row_num = 1;



SELECT * FROM (
SELECT
	ROW_NUMBER() OVER (
	PARTITION BY t.driver_id 
	ORDER BY requested_at desc) AS row_num ,
	*
FROM
	trips t ) t
	WHERE row_num = 1;



--------------


-- ── 1. Running total of driver earnings over time ─────────────────
-- SUM() OVER (PARTITION BY ... ORDER BY ...)
SELECT
    driver_id,
    requested_at,
    fare_amount,
    SUM(fare_amount) OVER (
        PARTITION BY driver_id
        ORDER BY requested_at
    ) AS running_total
FROM trips
WHERE status = 'completed'
ORDER BY driver_id desc, requested_at;


----- Rank drivers by total revenue
driver_id, total_revenue, RANK BY total revenue  

SELECT
    driver_id,
    SUM(fare_amount) AS total_earnings,
    RANK() OVER (ORDER BY SUM(fare_amount) DESC) AS revenue_rank
FROM trips
WHERE status = 'completed'
GROUP BY driver_id;



SELECT
    driver_id,
    count(fare_amount) AS total_earnings,
    RANK() OVER (ORDER BY count(fare_amount) DESC) AS revenue_rank
FROM trips
WHERE status = 'completed'
GROUP BY driver_id;



--4. Time gap between a driver's consecutive trips
SELECT
    driver_id,
    requested_at,
    LAG(requested_at) OVER (
        PARTITION BY driver_id
        ORDER BY requested_at
    ) ,
    requested_at - LAG(completed_at) OVER (
        PARTITION BY driver_id
        ORDER BY requested_at
    ) AS gap_since_last_trip
FROM trips;
