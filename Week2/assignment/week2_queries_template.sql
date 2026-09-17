-- Week 2 Queries — Answers
-- Fill in each query below. See sql_assignment.md for the full scenario text.
-- Rename this file to week2_queries.sql before committing.


-- Q1 — Rides per driver (Basic · JOIN + GROUP BY)
-- name, total_rides — completed rides only, ordered by total_rides desc



-- Q2 — Drivers with zero completed rides (Intermediate · anti-join)
-- name of every driver with no completed trip (LEFT JOIN, not a subquery)



-- Q3 — Average fare per pickup city (Intermediate · 3-table JOIN + AVG)
-- city_name, avg_fare (2 decimals) — ordered by avg_fare desc



-- Q4 — Same-city driver/passenger trips (Basic–Intermediate · schema thinking)
-- Partial query + written explanation (as a comment) of what the schema is missing



-- Q5 — Re-run Week 1's revenue query (Basic · verification)
-- Total revenue from completed rides — must match your Week 1 answer



-- Q6 — WHERE and HAVING, together (Intermediate · WHERE + GROUP BY + HAVING)
-- Drivers with > 280 completed rides AND total revenue > NPR 140,000



-- Q7 — Clean the phone numbers (Intermediate · REGEXP_REPLACE)
-- Scratch copy (TEMP temp_rides, same as day1_class_query.sql) + ALTER TABLE + UPDATE to add
-- messy phone_number values, then a digits-only SELECT
-- Comment: why REPLACE() alone can't do this



-- Q8 — Prove the city data is clean (Intermediate · STRPOS / ILIKE)
-- Version 1: STRPOS
-- Version 2: ILIKE



-- Q9 — Self-join: drivers who overlapped (Advanced · self-join + date functions)
-- Pairs of different drivers, same pickup location, same calendar day



-- Q10 — Design challenge: promo codes (Design · no SQL required)
-- Written answer only — table(s), keys, and the normal-form problem with the flat-column approach
