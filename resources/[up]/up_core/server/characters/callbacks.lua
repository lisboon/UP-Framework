UP.Callbacks.register('characters.list', function(source)
    return UP.Characters.list(source)
end)

UP.Callbacks.register('characters.bootstrap', function(source)
    return UP.Characters.bootstrap(source)
end)

UP.Callbacks.register('characters.create', function(source, payload)
    return UP.Characters.create(source, payload)
end)

UP.Callbacks.register('characters.delete', function(source, payload)
    if type(payload) ~= 'table' then return nil, 'invalid_payload' end
    return UP.Characters.delete(source, payload.passport)
end)

UP.Callbacks.register('characters.select', function(source, payload)
    if type(payload) ~= 'table' then return nil, 'invalid_payload' end
    return UP.Characters.select(source, payload.passport)
end)
