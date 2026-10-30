# Course Catalog Database — Lab 6

PostgreSQL schema for a small course catalog. The project demonstrates relational
modeling, integrity constraints, joins, transactions, and index analysis without
changing the existing frontend or API repositories.

## Repository structure

```text
course-catalog-db/
├── schema.sql
├── seed.sql
├── queries.sql
├── README.md
└── experiments/
    └── idx_data.sql
```

## Requirements

- PostgreSQL 16 or newer
- `psql` command-line client

## Database setup

Run the administrative commands as a PostgreSQL superuser:

```sql
CREATE ROLE catalog_app WITH LOGIN PASSWORD 'change-me';
CREATE DATABASE course_catalog OWNER catalog_app;
```

Set the password for the current terminal, then create and populate the schema:

```bash
export PGPASSWORD='change-me'
psql -v ON_ERROR_STOP=1 -U catalog_app -d course_catalog -f schema.sql
psql -v ON_ERROR_STOP=1 -U catalog_app -d course_catalog -f seed.sql
psql -v ON_ERROR_STOP=1 -U catalog_app -d course_catalog -f queries.sql
```

PowerShell equivalent:

```powershell
$env:PGPASSWORD = 'change-me'
psql -v ON_ERROR_STOP=1 -U catalog_app -d course_catalog -f schema.sql
psql -v ON_ERROR_STOP=1 -U catalog_app -d course_catalog -f seed.sql
psql -v ON_ERROR_STOP=1 -U catalog_app -d course_catalog -f queries.sql
```

`schema.sql` drops the three lab tables before recreating them, so the setup can
be repeated. `queries.sql` rolls back its example writes and is also repeatable.

Verify the seeded row counts:

```sql
SELECT 'courses' AS table_name, count(*) FROM courses
UNION ALL
SELECT 'students', count(*) FROM students
UNION ALL
SELECT 'enrollments', count(*) FROM enrollments;
```

Expected counts are 6 courses, 3 students, and 6 enrollments.

## Entity-relationship diagram

```mermaid
erDiagram
    COURSES ||--o{ ENROLLMENTS : has
    STUDENTS ||--o{ ENROLLMENTS : makes

    COURSES {
        text id PK
        text title
        text description
        integer credits
        boolean is_elective
        integer likes
    }

    STUDENTS {
        bigint id PK
        text name
        text email UK
    }

    ENROLLMENTS {
        bigint id PK
        text course_id FK
        bigint student_id FK
        timestamptz enrolled_at
    }
```

`enrollments` is the junction table that implements the many-to-many relationship
between students and courses. Its unique constraint on `(course_id, student_id)`
prevents the same student from enrolling in the same course twice.

## Design decisions

### Course and student identifiers

Course IDs are `text` slugs such as `modern-frontend`. They are stable,
human-readable, and suitable for URLs. Student IDs are generated `bigint` values
because students do not have a natural public identifier and automatic numeric
keys make inserts and joins straightforward.

### Referential actions

- `enrollments.course_id` uses `ON DELETE RESTRICT`. A course with enrollment
  history cannot be deleted accidentally; the application must handle that case.
- `enrollments.student_id` uses `ON DELETE CASCADE`. Removing a student also
  removes rows that only describe that student's enrollments.

The course itself is never deleted by either action.

### Data types

- `timestamptz` stores one absolute moment and renders it in the session time
  zone. Plain `timestamp` has no time-zone context and is easier to misinterpret.
- PostgreSQL `text` and `varchar(n)` have the same general storage and performance
  characteristics. `text` is used where the domain has no genuine business
  maximum; explicit `CHECK` constraints express the limits that matter.
- `integer` is appropriate for credits and likes, while `bigint` identity keys
  leave ample space for generated identifiers.

## Query catalogue

`queries.sql` contains examples for:

1. filtering, sorting, and paginating courses;
2. retrieving a course by ID, including the not-found case;
3. incrementing likes;
4. creating an enrollment;
5. listing enrollments with student and course names;
6. counting enrollments for every course;
7. finding courses with no enrollments;
8. finding students enrolled in more than one course.

The statistics query uses `count(e.id)`, not `count(*)`, so a course with no
matching enrollment receives a count of zero after the `LEFT JOIN`.

## Constraint violation log

The following cases demonstrate that correctness does not depend only on the
application. PostgreSQL rejects invalid writes even when SQL is executed directly.

| Test case | SQLSTATE | Constraint or column | Suggested API status |
|---|---:|---|---:|
| Course title is `NULL` | `23502` | `courses.title` (`NOT NULL`) | `422` |
| Course credits are `0` | `23514` | `courses_credits_check` | `422` |
| Course likes are `-1` | `23514` | `courses_likes_check` | `422` |
| Student name has one character | `23514` | `students_name_check` | `422` |
| Student email already exists | `23505` | `students_email_key` | `409` |
| Course ID already exists | `23505` | `courses_pkey` | `409` |
| Enrollment pair already exists | `23505` | `enrollments_course_id_student_id_key` | `409` |
| Course ID does not exist | `23503` | `enrollments_course_id_fkey` | `404` |
| Student ID does not exist | `23503` | `enrollments_student_id_fkey` | `404` |
| Delete a course that still has enrollments | `23503` on PostgreSQL 16/17 (`23001` may be used in PostgreSQL 18) | `enrollments_course_id_fkey` | `409` |

