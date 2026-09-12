-- Week 1 SQL Assignment — Answers
-- Fill in each query below. See sql_assignment.md for the full scenario text.
-- Rename this file to sql_answers.sql before committing.

-- Q1 — Kathmandu to Pokhara (Basic · DQL)
-- Completed rides from Kathmandu to Pokhara: ride_id, driver_name, passenger_name, fare_amount
SELECT
	r.ride_id,
	r.driver_name ,
	r.passenger_name ,
	r.fare_amount
FROM
	rides r
WHERE
	r.pickup_city = 'Kathmandu'
	AND r.dropoff_city = 'Pokhara'
	AND r.ride_status = 'completed';


-- Q2 — Top 5 highest fares (Basic · DQL)
-- driver_name, passenger_name, fare_amount — 5 highest fares, descending
SELECT
	r.driver_name,
	r.passenger_name ,
	r.fare_amount
FROM
	rides r
ORDER BY
	fare_amount DESC
LIMIT 5;


-- Q3 — The "Shrestha" complaint (Basic · DQL)
-- Every ride where driver_name contains "shrestha", case-insensitive
SELECT
	*
FROM
	rides r
WHERE
	r.driver_name ILIKE '%shrestha%';


-- Q4 — How many rides were never rated? (Basic–Intermediate · NULL)
-- One query returning: total_rides, rated_rides, unrated_rides
SELECT 
    COUNT(*) AS total_rides,
    COUNT(rating) AS rated_rides,
    COUNT(*) - COUNT(rating) AS unrated_rides
FROM rides;


-- Q5 — Every ride that wasn't paid in cash (Intermediate · NULL)
-- ride_id, driver_name, payment_method — not cash, including unrecorded payment methods
SELECT
	r.ride_id ,
	r.driver_name ,
	r.payment_method
FROM
	rides r
WHERE
	r.payment_method <> 'cash'
	OR r.payment_method IS NULL;


-- Q6 — Revenue by pickup city (Intermediate · Aggregation)
-- pickup_city, total_rides, total_revenue, avg_fare (2 decimals) — sorted by total_revenue desc
SELECT
	r.pickup_city ,
	count(*) AS total_rides,
	sum(r.fare_amount) AS total_revenue,
	round(avg(r.fare_amount), 2) AS average_fare
FROM
	rides r
GROUP BY
	r.pickup_city
ORDER BY 
	total_revenue DESC;


-- Q7 — Ride outcomes by status (Intermediate · Aggregation)
-- ride_status, ride_count, avg_distance_km (2 decimals) — sorted by ride_count desc
SELECT
	r.ride_status,
	count(*) AS total_rides,
	round(avg(r.ride_distance_km), 2) AS average_distance_km
FROM
	rides r
GROUP BY
	r.ride_status
ORDER BY
	total_rides DESC;


-- Q8 — A new driver's first ride (Basic–Intermediate · DML)
-- 8a. INSERT the new ride (ride_id 9001, rating NULL)
INSERT
	INTO
	rides
VALUES (
9001,
'Sunita Gurung',
'Rajan Thapa',
'Lalitpur',
'Bhaktapur',
350,
12.4,
'completed',
CURRENT_TIMESTAMP, 
CURRENT_TIMESTAMP, 
NULL,
'cash'
);


-- 8b. UPDATE the rating to 4.8 for ride_id 9001
UPDATE
	rides
SET
	rating = 4.8
WHERE
	ride_id = 9001;


-- Q9 — Locking down payment methods (Intermediate · DDL)
-- 9a. ALTER TABLE to restrict payment_method to a fixed set of values
ALTER TABLE rides
ADD CONSTRAINT rides_payment_method_check
CHECK (payment_method IN ('cash', 'esewa', 'khalti', 'card', 'wallet'))
NOT VALID;


-- 9b. INSERT using an invalid payment method — note the error you'd expect in a comment
INSERT
	INTO
	rides
VALUES (
    9003,
'Pratik Acharya',
'Cristano Ronaldo',
'Kathmandu',
'Pokhara',
500,
200,
'completed',
CURRENT_TIMESTAMP,
CURRENT_TIMESTAMP,
4.5,
'paypal'
);


-- Q10 — Rides priced above the platform average (Basic · Subquery)
-- ride_id, driver_name, fare_amount — fare_amount above the average of ALL rides (via subquery)
SELECT
	r.ride_id ,
	r.driver_name ,
	r.fare_amount
FROM
	rides r
WHERE
	r.fare_amount > (
	SELECT
		avg(fare_amount)
	FROM
		rides);

