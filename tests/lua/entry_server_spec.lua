UPEntryContracts = {
    version = 1,
    events = {
        clientReady = 'up:entry:clientReady',
        entered = 'up:entry:entered',
        left = 'up:entry:left'
    },
    coreEvents = {
        playerLoaded = 'up:playerLoaded',
        playerUnloaded = 'up:playerUnloaded',
        playerSpawned = 'up:playerSpawned'
    }
}
UPEntryConfig = {
    bucketBase = 100000,
    bucketLockdownMode = 'strict',
    populationEnabled = false
}

local player = { phase = 'account_ready' }
local handlers = {}
local netHandlers = {}
local buckets = {}
local lockdown
local population
local clientEvent
local registeredExport
local entryState
local connectedPlayers = {}

exports = setmetatable({
    up_core = {
        GetPlayerState = function(_, source)
            if source == 42 then return player end
        end
    }
}, {
    __call = function(_, name, handler)
        registeredExport = { name = name, handler = handler }
    end
})

function AddEventHandler(name, handler)
    handlers[name] = handler
end

function RegisterNetEvent(name, handler)
    netHandlers[name] = handler
end

function SetRoutingBucketEntityLockdownMode(bucket, mode)
    lockdown = { bucket = bucket, mode = mode }
end

function SetRoutingBucketPopulationEnabled(bucket, enabled)
    population = { bucket = bucket, enabled = enabled }
end

function SetPlayerRoutingBucket(playerSource, bucket)
    buckets[playerSource] = bucket
end

function TriggerClientEvent(name, playerSource, payload)
    clientEvent = { name = name, source = playerSource, payload = payload }
end

function SetTimeout(_, handler)
    handler()
end

function GetPlayers()
    return connectedPlayers
end

function GetCurrentResourceName()
    return 'up_entry'
end

function Player(source)
    if source ~= 42 then return nil end
    return {
        state = {
            set = function(_, key, value, replicated)
                entryState = { key = key, value = value, replicated = replicated }
            end
        }
    }
end

dofile('resources/[up]/up_entry/server/session.lua')
assert(registeredExport.name == 'GetEntryState')

handlers[UPEntryContracts.coreEvents.playerLoaded](42)
assert(UPEntry.sessions[42].bucket == 100042)
assert(buckets[42] == 100042)
assert(lockdown.bucket == 100042 and lockdown.mode == 'strict')
assert(population.bucket == 100042 and population.enabled == false)
assert(clientEvent.name == UPEntryContracts.events.entered)
assert(entryState.key == 'up:entry' and entryState.value == true and entryState.replicated == true)

local existing = assert(UPEntry.enter(42))
assert(existing == UPEntry.sessions[42])

handlers[UPEntryContracts.coreEvents.playerSpawned](42)
assert(UPEntry.sessions[42] == nil)
assert(buckets[42] == 0)
assert(clientEvent.name == UPEntryContracts.events.left)
assert(entryState.value == false)
assert(UPEntry.leave(42) == false)

UPEntry.sessions[42] = { bucket = 100042 }
player.phase = 'spawned'
local unavailable, unavailableError = UPEntry.enter(42)
assert(unavailable == nil and unavailableError == 'entry_not_required')
assert(UPEntry.sessions[42] == nil)
assert(buckets[42] == 0)

connectedPlayers = { '42' }
handlers.onResourceStart('up_entry')
assert(UPEntry.sessions[42] == nil)
assert(buckets[42] == 0)

player.phase = 'character_selected'
-- FiveM provides source as a global inside network event handlers; the fixture mirrors that runtime contract.
_G.source = 42
netHandlers[UPEntryContracts.events.clientReady]({ version = 999 })
assert(UPEntry.sessions[42] == nil)
netHandlers[UPEntryContracts.events.clientReady]({ version = 1 })
assert(UPEntry.sessions[42] == nil)

handlers.onResourceStart('up_entry')
assert(UPEntry.sessions[42] ~= nil)

player.phase = 'spawned'
netHandlers[UPEntryContracts.events.clientReady]({ version = 1 })
assert(UPEntry.sessions[42] == nil)
assert(buckets[42] == 0)
assert(clientEvent.name == UPEntryContracts.events.left)
_G.source = nil

handlers[UPEntryContracts.coreEvents.playerUnloaded](42)
assert(UPEntry.sessions[42] == nil)

player.phase = 'character_selected'
assert(UPEntry.enter(42))
handlers.onResourceStop('up_entry')
assert(UPEntry.sessions[42] == nil)
assert(buckets[42] == 0)
