# SQL Assignment — Week 2

Pathao's data team has decided the flat `rides` table has to go — it's been causing duplicate
driver names, wasted storage, and update bugs. Your job: normalize it into a proper schema, then
answer the questions the different teams keep asking, this time with `JOIN`s instead of one giant
table.

Write your schema and migration in `schema.sql`, and your query answers in `week2_queries.sql` —
start from [`schema_template.sql`](schema_template.sql) and
[`week2_queries_template.sql`](week2_queries_template.sql).

## Reference schema — what you're building

This is the exact structure we built together in class
([`classqueryday2.sql`](../classqueryday2.sql)):

```sql
CREATE TABLE locations (
    location_id   SERIAL        PRIMARY KEY,
    city_name     VARCHAR(100)  NOT NULL UNIQUE
);

CREATE TABLE drivers (
    driver_id     SERIAL        PRIMARY KEY,
    name          VARCHAR(100)  NOT NULL
);

CREATE TABLE passengers (
    passenger_id  SERIAL        PRIMARY KEY,
    name          VARCHAR(100)  NOT NULL
);

CREATE TABLE payment_methods (
    payment_method_id SERIAL       PRIMARY KEY,
    name               VARCHAR(30) NOT NULL UNIQUE
);

CREATE TABLE trips (
    trip_id              SERIAL        PRIMARY KEY,
    driver_id            INTEGER       NOT NULL REFERENCES drivers(driver_id),
    passenger_id         INTEGER       NOT NULL REFERENCES passengers(passenger_id),
    pickup_location_id   INTEGER       NOT NULL REFERENCES locations(location_id),
    dropoff_location_id  INTEGER       NOT NULL REFERENCES locations(location_id),
    fare_amount          NUMERIC(10,2) NOT NULL CHECK (fare_amount > 0),
    distance_km           NUMERIC(6,2)  NOT NULL,
    status                VARCHAR(50)   NOT NULL CHECK (status IN ('completed','cancelled','no_show')),
    requested_at          TIMESTAMP     NOT NULL,
    completed_at          TIMESTAMP,
    rating                NUMERIC(2,1)  CHECK (rating BETWEEN 1.0 AND 5.0),
    payment_method_id     INTEGER       REFERENCES payment_methods(payment_method_id)
);
```

---

## Part 1 — Migration (DDL/DML)

1. Create the five tables above, in dependency order. You already have `rides` from Week 1 — no
   staging copy needed, we migrate straight out of it, same as `classqueryday2.sql`.
2. Populate `drivers` and `passengers` with `INSERT ... SELECT DISTINCT ... FROM rides`, cleaning
   each name with `INITCAP(TRIM(REGEXP_REPLACE(name, '\s+', ' ', 'g')))` — the same expression
   from class.

   > ⚠ **Casing/whitespace trap:** somewhere in the raw data, one driver's name shows up with a
   > double space in roughly half their rides (the same issue we saw with `'Anita Rai'` in
   > class). If you insert distinct names *without* cleaning them first, that driver splits into
   > two separate rows in `drivers` — and every query that groups or counts by driver will quietly
   > undercount them. Run `SELECT DISTINCT driver_name FROM rides WHERE driver_name LIKE '%  %'`
   > before you migrate to confirm you've found it.

3. Populate `locations` from the `UNION` of distinct `pickup_city` and `dropoff_city` values (same
   pattern as class).
4. Populate `payment_methods` from the distinct, non-null `payment_method` values.
5. Migrate `rides` into `trips`, using scalar subqueries to resolve each driver/passenger name and
   city name into its integer ID — same pattern as the `INSERT INTO trips` in `classqueryday2.sql`.
6. **Verify:** `SELECT COUNT(*) FROM trips` should equal `SELECT COUNT(*) FROM rides`. If it
   doesn't, something failed to match (usually the casing trap above) — find it before moving on.
7. As we did in class with `'Bishal Rijal'`, manually `INSERT` one extra driver directly into
   `drivers` with **no matching trip** — someone who just signed up but hasn't completed a ride
   yet. You'll need this row for Q2 below; without it, every driver in your migrated table already
   has at least one ride, and the anti-join query would trivially return nothing.

---

## Part 2 — Core queries

Write each as a numbered, commented query in `week2_queries.sql`. Every query must run against
your **normalized** tables — no querying the flat `rides` table for these answers.

