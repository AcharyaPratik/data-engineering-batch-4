# Week 2 Assignment

Two parts, building on the same `rides` table from Week 1 (already loaded in your `ride_share`
database — no new CSV load needed):

1. **[SQL](sql_assignment.md)** — normalize `rides` into a proper schema (mirroring what we built
   live in class), then answer 9 scenario-based queries plus a written design question, covering
   everything from the [normalization walkthrough](../normalization_exercise.html),
   [GROUP BY under the hood](../group_by_under_the_hood.html),
   [string functions cheat sheet](../week2_string_functions_cheatsheet.html), and
   [joins pre-read](../week2_joins_preread.html) — plus a few extension questions that go a step
   beyond what class covered.
2. **[Python](python_assignment.md)** — a required script that connects to the database and
   prints Q1's results as a formatted table, plus three extension exercises (parameterized
   queries, a generic result printer, and graceful error handling).

Our two class sessions ([`day1_class_query.sql`](../day1_class_query.sql),
[`classqueryday2.sql`](../classqueryday2.sql)) worked through this exact migration live — lean on
them as worked examples when you get stuck, but don't just copy-paste; the point is to rebuild it
yourself and understand each step.

## Setup

```bash
pip install -r ../requirements.txt
```

Use the same `python-dotenv` + `.env` pattern from [`query.py`](../query.py) for your database
credentials (`DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`) — don't hardcode
credentials in any script you submit.

## What to submit

- `schema.sql` — `CREATE TABLE` statements in dependency order, plus the migration `INSERT`
  statements that populate them from `rides`
- `week2_queries.sql` — Q1–Q9, each preceded by a one-line comment stating what it answers (Q10 is
  a written answer only — a comment block at the bottom of this file, or a short `notes.md`)
- `query_drivers.py` — required Python script
- `extensions.py` — P1, P2, P3 (one file or three, your choice)

Start from the `*_template` files in this folder.

## How to submit

Same workflow as the [Git & GitHub pre-read](../../Week1/git_github_preread.html):

```bash
git checkout main
git pull upstream main
git checkout -b week2-assignment

# ... fill in schema.sql, week2_queries.sql, query_drivers.py, extensions.py ...

git add Week2/assignment/schema.sql Week2/assignment/week2_queries.sql \
        Week2/assignment/query_drivers.py Week2/assignment/extensions.py
git commit -m "Complete week 2 SQL and Python assignment"
git push -u origin week2-assignment
```

Then open a pull request **on your own fork** — base: `main`, compare: `week2-assignment` — and
share the link with your instructor. Submit before the Week 3 session begins.
