# SQL Assignment — Week 3

Eight questions against your normalized schema from Week 2 (`drivers`, `passengers`, `locations`,
`payment_methods`, `trips`), a written stretch exercise, and one Python exercise. These aren't the
same queries we ran in class — each one asks you to apply the *concept* (transactions, indexing,
views, window functions) to a new scenario, or to extend a pattern from class one step further than
we took it live.

Write your SQL answers in `week3_queries.sql` — start from
[`week3_queries_template.sql`](week3_queries_template.sql).

---

## Part 1 — Transactions & ACID

### Q1 — A bulk update that must not partially apply (Basic–Intermediate · transactions + CHECK)

Finance asks you to apply a 10% fare correction to every **completed** trip for one driver:

```sql
UPDATE trips SET fare_amount = fare_amount * 1.1
WHERE driver_id = <your chosen driver> AND status = 'completed';
```

Before running the real correction, prove the all-or-nothing guarantee: inside a transaction, run
the correction above, then — in the *same* transaction — run one more `UPDATE` that would push a
single row's `fare_amount` negative (e.g. targeting one specific `trip_id` you pick). Postgres will
reject that second statement. Check whether the first (valid) correction is still visible from
another session, or query the row count/sum in a fresh statement after you `ROLLBACK` — confirm
**none** of the 10% corrections landed, not just the bad row.

Then run the correction properly — by itself, no bad statement — and `COMMIT`. Verify the fares
actually changed.

In a comment: why does "the whole batch either fully applies or not at all" matter for a
finance-facing operation like this? What would go wrong for the business if Postgres instead
applied each row of a transaction independently, keeping the good ones even when a later one fails?

### Q2 — FK delete-rule audit (Intermediate · introspection + design)

Before touching anything, find out what delete behavior is *actually* configured on `trips` right
now — don't assume. Use `\d trips` in `psql`, or query
`information_schema.referential_constraints` / `information_schema.key_column_usage`, to list the
`ON DELETE` rule for every foreign key on `trips`. Paste what you find as a comment.

Then prove it on rows you control (never delete real class data):

1. Insert a new driver, give them one trip, `DELETE` that driver, and verify what happened to their
   trip.
2. Insert a new payment method, attach it to one trip, `DELETE` that payment method, and verify
   what happened to that trip's `payment_method_id`.

In a comment: is the current rule on `driver_id` actually safe for a real ride-share company? What
financial/reporting record disappears the moment a driver row is deleted, and what would you use
instead (`ON DELETE RESTRICT`? a `deleted_at` soft-delete column and no real `DELETE` at all)?

---

## Part 2 — Query Plans & Indexing

> Confirm `SELECT count(*) FROM trips;` returns ~1,000,000 before starting.

### Q3 — Anti-join shootout: drivers with no trips (Intermediate–Advanced · EXPLAIN ANALYZE)

"Which drivers have never completed a trip?" can be written at least three ways. Write and run
`EXPLAIN ANALYZE` on all three, and paste all three plans as comments:

```sql
-- (a) NOT IN
SELECT * FROM drivers WHERE driver_id NOT IN (SELECT driver_id FROM trips);

-- (b) LEFT JOIN ... IS NULL
SELECT d.* FROM drivers d LEFT JOIN trips t ON d.driver_id = t.driver_id WHERE t.trip_id IS NULL;

-- (c) NOT EXISTS
SELECT * FROM drivers d WHERE NOT EXISTS (SELECT 1 FROM trips t WHERE t.driver_id = d.driver_id);
```

In a comment: which plan shape does each one produce (`Seq Scan`, `Hash Anti Join`,
`Nested Loop Anti Join`, a materialized subquery, etc.), and which was actually fastest on your
data? They don't have to be identical.

**Now the trap.** Run the same `NOT IN` pattern to find payment methods nobody has ever used:

```sql
SELECT * FROM payment_methods
WHERE payment_method_id NOT IN (SELECT payment_method_id FROM trips);
```

`trips.payment_method_id` is nullable — if even one row in `trips` has `payment_method_id IS NULL`,
this query silently returns **zero rows**, even if unused payment methods genuinely exist. Check
`SELECT count(*) FROM trips WHERE payment_method_id IS NULL;` to confirm you've hit the trap, then
rewrite the query with `LEFT JOIN ... IS NULL` or `NOT EXISTS` to get the correct answer. In a
comment, explain in your own words *why* `NOT IN` breaks the moment its subquery can return `NULL`
— what is `x NOT IN (1, 2, NULL)` actually evaluating to, and why does that make the whole `WHERE`
clause false for every row?

### Q4 — Index the fix (Intermediate · CREATE INDEX)

`payment_method_id` has no index yet. Run `EXPLAIN ANALYZE` on your corrected (non-`NOT IN`) query
from Q3 as a baseline, `CREATE INDEX` on `trips(payment_method_id)`, then re-run and paste both
plans. Did the scan type change? By roughly what factor did execution time move?

### Q5 — When *not* to index (Design · no new SQL required)

You now have indexes on `driver_id`, `status`, `(driver_id, status)`, and `payment_method_id`. In a
comment: what does an index cost you beyond disk space — what gets slower every time a row is
written? Given that, would you add an index on `trips.rating`? On `drivers.name`? Give a one-line
reason for each, thinking about how many distinct values each column has and how selective a
typical filter on it would be.

---

## Part 3 — Views

### Q6 — Driver performance summary (Intermediate–Advanced · aggregation view)

The class's `completed_trips_detail_view` was a row-level view — one output row per trip. Build a
**summary** view instead: `driver_performance_summary`, one row per driver, with:

