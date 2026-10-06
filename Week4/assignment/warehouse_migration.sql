BEGIN;

-- 1. Deduplicate dim_driver
--    Re-point fact_trips.driver_key to the surviving copy (UPDATE ... FROM),
--    then DELETE the extra copies (DELETE ... USING).

WITH driver_survivors AS (
SELECT
	driver_id,
	MIN(driver_key) AS surviving_driver_key
FROM
	dim_driver
GROUP BY
	driver_id
)
UPDATE
	fact_trips AS f
SET
	driver_key = s.surviving_driver_key
FROM
	dim_driver AS duplicate_driver
JOIN driver_survivors AS s
    ON
	s.driver_id = duplicate_driver.driver_id
WHERE
	f.driver_key = duplicate_driver.driver_key
	AND duplicate_driver.driver_key <> s.surviving_driver_key;

DELETE
FROM
	dim_driver AS d
		USING (
	SELECT
		driver_id,
		MIN(driver_key) AS surviving_driver_key
	FROM
		dim_driver
	GROUP BY
		driver_id
) AS s
WHERE
	d.driver_id = s.driver_id
	AND d.driver_key <> s.surviving_driver_key;


-- 1b. Deduplicate dim_passenger (same pattern)

WITH passenger_survivors AS (
SELECT
	passenger_id,
	MIN(passenger_key) AS surviving_passenger_key
FROM
	dim_passenger
GROUP BY
	passenger_id
)
UPDATE
	fact_trips AS f
SET
	passenger_key = s.surviving_passenger_key
FROM
	dim_passenger AS duplicate_passenger
JOIN passenger_survivors AS s
    ON
	s.passenger_id = duplicate_passenger.passenger_id
WHERE
	f.passenger_key = duplicate_passenger.passenger_key
	AND duplicate_passenger.passenger_key <> s.surviving_passenger_key;

DELETE
FROM
	dim_passenger AS p
		USING (
	SELECT
		passenger_id,
		MIN(passenger_key) AS surviving_passenger_key
	FROM
		dim_passenger
	GROUP BY
		passenger_id
) AS s
WHERE
	p.passenger_id = s.passenger_id
	AND p.passenger_key <> s.surviving_passenger_key;


-- 2. UNIQUE constraints on dim_driver(driver_id) and dim_passenger(passenger_id)

ALTER TABLE dim_driver
ADD CONSTRAINT uq_dim_driver_driver_id
UNIQUE (driver_id);

ALTER TABLE dim_passenger
ADD CONSTRAINT uq_dim_passenger_passenger_id
UNIQUE (passenger_id);


-- 3. New fact_trips columns
--    time_key     INTEGER      -> FK to dim_time(time_key)
--    trip_status  VARCHAR(20)  -> CHECK: completed / cancelled / no_show
--    cancelled_by VARCHAR(10)  -> CHECK: driver / passenger / system

ALTER TABLE fact_trips
ADD COLUMN time_key INTEGER;

ALTER TABLE fact_trips
ADD COLUMN trip_status VARCHAR(20);

ALTER TABLE fact_trips
ADD COLUMN cancelled_by VARCHAR(10);

ALTER TABLE fact_trips
ADD CONSTRAINT fk_fact_trips_time_key
FOREIGN KEY (time_key)
REFERENCES dim_time(time_key);

ALTER TABLE fact_trips
ADD CONSTRAINT chk_fact_trips_trip_status
CHECK (trip_status IN ('completed', 'cancelled', 'no_show'));

ALTER TABLE fact_trips
ADD CONSTRAINT chk_fact_trips_cancelled_by
CHECK (cancelled_by IN ('driver', 'passenger', 'system'));


-- 4. Backfill time_key from requested_at (HHMM, minutes rounded down to 15)

UPDATE fact_trips
SET time_key =
      EXTRACT(HOUR FROM requested_at)::INTEGER * 100
    + (
        EXTRACT(MINUTE FROM requested_at)::INTEGER / 15
      ) * 15
WHERE time_key IS NULL;

COMMIT;

