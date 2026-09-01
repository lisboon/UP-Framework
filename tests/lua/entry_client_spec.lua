UPEntryContracts = {
    version = 1,
    events = {
        clientReady = 'up:entry:clientReady',
        entered = 'up:entry:entered',
        left = 'up:entry:left'
    }
}
UPEntryConfig = {
    stateRecovery = {
        enabled = true,
        retryDelaysMs = { 0, 250, 750, 1750 }
    }
}

local netHandlers = {}
local handlers = {}
local calls = {}
local serverEvents = {}
local timers = {}
local stateBagHandler
local frozenBeforeEntry = true
local playerActive = true

LocalPlayer = { state = { ['up:entry'] = false } }

function RegisterNetEvent(name, handler)
    netHandlers[name] = handler
end

function AddEventHandler(name, handler)
    handlers[name] = handler
end

function AddStateBagChangeHandler(key, bag, handler)
    assert(key == 'up:entry' and bag == nil)
    stateBagHandler = handler
    return 1
end

function SetTimeout(delay, handler)
    timers[#timers + 1] = { delay = delay, handler = handler, ran = false }
end

function SetNuiFocus(focus, cursor) calls.focus = { focus, cursor } end
function RenderScriptCams(active) calls.camera = active end
function ClearTimecycleModifier() calls.timecycleCleared = true end
function DisplayRadar(visible) calls.radar = visible end
function PlayerPedId() return 7 end
function PlayerId() return 3 end
function GetPlayerServerId() return 42 end
function NetworkIsPlayerActive() return playerActive end
function IsRadarHidden() return false end
function IsEntityPositionFrozen() return frozenBeforeEntry end
function IsEntityVisible() return true end
function GetPlayerInvincible() return false end
function FreezeEntityPosition(_, frozen) calls.frozen = frozen end
function SetEntityVisible(_, visible) calls.visible = visible end
function SetPlayerInvincible(_, invincible) calls.invincible = invincible end
function GetCurrentResourceName() return 'up_entry' end
function TriggerServerEvent(name, payload)
    serverEvents[#serverEvents + 1] = { name = name, payload = payload }
end

local function setLocalEntryState(value)
    LocalPlayer.state['up:entry'] = value
    stateBagHandler('player:42', 'up:entry', value, 0, true)
end

local function runTimers(first, last)
    for index = first, last do
        local timer = assert(timers[index], ('missing timer %d'):format(index))
        assert(not timer.ran, ('timer %d ran twice'):format(index))
        timer.ran = true
        timer.handler()
    end
end

dofile('resources/[up]/up_entry/client/session.lua')

assert(type(stateBagHandler) == 'function')

-- Invalid or redundant leave events remain harmless.
netHandlers[UPEntryContracts.events.left]({ version = 1 })
assert(calls.camera == nil)
assert(calls.timecycleCleared == nil)

-- A normal resource start with no replicated entry state performs one handshake.
handlers.onClientResourceStart('up_entry')
assert(#serverEvents == 1)
assert(serverEvents[1].name == UPEntryContracts.events.clientReady)
assert(serverEvents[1].payload.version == 1)

-- A lost entered event starts one bounded sequence at the exact configured offsets.
serverEvents = {}
stateBagHandler('player:99', 'up:entry', true, 0, true)
assert(#timers == 0)
setLocalEntryState(true)
assert(#timers == 4)
assert(timers[1].delay == 0)
assert(timers[2].delay == 250)
assert(timers[3].delay == 750)
assert(timers[4].delay == 1750)
runTimers(1, 4)
assert(#serverEvents == 4)
for _, event in ipairs(serverEvents) do
    assert(event.name == UPEntryContracts.events.clientReady)
    assert(event.payload.version == 1)
end

-- Repeated notifications for the same divergence cannot create another sequence.
setLocalEntryState(true)
assert(#timers == 4)
setLocalEntryState(false)

-- Synchronization on any attempt cancels every remaining callback.
serverEvents = {}
setLocalEntryState(true)
assert(#timers == 8)
runTimers(5, 5)
netHandlers[UPEntryContracts.events.entered]({ version = 1 })
runTimers(6, 8)
assert(#serverEvents == 1)
assert(calls.radar == false)
assert(calls.frozen == true)
assert(calls.visible == false)
assert(calls.invincible == true)

-- Spawn completion restores gameplay state and also resets recovery eligibility.
netHandlers[UPEntryContracts.events.left]({ version = 1, reason = 'player_spawned' })
setLocalEntryState(false)
assert(calls.radar == true)
assert(calls.frozen == false)
assert(calls.visible == true)
assert(calls.invincible == false)
assert(calls.camera == false)
assert(calls.timecycleCleared == true)

-- A left event cancels a pending sequence before the first attempt.
serverEvents = {}
setLocalEntryState(true)
assert(#timers == 12)
netHandlers[UPEntryContracts.events.left]({ version = 1, reason = 'entry_state_reconciled' })
runTimers(9, 12)
assert(#serverEvents == 0)
setLocalEntryState(false)

-- Resource stop cancels timers even while no entry presentation is active.
setLocalEntryState(true)
assert(#timers == 16)
handlers.onClientResourceStop('up_entry')
runTimers(13, 16)
assert(#serverEvents == 0)
setLocalEntryState(false)

-- Losing the local player terminates the sequence without further retries.
setLocalEntryState(true)
assert(#timers == 20)
playerActive = false
runTimers(17, 20)
assert(#serverEvents == 0)
playerActive = true
setLocalEntryState(false)

-- Resource cleanup still restores the exact pre-entry snapshot when appropriate.
frozenBeforeEntry = true
netHandlers[UPEntryContracts.events.entered]({ version = 1 })
handlers.onClientResourceStop('up_entry')
assert(calls.frozen == true and calls.visible == true)

frozenBeforeEntry = true
netHandlers[UPEntryContracts.events.entered]({ version = 1 })
netHandlers[UPEntryContracts.events.left]({ version = 1, reason = 'entry_state_reconciled' })
assert(calls.frozen == false and calls.visible == true and calls.invincible == false)
