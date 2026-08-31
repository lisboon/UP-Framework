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

exports('ActivateCharacter', function(source, passport)
    return UP.Players.activateCharacter(source, passport)
end)

exports('IsReady', function()
    return UP.ready
end)
