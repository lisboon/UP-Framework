UPEntry = {
    sessions = {}
}

local validLockdownModes = {
    inactive = true,
    relaxed = true,
    strict = true
}
local droppedEnteredRemaining = math.max(0, GetConvarInt('up_entry_test_drop_entered', 0))

assert(type(UPEntryConfig.bucketBase) == 'number'
    and UPEntryConfig.bucketBase == math.floor(UPEntryConfig.bucketBase)
    and UPEntryConfig.bucketBase > 0, 'entry bucket base must be a positive integer')
assert(validLockdownModes[UPEntryConfig.bucketLockdownMode], 'entry bucket lockdown mode is invalid')
assert(type(UPEntryConfig.populationEnabled) == 'boolean', 'entry population setting must be boolean')

local function playerState(source)
    return exports.up_core:GetPlayerState(source)
end

local function requiresEntry(state)
    return state and state.phase ~= 'spawned'
end

local function bucketFor(source)
    return UPEntryConfig.bucketBase + source
end

local function setEntryState(source, active)
    local player = Player(source)
    if player then player.state:set('up:entry', active, true) end
end

local function notifyEntered(source)
    if droppedEnteredRemaining > 0 then
        droppedEnteredRemaining = droppedEnteredRemaining - 1
        print(('[up_entry] test hook dropped entered event for source %d'):format(source))
        return false
    end

    TriggerClientEvent(UPEntryContracts.events.entered, source, {
        version = UPEntryContracts.version
    })
    return true
end

function UPEntry.sync(source)
    source = tonumber(source)
    if not source or source < 1 or source ~= math.floor(source) then return nil, 'invalid_source' end

    local session = UPEntry.sessions[source]
    if not session then return nil, 'entry_not_open' end

    local state = playerState(source)
    if not requiresEntry(state) then
        UPEntry.leave(source, 'entry_state_reconciled')
        return nil, 'entry_not_required'
    end

    SetRoutingBucketEntityLockdownMode(session.bucket, UPEntryConfig.bucketLockdownMode)
    SetRoutingBucketPopulationEnabled(session.bucket, UPEntryConfig.populationEnabled)
    SetPlayerRoutingBucket(source, session.bucket)
    setEntryState(source, true)
    notifyEntered(source)
    return session
end

function UPEntry.enter(source)
    source = tonumber(source)
    if not source or source < 1 or source ~= math.floor(source) then return nil, 'invalid_source' end

    if UPEntry.sessions[source] then
        return UPEntry.sync(source)
    end

    local state = playerState(source)
    if not requiresEntry(state) then return nil, 'entry_not_required' end

    UPEntry.sessions[source] = { bucket = bucketFor(source) }
    return UPEntry.sync(source)
end

function UPEntry.leave(source, reason)
    source = tonumber(source)
    if not source then return false end

    local session = UPEntry.sessions[source]
    if not session then return false end

    UPEntry.sessions[source] = nil
    SetPlayerRoutingBucket(source, 0)
    setEntryState(source, false)
    TriggerClientEvent(UPEntryContracts.events.left, source, {
        version = UPEntryContracts.version,
        reason = reason or 'entry_completed'
    })
    return true
end

function UPEntry.drop(source)
    source = tonumber(source)
    if not source then return false end
    local existed = UPEntry.sessions[source] ~= nil
    UPEntry.sessions[source] = nil
    return existed
end

AddEventHandler(UPEntryContracts.coreEvents.playerLoaded, function(source)
    UPEntry.enter(source)
end)

AddEventHandler(UPEntryContracts.coreEvents.playerSpawned, function(source)
    UPEntry.leave(source, 'player_spawned')
end)

AddEventHandler(UPEntryContracts.coreEvents.playerUnloaded, function(source)
    UPEntry.drop(source)
end)

RegisterNetEvent(UPEntryContracts.events.clientReady, function(envelope)
    if type(envelope) ~= 'table' or envelope.version ~= UPEntryContracts.version then return end
    UPEntry.sync(source)
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    SetTimeout(0, function()
        for _, playerId in ipairs(GetPlayers()) do
            UPEntry.enter(tonumber(playerId))
        end
    end)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for source in pairs(UPEntry.sessions) do
        SetPlayerRoutingBucket(source, 0)
        setEntryState(source, false)
    end
    UPEntry.sessions = {}
end)

exports('IsInEntry', function(source)
    return UPEntry.sessions[tonumber(source)] ~= nil
end)
