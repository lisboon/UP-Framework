UPEntryContracts = {
    version = 1,
    uiVersion = 1,
    events = {
        entered = 'up:entry:entered',
        left = 'up:entry:left'
    }
}

local netHandlers = {}
local handlers = {}
local nuiHandlers = {}
local messages = {}

function RegisterNetEvent(name, handler) netHandlers[name] = handler end
function RegisterNUICallback(name, handler) nuiHandlers[name] = handler end
function AddEventHandler(name, handler) handlers[name] = handler end
function GetCurrentResourceName() return 'up_entry' end
function SendNUIMessage(message) messages[#messages + 1] = message end

dofile('resources/[up]/up_entry/client/ui.lua')

netHandlers[UPEntryContracts.events.entered]({ version = 1 })
assert(#messages == 0)

local readyReply
nuiHandlers['entry/ready']({ version = 1 }, function(response) readyReply = response end)
assert(readyReply.ok == true and readyReply.version == 1)
assert(messages[1].action == 'entry/open' and messages[1].version == 1)

netHandlers[UPEntryContracts.events.left]({ version = 1, reason = 'entry_completed' })
assert(messages[2].action == 'entry/close')
assert(messages[2].payload.reason == 'entry_completed')

local invalidReply
nuiHandlers['entry/ready']({ version = 2 }, function(response) invalidReply = response end)
assert(invalidReply.ok == false and invalidReply.error == 'unsupported_version')

handlers.onClientResourceStop('up_entry')
assert(messages[3].action == 'entry/close')
