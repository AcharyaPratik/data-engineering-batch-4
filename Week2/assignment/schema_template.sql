-- Week 2 Schema & Migration — Answers
-- See sql_assignment.md Part 1 for the full instructions.
-- Rename this file to schema.sql before committing.


-- Step 1: CREATE TABLE statements, in dependency order
-- (locations, drivers, passengers, payment_methods, then trips)



-- Step 2: populate drivers and passengers (INSERT ... SELECT DISTINCT ... FROM rides, cleaned names)
-- Remember: INITCAP(TRIM(REGEXP_REPLACE(name, '\s+', ' ', 'g')))



-- Step 3: populate locations (UNION of pickup_city and dropoff_city, from rides)



-- Step 4: populate payment_methods (from rides)



-- Step 5: migrate rides into trips (scalar subqueries resolve each ID)



-- Step 6: verification query — COUNT(*) FROM trips should equal COUNT(*) FROM rides



-- Step 7: manually insert one driver with no matching trip (needed for Q2)
