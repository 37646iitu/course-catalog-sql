-- Bonus 1: migrate the flat registrations rows into normalized tables.
-- Run schema.sql in norm_demo before this file.

INSERT INTO students (name, email)
SELECT student_name, student_email
FROM registrations
GROUP BY student_name, student_email
ORDER BY min(id);

INSERT INTO courses (id, title, description, credits)
SELECT DISTINCT course_id, course_title, '', credits
FROM registrations;

INSERT INTO enrollments (course_id, student_id)
SELECT r.course_id, s.id
FROM registrations r
JOIN students s ON s.email = r.student_email
ORDER BY r.id;

SELECT s.name, c.title
FROM enrollments e
JOIN students s ON s.id = e.student_id
JOIN courses c ON c.id = e.course_id
ORDER BY e.id;

SELECT
    (SELECT count(*) FROM courses) AS courses,
    (SELECT count(*) FROM students) AS students,
    (SELECT count(*) FROM enrollments) AS enrollments;

