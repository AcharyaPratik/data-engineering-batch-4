select * from drivers;


INSERT INTO trips (driver_id,passenger_id,pickup_location_id,dropoff_location_id,fare_amount,distance_km,status,requested_at,completed_at,rating,payment_method_id) VALUES
	 (11,16,3,8,17.96,31.75,'completed','2024-10-27 12:16:55','2024-10-27 13:26:12.960719',4.6,3);

DELETE FROM drivers 
WHERE driver_id  = 11;


ALTER TABLE  trips 
DROP CONSTRAINT trips_driver_id_fkey;

ALTER TABLE trips 
ADD CONSTRAINT trips_driver_id_fkey 
FOREIGN KEY (driver_id)
REFERENCES drivers(driver_id)
ON DELETE CASCADE ;


select * from trips order by trip_id desc limit 1;




INSERT INTO payment_methods (name)
VALUES ('IME pay');


select * from payment_methods;


INSERT INTO trips (driver_id,passenger_id,pickup_location_id,dropoff_location_id,fare_amount,distance_km,status,requested_at,completed_at,rating,payment_method_id) VALUES
	 (10,16,3,8,17.96,31.75,'completed','2024-10-27 12:16:55','2024-10-27 13:26:12.960719',4.6,5);


DELETE  FROM payment_methods WHERE name =  'IME pay';

DELETE  FROM payment_methods WHERE name =  'IME pay';


ALTER TABLE trips 
DROP CONSTRAINT trips_payment_method_id_fkey ;

ALTER TABLE trips 
ADD CONSTRAINT trips_payment_method_id_fkey 
FOREIGN KEY (payment_method_id) REFERENCES public.payment_methods(payment_method_id)
ON DELETE SET NULL ;


DELETE  FROM payment_methods WHERE name =  'IME pay';

select * FROM trips order by trip_id desc LIMIT 1;


select count(*) from trips;


INSERT INTO trips (driver_id, passenger_id, pickup_location_id, dropoff_location_id,
                   fare_amount, distance_km, status, requested_at)
VALUES (1, 1, 1, 2, 250.00, 8.5, 'completed', NOW());


SELECT count(*) from rides;

BEGIN;

INSERT INTO trips (driver_id, passenger_id, pickup_location_id, dropoff_location_id,
                   fare_amount, distance_km, status, requested_at)
VALUES (1, 1, 1, 2, 250.00, 8.5, 'completed', NOW());


INSERT INTO trips (driver_id, passenger_id, pickup_location_id, dropoff_location_id,
                   fare_amount, distance_km, status, requested_at)
VALUES (1, 1, 1, 2, 250.00, 8.5, 'completed', NOW());


INSERT INTO trips (driver_id, passenger_id, pickup_location_id, dropoff_location_id,
                   fare_amount, distance_km, status, requested_at)
VALUES (1, 1, 1, 2, 250.00, 8.5, 'completed', NOW());

ROLLBACK;

COMMIT

select count(*) from trips;


BEGIN;


INSERT INTO trips (driver_id, passenger_id, pickup_location_id, dropoff_location_id,
                   fare_amount, distance_km, status, requested_at)
VALUES (1, 1, 1, 2, 250.00, 8.5, 'completed', NOW());


INSERT INTO trips (driver_id, passenger_id, pickup_location_id, dropoff_location_id,
                   fare_amount, distance_km, status, requested_at)
VALUES (1, 1, 1, 2, -250.00, 8.5, 'completed', NOW());

rollback

commit ;


begin ;

INSERT INTO trips (driver_id, passenger_id, pickup_location_id, dropoff_location_id,
                   fare_amount, distance_km, status, requested_at)
VALUES (1, 1, 1, 2, 250.00, 8.5, 'completed', NOW());

INSERT INTO trips (driver_id, passenger_id, pickup_location_id, dropoff_location_id,
                   fare_amount, distance_km, status, requested_at)
VALUES (1, 1, 1, 2, 250.00, 8.5, 'completed', NOW());


SELECT count(*) from trips;

commit ;