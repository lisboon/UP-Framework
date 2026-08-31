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
local focus
local coreCalls = {}

exports = {
    up_core = {
        TriggerCallback = function(_, name, payload)
            coreCalls[#coreCalls + 1] = { name = name, payload = payload }
            if name == 'characters.delete' and payload.passport == -1 then error('core restarting') end
            if name == 'characters.bootstrap' then
                return { characters = {}, constraints = { maxPerAccount = 3 } }, nil
            end
            if name == 'characters.select' then return { passport = payload.passport }, nil end
            return true, nil
        end
    }
}

function RegisterNetEvent(name, handler) netHandlers[name] = handler end
function RegisterNUICallback(name, handler) nuiHandlers[name] = handler end
function AddEventHandler(name, handler) handlers[name] = handler end
function GetCurrentResourceName() return 'up_entry' end
function SendNUIMessage(message) messages[#messages + 1] = message end
function SetNuiFocus(keyboard, cursor) focus = { keyboard, cursor } end

dofile('resources/[up]/up_entry/client/ui.lua')

netHandlers[UPEntryContracts.events.entered]({ version = 1 })
assert(#messages == 0)

local readyReply
nuiHandlers['entry/ready']({ version = 1 }, function(response) readyReply = response end)
assert(readyReply.ok == true and readyReply.version == 1)
assert(messages[1].action == 'entry/open' and messages[1].version == 1)
assert(focus[1] == true and focus[2] == true)

local loadReply
nuiHandlers['characters/load']({ version = 1 }, function(response) loadReply = response end)
assert(loadReply.ok == true and loadReply.result.constraints.maxPerAccount == 3)
assert(coreCalls[#coreCalls].name == 'characters.bootstrap')

local createReply
nuiHandlers['characters/create']({
    version = 1,
    payload = { firstName = 'Ana', lastName = 'Silva', birthDate = '2000-02-29' }
}, function(response) createReply = response end)
assert(createReply.ok == true)
assert(coreCalls[#coreCalls].name == 'characters.create')

local selectReply
nuiHandlers['characters/select']({ version = 1, payload = { passport = 1000 } }, function(response)
    selectReply = response
end)
assert(selectReply.ok == true and selectReply.result.passport == 1000)
assert(focus[1] == false and focus[2] == false)

local unavailableReply
nuiHandlers['characters/delete']({ version = 1, payload = { passport = -1 } }, function(response)
    unavailableReply = response
end)
assert(unavailableReply.ok == false and unavailableReply.error == 'core_unavailable')

netHandlers[UPEntryContracts.events.left]({ version = 1, reason = 'entry_completed' })
assert(messages[2].action == 'entry/close')
assert(messages[2].payload.reason == 'entry_completed')

local invalidReply
nuiHandlers['entry/ready']({ version = 2 }, function(response) invalidReply = response end)
assert(invalidReply.ok == false and invalidReply.error == 'unsupported_version')

handlers.onClientResourceStop('up_entry')
assert(messages[3].action == 'entry/close')
