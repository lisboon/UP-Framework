UP = {
    Spawns = {},
    Players = {}
}
UPConfig = {
    spawn = {
        locations = {
            {
                id = 'airport',
                label = 'Airport',
                coordinates = { x = 1.0, y = 2.0, z = 3.0, heading = 4.0 }
            }
        }
    }
}

local player = { phase = 'character_selected' }
local selectedLocation
local completedAttempt

function UP.Players.get()
    return player
end

function UP.Players.beginSpawn(_, location)
    selectedLocation = location
    return 'attempt-1'
end

function UP.Players.completeSpawn(_, attemptId)
    completedAttempt = attemptId
    return true
end

dofile('resources/[up]/up_core/server/spawn/service.lua')

local locations = assert(UP.Spawns.list(1))
assert(#locations == 1)
assert(locations[1].id == 'airport')
assert(locations[1].coordinates.heading == 4.0)

locations[1].coordinates.x = 999.0
assert(UPConfig.spawn.locations[1].coordinates.x == 1.0)

local selected = assert(UP.Spawns.select(1, { locationId = 'airport' }))
assert(selected.attemptId == 'attempt-1')
assert(selectedLocation.id == 'airport')

local missing, missingError = UP.Spawns.select(1, { locationId = 'unknown' })
assert(missing == nil and missingError == 'spawn_location_invalid')

local invalid, invalidError = UP.Spawns.select(1, {})
assert(invalid == nil and invalidError == 'invalid_payload')

assert(UP.Spawns.complete(1, { attemptId = 'attempt-1' }))
assert(completedAttempt == 'attempt-1')

player.phase = 'spawned'
local unavailable, unavailableError = UP.Spawns.list(1)
assert(unavailable == nil and unavailableError == 'spawn_not_available')
