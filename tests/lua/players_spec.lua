UP = {
    players = {},
    accountSources = {},
    pendingPlayers = {},
    playerMutations = {},
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
        characterSelected = 'up:characterSelected',
        characterReady = 'up:characterReady'
    }
}

local handlers = {}
local dropped
local loaded
local selected

function AddEventHandler(name, handler)
    handlers[name] = handler
end

function TriggerEvent(name, ...)
    if name == UPContracts.events.playerLoaded then loaded = { ... } end
end

function TriggerClientEvent(name, playerSource, payload)
    if name == UPContracts.events.characterSelected then
        selected = { playerSource, payload }
    end
end
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
assert(UP.players[42].phase == 'account_ready')
assert(UP.accountSources['account-1'] == 42)
assert(loaded[1] == 42)

local activated, state = UP.Players.activateCharacter(42, {
    id = 'character-1',
    passport = 1000
})
assert(activated and state.phase == 'character_selected')
assert(selected[1] == 42 and selected[2].passport == 1000)

expirePending()
assert(UP.players[42].accountId == 'account-1')

source = 43
handlers.playerJoining('999')
assert(dropped[1] == 43)
assert(dropped[2]:find('expired', 1, true))

UP.pendingPlayers[8] = { id = 'account-1', status = 'active' }
source = 44
handlers.playerJoining('8')
assert(dropped[1] == 44)
assert(dropped[2]:find('already connected', 1, true))

source = 42
handlers.playerDropped('test complete')
assert(UP.players[42] == nil)
assert(UP.accountSources['account-1'] == nil)
