# Python Assignment — Week 1

Write a script, `db_report.py`, that connects to the `ride_share` database and prints the
results of the **three aggregation questions** from the SQL assignment (Q6, Q7, Q8) — revenue by
pickup city, drivers who qualify for the loyalty bonus, and ride outcomes by status.

Start from [`db_report_starter.py`](db_report_starter.py), which already has the logging setup
and connection handling from the [Python pre-read](../python_preread.html) — you fill in the
three queries and the printing.

## Requirements

- Connect using `psycopg2` and a `DB_CONFIG` dict — don't hardcode the connection call
- Use the `logging` setup from the pre-read (`INFO` level, timestamped, file + console) — no bare
  `print()` for status messages, only for the actual report rows
- Every query runs inside a `with conn.cursor() as cur:` block
- Wrap the connection and each query in `try/except` — on failure, log the error and `raise`.
  **Do not swallow exceptions** — a script that silently prints nothing on a broken connection is
  worse than one that crashes loudly
- For each of the 3 aggregation queries: run it, `fetchall()` the rows, and print each row in a
  readable format — not a raw tuple dump. For example:

  ```
  Kathmandu       | rides:  842 | revenue: NPR 412,530.00 | avg fare: NPR 489.94
  Pokhara         | rides:  511 | revenue: NPR 198,220.50 | avg fare: NPR 387.90
  ```

  rather than:

  ```
  ('Kathmandu', 842, Decimal('412530.00'), Decimal('489.94'))
  ```

- Close the connection when the script finishes, even if a query fails partway through

## What "done" looks like

Running `python db_report.py` against your local `ride_share` database prints three clearly
labeled sections — one per aggregation question — with readable rows, and `pipeline.log` records
each step (connecting, running each query, row counts, completion).

## Grading checklist

- [ ] Connects using `psycopg2` with a `DB_CONFIG` dict
- [ ] Logging configured per the pre-read pattern — no bare `print()` for status/progress
- [ ] All three queries match Q6/Q7/Q8 from the SQL assignment
- [ ] Each query is wrapped in `try/except`, re-raises on failure, no swallowed exceptions
- [ ] Cursors used via `with conn.cursor() as cur:`
- [ ] Output is formatted per-row, not a raw tuple dump
- [ ] Connection is closed at the end
