SELECT * FROM rides;

SELECT 
	sum(fare_amount) 
FROM rides;

SELECT min(ride_distance_km )
FROM  rides


SELECT max(ride_distance_km )
FROM  rides


SELECT avg(ride_distance_km )
FROM  rides


SELECT driver_name,
avg(ride_distance_km )
FROM  rides
GROUP BY driver_name ;

SELECT driver_name,
count(*)
FROM rides r 
WHERE ride_status = 'completed'
GROUP BY driver_name 
HAVING count(*) > 150



SELECT driver_name,
count(*) total_ride,
sum(fare_amount ) total_revenue
FROM rides r 
WHERE ride_status = 'completed'
GROUP BY driver_name
ORDER BY total_revenue desc;




------- Normalization
SELECT
	*
INTO
	TEMP temp_rides
FROM
	rides r;

SELECT * FROM temp_rides;

ALTER 
TABLE temp_rides 
ADD phone_number varchar(20);

UPDATE temp_rides 
SET phone_number = '987654321'
WHERE driver_name 
LIKE '%Anita Rai%';

UPDATE temp_rides 
SET phone_number = '9876543210'
WHERE driver_name LIKE '%Anita Rai%'
AND ride_id >1000;


SELECT DISTINCT driver_name, phone_number 
FROM temp_rides
WHERE driver_name LIKE '%Anita Rai%';

SELECT * FROM temp_rides;



----- Bishal is enrolled into the app but has not got the rides at
--how can I have the data ?
SELECT * FROM temp_rides ORDER BY ride_id DESC LIMIT 1;


--- insert anamoly 
--How to insert without ride ?

INSERT INTO temp_rides (ride_id,driver_name,passenger_name,pickup_city,dropoff_city,fare_amount,ride_distance_km,ride_status,requested_at,completed_at,rating,payment_method,phone_number) VALUES
	 (5001,'Bishal Rijal','Sabina Dahal','Birgunj','Kathmandu',17.96,31.75,'completed','2024-10-27 12:16:55','2024-10-27 13:26:12.960719',4.6,'esewa','9876543210');

SELECT DISTINCT driver_name
FROM temp_rides;

DELETE FROM temp_rides 
WHERE ride_id = 5001;
