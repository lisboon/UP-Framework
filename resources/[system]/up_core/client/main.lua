RegisterNetEvent(UPContracts.events.characterReady, function(state)
    if type(state) ~= 'table' then return end
    LocalPlayer.state:set('up:passport', state.passport, false)
    LocalPlayer.state:set('up:loaded', true, false)
end)
