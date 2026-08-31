UP = {
    players = {},
    pendingPlayers = {},
    rateLimits = {},
    ready = true,
    Players = {},
    Identity = {},
    Validation = {}
}
UPContracts = {
    events = {
        playerLoaded = 'up:playerLoaded',
        playerUnloaded = 'up:playerUnloaded',
        characterActivated = 'up:characterActivated',
        characterReady = 'up:characterReady'
    }
}

local handlers = {}
local dropped
local loaded

function AddEventHandler(name, handler)
    handlers[name] = handler
end

function TriggerEvent(name, ...)
    if name == UPContracts.events.playerLoaded then loaded = { ... } end
end

function TriggerClientEvent() end
function Wait() end
function SetTimeout(_, handler) _G.expirePending = handler end
function DropPlayer(playerSource, reason) dropped = { playerSource, reason } end

function UP.Identity.resolve()
    return { id = 'account-1', status = 'active' }
end

dofile('resources/[up]/up_core/server/core/players.lua')

local doneReason = false
local deferrals = {
    defer = function() end,
    update = function() end,
    done = function(reason) doneReason = reason end
}

source = 7
handlers.playerConnecting(nil, nil, deferrals)
assert(doneReason == nil)
assert(UP.pendingPlayers[7].id == 'account-1')

source = 42
handlers.playerJoining('7')
assert(UP.pendingPlayers[7] == nil)
assert(UP.players[42].accountId == 'account-1')
assert(loaded[1] == 42)

expirePending()
assert(UP.players[42].accountId == 'account-1')

source = 43
handlers.playerJoining('999')
assert(dropped[1] == 43)
assert(dropped[2]:find('expired', 1, true))
