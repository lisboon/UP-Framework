RegisterNetEvent(UPContracts.events.spawnAuthorized, function(payload)
    if type(payload) ~= 'table'
        or type(payload.attemptId) ~= 'string'
        or type(payload.location) ~= 'table'
        or type(payload.location.coordinates) ~= 'table'
    then
        return
    end

    local coordinates = payload.location.coordinates
    if type(coordinates.x) ~= 'number'
        or type(coordinates.y) ~= 'number'
        or type(coordinates.z) ~= 'number'
        or type(coordinates.heading) ~= 'number'
    then
        return
    end

    exports.spawnmanager:spawnPlayer({
        x = coordinates.x,
        y = coordinates.y,
        z = coordinates.z,
        heading = coordinates.heading,
        skipFade = false
    }, function()
        TriggerServerEvent(UPContracts.events.spawnCompleted, {
            version = UPContracts.version,
            attemptId = payload.attemptId
        })
    end)
end)
