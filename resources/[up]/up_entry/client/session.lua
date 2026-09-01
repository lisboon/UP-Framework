local active = false
local snapshot
local recovery = {
    exhausted = false,
    generation = 0,
    running = false
}
local gameplayLeaveReasons = {
    entry_state_reconciled = true,
    player_spawned = true
}

local recoveryConfig = UPEntryConfig.stateRecovery
assert(type(recoveryConfig) == 'table', 'entry state recovery config is required')
assert(type(recoveryConfig.enabled) == 'boolean', 'entry state recovery flag must be boolean')
assert(type(recoveryConfig.retryDelaysMs) == 'table'
    and #recoveryConfig.retryDelaysMs > 0, 'entry state recovery delays are required')

local previousDelay = -1
for _, delay in ipairs(recoveryConfig.retryDelaysMs) do
    assert(type(delay) == 'number'
        and delay == math.floor(delay)
        and delay >= 0
        and delay > previousDelay, 'entry state recovery delays must be increasing non-negative integers')
    previousDelay = delay
end

local function sendClientReady()
    TriggerServerEvent(UPEntryContracts.events.clientReady, {
        version = UPEntryContracts.version
    })
end

local function localEntryStateIsActive()
    return LocalPlayer.state['up:entry'] == true
end

local function localPlayerIsAvailable()
    return NetworkIsPlayerActive(PlayerId())
end

local function cancelRecovery(resetExhaustion)
    recovery.generation = recovery.generation + 1
    recovery.running = false
    if resetExhaustion then recovery.exhausted = false end
end

local function startRecovery()
    if not recoveryConfig.enabled
        or active
        or recovery.running
        or recovery.exhausted
        or not localEntryStateIsActive()
    then
        return false
    end

    recovery.generation = recovery.generation + 1
    recovery.running = true
    local generation = recovery.generation

    for index, delay in ipairs(recoveryConfig.retryDelaysMs) do
        SetTimeout(delay, function()
            if recovery.generation ~= generation then return end

            if active or not localEntryStateIsActive() then
                cancelRecovery(true)
                return
            end

            if not localPlayerIsAvailable() then
                cancelRecovery(false)
                recovery.exhausted = true
                return
            end

            sendClientReady()

            if index == #recoveryConfig.retryDelaysMs then
                recovery.running = false
                recovery.exhausted = true
            end
        end)
    end

    return true
end

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

    cancelRecovery(true)

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
    cancelRecovery(true)
    restoreClient(envelope.reason)
end)

AddStateBagChangeHandler('up:entry', nil, function(bagName, _, value)
    local localBagName = ('player:%d'):format(GetPlayerServerId(PlayerId()))
    if bagName ~= localBagName then return end

    if value == true then
        startRecovery()
    else
        cancelRecovery(true)
    end
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    cancelRecovery(true)
    if not startRecovery() then sendClientReady() end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    cancelRecovery(true)
    if active then restoreClient('resource_stopped') end
end)
