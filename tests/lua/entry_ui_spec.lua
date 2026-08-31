UPEntryContracts = {
    version = 1,
    uiVersion = 1,
    events = {
        entered = 'up:entry:entered',
        left = 'up:entry:left'
    },
    coreEvents = { spawnFailed = 'up:spawn:failed' }
}

UPEntryPresentation = {
    preview = function(passport) return passport == 1000 end,
    previewLocation = function(location) return location and location.id == 'airport' end,
    commitLocation = function(location) return location and location.id == 'airport' end,
    resumeLocation = function() return true end
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
            if name == 'spawns.list' then
                return {{ id = 'airport', label = 'Airport', coordinates = { x = 1.0, y = 2.0, z = 3.0, heading = 4.0 } }}, nil
            end
            if name == 'spawns.select' then return { attemptId = '42:1' }, nil end
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
assert(focus[1] == true and focus[2] == true)

local previewReply
nuiHandlers['characters/preview']({ version = 1, payload = { passport = 1000 } }, function(response)
    previewReply = response
end)
assert(previewReply.ok == true and previewReply.result == true)

local locationsReply
nuiHandlers['spawns/load']({ version = 1, payload = {} }, function(response) locationsReply = response end)
assert(locationsReply.ok == true and locationsReply.result[1].id == 'airport')
assert(locationsReply.result[1].coordinates == nil)

local locationPreviewReply
nuiHandlers['spawns/preview']({ version = 1, payload = { locationId = 'airport' } }, function(response) locationPreviewReply = response end)
assert(locationPreviewReply.ok == true)

local spawnReply
nuiHandlers['spawns/select']({ version = 1, payload = { locationId = 'airport' } }, function(response) spawnReply = response end)
assert(spawnReply.ok == true and spawnReply.result.attemptId == '42:1')
assert(focus[1] == false and focus[2] == false)

netHandlers[UPEntryContracts.coreEvents.spawnFailed]({ version = 1, reason = 'spawn_attempt_expired' })
assert(focus[1] == true and focus[2] == true)
assert(messages[#messages].action == 'spawn/failed')

local unavailableReply
nuiHandlers['characters/delete']({ version = 1, payload = { passport = -1 } }, function(response)
    unavailableReply = response
end)
assert(unavailableReply.ok == false and unavailableReply.error == 'core_unavailable')

netHandlers[UPEntryContracts.events.left]({ version = 1, reason = 'entry_completed' })
assert(messages[#messages].action == 'entry/close')
assert(messages[#messages].payload.reason == 'entry_completed')

local invalidReply
nuiHandlers['entry/ready']({ version = 2 }, function(response) invalidReply = response end)
assert(invalidReply.ok == false and invalidReply.error == 'unsupported_version')

handlers.onClientResourceStop('up_entry')
assert(messages[#messages].action == 'entry/close')
