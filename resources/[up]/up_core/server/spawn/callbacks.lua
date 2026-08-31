UP.Callbacks.register('spawns.list', function(source)
    return UP.Spawns.list(source)
end)

UP.Callbacks.register('spawns.select', function(source, payload)
    return UP.Spawns.select(source, payload)
end)

RegisterNetEvent(UPContracts.events.spawnCompleted, function(envelope)
    if type(envelope) ~= 'table' or envelope.version ~= UPContracts.version then return end
    UP.Spawns.complete(source, envelope)
end)