### Q1 — Rides per driver (Basic · JOIN + GROUP BY)

Ops wants a leaderboard: each driver's name and their total **completed** ride count, ordered by
count descending.

### Q2 — Drivers with zero completed rides (Intermediate · anti-join)

Onboarding wants to know which drivers in the `drivers` table have **never completed a single
ride** — including drivers who signed up but haven't driven yet (the row you inserted in Part 1,
step 8). Write this as a `LEFT JOIN` where the matching row is missing, not as a subquery.

### Q3 — Average fare per pickup city (Intermediate · 3-table JOIN + AVG)

The expansion team wants each pickup city and the average fare of trips picked up there, ordered
by average fare descending.

### Q4 — Same-city driver/passenger trips (Basic–Intermediate · schema thinking)

A team lead asks: "Show me every trip where the driver and the passenger are from the same city."
Write the query you'd need to answer this — then, in a comment, answer: does the current schema
actually store a driver's or passenger's home city anywhere? If not, what table or column would
you need to add, and what would go wrong if you just added a `home_city` text column to `drivers`
and `passengers` directly instead of referencing `locations`?

*A partial query plus a clear written explanation of what's missing counts as a complete answer —
this question checks schema understanding as much as SQL.*

### Q5 — Re-run Week 1's revenue query (Basic · verification)

Re-write your Week 1 "total revenue from completed rides" query against the new schema. It must
match your Week 1 answer exactly — if it doesn't, your migration has a bug to find before
submitting.

---

## Part 3 — Extension queries

New patterns — not walked through live in class. Attempt all of them; a correct approach earns
partial credit even if the final answer isn't perfect.

### Q6 — WHERE and HAVING, together (Intermediate · WHERE + GROUP BY + HAVING)

Find drivers with **more than 280 completed rides** *and* **total revenue over NPR 140,000**. This
needs a row-level filter (`status = 'completed'`) applied *before* grouping, and two
aggregate-level filters applied *after* grouping — in the same query. Get the clause each filter
belongs in wrong and you'll get a different (and wrong) answer, not an error — so check your
result by hand against Q1's leaderboard.

### Q7 — Clean the phone numbers (Intermediate · REGEXP_REPLACE)

Don't touch the real `rides` table for this one — make a scratch copy first, same as the
`temp_rides` table from `day1_class_query.sql` (`SELECT * INTO TEMP temp_rides FROM rides;`). Add
a `phone_number` column to it (`ALTER TABLE`, same as class), and set a few rows to deliberately
messy values like `'98-4100 1234'` and `'986 123 4567'` (`UPDATE ... WHERE ...`). Then write a
`SELECT` that produces a clean, digits-only version of every phone number using `REGEXP_REPLACE`.
In a comment, explain why plain `REPLACE()` can't do this in one call the way
`REGEXP_REPLACE` can.

### Q8 — Prove the city data is clean (Intermediate · STRPOS / ILIKE)

A messy migration could leave a `city_name` in `locations` with leftover whitespace or two words
mashed together. Write a query that returns any location whose name contains a space, using
`STRPOS`. Then write a second version of the *same* check using `ILIKE` instead, so you can
compare the two techniques. If both return zero rows, that's your proof the migration is clean —
say so in a comment. If either returns rows, you've found a bug — fix your migration and re-run
Part 1's verification step.

### Q9 — Self-join: drivers who overlapped (Advanced · self-join + date functions)

Using a self-join on `trips` (join the table to itself with two different aliases), find pairs of
**different** drivers who picked up a rider from the **same pickup location** on the **same
calendar day**. This is a genuinely new pattern — you haven't joined a table to itself yet in this
course. Think about: what condition stops a driver from being paired with themselves, and what
stops each pair from appearing twice (once in each direction)?

### Q10 — Design challenge: promo codes (Design · no SQL required)

Product wants to add promo codes: a rider can apply a code like `SAVE10` to a trip, each code has
a discount percentage and an expiry date, and the same code can be used by many riders on many
different trips. Sketch (in words, or an ERD-style list) the table(s) you'd add and their keys.
Then explain: which normal-form problem would you create if you instead just added
`promo_code`, `discount_pct`, and `promo_expiry` as three new columns directly on `trips`?
