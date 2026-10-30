-- Bonus 5: add a rule to a live table without recreating it.
-- DROP IF EXISTS makes the teaching experiment repeatable.

ALTER TABLE students
DROP CONSTRAINT IF EXISTS students_email_format;

ALTER TABLE students
ADD CONSTRAINT students_email_format
CHECK (position('@' IN email) > 1);

SELECT conname, pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'students'::regclass
  AND conname = 'students_email_format';
