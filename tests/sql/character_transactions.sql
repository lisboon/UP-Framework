DROP PROCEDURE IF EXISTS up_character_tx_assert;
DROP PROCEDURE IF EXISTS up_character_tx_limit;
DROP PROCEDURE IF EXISTS up_character_tx_stale_delete;

DELIMITER //
CREATE PROCEDURE up_character_tx_assert(IN condition_value BOOLEAN, IN failure_message VARCHAR(128))
BEGIN
    IF condition_value IS NULL OR condition_value = FALSE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = failure_message;
    END IF;
END//

CREATE PROCEDURE up_character_tx_limit(IN p_account_id CHAR(36), IN p_character_id CHAR(36))
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION ROLLBACK;
    START TRANSACTION;
    INSERT INTO up_core_character_slots (account_id, used)
    VALUES (p_account_id, 1)
    ON DUPLICATE KEY UPDATE used = IF(used < 3, used + 1, NULL);
    INSERT INTO up_core_passport_allocations (character_id) VALUES (p_character_id);
    COMMIT;
END//

CREATE PROCEDURE up_character_tx_stale_delete(
    IN p_account_id CHAR(36),
    IN p_character_id CHAR(36),
    IN p_expected_version INT UNSIGNED
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION ROLLBACK;
    START TRANSACTION;
    INSERT INTO up_core_character_slots (account_id, used)
    VALUES (
        IF(EXISTS(
            SELECT 1 FROM up_core_characters
             WHERE id = p_character_id AND account_id = p_account_id
               AND status = 'active' AND version = p_expected_version
        ), p_account_id, NULL),
        0
    )
    ON DUPLICATE KEY UPDATE used = used;
    UPDATE up_core_character_slots SET used = GREATEST(used - 1, 0) WHERE account_id = p_account_id;
    COMMIT;
END//
DELIMITER ;

SET @account_id = '00000000-0000-0000-0000-000000000031';
SET @character_id = '00000000-0000-0000-0000-000000000032';
SET @rejected_character_id = '00000000-0000-0000-0000-000000000033';

DELETE FROM up_core_audit_log WHERE subject_id IN (@character_id, @rejected_character_id);
DELETE FROM up_core_characters WHERE id IN (@character_id, @rejected_character_id);
DELETE FROM up_core_passport_allocations WHERE character_id IN (@character_id, @rejected_character_id);
DELETE FROM up_core_accounts WHERE id = @account_id;
INSERT INTO up_core_accounts (id, status) VALUES (@account_id, 'active');

START TRANSACTION;
INSERT INTO up_core_character_slots (account_id, used)
VALUES (@account_id, 1)
ON DUPLICATE KEY UPDATE used = IF(used < 3, used + 1, NULL);
INSERT INTO up_core_passport_allocations (character_id) VALUES (@character_id);
INSERT INTO up_core_characters
    (id, account_id, passport, first_name, last_name, birth_date, metadata)
SELECT @character_id, @account_id, passport, 'Ana', 'Silva', '2000-02-29', JSON_OBJECT()
  FROM up_core_passport_allocations
 WHERE character_id = @character_id;
COMMIT;

CALL up_character_tx_assert(
    (SELECT used = 1 FROM up_core_character_slots WHERE account_id = @account_id),
    'atomic create did not reserve exactly one slot'
);
CALL up_character_tx_assert(
    (SELECT COUNT(*) = 1 FROM up_core_characters WHERE id = @character_id),
    'atomic create did not persist the character'
);

UPDATE up_core_characters
   SET last_selected_at = CURRENT_TIMESTAMP(6), version = version + 1
 WHERE id = @character_id AND account_id = @account_id AND status = 'active' AND version = 1;
CALL up_character_tx_assert(
    (SELECT last_selected_at IS NOT NULL AND version = 2 FROM up_core_characters WHERE id = @character_id),
    'selection state was not persisted'
);

CALL up_character_tx_stale_delete(@account_id, @character_id, 1);
CALL up_character_tx_assert(
    (SELECT used = 1 FROM up_core_character_slots WHERE account_id = @account_id),
    'stale version released a character slot'
);
CALL up_character_tx_assert(
    (SELECT status = 'active' AND version = 2 FROM up_core_characters WHERE id = @character_id),
    'stale version changed character state'
);

START TRANSACTION;
INSERT INTO up_core_character_slots (account_id, used)
VALUES (
    IF(EXISTS(
        SELECT 1 FROM up_core_characters
         WHERE id = @character_id AND account_id = @account_id
           AND status = 'active' AND version = 2
    ), @account_id, NULL),
    0
)
ON DUPLICATE KEY UPDATE used = used;
UPDATE up_core_characters
   SET status = 'deleted', deleted_at = CURRENT_TIMESTAMP(6), version = version + 1
 WHERE id = @character_id AND account_id = @account_id AND status = 'active' AND version = 2;
UPDATE up_core_character_slots SET used = GREATEST(used - 1, 0) WHERE account_id = @account_id;
COMMIT;

CALL up_character_tx_assert(
    (SELECT status = 'deleted' AND deleted_at IS NOT NULL AND version = 3
       FROM up_core_characters WHERE id = @character_id),
    'atomic soft delete state is invalid'
);
CALL up_character_tx_assert(
    (SELECT used = 0 FROM up_core_character_slots WHERE account_id = @account_id),
    'atomic soft delete did not release the slot'
);

UPDATE up_core_character_slots SET used = 3 WHERE account_id = @account_id;
CALL up_character_tx_limit(@account_id, @rejected_character_id);
CALL up_character_tx_assert(
    (SELECT used = 3 FROM up_core_character_slots WHERE account_id = @account_id),
    'failed create changed the slot count'
);
CALL up_character_tx_assert(
    (SELECT COUNT(*) = 0 FROM up_core_passport_allocations WHERE character_id = @rejected_character_id),
    'failed create leaked a passport allocation'
);

CALL up_character_tx_stale_delete(@account_id, @character_id, 2);
CALL up_character_tx_assert(
    (SELECT used = 3 FROM up_core_character_slots WHERE account_id = @account_id),
    'stale delete released a slot'
);

DELETE FROM up_core_audit_log WHERE subject_id IN (@character_id, @rejected_character_id);
DELETE FROM up_core_characters WHERE id IN (@character_id, @rejected_character_id);
DELETE FROM up_core_passport_allocations WHERE character_id IN (@character_id, @rejected_character_id);
DELETE FROM up_core_accounts WHERE id = @account_id;
DROP PROCEDURE up_character_tx_assert;
DROP PROCEDURE up_character_tx_limit;
DROP PROCEDURE up_character_tx_stale_delete;
