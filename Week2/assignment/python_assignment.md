# Python Assignment — Week 2

## Required: query_drivers.py

Connect to the `ride_share` database with `psycopg2`, run Q1 (rides per driver) against your
normalized schema, `fetchall()` the rows, and print them as a readable formatted table — no
`pandas`.

Start from [`query_drivers_starter.py`](query_drivers_starter.py), which already has the
`.env`-based connection setup (same pattern as [`query.py`](../query.py)) and logging.

### Requirements

- Load credentials with `python-dotenv` — no hardcoded connection details
- Use the `logging` setup already in the starter (`INFO` level, timestamped, file + console) — no
  bare `print()` for status messages, only for the actual report rows
- Run the query inside a `with conn.cursor() as cur:` block
- Wrap the connection and the query in `try/except` — on failure, log the error and `raise`. Don't
  swallow exceptions; a script that silently prints nothing on a broken query is worse than one
  that crashes loudly
- Print each row formatted, not a raw tuple dump — e.g.:

  ```
  Rajan Pandey    | completed rides:  307
  Nisha Bista     | completed rides:  300
  ```

  rather than `('Rajan Pandey', 307)`

- Close the connection when the script finishes, even if the query fails partway through

---

## Extensions: extensions.py

Three independent exercises. One file or three, your choice — start from
[`extensions_starter.py`](extensions_starter.py).

### P1. Parameterized query function

*psycopg2 · SQL parameters · injection safety*

Write `get_rides_for_driver(cur, driver_name)` that returns every trip for the given driver name
(case-insensitive). Use a parameterized query — the `%s` placeholder passed as a second argument
to `cur.execute()` — **not** an f-string or `.format()` to build the SQL. In a short comment,
explain in your own words what could go wrong if you built this query with string concatenation
instead.

### P2. Generic table printer

*cursor.description · dynamic columns*

Write `run_and_print(cur, sql)` that accepts **any** `SELECT` query as a string, executes it, and
prints the results as an aligned table with column headers — using `cur.description` to get the
column names dynamically, rather than hardcoding them per-query. This is the same mechanism
`pandas.read_sql()` uses internally. Prove it works unmodified against Q1, Q3, and Q6 from the SQL
assignment (three very differently-shaped result sets).

### P3. Handle a bad insert gracefully

*try/except · psycopg2 errors · transactions*

Write a script that attempts to insert a trip with a `driver_id` that doesn't exist in `drivers`
(this should fail the foreign key constraint). Catch the resulting `psycopg2` exception, print a
friendly error message instead of letting the program crash, and call `conn.rollback()` so the
connection is left usable afterward — prove it's usable by running a normal `SELECT` right after
and getting a real result back.

---

## What "done" looks like

Running `python query_drivers.py` against your migrated database prints a clearly labeled,
formatted leaderboard, and `pipeline.log` records each step. Running your extensions script(s)
demonstrates all three of P1–P3 working, including the rollback-then-recover in P3.

## Grading checklist

- [ ] `query_drivers.py` connects via `.env`/`python-dotenv`, no hardcoded credentials
- [ ] Logging configured — no bare `print()` for status/progress
- [ ] Query runs inside `with conn.cursor() as cur:`, wrapped in `try/except` that re-raises
- [ ] Output formatted per-row, not a raw tuple dump
- [ ] Connection closed at the end, even on failure
- [ ] P1 uses a parameterized query (`%s` + tuple), not string formatting, plus the explanation comment
- [ ] P2's printer uses `cur.description` and works unmodified on at least 3 different queries
- [ ] P3 catches the FK violation, prints a friendly message, calls `conn.rollback()`, and the
      connection is demonstrably still usable afterward
