CREATE TABLE IF NOT EXISTS up_core_passport_allocations (
    passport BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    character_id CHAR(36) NOT NULL,
    allocated_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (passport),
    UNIQUE KEY uq_up_core_passport_character (character_id)
) ENGINE=InnoDB AUTO_INCREMENT=1000;

INSERT IGNORE INTO up_core_passport_allocations (passport, character_id)
SELECT passport, id FROM up_core_characters;

CREATE TABLE IF NOT EXISTS up_core_character_slots (
    account_id CHAR(36) NOT NULL,
    used TINYINT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (account_id),
    CONSTRAINT fk_up_core_slots_account
        FOREIGN KEY (account_id) REFERENCES up_core_accounts(id)
        ON DELETE CASCADE,
    CONSTRAINT chk_up_core_slots_used CHECK (used <= 32)
) ENGINE=InnoDB;

INSERT INTO up_core_character_slots (account_id, used)
SELECT account_id, COUNT(*)
  FROM up_core_characters
 WHERE status = 'active'
 GROUP BY account_id
ON DUPLICATE KEY UPDATE used = VALUES(used);

ALTER TABLE up_core_characters
    ADD COLUMN deleted_at TIMESTAMP(6) NULL AFTER status,
    ADD COLUMN last_selected_at TIMESTAMP(6) NULL AFTER deleted_at,
    ADD COLUMN version INT UNSIGNED NOT NULL DEFAULT 1 AFTER metadata;

DROP TABLE up_core_passport_sequence;

INSERT INTO up_core_schema_migrations (version, name, checksum)
VALUES (2, 'character_lifecycle', REPEAT('0', 64))
ON DUPLICATE KEY UPDATE name = VALUES(name);
