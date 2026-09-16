


select * from rides;

select distinct driver_name from rides;

select distinct trim(driver_name) from rides;


select trim(' bishal  rijal ');

select Replace('bishal   rijal', '  ', ' ');

bishal  rijal

select distinct trim(replace(driver_name, '  ', ' ')) from rides;

SELECT DISTINCT driver_name from rides
where driver_name like '%  %';


SELECT DISTINCT driver_name from rides
where driver_name like 'Ram%';



SELECT DISTINCT driver_name from rides
where driver_name ilike 'Ram%';

select DISTINCT upper(driver_name) from rides;

select DISTINCT initcap(driver_name) from rides;


SELECT
	DISTINCT INITCAP(REPLACE(driver_name, '  ', ' '))
FROM
	rides r ;


'  Bishal  j     
rijal'

select trim(regexp_replace(
'  Bishal  j     
rijal', '\s+', ' ', 'g'));

' Bishal j rijal'


select regexp_replace(
'  Bishal  j     
rijal', '\s+', ' ');

' Bishal  j     
rijal'


SELECT
	DISTINCT INITCAP(TRIM(REGEXP_REPLACE(
	r.driver_name, '\s+', ' ', 'g')))
FROM
	rides r;


insert into drivers (name)
SELECT
	DISTINCT INITCAP(TRIM(REGEXP_REPLACE(
	r.driver_name, '\s+', ' ', 'g')))
FROM
	rides r;

select * from drivers;




insert into passengers (name)
SELECT
	DISTINCT INITCAP(TRIM(REGEXP_REPLACE(
	r.passenger_name, '\s+', ' ', 'g')))
FROM
	rides r;

select * from passengers;



select * from rides;

SELECT DISTINCT pickup_city from rides
union
SELECT DISTINCT dropoff_city from rides;



SELECT DISTINCT pickup_city from rides
EXCEPT
SELECT DISTINCT dropoff_city from rides;



SELECT name from drivers
EXCEPT
SELECT name  from passengers;



SELECT name from drivers
INTERSECT
SELECT name  from passengers;


SELECT name from drivers
UNION
SELECT name  from passengers;



SELECT name, driver_id, 'driver' from drivers
UNION
SELECT name, passenger_id, 'passenger' from passengers;



SELECT DISTINCT pickup_city from rides
union all
SELECT DISTINCT dropoff_city from rides;

INSERT INTO locations(city_name)
SELECT DISTINCT(pickup_city) FROM rides r 
UNION 
SELECT DISTINCT(dropoff_city ) FROM rides r ;


insert into payment_methods (name)
select distinct payment_method
from rides where payment_method is not null;

select * from payment_methods

SELECT * from trips;

SELECT 
(select driver_id from drivers d where d.name = INITCAP(TRIM(REGEXP_REPLACE(
	r.driver_name, '\s+', ' ', 'g'))) ) driver_id,
* from rides r ;



INSERT INTO trips (
	driver_id,
	passenger_id,
	pickup_location_id,
	dropoff_location_id,
	fare_amount,
	distance_km,
	status,
	requested_at,
	completed_at,
	rating,
	payment_method_id
)
SELECT 
(SELECT  driver_id 
	FROM drivers d 
	 WHERE d.name = INITCAP(TRIM(REGEXP_REPLACE(r.driver_name, '\s+', ' ', 'g')))) driver_id,
(SELECT  passenger_id 
		FROM passengers p
	 WHERE p.name = INITCAP(TRIM(REGEXP_REPLACE(r.passenger_name, '\s+', ' ', 'g')))) passenger_id,
(SELECT  location_id  
		FROM locations p
	 WHERE p.city_name = r.pickup_city ) pickup_location_id,
(SELECT  location_id  
		FROM locations p
	 WHERE p.city_name = r.dropoff_city ) dropoff_location_id,
fare_amount,
ride_distance_km,
ride_status,
requested_at,
completed_at,
rating,
(SELECT  payment_method_id  
		FROM payment_methods pm  
		WHERE pm.name = r.payment_method  ) payment_method_id
FROM rides r;


select * from trips;

select d.driver_id, name, trip_id, fare_amount
from trips t 
inner JOIN drivers d on d.driver_id = t.driver_id;


insert into drivers(name)
VALUES ('Bishal Rijal');


select d.driver_id, name, trip_id, fare_amount
from drivers d 
left JOIN trips t on d.driver_id = t.driver_id
ORDER BY trip_id DESC;


select name from drivers WHERE driver_id not in ( select driver_id from trips)


select d.driver_id, name, trip_id, fare_amount
from drivers d 
left JOIN trips t on d.driver_id = t.driver_id
where t.trip_id is NULL;

select d.driver_id, d.name driver_name, p.name passenger_name, pck.city_name pickup_city, dst.city_name dropoff_city, trip_id, fare_amount
from trips t 
join drivers d on d.driver_id = t.driver_id 
join passengers p on p.passenger_id = t.passenger_id 
join locations pck on pck.location_id = t.pickup_location_id 
join locations dst on dst.location_id = t.dropoff_location_id ;



select d.driver_id, name, trip_id, fare_amount
from drivers d 
left JOIN trips t on d.driver_id = t.driver_id
and  t.fare_amount > 100
order by t.trip_id DESC;