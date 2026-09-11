CREATE DATABASE ride_share;


CREATE TABLE rides (
    ride_id          INTEGER       PRIMARY KEY,
    driver_name      VARCHAR(100)          NOT NULL,
    passenger_name   VARCHAR(100)          NOT NULL,
    pickup_city      VARCHAR(100)          NOT NULL,
    dropoff_city     VARCHAR(100)          NOT NULL,
    fare_amount      NUMERIC(10,2) NOT NULL CHECK (fare_amount >= 0),
    ride_distance_km NUMERIC(6,2)  NOT NULL CHECK (ride_distance_km >= 0),
    ride_status      VARCHAR(50)   NOT NULL default 'pending' CHECK (ride_status IN ('no_show', 'completed', 'cancelled')),
    requested_at     TIMESTAMP     NOT NULL,
    completed_at     TIMESTAMP,
    rating           NUMERIC(2,1) CHECK (rating >= 1.0 AND rating <= 5.0),
    payment_method   VARCHAR(50)
);


SELECT
	*
FROM
	rides;

SELECT
	ride_id,
	driver_name,
	passenger_name
FROM
	rides;

SELECT * 
FROM rides r 
WHERE ride_status = 'cancelled';



SELECT * 
FROM rides r 
WHERE ride_status = 'cancelled'
AND payment_method = 'esewa';


SELECT * 
FROM rides r 
WHERE ride_status = 'cancelled'
AND payment_method = 'esewa'
ORDER BY fare_amount  DESC



SELECT * 
FROM rides r 
WHERE ride_status = 'cancelled'
AND payment_method = 'esewa'
ORDER BY fare_amount  DESC
LIMIT 10;

SELECT count(*) FROM rides;


SELECT ride_status,count(*) FROM rides
GROUP BY ride_status ;

SELECT driver_name,ride_status,count(*) 
FROM rides
WHERE ride_status = 'completed'
GROUP BY ride_status, driver_name 
ORDER BY driver_name ;


SELECT 
 * 
 FROM rides r 
 WHERE rating = NULL

 
 SELECT NULL = NULL ;
 SELECT 1 = 2;
 
 
SELECT 
 * 
 FROM rides r 
 WHERE rating is NULL
 
SELECT DISTINCT payment_method 
FROM rides r ;

SELECT ride_id, payment_method
FROM rides r 
WHERE payment_method  != 'cash';

SELECT count(*)
FROM rides r 
WHERE payment_method  != 'cash';



SELECT count(*)
FROM rides r 
WHERE payment_method  = 'cash';

SELECT (2292 + 2307);


SELECT count(*)
FROM rides r 
WHERE payment_method  != 'cash'
OR payment_method IS NULL ;


SELECT (2693 + 2307);


SELECT count(*)
FROM rides r 
WHERE payment_method IS NOT NULL ;


SELECT count(payment_method)
FROM rides r;


SELECT * FROM rides;


completed_at gt 2024-06-01 (-> 2024-06-02)

SELECT * FROM rides r 
WHERE CAST(completed_at AS date ) > '2024-06-01'
ORDER BY completed_at ;


SELECT * FROM rides r ORDER BY 1 DESC  LIMIT 1


INSERT
	INTO
	rides (ride_id,
	driver_name,
	passenger_name,
	pickup_city,
	dropoff_city,
	fare_amount,
	ride_distance_km,
	ride_status,
	requested_at,
	completed_at,
	rating,
	payment_method)
VALUES
	 (5000,
'Bikash Karki',
'Sabina Dahal',
'Birgunj',
'Kathmandu',
17.96,
31.75,
'completed',
'2024-10-27 12:16:55',
'2024-10-27 13:26:12.960719',
4.6,
'esewa');




INSERT
	INTO
	rides (ride_id,
	driver_name,
	passenger_name,
	pickup_city,
	dropoff_city,
	fare_amount,
	ride_distance_km,
	ride_status,
	requested_at,
	completed_at,
	rating,
	payment_method)
VALUES
	 (5001,
NUll,
'Sabina Dahal',
'Birgunj',
'Kathmandu',
17.96,
31.75,
'completed',
'2024-10-27 12:16:55',
'2024-10-27 13:26:12.960719',
4.6,
'esewa');


ALTER TABLE rides
DROP CONSTRAINT rides_ride_status_check;

ALTER TABLE rides
ALTER COLUMN ride_status SET DEFAULT 'pending',
   ADD CONSTRAINT rides_ride_status_check
CHECK 
(ride_status IN 
('no_show', 'completed', 'cancelled', 'pending'));
