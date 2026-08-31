UP.Players = {}

local function syncIdentifiers(accountId, identifiers)
    for _, identifier in ipairs(identifiers) do
        MySQL.prepare.await([[
            INSERT INTO up_core_account_identifiers (account_id, provider, identifier)
            VALUES (?, ?, ?)
            ON DUPLICATE KEY UPDATE account_id = VALUES(account_id), last_seen_at = CURRENT_TIMESTAMP
        ]], { accountId, identifier.kind, identifier.value })
    end
end

local function resolveAccount(source)
    local primary = UP.Identifiers.primary(source)
    if not primary then return nil, 'missing_license_identifier' end

    local identifiers = UP.Identifiers.collect(source)
    local account = MySQL.single.await([[
        SELECT a.id, a.status
          FROM up_core_accounts a
          JOIN up_core_account_identifiers ai ON ai.account_id = a.id
         WHERE ai.provider = ? AND ai.identifier = ?
         LIMIT 1
    ]], { primary.kind, primary.value })

    if not account then
        local accountId = MySQL.scalar.await('SELECT UUID()')
        local created = MySQL.transaction.await({
            {
                query = 'INSERT INTO up_core_accounts (id, status) VALUES (?, ?)',
                values = { accountId, 'active' }
            },
            {
                query = [[
                    INSERT INTO up_core_account_identifiers (account_id, provider, identifier)
                    VALUES (?, ?, ?)
                ]],
                values = { accountId, primary.kind, primary.value }
            }
        })
        if created then
            account = { id = accountId, status = 'active' }
        else
            -- A concurrent connection may have inserted the unique identifier.
            -- Resolve it again instead of keeping an account that was rolled back.
            account = MySQL.single.await([[
                SELECT a.id, a.status
                  FROM up_core_accounts a
                  JOIN up_core_account_identifiers ai ON ai.account_id = a.id
                 WHERE ai.provider = ? AND ai.identifier = ?
                 LIMIT 1
            ]], { primary.kind, primary.value })
            if not account then return nil, 'account_create_failed' end
        end
    end

    syncIdentifiers(account.id, identifiers)
    return account
end

local function unload(source, reason)
    local player = UP.players[source]
    if not player then return end

    TriggerEvent(UPContracts.events.playerUnloaded, source, player, reason)
    UP.players[source] = nil
    UP.rateLimits[source] = nil
end

AddEventHandler('playerJoining', function()
    local source = source
    if not UP.ready then
        DropPlayer(source, 'UP is still starting. Please reconnect in a moment.')
        return
    end

    local account, err = resolveAccount(source)
    if not account then
        DropPlayer(source, ('Unable to resolve account: %s'):format(err))
        return
    end

    if account.status ~= 'active' then
        DropPlayer(source, 'This account is not active.')
        return
    end

    local state = {
        source = source,
        accountId = account.id,
        characterId = nil,
        passport = nil,
        loaded = true
    }

    UP.players[source] = state
    TriggerEvent(UPContracts.events.playerLoaded, source, state)
end)

AddEventHandler('playerDropped', function(reason)
    unload(source, reason or 'player_dropped')
end)

function UP.Players.get(source)
    return UP.players[tonumber(source)]
end

function UP.Players.activateCharacter(source, passport)
    if not UP.Validation.passport(passport) then
        return false, 'invalid_passport'
    end

    local player = UP.players[source]
    if not player then return false, 'player_not_loaded' end

    local character = MySQL.single.await([[
        SELECT id, passport, status
          FROM up_core_characters
         WHERE account_id = ? AND passport = ?
         LIMIT 1
    ]], { player.accountId, passport })

    if not character or character.status ~= 'active' then
        return false, 'character_not_available'
    end

    player.characterId = character.id
    player.passport = tonumber(character.passport)
    TriggerEvent(UPContracts.events.characterActivated, source, player)
    TriggerClientEvent(UPContracts.events.characterReady, source, {
        passport = player.passport
    })
    return true, player
end
