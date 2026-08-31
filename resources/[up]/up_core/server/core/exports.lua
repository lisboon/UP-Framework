exports('GetPlayerState', function(source)
    return UP.Players.get(source)
end)

exports('GetPassport', function(source)
    local player = UP.Players.get(source)
    return player and player.passport or nil
end)

exports('HasPermission', function(source, permission)
    return UP.Permissions.has(source, permission)
end)

exports('RegisterCallback', function(name, handler)
    UP.Callbacks.register(name, handler)
end)

exports('ListCharacters', function(source)
    return UP.Characters.list(source)
end)

exports('CreateCharacter', function(source, payload)
    return UP.Characters.create(source, payload)
end)

exports('DeleteCharacter', function(source, passport)
    return UP.Characters.delete(source, passport)
end)

exports('SelectCharacter', function(source, passport)
    return UP.Characters.select(source, passport)
end)

exports('IsReady', function()
    return UP.ready
end)
