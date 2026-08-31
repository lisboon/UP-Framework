UP.Players = {}

local function unload(source, reason)
    local player = UP.players[source]
    if not player then return end

    TriggerEvent(UPContracts.events.playerUnloaded, source, player, reason)
    if UP.accountSources[player.accountId] == source then
        UP.accountSources[player.accountId] = nil
    end
    UP.players[source] = nil
    UP.rateLimits[source] = nil
    UP.playerMutations[source] = nil
end

local function expireAuthorization(source, account)
    SetTimeout(30000, function()
        if UP.pendingPlayers[source] == account then
            UP.pendingPlayers[source] = nil
        end
    end)
end

AddEventHandler('playerConnecting', function(_, _, deferrals)
    local source = source
    deferrals.defer()
    Wait(0)

    if not UP.ready then
        deferrals.done('UP is still starting. Please reconnect in a moment.')
        return
    end

    deferrals.update('UP is validating your identity.')
    local resolved, account, err = pcall(UP.Identity.resolve, source)
    Wait(0)

    if not resolved then
        deferrals.done('UP could not validate your identity. Please try again.')
        return
    end
    if not account then
        print(('^1[up_core]^7 identity rejected for source %s (%s)'):format(source, err))
        deferrals.done('UP could not validate your identity. Please contact support.')
        return
    end

    if account.status ~= 'active' then
        deferrals.done('This UP account is not active.')
        return
    end

    UP.pendingPlayers[source] = account
    expireAuthorization(source, account)
    deferrals.done()
end)

AddEventHandler('playerJoining', function(oldId)
    local source = source
    local pendingSource = tonumber(oldId)
    local account = pendingSource and UP.pendingPlayers[pendingSource]
    if pendingSource then UP.pendingPlayers[pendingSource] = nil end
    if not account then
        DropPlayer(source, 'UP connection authorization expired. Please reconnect.')
        return
    end
    if UP.accountSources[account.id] then
        DropPlayer(source, 'This UP account is already connected.')
        return
    end

    local state = {
        source = source,
        accountId = account.id,
        characterId = nil,
        passport = nil,
        loaded = true,
        phase = 'account_ready'
    }

    UP.players[source] = state
    UP.accountSources[account.id] = source
    TriggerEvent(UPContracts.events.playerLoaded, source, state)
end)

AddEventHandler('playerDropped', function(reason)
    UP.pendingPlayers[source] = nil
    unload(source, reason or 'player_dropped')
end)

function UP.Players.get(source)
    return UP.players[tonumber(source)]
end

function UP.Players.activateCharacter(source, character)
    local player = UP.players[source]
    if not player then return false, 'player_not_loaded' end
    if player.characterId then return false, 'character_already_active' end

    player.characterId = character.id
    player.passport = tonumber(character.passport)
    player.phase = 'character_selected'
    TriggerEvent(UPContracts.events.characterActivated, source, player)
    TriggerClientEvent(UPContracts.events.characterSelected, source, {
        passport = player.passport
    })
    return true, player
end
