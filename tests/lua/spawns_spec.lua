UP = {
    Spawns = {},
    Players = {}
}
UPConfig = {
    spawn = {
        providers = {
            spawnmanager = {
                attestation = {
                    mode = 'position',
                    stabilizationMs = 750,
                    tolerance = 5.0
                }
            }
        },
        locations = {
            {
                id = 'airport',
                label = 'Airport',
                provider = 'spawnmanager',
                coordinates = { x = 1.0, y = 2.0, z = 3.0, heading = 4.0 }
            },
            {
                id = 'interior',
                label = 'Interior handoff',
                provider = 'spawnmanager',
                coordinates = { x = 10.0, y = 20.0, z = 30.0, heading = 40.0 },
                attestation = {
                    mode = 'exempt',
                    reason = 'interior_handoff'
                }
            }
        }
    }
}

json = {
    encode = function() return '{}' end
}

local player = { phase = 'character_selected' }
local selectedLocation
local selectedAttestation
local completedAttempt
local failedAttempt
local failedReason
local attemptSequence = 0
local timers = {}
local actualPosition = { x = 1.0, y = 2.0, z = 3.0 }

function UP.Players.get()
    return player
end

function UP.Players.beginSpawn(_, location, attestation)
    attemptSequence = attemptSequence + 1
    selectedLocation = location
    selectedAttestation = attestation
    player.phase = 'spawning'
    player.spawnAttemptId = 'attempt-' .. attemptSequence
    player.spawnAttestation = attestation
    return player.spawnAttemptId
end

function UP.Players.getSpawnAttempt(_, attemptId)
    if not player or player.phase ~= 'spawning' or player.spawnAttemptId ~= attemptId then
        return nil, 'spawn_attempt_invalid'
    end
    return player
end

function UP.Players.beginSpawnAttestation(_, attemptId)
    local attempt, err = UP.Players.getSpawnAttempt(nil, attemptId)
    if not attempt then return nil, err end
    if attempt.spawnCompletionPending then return nil, 'spawn_completion_pending' end
    attempt.spawnCompletionPending = true
    return attempt
end

function UP.Players.completeSpawn(_, attemptId)
    completedAttempt = attemptId
    player.phase = 'spawned'
    return true
end

function UP.Players.failSpawn(_, attemptId, reason)
    failedAttempt = attemptId
    failedReason = reason
    player.phase = 'character_selected'
    return true
end

function SetTimeout(delay, handler)
    timers[#timers + 1] = { delay = delay, handler = handler }
end

function GetPlayerPed()
    return 99
end

function GetEntityCoords()
    return actualPosition
end

dofile('resources/[up]/up_core/server/spawn/service.lua')

local locations = assert(UP.Spawns.list(1))
assert(#locations == 2)
assert(locations[1].id == 'airport')
assert(locations[1].coordinates.heading == 4.0)

locations[1].coordinates.x = 999.0
assert(UPConfig.spawn.locations[1].coordinates.x == 1.0)

local selected = assert(UP.Spawns.select(1, { locationId = 'airport' }))
assert(selected.attemptId == 'attempt-1')
assert(selectedLocation.id == 'airport')
assert(selectedLocation.attestation == nil)
assert(selectedAttestation.mode == 'position')
assert(selectedAttestation.provider == 'spawnmanager')
assert(selectedAttestation.coordinates.x == 1.0)

local pending = assert(UP.Spawns.complete(1, { attemptId = 'attempt-1' }))
assert(pending.pending == true)
assert(#timers == 1 and timers[1].delay == 750)
timers[1].handler()
assert(completedAttempt == 'attempt-1')

player = { phase = 'character_selected' }
actualPosition = { x = 100.0, y = 200.0, z = 300.0 }
local rejected = assert(UP.Spawns.select(1, { locationId = 'airport' }))
assert(UP.Spawns.complete(1, { attemptId = rejected.attemptId }))
timers[2].handler()
assert(failedAttempt == rejected.attemptId)
assert(failedReason == 'spawn_position_mismatch')

player = { phase = 'character_selected' }
local exempt = assert(UP.Spawns.select(1, { locationId = 'interior' }))
assert(selectedAttestation.mode == 'exempt')
assert(selectedAttestation.reason == 'interior_handoff')
assert(UP.Spawns.complete(1, { attemptId = exempt.attemptId }))
assert(completedAttempt == exempt.attemptId)

player = { phase = 'character_selected' }
actualPosition = { x = 1.0, y = 2.0, z = 3.0 }
local disconnected = assert(UP.Spawns.select(1, { locationId = 'airport' }))
assert(UP.Spawns.complete(1, { attemptId = disconnected.attemptId }))
player = nil
timers[3].handler()
assert(completedAttempt ~= disconnected.attemptId)
assert(failedAttempt ~= disconnected.attemptId)

player = { phase = 'character_selected' }
local missing, missingError = UP.Spawns.select(1, { locationId = 'unknown' })
assert(missing == nil and missingError == 'spawn_location_invalid')

local invalid, invalidError = UP.Spawns.select(1, {})
assert(invalid == nil and invalidError == 'invalid_payload')

player.phase = 'spawned'
local unavailable, unavailableError = UP.Spawns.list(1)
assert(unavailable == nil and unavailableError == 'spawn_not_available')
