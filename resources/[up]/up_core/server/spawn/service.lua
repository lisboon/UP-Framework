UP.Spawns = {}

local locations = {}

for _, location in ipairs(UPConfig.spawn.locations) do
    assert(type(location.id) == 'string' and location.id ~= '', 'spawn location id is required')
    assert(type(location.label) == 'string' and location.label ~= '', 'spawn location label is required')
    assert(type(location.coordinates) == 'table', 'spawn location coordinates are required')
    assert(type(location.coordinates.x) == 'number', 'spawn location x coordinate is required')
    assert(type(location.coordinates.y) == 'number', 'spawn location y coordinate is required')
    assert(type(location.coordinates.z) == 'number', 'spawn location z coordinate is required')
    assert(type(location.coordinates.heading) == 'number', 'spawn location heading is required')
    assert(locations[location.id] == nil, ('duplicate spawn location: %s'):format(location.id))
    locations[location.id] = location
end

local function publicLocation(location)
    return {
        id = location.id,
        label = location.label,
        coordinates = {
            x = location.coordinates.x,
            y = location.coordinates.y,
            z = location.coordinates.z,
            heading = location.coordinates.heading
        }
    }
end

function UP.Spawns.list(source)
    local player = UP.Players.get(source)
    if not player then return nil, 'player_not_loaded' end
    if player.phase ~= 'character_selected' then return nil, 'spawn_not_available' end

    local result = {}
    for index, location in ipairs(UPConfig.spawn.locations) do
        result[index] = publicLocation(location)
    end
    return result
end

function UP.Spawns.select(source, payload)
    if type(payload) ~= 'table' or type(payload.locationId) ~= 'string' then
        return nil, 'invalid_payload'
    end

    local location = locations[payload.locationId]
    if not location then return nil, 'spawn_location_invalid' end

    local attemptId, err = UP.Players.beginSpawn(source, publicLocation(location))
    if not attemptId then return nil, err end
    return { attemptId = attemptId }
end

function UP.Spawns.complete(source, payload)
    if type(payload) ~= 'table' or type(payload.attemptId) ~= 'string' then
        return nil, 'invalid_payload'
    end
    return UP.Players.completeSpawn(source, payload.attemptId)
end
