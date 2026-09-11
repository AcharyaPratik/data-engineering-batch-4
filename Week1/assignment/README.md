# Week 1 Assignment

Two parts, both against the same `rides` table you already know from class:

1. **[SQL](sql_assignment.md)** — 12 scenario-based questions, basic → intermediate, covering everything from the [SQL pre-read](../sql_preread.html) (DDL, DML, DQL, NULL handling, aggregation, GROUP BY, HAVING), plus 2 subquery questions that go a step beyond it.
2. **[Python](python_assignment.md)** — a script that connects to the database and prints the results of the three aggregation questions from Part 1, following the patterns from the [Python pre-read](../python_preread.html).

## Dataset

Everything runs against the `rides` table (`ride_share` database), created in `Week1/create_ride.sql` and loaded from `Week1/rides.csv`. If your local database doesn't have it yet:

```bash
psql -U postgres -d ride_share -f Week1/create_ride.sql
psql -U postgres -d ride_share -c "\copy rides FROM 'Week1/rides.csv' CSV HEADER NULL ''"
```

## What to submit

- `sql_answers.sql` — your 12 SQL answers, filled in from `sql_answers_template.sql`
- `db_report.py` — your Python script, filled in from `db_report_starter.py`

Both files live in this `Week1/assignment/` folder.

## How to submit

Same workflow as the [Git & GitHub pre-read](../git_github_preread.html):

```bash
git checkout main
git pull upstream main            # make sure you're on the latest material
git checkout -b week1-assignment

# ... fill in sql_answers.sql and db_report.py ...

git add Week1/assignment/sql_answers.sql Week1/assignment/db_report.py
git commit -m "Complete week 1 SQL and Python assignment"
git push -u origin week1-assignment
```

Then open a pull request **on your own fork** — base: `main`, compare: `week1-assignment` — and share the link with your instructor.
