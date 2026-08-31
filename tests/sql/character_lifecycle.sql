DROP PROCEDURE IF EXISTS up_test_assert;

DELIMITER //
CREATE PROCEDURE up_test_assert(IN condition_value BOOLEAN, IN failure_message VARCHAR(128))
BEGIN
    IF condition_value IS NULL OR condition_value = FALSE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = failure_message;
    END IF;
END//
DELIMITER ;

SET @account_id = '00000000-0000-0000-0000-000000000001';
SET @character_id = '00000000-0000-0000-0000-000000000002';

DELETE FROM up_core_passport_allocations WHERE character_id = @character_id;
DELETE FROM up_core_characters WHERE id = @character_id;
DELETE FROM up_core_accounts WHERE id = @account_id;

INSERT INTO up_core_accounts (id, status) VALUES (@account_id, 'active');
INSERT INTO up_core_character_slots (account_id, used) VALUES (@account_id, 2);

UPDATE up_core_character_slots SET used = used + 1 WHERE account_id = @account_id AND used < 3;
CALL up_test_assert(ROW_COUNT() = 1, 'third character slot was not reserved');

UPDATE up_core_character_slots SET used = used + 1 WHERE account_id = @account_id AND used < 3;
CALL up_test_assert(ROW_COUNT() = 0, 'character limit was exceeded');

INSERT INTO up_core_passport_allocations (character_id) VALUES (@character_id);
SET @passport = LAST_INSERT_ID();
CALL up_test_assert(@passport >= 1000, 'passport allocation is outside the public range');

INSERT INTO up_core_characters
    (id, account_id, passport, first_name, last_name, birth_date, metadata, created_at, updated_at)
VALUES
    (@character_id, @account_id, @passport, 'Ana', 'Silva', '2000-02-29', JSON_OBJECT(), '2026-01-01', '2026-01-01');

UPDATE up_core_characters
   SET status = 'deleted', deleted_at = CURRENT_TIMESTAMP(6), version = version + 1
 WHERE id = @character_id AND status = 'active';
CALL up_test_assert(ROW_COUNT() = 1, 'character was not soft deleted');
CALL up_test_assert(
    (SELECT status = 'deleted' AND deleted_at IS NOT NULL AND updated_at > created_at AND version = 2
       FROM up_core_characters WHERE id = @character_id),
    'soft delete state is invalid'
);

DELETE FROM up_core_characters WHERE id = @character_id;
DELETE FROM up_core_passport_allocations WHERE character_id = @character_id;
DELETE FROM up_core_accounts WHERE id = @account_id;
DROP PROCEDURE up_test_assert;
