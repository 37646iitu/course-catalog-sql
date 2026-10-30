-- Bonus 2: compare a lost update with an atomic increment.
-- Everything is rolled back, so the main seed data remains unchanged.

BEGIN;

UPDATE courses SET likes = 11 WHERE id = 'api-design';

-- Two clients both read 11 and both write the value they computed: 12.
SELECT likes AS both_clients_read FROM courses WHERE id = 'api-design';
UPDATE courses SET likes = 12 WHERE id = 'api-design';
UPDATE courses SET likes = 12 WHERE id = 'api-design';
SELECT likes AS lost_update_result FROM courses WHERE id = 'api-design';

-- Computing inside UPDATE preserves both increments.
UPDATE courses SET likes = 11 WHERE id = 'api-design';
UPDATE courses SET likes = likes + 1 WHERE id = 'api-design';
UPDATE courses SET likes = likes + 1 WHERE id = 'api-design';
SELECT likes AS atomic_increment_result FROM courses WHERE id = 'api-design';

ROLLBACK;

