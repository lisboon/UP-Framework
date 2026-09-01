local active = false
local snapshot
local gameplayLeaveReasons = {
    entry_state_reconciled = true,
    player_spawned = true
}

local function restoreClient(reason)
    if not active then return false end

    SetNuiFocus(false, false)
    RenderScriptCams(false, false, 0, true, true)
    ClearTimecycleModifier()

    local ped = PlayerPedId()
    if gameplayLeaveReasons[reason] then
        DisplayRadar(true)
        FreezeEntityPosition(ped, false)
        SetEntityVisible(ped, true, false)
        SetPlayerInvincible(PlayerId(), false)
    elseif snapshot then
        DisplayRadar(not snapshot.radarHidden)
        FreezeEntityPosition(ped, snapshot.frozen)
        SetEntityVisible(ped, snapshot.visible, false)
        SetPlayerInvincible(PlayerId(), snapshot.invincible)
    end

    snapshot = nil
    active = false
    return true
end

RegisterNetEvent(UPEntryContracts.events.entered, function(envelope)
    if type(envelope) ~= 'table' or envelope.version ~= UPEntryContracts.version then return end

    local ped = PlayerPedId()
    if not active then
        snapshot = {
            radarHidden = IsRadarHidden(),
            frozen = IsEntityPositionFrozen(ped),
            visible = IsEntityVisible(ped),
            invincible = GetPlayerInvincible(PlayerId())
        }
    end

    SetNuiFocus(false, false)
    DisplayRadar(false)
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false, false)
    SetPlayerInvincible(PlayerId(), true)
    active = true
end)

RegisterNetEvent(UPEntryContracts.events.left, function(envelope)
    if type(envelope) ~= 'table' or envelope.version ~= UPEntryContracts.version then return end
    restoreClient(envelope.reason)
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    TriggerServerEvent(UPEntryContracts.events.clientReady, {
        version = UPEntryContracts.version
    })
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() or not active then return end
    restoreClient('resource_stopped')
end)