- `driver_id`, `driver_name`
- `total_rides` — every trip ever requested by this driver, any status
- `total_completed_trips`, `total_cancelled_trips`
- `completion_rate` — `total_completed_trips / total_rides`, as a percentage, 1 decimal place
- `cancellation_rate` — same idea, for cancelled trips
- `total_revenue` — sum of `fare_amount` for completed trips only
- `avg_rating` — average rating across completed trips (2 decimals)

Handle the division-by-zero case: a driver with `total_rides = 0` shouldn't crash the view (should
that driver even appear here — depends how you write the join). Query your finished view, sorted by
`completion_rate` ascending, to surface your worst-performing drivers first.

---

## Part 4 — Window Functions

### Q7 — 7-day moving average fare (Advanced · window frame clause)

Everything we did with window functions in class used `PARTITION BY` with the *default* frame
(running total from the start of the partition). This one requires an explicit frame.

First, build a daily series: one row per calendar day, with that day's average `fare_amount` across
all completed trips (`GROUP BY date_trunc('day', requested_at)` or `::date`). Then, over that
daily series, compute a trailing 7-day moving average using:

```sql
AVG(daily_avg_fare) OVER (
    ORDER BY trip_date
    ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
)
```

In a comment: for the first 6 days of your series, the frame can't actually reach back 6 rows — what
does Postgres do instead, and is the resulting average still meaningful, or should those early rows
be treated as unreliable?

### Q8 — Ranking ties, using your own view (Intermediate · ROW_NUMBER / RANK / DENSE_RANK)

Query your `driver_performance_summary` view from Q6 and rank drivers by `total_revenue` using all
three ranking functions side by side: `ROW_NUMBER()`, `RANK()`, `DENSE_RANK()`, each
`ORDER BY total_revenue DESC`. Find (or construct, by adjusting a trip's `fare_amount` if the real
data has no exact tie) two drivers tied on `total_revenue`. In a comment: how do the three functions
handle that tie differently, and what rank number does the *next* driver after the tie get under
each one?

---

## Python Exercise — Transactional Batch Loader (P1)

Q1 proved the all-or-nothing guarantee from `psql`, one `BEGIN`/`ROLLBACK`/`COMMIT` at a time. This
exercise makes you enforce the same guarantee from application code, which is how it actually shows
up in a real pipeline — a script loading a batch of trips has to decide for itself what "roll back
the whole batch" means when *it*, not a human at a terminal, is the one running the transaction.

Complete [`transaction_loader.py`](transaction_loader.py). The connection boilerplate and
`INSERT` SQL are already provided — you write the body of `load_batch()`:

- Load a list of trip dicts into `trips` inside a **single transaction** (`conn.autocommit = False`)
- If any row fails, roll back the **entire batch** — no partial commits
- Log which row failed and why (use the `logger` already configured in the file)
- Return the number of rows loaded (`0` on failure)
- Never swallow the error silently — re-raise it after rolling back, so the caller knows the batch
  failed

Run it with `python transaction_loader.py` from `Week3/assignment/`. `main()` already runs two
tests for you:

1. A clean 5-row batch — should commit, `load_batch()` returns `5`
2. A batch where row 3 has `rating=99` (violates the `CHECK (rating BETWEEN 1.0 AND 5.0)`
   constraint on `trips`) — should roll back, `load_batch()` returns `0` (or raises, which `main()`
   catches)

The final log line reports `count_after - count_before` — it should read exactly `+5`: the good
batch landed, the bad batch left no trace at all, not even the two valid-looking rows that came
before row 3 in that batch. That's the same principle as Q1, proven from Python instead of `psql`.

---

## Stretch Exercise — KPI, Metric, Dimension (Conceptual · no SQL required)

These three words get used interchangeably by non-technical stakeholders, but they mean different
things, and knowing the difference changes how you design a view like `driver_performance_summary`.

In a comment block, in your own words:

1. Define **metric**, **dimension**, and **KPI** — one or two sentences each.
2. Go through every column in your `driver_performance_summary` view from Q6 and classify each one
   as a metric or a dimension. (Hint: a dimension is something you slice or group by; a metric is a
   number you measure.)
3. Of the metrics in that view, which ones would you argue are actually **KPIs** for a ride-share
   company specifically — i.e. ones leadership would set a target against and track over time —
   versus which are just useful numbers with no target attached? There's no single right answer
   here; justify your choice.

---

## What "done" looks like

`week3_queries.sql` runs top-to-bottom against your `ride_share` database without manual
intervention (aside from the `EXPLAIN ANALYZE` outputs, which are pasted as comments, not
re-executed). Every question has a one-line comment stating what it answers, and every question
that asks for a written explanation has that explanation as a comment directly beneath the query.
`transaction_loader.py` runs end-to-end and its final log line reports `+5`.

## Grading checklist

- [ ] Q1 — bad statement proven to abort the whole transaction, valid correction committed separately, business-impact explanation given
- [ ] Q2 — actual FK rules looked up (not assumed), CASCADE and SET NULL each demonstrated on your own rows, design tradeoff answered
- [ ] Q3 — all three anti-join plans pasted and compared, NULL-trap reproduced on `payment_method_id`, fixed, and explained
- [ ] Q4 — index created, before/after EXPLAIN ANALYZE pasted
- [ ] Q5 — index cost and candidate reasoning answered
- [ ] Q6 — `driver_performance_summary` view correct, rates computed correctly, zero-ride case handled
- [ ] Q7 — daily series built correctly, 7-day frame applied correctly, early-row behavior explained
- [ ] Q8 — all three ranking functions shown together on a real or constructed tie, difference explained
- [ ] P1 — `load_batch()` implemented: single transaction, full rollback on any failure, error logged with row context, re-raises, connection still usable after
- [ ] Stretch — KPI/metric/dimension defined and applied to every column of the Q6 view
