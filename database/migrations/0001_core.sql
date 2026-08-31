CREATE TABLE IF NOT EXISTS up_core_schema_migrations (
    version INT UNSIGNED NOT NULL,
    name VARCHAR(128) NOT NULL,
    checksum CHAR(64) NOT NULL,
    applied_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (version)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS up_core_accounts (
    id CHAR(36) NOT NULL,
    status ENUM('active', 'suspended', 'deleted') NOT NULL DEFAULT 'active',
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    KEY idx_up_core_accounts_status (status)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS up_core_account_identifiers (
    provider VARCHAR(24) NOT NULL,
    identifier VARCHAR(128) NOT NULL,
    account_id CHAR(36) NOT NULL,
    first_seen_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    last_seen_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (provider, identifier),
    KEY idx_up_core_identifiers_account (account_id),
    CONSTRAINT fk_up_core_identifier_account
        FOREIGN KEY (account_id) REFERENCES up_core_accounts(id)
        ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS up_core_passport_sequence (
    id TINYINT UNSIGNED NOT NULL,
    next_value BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT chk_up_core_passport_singleton CHECK (id = 1)
) ENGINE=InnoDB;

INSERT INTO up_core_passport_sequence (id, next_value)
VALUES (1, 1000)
ON DUPLICATE KEY UPDATE next_value = next_value;

CREATE TABLE IF NOT EXISTS up_core_characters (
    id CHAR(36) NOT NULL,
    account_id CHAR(36) NOT NULL,
    passport BIGINT UNSIGNED NOT NULL,
    first_name VARCHAR(32) NOT NULL,
    last_name VARCHAR(32) NOT NULL,
    birth_date DATE NOT NULL,
    status ENUM('active', 'deleted') NOT NULL DEFAULT 'active',
    metadata JSON NOT NULL,
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    UNIQUE KEY uq_up_core_characters_passport (passport),
    KEY idx_up_core_characters_account_status (account_id, status),
    CONSTRAINT fk_up_core_character_account
        FOREIGN KEY (account_id) REFERENCES up_core_accounts(id)
        ON DELETE RESTRICT,
    CONSTRAINT chk_up_core_character_metadata CHECK (JSON_VALID(metadata))
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS up_core_roles (
    name VARCHAR(64) NOT NULL,
    label VARCHAR(96) NOT NULL,
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (name)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS up_core_role_permissions (
    role_name VARCHAR(64) NOT NULL,
    permission VARCHAR(96) NOT NULL,
    PRIMARY KEY (role_name, permission),
    CONSTRAINT fk_up_core_permission_role
        FOREIGN KEY (role_name) REFERENCES up_core_roles(name)
        ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS up_core_character_roles (
    character_id CHAR(36) NOT NULL,
    role_name VARCHAR(64) NOT NULL,
    granted_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    granted_by CHAR(36) NULL,
    PRIMARY KEY (character_id, role_name),
    CONSTRAINT fk_up_core_character_role_character
        FOREIGN KEY (character_id) REFERENCES up_core_characters(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_up_core_character_role_role
        FOREIGN KEY (role_name) REFERENCES up_core_roles(name)
        ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS up_core_audit_log (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    occurred_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    actor_account_id CHAR(36) NULL,
    actor_character_id CHAR(36) NULL,
    action VARCHAR(96) NOT NULL,
    subject_type VARCHAR(64) NOT NULL,
    subject_id VARCHAR(128) NULL,
    correlation_id VARCHAR(64) NULL,
    metadata JSON NOT NULL,
    PRIMARY KEY (id),
    KEY idx_up_core_audit_occurred (occurred_at),
    KEY idx_up_core_audit_subject (subject_type, subject_id),
    KEY idx_up_core_audit_correlation (correlation_id),
    CONSTRAINT chk_up_core_audit_metadata CHECK (JSON_VALID(metadata))
) ENGINE=InnoDB;

INSERT INTO up_core_roles (name, label)
VALUES ('player', 'Player'), ('staff', 'Staff'), ('admin', 'Administrator')
ON DUPLICATE KEY UPDATE label = VALUES(label);

INSERT INTO up_core_role_permissions (role_name, permission)
VALUES
    ('staff', 'up.staff'),
    ('admin', 'up.staff'),
    ('admin', 'up.admin')
ON DUPLICATE KEY UPDATE permission = VALUES(permission);

INSERT INTO up_core_schema_migrations (version, name, checksum)
VALUES (1, 'core', REPEAT('0', 64))
ON DUPLICATE KEY UPDATE name = VALUES(name);
