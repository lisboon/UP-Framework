DROP PROCEDURE IF EXISTS up_upgrade_assert;

DELIMITER //
CREATE PROCEDURE up_upgrade_assert(IN condition_value BOOLEAN, IN failure_message VARCHAR(128))
BEGIN
    IF condition_value IS NULL OR condition_value = FALSE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = failure_message;
    END IF;
END//
DELIMITER ;

CALL up_upgrade_assert(
    (SELECT COUNT(*) = 1 FROM up_core_passport_allocations WHERE passport = 4242 AND character_id = '00000000-0000-0000-0000-000000000012'),
    'existing passport was not preserved'
);
CALL up_upgrade_assert(
    (SELECT used = 1 FROM up_core_character_slots WHERE account_id = '00000000-0000-0000-0000-000000000011'),
    'existing character slot was not counted'
);
CALL up_upgrade_assert(
    (SELECT COUNT(*) = 0 FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'up_core_passport_sequence'),
    'obsolete passport sequence still exists'
);
CALL up_upgrade_assert(
    (SELECT COUNT(*) = 1 FROM up_core_schema_migrations WHERE version = 2),
    'schema v2 was not registered'
);

DROP PROCEDURE up_upgrade_assert;
