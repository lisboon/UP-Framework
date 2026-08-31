UP.CharacterRepository = {}

local function releaseSlot(accountId)
    MySQL.update.await('UPDATE up_core_character_slots SET used = GREATEST(used - 1, 0) WHERE account_id = ?', { accountId })
end

local function reserveSlot(accountId)
    MySQL.insert.await('INSERT IGNORE INTO up_core_character_slots (account_id, used) VALUES (?, 0)', { accountId })
    local affected = MySQL.update.await(
        'UPDATE up_core_character_slots SET used = used + 1 WHERE account_id = ? AND used < ?',
        { accountId, UPConfig.character.maxPerAccount }
    )
    return affected > 0
end

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
    if not reserveSlot(accountId) then return nil, 'character_limit_reached' end

    local characterId = MySQL.scalar.await('SELECT UUID()')
    local allocationOK, passport = pcall(MySQL.insert.await, [[
        INSERT INTO up_core_passport_allocations (character_id) VALUES (?)
    ]], { characterId })
    if not allocationOK or not passport then
        releaseSlot(accountId)
        return nil, 'passport_allocation_failed'
    end

    local transactionOK, created = pcall(MySQL.transaction.await, {
        {
            query = [[
                INSERT INTO up_core_characters
                    (id, account_id, passport, first_name, last_name, birth_date, metadata)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            ]],
            values = { characterId, accountId, passport, data.firstName, data.lastName, data.birthDate, json.encode({}) }
        },
        {
            query = "INSERT INTO up_core_character_roles (character_id, role_name, granted_by) VALUES (?, 'player', NULL)",
            values = { characterId }
        },
        {
            query = [[
                INSERT INTO up_core_audit_log
                    (actor_account_id, action, subject_type, subject_id, metadata)
                VALUES (?, 'character.created', 'character', ?, ?)
            ]],
            values = { accountId, characterId, json.encode({ passport = passport }) }
        }
    })

    if not transactionOK or not created then
        MySQL.update.await('DELETE FROM up_core_passport_allocations WHERE character_id = ?', { characterId })
        releaseSlot(accountId)
        return nil, 'character_create_failed'
    end

    return UP.CharacterRepository.findActive(accountId, passport)
end

function UP.CharacterRepository.softDelete(accountId, character)
    local transactionOK, deleted = pcall(MySQL.transaction.await, {
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

function UP.CharacterRepository.markSelected(characterId)
    return MySQL.update.await([[
        UPDATE up_core_characters
           SET last_selected_at = CURRENT_TIMESTAMP(6), version = version + 1
         WHERE id = ? AND status = 'active'
    ]], { characterId })
end
