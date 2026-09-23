# Week 3 Assignment

Against the same normalized schema (`drivers`, `passengers`, `locations`, `payment_methods`,
`trips`) you built in Week 2 — no new migration needed. The `trips` table now holds 1,000,000 rows
(loaded by the instructor) specifically so index effects in `EXPLAIN ANALYZE` are visible instead
of theoretical.

**[SQL](sql_assignment.md)** — 8 questions, a written stretch exercise, and one Python exercise.
These are **not** the same queries we ran in class — each one takes a concept from
[`day1 query.sql`](../day1%20query.sql) / [`day2query.sql`](../day2query.sql) (transactions &
ACID, indexing, views, window functions) and applies it to a new scenario:

- a bulk-update transaction that has to be all-or-nothing, plus auditing the FK delete rules
  instead of just being told them
- an **anti-join shootout** — `NOT IN` vs `LEFT JOIN ... IS NULL` vs `NOT EXISTS` for "drivers with
  no trips," including the classic `NOT IN` + `NULL` trap
- a **summary/KPI view** (`driver_performance_summary`) with completion rate, cancellation rate,
  and revenue per driver — not just a row-level detail view like class built
- a **7-day moving average** on fares, which needs an explicit window frame (`ROWS BETWEEN`), a
  step beyond the default-frame running totals from class
- a **Python exercise** ([`transaction_loader.py`](transaction_loader.py)) — enforce the same
  all-or-nothing guarantee from Q1, this time from `psycopg2` application code instead of `psql`
- a written stretch exercise on **KPI vs. metric vs. dimension**, applied to the view you build

Lean on the class files as worked examples for syntax, but don't copy-paste — none of the questions
can be answered by pasting a class query unchanged.

## Setup

You should already have the 1M-row `trips` table from class. If `SELECT count(*) FROM trips;`
comes back with anything less than ~1,000,000, ask your instructor before starting Part 2 — the
index timing questions won't show a meaningful difference on a small table.

```bash
pip install -r ../requirements.txt
```

Use the same `python-dotenv` + `.env` pattern from Week 1/2 for your database credentials —
`transaction_loader.py`'s `load_dotenv()` call searches upward from its own folder, so your
existing `Week3/.env` is found automatically even though the script now lives one level down in
`Week3/assignment/`.

## What to submit

- `week3_queries.sql` — Q1–Q8 plus the stretch exercise, each preceded by a one-line comment
  stating what it answers. Every question that asks you to also *explain* something needs that
  explanation as a comment directly under the query — don't split it into a separate file.
- For Q3/Q4/Q7, paste the actual `EXPLAIN ANALYZE` output you got (as a comment block under the
  query) — we're checking that you ran it against the real 1M-row table, not just that the SQL is
  syntactically right.
- `transaction_loader.py` — your completed `load_batch()` implementation

Start from [`week3_queries_template.sql`](week3_queries_template.sql).

## How to submit

Same workflow as previous weeks:

```bash
git checkout main
git pull upstream main
git checkout -b week3-assignment

# ... fill in week3_queries.sql and transaction_loader.py ...

git add Week3/assignment/week3_queries.sql Week3/assignment/transaction_loader.py
git commit -m "Complete week 3 assignment"
git push -u origin week3-assignment
```

Then open a pull request **on your own fork** — base: `main`, compare: `week3-assignment` — and
share the link with your instructor. Submit before the Week 4 session begins.
