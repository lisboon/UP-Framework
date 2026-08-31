UP.CharacterRepository = {}

function UP.CharacterRepository.listActive(accountId)
    return MySQL.query.await([[
        SELECT passport,
               first_name AS firstName,
               last_name AS lastName,
               DATE_FORMAT(birth_date, '%Y-%m-%d') AS birthDate,
               created_at AS createdAt,
               updated_at AS updatedAt,
               last_selected_at AS lastSelectedAt
          FROM up_core_characters
         WHERE account_id = ? AND status = 'active'
         ORDER BY passport ASC
    ]], { accountId })
end

function UP.CharacterRepository.findActive(accountId, passport)
    return MySQL.single.await([[
        SELECT id,
               passport,
               first_name AS firstName,
               last_name AS lastName,
               DATE_FORMAT(birth_date, '%Y-%m-%d') AS birthDate,
               created_at AS createdAt,
               updated_at AS updatedAt,
               last_selected_at AS lastSelectedAt
          FROM up_core_characters
         WHERE account_id = ? AND passport = ? AND status = 'active'
         LIMIT 1
    ]], { accountId, passport })
end

function UP.CharacterRepository.create(accountId, data)
    local characterId = MySQL.scalar.await('SELECT UUID()')
    local transactionOK, created = pcall(MySQL.transaction.await, {
        {
            query = [[
                INSERT INTO up_core_character_slots (account_id, used)
                VALUES (?, 1)
                ON DUPLICATE KEY UPDATE
                    used = IF(used < ?, used + 1, NULL)
            ]],
            values = { accountId, UPConfig.character.maxPerAccount }
        },
        {
            query = 'INSERT INTO up_core_passport_allocations (character_id) VALUES (?)',
            values = { characterId }
        },
        {
            query = [[
                INSERT INTO up_core_characters
                    (id, account_id, passport, first_name, last_name, birth_date, metadata)
                SELECT ?, ?, passport, ?, ?, ?, ?
                  FROM up_core_passport_allocations
                 WHERE character_id = ?
            ]],
            values = {
                characterId, accountId, data.firstName, data.lastName,
                data.birthDate, json.encode({}), characterId
            }
        },
        {
            query = "INSERT INTO up_core_character_roles (character_id, role_name, granted_by) VALUES (?, 'player', NULL)",
            values = { characterId }
        },
        {
            query = [[
                INSERT INTO up_core_audit_log
                    (actor_account_id, action, subject_type, subject_id, metadata)
                SELECT ?, 'character.created', 'character', ?, JSON_OBJECT('passport', passport)
                  FROM up_core_passport_allocations
                 WHERE character_id = ?
            ]],
            values = { accountId, characterId, characterId }
        }
    })

    if not transactionOK or not created then
        local used = MySQL.scalar.await(
            'SELECT used FROM up_core_character_slots WHERE account_id = ?',
            { accountId }
        )
        if tonumber(used) and tonumber(used) >= UPConfig.character.maxPerAccount then
            return nil, 'character_limit_reached'
        end
        return nil, 'character_create_failed'
    end
    return MySQL.single.await([[
        SELECT id,
               passport,
               first_name AS firstName,
               last_name AS lastName,
               DATE_FORMAT(birth_date, '%Y-%m-%d') AS birthDate,
               created_at AS createdAt,
               updated_at AS updatedAt,
               last_selected_at AS lastSelectedAt
          FROM up_core_characters
         WHERE id = ? AND account_id = ? AND status = 'active'
         LIMIT 1
    ]], { characterId, accountId })
end

function UP.CharacterRepository.softDelete(accountId, character)
    local transactionOK, deleted = pcall(MySQL.transaction.await, {
        {
            query = [[
                INSERT INTO up_core_character_slots (account_id, used)
                VALUES (
                    IF(EXISTS(
                        SELECT 1 FROM up_core_characters
                         WHERE id = ? AND account_id = ? AND status = 'active'
                    ), ?, NULL),
                    0
                )
                ON DUPLICATE KEY UPDATE used = used
            ]],
            values = { character.id, accountId, accountId }
        },
        {
            query = [[
                UPDATE up_core_characters
                   SET status = 'deleted', deleted_at = CURRENT_TIMESTAMP(6), version = version + 1
                 WHERE id = ? AND account_id = ? AND status = 'active'
            ]],
            values = { character.id, accountId }
        },
        {
            query = 'UPDATE up_core_character_slots SET used = GREATEST(used - 1, 0) WHERE account_id = ?',
            values = { accountId }
        },
        {
            query = [[
                INSERT INTO up_core_audit_log
                    (actor_account_id, action, subject_type, subject_id, metadata)
                VALUES (?, 'character.deleted', 'character', ?, ?)
            ]],
            values = { accountId, character.id, json.encode({ passport = character.passport }) }
        }
    })
    return transactionOK and deleted
end

function UP.CharacterRepository.select(accountId, character)
    local transactionOK, selected = pcall(MySQL.transaction.await, {
        {
            query = [[
                INSERT INTO up_core_character_slots (account_id, used)
                VALUES (
                    IF(EXISTS(
                        SELECT 1 FROM up_core_characters
                         WHERE id = ? AND account_id = ? AND status = 'active'
                    ), ?, NULL),
                    0
                )
                ON DUPLICATE KEY UPDATE used = used
            ]],
            values = { character.id, accountId, accountId }
        },
        {
            query = [[
                UPDATE up_core_characters
                   SET last_selected_at = CURRENT_TIMESTAMP(6), version = version + 1
                 WHERE id = ? AND account_id = ? AND status = 'active'
            ]],
            values = { character.id, accountId }
        },
        {
            query = [[
                INSERT INTO up_core_audit_log
                    (actor_account_id, action, subject_type, subject_id, metadata)
                VALUES (?, 'character.selected', 'character', ?, ?)
            ]],
            values = { accountId, character.id, json.encode({ passport = character.passport }) }
        }
    })
    return transactionOK and selected
end
