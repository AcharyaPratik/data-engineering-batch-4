-- Week 3 Queries — Answers
-- Fill in each query below. See sql_assignment.md for the full scenario text.
-- Rename this file to week3_queries.sql before committing.


-- Q1 — A bulk update that must not partially apply (Basic–Intermediate · transactions + CHECK)
-- Transaction: valid 10% fare correction + one deliberately bad UPDATE -> whole batch rejected
-- Then: correction run alone, COMMIT, verified
-- Comment: why does all-or-nothing matter for a finance-facing bulk update?



-- Q2 — FK delete-rule audit (Intermediate · introspection + design)
-- \d trips or information_schema query -> paste actual ON DELETE rules found
-- Your own driver + trip -> DELETE driver -> verify result
-- Your own payment method + trip -> DELETE payment method -> verify result
-- Comment: is CASCADE on driver_id safe for a real company? what would you use instead?



-- Q3 — Anti-join shootout: drivers with no trips (Intermediate–Advanced · EXPLAIN ANALYZE)
-- (a) NOT IN, (b) LEFT JOIN ... IS NULL, (c) NOT EXISTS -- EXPLAIN ANALYZE all three, paste plans
-- Comment: plan shape of each, which was fastest
-- NULL trap: NOT IN on payment_method_id (nullable) -> reproduce, fix with LEFT JOIN/NOT EXISTS
-- Comment: why does NOT IN break when its subquery can return NULL?



-- Q4 — Index the fix (Intermediate · CREATE INDEX)
-- EXPLAIN ANALYZE baseline on corrected Q3 query, CREATE INDEX on payment_method_id, re-run
-- Paste both plans



-- Q5 — When not to index (Design · no new SQL required)
-- Comment only: cost of an index beyond disk space; would you index rating / drivers.name?



-- Q6 — Driver performance summary (Intermediate–Advanced · aggregation view)
-- CREATE VIEW driver_performance_summary AS ...
-- driver_id, driver_name, total_rides, total_completed_trips, total_cancelled_trips,
-- completion_rate, cancellation_rate, total_revenue, avg_rating
-- SELECT from it ordered by completion_rate ascending



-- Q7 — 7-day moving average fare (Advanced · window frame clause)
-- Daily series: one row per day, avg fare_amount for completed trips that day
-- AVG(...) OVER (ORDER BY trip_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)
-- Comment: what happens for the first 6 days of the series, and is that average meaningful?



-- Q8 — Ranking ties, using your own view (Intermediate · ROW_NUMBER / RANK / DENSE_RANK)
-- From driver_performance_summary, rank by total_revenue with all three functions side by side
-- Comment: how do the three handle a tie differently, what does the next driver get under each?



-- Stretch — KPI, Metric, Dimension (Conceptual · no SQL required)
-- Comment only:
-- 1. Define metric, dimension, KPI in your own words
-- 2. Classify every column of driver_performance_summary as metric or dimension
-- 3. Which metrics in that view would you argue are actual KPIs for a ride-share company, and why?
