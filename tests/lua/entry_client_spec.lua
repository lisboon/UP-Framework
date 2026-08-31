UPEntryContracts = {
    version = 1,
    events = {
        clientReady = 'up:entry:clientReady',
        entered = 'up:entry:entered',
        left = 'up:entry:left'
    }
}

local netHandlers = {}
local handlers = {}
local calls = {}
local serverEvent

function RegisterNetEvent(name, handler)
    netHandlers[name] = handler
end

function AddEventHandler(name, handler)
    handlers[name] = handler
end

function SetNuiFocus(focus, cursor) calls.focus = { focus, cursor } end
function RenderScriptCams(active) calls.camera = active end
function ClearTimecycleModifier() calls.timecycleCleared = true end
function DisplayRadar(visible) calls.radar = visible end
function PlayerPedId() return 7 end
function PlayerId() return 3 end
function IsRadarHidden() return false end
function IsEntityPositionFrozen() return false end
function IsEntityVisible() return true end
function GetPlayerInvincible() return false end
function FreezeEntityPosition(_, frozen) calls.frozen = frozen end
function SetEntityVisible(_, visible) calls.visible = visible end
function SetPlayerInvincible(_, invincible) calls.invincible = invincible end
function GetCurrentResourceName() return 'up_entry' end
function TriggerServerEvent(name, payload) serverEvent = { name = name, payload = payload } end

dofile('resources/[up]/up_entry/client/session.lua')

netHandlers[UPEntryContracts.events.left]({ version = 1 })
assert(calls.camera == nil)
assert(calls.timecycleCleared == nil)

handlers.onClientResourceStart('up_entry')
assert(serverEvent.name == UPEntryContracts.events.clientReady)
assert(serverEvent.payload.version == 1)

netHandlers[UPEntryContracts.events.entered]({ version = 1 })
assert(calls.radar == false)
assert(calls.frozen == true)
assert(calls.visible == false)
assert(calls.invincible == true)

netHandlers[UPEntryContracts.events.left]({ version = 1 })
assert(calls.radar == true)
assert(calls.frozen == false)
assert(calls.visible == true)
assert(calls.invincible == false)
assert(calls.camera == false)
assert(calls.timecycleCleared == true)

netHandlers[UPEntryContracts.events.entered]({ version = 1 })
handlers.onClientResourceStop('up_entry')
assert(calls.frozen == false and calls.visible == true)
