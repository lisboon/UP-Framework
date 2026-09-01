UP.Spawns = {}

local locations = {}
local validAttestationModes = {
    exempt = true,
    position = true
}

local function validateAttestation(policy, context)
    assert(type(policy) == 'table', context .. ' attestation policy is required')
    assert(validAttestationModes[policy.mode], context .. ' attestation mode is invalid')
    if policy.mode == 'position' then
        assert(type(policy.stabilizationMs) == 'number'
            and policy.stabilizationMs >= 0
            and policy.stabilizationMs == math.floor(policy.stabilizationMs),
            context .. ' attestation stabilization must be a non-negative integer')
        assert(type(policy.tolerance) == 'number' and policy.tolerance > 0,
            context .. ' attestation tolerance must be positive')
    else
        assert(type(policy.reason) == 'string' and policy.reason ~= '',
            context .. ' attestation exemption reason is required')
    end
end

local function copyCoordinates(coordinates)
    return {
        x = coordinates.x,
        y = coordinates.y,
        z = coordinates.z,
        heading = coordinates.heading
    }
end

local function attestationFor(location)
    local provider = UPConfig.spawn.providers[location.provider]
    local configured = location.attestation or provider.attestation
    local policy = {
        mode = configured.mode,
        provider = location.provider,
        coordinates = copyCoordinates(location.coordinates)
    }
    if configured.mode == 'position' then
        policy.stabilizationMs = configured.stabilizationMs
        policy.tolerance = configured.tolerance
    else
        policy.reason = configured.reason
    end
    return policy
end

local function diagnostic(event, fields)
    fields.component = 'up_core'
    fields.event = event
    print(json.encode(fields))
end

assert(type(UPConfig.spawn.providers) == 'table', 'spawn providers are required')
for providerName, provider in pairs(UPConfig.spawn.providers) do
    assert(type(providerName) == 'string' and providerName ~= '', 'spawn provider name is invalid')
    assert(type(provider) == 'table', ('spawn provider %s is invalid'):format(providerName))
    validateAttestation(provider.attestation, ('spawn provider %s'):format(providerName))
end

for _, location in ipairs(UPConfig.spawn.locations) do
    assert(type(location.id) == 'string' and location.id ~= '', 'spawn location id is required')
    assert(type(location.label) == 'string' and location.label ~= '', 'spawn location label is required')
    assert(type(location.coordinates) == 'table', 'spawn location coordinates are required')
    assert(type(location.coordinates.x) == 'number', 'spawn location x coordinate is required')
    assert(type(location.coordinates.y) == 'number', 'spawn location y coordinate is required')
    assert(type(location.coordinates.z) == 'number', 'spawn location z coordinate is required')
    assert(type(location.coordinates.heading) == 'number', 'spawn location heading is required')
    assert(type(location.provider) == 'string'
        and UPConfig.spawn.providers[location.provider] ~= nil,
        ('spawn location %s provider is invalid'):format(location.id))
    if location.attestation then
        validateAttestation(location.attestation, ('spawn location %s'):format(location.id))
    end
    assert(locations[location.id] == nil, ('duplicate spawn location: %s'):format(location.id))
    locations[location.id] = location
end

local function publicLocation(location)
    return {
        id = location.id,
        label = location.label,
        coordinates = copyCoordinates(location.coordinates)
    }
end

local function rejectAttestation(source, attemptId, reason, policy, actual)
    local rejected = UP.Players.failSpawn(source, attemptId, reason)
    if not rejected then return end

    diagnostic('spawn_attestation_rejected', {
        source = source,
        attemptId = attemptId,
        provider = policy.provider,
        reason = reason,
        expected = policy.coordinates,
        actual = actual
    })
end

local function attestPosition(source, attemptId, policy)
    local player = UP.Players.getSpawnAttempt(source, attemptId)
    if not player then return end

    local ped = GetPlayerPed(source)
    if not ped or ped <= 0 then
        rejectAttestation(source, attemptId, 'spawn_entity_unavailable', policy)
        return
    end

    local actual = GetEntityCoords(ped)
    if not actual then
        rejectAttestation(source, attemptId, 'spawn_position_unavailable', policy)
        return
    end

    local dx = actual.x - policy.coordinates.x
    local dy = actual.y - policy.coordinates.y
    local dz = actual.z - policy.coordinates.z
    local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
    if distance > policy.tolerance then
        rejectAttestation(source, attemptId, 'spawn_position_mismatch', policy, {
            x = actual.x,
            y = actual.y,
            z = actual.z,
            distance = distance
        })
        return
    end

    local completed = UP.Players.completeSpawn(source, attemptId)
    if completed then
        diagnostic('spawn_attestation_accepted', {
            source = source,
            attemptId = attemptId,
            provider = policy.provider,
            distance = distance,
            tolerance = policy.tolerance
        })
    end
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

    local attemptId, err = UP.Players.beginSpawn(
        source,
        publicLocation(location),
        attestationFor(location)
    )
    if not attemptId then return nil, err end
    return { attemptId = attemptId }
end

function UP.Spawns.complete(source, payload)
    if type(payload) ~= 'table' or type(payload.attemptId) ~= 'string' then
        return nil, 'invalid_payload'
    end
    local player, err = UP.Players.getSpawnAttempt(source, payload.attemptId)
    if not player then return nil, err end
    local policy = player.spawnAttestation
    if not policy then return nil, 'spawn_attestation_missing' end

    if policy.mode == 'exempt' then
        diagnostic('spawn_attestation_exempted', {
            source = source,
            attemptId = payload.attemptId,
            provider = policy.provider,
            reason = policy.reason
        })
        return UP.Players.completeSpawn(source, payload.attemptId)
    end

    local pending, pendingError = UP.Players.beginSpawnAttestation(source, payload.attemptId)
    if not pending then return nil, pendingError end
    SetTimeout(policy.stabilizationMs, function()
        attestPosition(source, payload.attemptId, policy)
    end)
    return { pending = true }
end
