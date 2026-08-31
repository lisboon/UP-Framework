DROP PROCEDURE IF EXISTS up_identity_assert;

DELIMITER //
CREATE PROCEDURE up_identity_assert(IN condition_value BOOLEAN, IN failure_message VARCHAR(128))
BEGIN
    IF condition_value IS NULL OR condition_value = FALSE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = failure_message;
    END IF;
END//

CREATE PROCEDURE up_identity_attach_conflict(IN target_account CHAR(36))
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION ROLLBACK;
    START TRANSACTION;
    INSERT INTO up_core_account_identifiers (account_id, provider, identifier)
    VALUES (target_account, 'steam', 'identity-atomic-test')
    ON DUPLICATE KEY UPDATE
        account_id = IF(account_id = VALUES(account_id), account_id, NULL),
        last_seen_at = CURRENT_TIMESTAMP(6);
    INSERT INTO up_core_account_identifiers (account_id, provider, identifier)
    VALUES (target_account, 'discord', 'identity-security-test')
    ON DUPLICATE KEY UPDATE
        account_id = IF(account_id = VALUES(account_id), account_id, NULL),
        last_seen_at = CURRENT_TIMESTAMP(6);
    COMMIT;
END//
DELIMITER ;

SET @account_a = '00000000-0000-0000-0000-000000000021';
SET @account_b = '00000000-0000-0000-0000-000000000022';

DELETE FROM up_core_accounts WHERE id IN (@account_a, @account_b);
INSERT INTO up_core_accounts (id, status) VALUES (@account_a, 'active'), (@account_b, 'active');
INSERT INTO up_core_account_identifiers (account_id, provider, identifier)
VALUES (@account_a, 'discord', 'identity-security-test');

INSERT IGNORE INTO up_core_account_identifiers (account_id, provider, identifier)
VALUES (@account_b, 'discord', 'identity-security-test');

CALL up_identity_assert(
    (SELECT account_id = @account_a
       FROM up_core_account_identifiers
      WHERE provider = 'discord' AND identifier = 'identity-security-test'),
    'existing identifier was reassigned'
);

CALL up_identity_attach_conflict(@account_b);
CALL up_identity_assert(
    (SELECT COUNT(*) = 0
       FROM up_core_account_identifiers
      WHERE provider = 'steam' AND identifier = 'identity-atomic-test'),
    'conflicting identifier attachment was not atomic'
);

DELETE FROM up_core_account_identifiers WHERE provider = 'discord' AND identifier = 'identity-security-test';
DELETE FROM up_core_accounts WHERE id IN (@account_a, @account_b);
DROP PROCEDURE up_identity_assert;
DROP PROCEDURE up_identity_attach_conflict;
