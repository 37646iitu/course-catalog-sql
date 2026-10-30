-- Bonus 3: string concatenation versus a parameterized statement.

-- If this text came from string concatenation, the injected OR is SQL code
-- and makes the condition true for all six courses.
SELECT id, title
FROM courses
WHERE id = 'x' OR '1' = '1'
ORDER BY id;

-- A parameter is parsed as a value, never as part of the SQL statement.
DEALLOCATE ALL;
PREPARE course_by_id (text) AS
    SELECT id, title FROM courses WHERE id = $1;

EXECUTE course_by_id('x'' OR ''1''=''1');
EXECUTE course_by_id('api-design');

DEALLOCATE course_by_id;