Deleting seeded student Daniyar Bekov demonstrates `ON DELETE CASCADE`:

```sql
BEGIN;
SELECT count(*) FROM enrollments; -- 6
DELETE FROM students WHERE email = 'daniyar@example.com';
SELECT count(*) FROM enrollments; -- 3
ROLLBACK;
SELECT count(*) FROM enrollments; -- 6 again
```

### Why validation is duplicated in Pydantic and PostgreSQL

Pydantic gives API clients fast, readable `422 Unprocessable Entity` responses
before a query is sent. Database constraints remain essential because data can
also be written by scripts, migrations, administrative tools, other services, or
concurrent requests. Pydantic improves the interface; PostgreSQL is the final
authority for stored data. A backend should translate known SQLSTATE values such
as unique (`23505`), foreign-key (`23503`), and check (`23514`) violations into
stable HTTP responses instead of returning an unexplained server error.

## Index experiment

`experiments/idx_data.sql` adds 500 courses, 20,000 students, and 50,000
enrollments. Use a separate database so the lab seed counts remain unchanged:

```sql
CREATE DATABASE course_catalog_idx OWNER catalog_app;
```

```bash
psql -v ON_ERROR_STOP=1 -U catalog_app -d course_catalog_idx -f schema.sql
psql -v ON_ERROR_STOP=1 -U catalog_app -d course_catalog_idx -f experiments/idx_data.sql
```

For the before measurement, remove the explicit foreign-key index and execute the
same query several times:

```sql
DROP INDEX enrollments_student_id_idx;
ANALYZE enrollments;
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM enrollments WHERE student_id = 12345;
```

A representative plan scans the complete table:

```text
Seq Scan on enrollments
  Filter: (student_id = 12345)
  Rows Removed by Filter: about 49,997
Execution Time: about 3.6 ms
```

Create the index and repeat the exact query:

```sql
CREATE INDEX enrollments_student_id_idx ON enrollments (student_id);
ANALYZE enrollments;
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM enrollments WHERE student_id = 12345;
```

A representative indexed plan is:

```text
Bitmap Heap Scan on enrollments
  Recheck Cond: (student_id = 12345)
  -> Bitmap Index Scan on enrollments_student_id_idx
       Index Cond: (student_id = 12345)
Execution Time: a few hundredths of a millisecond
```

Exact costs and timings depend on PostgreSQL version, hardware, caching, and data
distribution. The important change is from examining roughly 50,000 rows to
locating only matching index entries.

| Measurement | Plan | Rows inspected | Typical time |
|---|---|---:|---:|
| Before index | Sequential scan | about 50,000 | about 3.6 ms |
| After index | Bitmap index/heap scan | matching rows | hundredths of a millisecond |

PostgreSQL automatically indexes primary keys and unique constraints, but it does
not automatically index the referencing side of a foreign key. Therefore:

- `students.email` uses the index created by `UNIQUE`;
- `enrollments.course_id` can use the unique `(course_id, student_id)` index
  because `course_id` is its first column;
- `enrollments.student_id` needs its own index because it is the second column of
  that composite index;
- a query on the six-row `courses` table may still choose a sequential scan even
  though a primary-key index exists, because reading the small table is cheaper.

The student index speeds up enrollment listings and helps PostgreSQL locate the
dependent rows that must be removed during a cascaded student deletion.

## Transaction experiment

### Failed transaction is atomic

```sql
BEGIN;

INSERT INTO students (name, email)
VALUES ('Transaction Student', 'transaction@example.com');

INSERT INTO enrollments (course_id, student_id)
VALUES ('course-does-not-exist',
        (SELECT id FROM students WHERE email = 'transaction@example.com'));

-- PostgreSQL now reports that the current transaction is aborted.
SELECT * FROM students WHERE email = 'transaction@example.com';

ROLLBACK;

-- Returns zero rows: the first successful insert was rolled back too.
SELECT * FROM students WHERE email = 'transaction@example.com';
```

The foreign-key failure aborts the transaction. Until `ROLLBACK`, PostgreSQL
refuses subsequent statements. No partial result survives.

### Visibility between two connections

In connection A, start a transaction and insert a student plus an enrollment, but
do not commit yet. A query from connection B returns zero matching rows because
the default `READ COMMITTED` isolation level hides uncommitted changes. After
connection A runs `COMMIT`, connection B sees both rows. The student and their
enrollment become visible as one atomic change, never as a half-completed state.

## Self-review checklist

- [x] Three related tables with appropriate primary and foreign keys
- [x] Required `NOT NULL`, `DEFAULT`, `CHECK`, and `UNIQUE` constraints
- [x] `RESTRICT` for course deletion and `CASCADE` for student deletion
- [x] Seed data contains 6 courses, 3 students, and 6 enrollments
- [x] API-oriented queries include joins, aggregation, pagination, and bonuses
- [x] Example writes in `queries.sql` end with `ROLLBACK`
- [x] Foreign-key index experiment includes before/after methodology
- [x] Transaction atomicity and visibility are documented
- [x] Mermaid ER diagram and design decisions are documented
- [x] Repository contains at least six meaningful commits
