-- Week 2 Queries — Answers
-- Fill in each query below. See sql_assignment.md for the full scenario text.
-- Rename this file to week2_queries.sql before committing.

-- Q1 — Rides per driver (Basic · JOIN + GROUP BY)
-- name, total_rides — completed rides only, ordered by total_rides desc
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


-- Q2 — Drivers with zero completed rides (Intermediate · anti-join)
-- name of every driver with no completed trip (LEFT JOIN, not a subquery)
SELECT
	d.name
FROM
	drivers d
LEFT JOIN trips t ON
	d.driver_id = t.driver_id
	AND t.status = 'completed'
WHERE
	t.trip_id IS NULL;


-- Q3 — Average fare per pickup city (Intermediate · 3-table JOIN + AVG)
-- city_name, avg_fare (2 decimals) — ordered by avg_fare desc
SELECT
	l.city_name ,
	round(avg(t.fare_amount), 2) AS avg_fare
FROM
	locations l
JOIN trips t ON
	l.location_id = t.pickup_location_id
GROUP BY
	l.city_name
ORDER BY
	avg_fare DESC ;


-- Q4 — Same-city driver/passenger trips (Basic–Intermediate · schema thinking)
-- Partial query + written explanation (as a comment) of what the schema is missing

/* This cannot be completed with the current schema because drivers and passengers do not 
have a home_location_id. To fix this, we should add a foreign key column referencing 
locations(location_id) instead of a plain text field, to preserve referential integrity 
and avoid inconsistent spellings.

SELECT
	t.trip_id,
	d.name AS driver_name,
	p.name AS passenger_name,
	l.city_name AS home_city
FROM
	trips t
JOIN drivers d ON
	t.driver_id = d.driver_id
JOIN passengers p ON
	t.passenger_id = p.passenger_id
JOIN locations l ON
	d.home_location_id = l.location_id
WHERE
	d.home_location_id = p.home_location_id;
*/

-- Q5 — Re-run Week 1's revenue query (Basic · verification)
-- Total revenue from completed rides — must match your Week 1 answer
SELECT
	SUM(fare_amount) AS total_revenue
FROM
	trips
WHERE
	status = 'completed';
-- During testing, a bug appeared because fare_amount was stored as FLOAT in rides
-- and NUMERIC in trips. FLOAT can introduce rounding errors, so the totals did not match.


-- Q6 — WHERE and HAVING, together (Intermediate · WHERE + GROUP BY + HAVING)
-- Drivers with > 280 completed rides AND total revenue > NPR 140,000
SELECT
	d."name",
	COUNT(*) AS completed_rides,
	SUM(t.fare_amount) AS total_revenue
FROM
	drivers d
JOIN trips t ON
	d.driver_id = t.driver_id
WHERE
	t.status = 'completed'
GROUP BY
	d.name
HAVING
	count(*) > 280
	AND 
	sum(t.fare_amount) > 140000;


-- Q7 — Clean the phone numbers (Intermediate · REGEXP_REPLACE)
-- Scratch copy (TEMP temp_rides, same as day1_class_query.sql) + ALTER TABLE + UPDATE to add
-- messy phone_number values, then a digits-only SELECT
-- Comment: why REPLACE() alone can't do this
CREATE TEMP TABLE temp_rides AS
SELECT
	*
FROM
	rides;

ALTER TABLE temp_rides 
ADD COLUMN phone_no varchar(50);

UPDATE
	temp_rides
SET
	phone_no = '(9800)-00 0000'
WHERE
	ride_id = 1;

UPDATE
	temp_rides
SET
	phone_no = '(9800)-00 0001'
WHERE
	ride_id = 2;

UPDATE
	temp_rides
SET
	phone_no = '(98)-1111 1234'
WHERE
	ride_id = 3;

SELECT
	ride_id,
	phone_no,
	REGEXP_REPLACE(phone_no, '[^0-9]', '', 'g') AS clean_phone_number
FROM
	temp_rides
WHERE
	phone_no IS NOT NULL;
-- REPLACE() is too limited (one character at a time) while REGEXP_REPLACE handles 
-- all non-digits in one go.

-- Q8 — Prove the city data is clean (Intermediate · STRPOS / ILIKE)
-- Version 1: STRPOS
-- Version 2: ILIKE
SELECT
	*
FROM
	locations l
WHERE
	STRPOS(l.city_name, ' ') > 0;

SELECT
	*
FROM
	locations l
WHERE
	l.city_name ILIKE '% %';
-- If both queries return zero rows, that's proof the migration is clean.
-- If either returns rows, you've found a bug — fix your migration and re-run verification.

-- Q9 — Self-join: drivers who overlapped (Advanced · self-join + date functions)
-- Pairs of different drivers, same pickup location, same calendar day
SELECT distinct 
	d1.name AS driver_1_name,
	d2.name AS driver_2_name,
	l.city_name AS same_pickup_city,
	date(t1.requested_at) AS same_ride_date
FROM
	trips t1
JOIN trips t2
    ON
	t1.pickup_location_id = t2.pickup_location_id
	AND Date(t1.requested_at) = Date(t2.requested_at)
	AND t1.driver_id < t2.driver_id
JOIN drivers d1
    ON
	d1.driver_id = t1.driver_id
JOIN drivers d2
    ON
	d2.driver_id = t2.driver_id
JOIN locations l
    ON
	l.location_id = t1.pickup_location_id
ORDER BY
	same_ride_date,
	same_pickup_city,
	driver_1_name,
	driver_2_name;


-- Q10 — Design challenge: promo codes (Design · no SQL required)
-- Written answer only — table(s), keys, and the normal-form problem with the flat-column approach

/*
promo_codes
-----------
promo_code_id  PRIMARY KEY
code           UNIQUE NOT NULL
description
discount_pct   NOT NULL
promo_expiry   NOT NULL

promo_usage
-----------
trip_id        FOREIGN KEY REFERENCES trips(trip_id)
promo_code_id  FOREIGN KEY REFERENCES promo_codes(promo_code_id)
applied_at

PRIMARY KEY (trip_id, promo_code_id)

If promo_code, discount_pct, and promo_expiry were stored directly in trips, 
the discount and expiry information would be repeated for every trip using the same code.
>>
	This creates a Third Normal Form problem because discount_pct and promo_expiry depend 
	on promo_code, not directly on trip_id:
	
	    trip_id -> promo_code -> discount_pct, promo_expiry
	
	This causes update anomalies because changing a promo's discount or expiry would require 
	updating multiple trip rows.
	
*/










