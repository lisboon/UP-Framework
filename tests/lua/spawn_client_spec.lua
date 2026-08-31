UPContracts = {
    version = 1,
    events = {
        spawnAuthorized = 'up:spawnAuthorized',
        spawnCompleted = 'up:spawnCompleted'
    }
}

local handlers = {}
local spawnData
local completion

function RegisterNetEvent(name, handler)
    handlers[name] = handler
end

function TriggerServerEvent(name, payload)
    completion = { name = name, payload = payload }
end

exports = {
    spawnmanager = {
        spawnPlayer = function(_, data, callback)
            spawnData = data
            callback()
        end
    }
}

dofile('resources/[up]/up_core/client/spawn/session.lua')

handlers[UPContracts.events.spawnAuthorized]({
    attemptId = 'attempt-1',
    location = {
        coordinates = { x = 1.0, y = 2.0, z = 3.0, heading = 4.0 }
    }
})

assert(spawnData.x == 1.0 and spawnData.heading == 4.0)
assert(completion.name == UPContracts.events.spawnCompleted)
assert(completion.payload.version == 1)
assert(completion.payload.attemptId == 'attempt-1')

spawnData = nil
handlers[UPContracts.events.spawnAuthorized]({
    attemptId = 'attempt-2',
    location = {
        coordinates = { x = 'invalid', y = 2.0, z = 3.0, heading = 4.0 }
    }
})
assert(spawnData == nil)
