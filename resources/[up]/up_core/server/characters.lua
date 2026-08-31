UP.Characters = {}

local function releaseSlot(accountId)
    MySQL.update.await([[
        UPDATE up_core_character_slots
           SET used = GREATEST(used - 1, 0)
         WHERE account_id = ?
    ]], { accountId })
end

local function reserveSlot(accountId)
    MySQL.insert.await([[
        INSERT IGNORE INTO up_core_character_slots (account_id, used)
        VALUES (?, 0)
    ]], { accountId })

    local affected = MySQL.update.await([[
        UPDATE up_core_character_slots
           SET used = used + 1
         WHERE account_id = ? AND used < ?
    ]], { accountId, UPConfig.character.maxPerAccount })

    return affected > 0
end

local function publicCharacter(character)
    return {
        passport = tonumber(character.passport),
        firstName = character.firstName,
        lastName = character.lastName,
        birthDate = character.birthDate,
        createdAt = character.createdAt,
        lastSelectedAt = character.lastSelectedAt
    }
end

function UP.Characters.list(source)
    local player = UP.Players.get(source)
    if not player then return nil, 'player_not_loaded' end

    local rows = MySQL.query.await([[
        SELECT passport,
               first_name AS firstName,
               last_name AS lastName,
               DATE_FORMAT(birth_date, '%Y-%m-%d') AS birthDate,
               created_at AS createdAt,
               last_selected_at AS lastSelectedAt
          FROM up_core_characters
         WHERE account_id = ? AND status = 'active'
         ORDER BY passport ASC
    ]], { player.accountId })

    local characters = {}
    for index, character in ipairs(rows) do
        characters[index] = publicCharacter(character)
    end
    return characters
end

function UP.Characters.create(source, payload)
    local player = UP.Players.get(source)
    if not player then return nil, 'player_not_loaded' end
    if player.characterId then return nil, 'character_session_active' end
    if type(payload) ~= 'table' then return nil, 'invalid_payload' end

    local config = UPConfig.character
    local firstName = UP.Validation.characterName(payload.firstName, config.firstNameMinLength, config.firstNameMaxLength)
    local lastName = UP.Validation.characterName(payload.lastName, config.lastNameMinLength, config.lastNameMaxLength)
    if not firstName or not lastName then return nil, 'invalid_name' end
    if not UP.Validation.birthDate(payload.birthDate, config.minimumAge, config.maximumAge) then
        return nil, 'invalid_birth_date'
    end

    if not reserveSlot(player.accountId) then return nil, 'character_limit_reached' end

    local characterId = MySQL.scalar.await('SELECT UUID()')
    local allocationOK, passport = pcall(MySQL.insert.await, [[
        INSERT INTO up_core_passport_allocations (character_id)
        VALUES (?)
    ]], { characterId })

    if not allocationOK or not passport then
        releaseSlot(player.accountId)
        return nil, 'passport_allocation_failed'
    end

    local metadata = json.encode({})
    local auditMetadata = json.encode({ passport = passport })
    local transactionOK, created = pcall(MySQL.transaction.await, {
        {
            query = [[
                INSERT INTO up_core_characters
                    (id, account_id, passport, first_name, last_name, birth_date, metadata)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            ]],
            values = { characterId, player.accountId, passport, firstName, lastName, payload.birthDate, metadata }
        },
        {
            query = [[
                INSERT INTO up_core_character_roles (character_id, role_name, granted_by)
                VALUES (?, 'player', NULL)
            ]],
            values = { characterId }
        },
        {
            query = [[
                INSERT INTO up_core_audit_log
                    (actor_account_id, action, subject_type, subject_id, metadata)
                VALUES (?, 'character.created', 'character', ?, ?)
            ]],
            values = { player.accountId, characterId, auditMetadata }
        }
    })

    if not transactionOK or not created then
        MySQL.update.await('DELETE FROM up_core_passport_allocations WHERE character_id = ?', { characterId })
        releaseSlot(player.accountId)
        return nil, 'character_create_failed'
    end

    local character = {
        passport = passport,
        firstName = firstName,
        lastName = lastName,
        birthDate = payload.birthDate,
        createdAt = nil,
        lastSelectedAt = nil
    }

    TriggerEvent(UPContracts.events.characterCreated, source, character)
    return character
end

function UP.Characters.delete(source, passport)
    if not UP.Validation.passport(passport) then return nil, 'invalid_passport' end

    local player = UP.Players.get(source)
    if not player then return nil, 'player_not_loaded' end
    if player.characterId then return nil, 'character_session_active' end

    local character = MySQL.single.await([[
        SELECT id
          FROM up_core_characters
         WHERE account_id = ? AND passport = ? AND status = 'active'
         LIMIT 1
    ]], { player.accountId, passport })

    if not character then return nil, 'character_not_available' end
    if UP.characterMutations[character.id] then return nil, 'character_busy' end
    UP.characterMutations[character.id] = true

    local auditMetadata = json.encode({ passport = passport })
    local transactionOK, deleted = pcall(MySQL.transaction.await, {
        {
            query = [[
                UPDATE up_core_characters
                   SET status = 'deleted', deleted_at = CURRENT_TIMESTAMP(6), version = version + 1
                 WHERE id = ? AND account_id = ? AND status = 'active'
            ]],
            values = { character.id, player.accountId }
        },
        {
            query = [[
                UPDATE up_core_character_slots
                   SET used = GREATEST(used - 1, 0)
                 WHERE account_id = ?
            ]],
            values = { player.accountId }
        },
        {
            query = [[
                INSERT INTO up_core_audit_log
                    (actor_account_id, action, subject_type, subject_id, metadata)
                VALUES (?, 'character.deleted', 'character', ?, ?)
            ]],
            values = { player.accountId, character.id, auditMetadata }
        }
    })

    UP.characterMutations[character.id] = nil
    if not transactionOK or not deleted then return nil, 'character_delete_failed' end

    TriggerEvent(UPContracts.events.characterDeleted, source, passport)
    return true
end

function UP.Characters.select(source, passport)
    local activated, result = UP.Players.activateCharacter(source, passport)
    if not activated then return nil, result end

    MySQL.update.await([[
        UPDATE up_core_characters
           SET last_selected_at = CURRENT_TIMESTAMP(6), version = version + 1
         WHERE id = ?
    ]], { result.characterId })

    return {
        passport = result.passport
    }
end

UP.Callbacks.register('characters.list', function(source)
    return UP.Characters.list(source)
end)

UP.Callbacks.register('characters.create', function(source, payload)
    return UP.Characters.create(source, payload)
end)

UP.Callbacks.register('characters.delete', function(source, payload)
    if type(payload) ~= 'table' then return nil, 'invalid_payload' end
    return UP.Characters.delete(source, payload.passport)
end)

UP.Callbacks.register('characters.select', function(source, payload)
    if type(payload) ~= 'table' then return nil, 'invalid_payload' end
    return UP.Characters.select(source, payload.passport)
end)
