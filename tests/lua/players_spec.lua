UP = {
    players = {},
    accountSources = {},
    pendingPlayers = {},
    playerMutations = {},
    spawnSequence = 0,
    authorizationSequence = 0,
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
        characterReady = 'up:characterReady',
        spawnAuthorized = 'up:spawnAuthorized',
        playerSpawned = 'up:playerSpawned'
    }
}
UPConfig = {
    connection = { authorizationTtlSeconds = 30 },
    spawn = { attemptTimeoutMs = 15000 }
}

local handlers = {}
local dropped
local loaded
local selected
local authorized
local ready
local spawned

function AddEventHandler(name, handler)
    handlers[name] = handler
end

function TriggerEvent(name, ...)
    if name == UPContracts.events.playerLoaded then loaded = { ... } end
    if name == UPContracts.events.playerSpawned then spawned = { ... } end
end

function TriggerClientEvent(name, playerSource, payload)
    if name == UPContracts.events.characterSelected then
        selected = { playerSource, payload }
    end
    if name == UPContracts.events.spawnAuthorized then
        authorized = { playerSource, payload }
    end
    if name == UPContracts.events.characterReady then
        ready = { playerSource, payload }
    end
end
function Wait() end
function GetGameTimer() return 123 end
function SetTimeout(_, handler)
    if not _G.expirePending then
        _G.expirePending = handler
    else
        _G.expireSpawn = handler
    end
end
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
assert(UP.pendingPlayers[7].account.id == 'account-1')
assert(UP.pendingPlayers[7].expiresAt >= os.time())

source = 42
handlers.playerJoining('7')
assert(UP.pendingPlayers[7] == nil)
assert(UP.players[42].accountId == 'account-1')
assert(UP.players[42].phase == 'account_ready')
assert(UP.players[42].loaded == false)
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

local attemptId = assert(UP.Players.beginSpawn(42, { id = 'airport' }))
assert(UP.players[42].phase == 'spawning')
assert(authorized[1] == 42 and authorized[2].attemptId == attemptId)

local invalid, invalidError = UP.Players.completeSpawn(42, 'invalid')
assert(invalid == nil and invalidError == 'spawn_attempt_invalid')
assert(UP.Players.completeSpawn(42, attemptId))
assert(UP.players[42].phase == 'spawned')
assert(UP.players[42].loaded == true)
assert(UP.players[42].spawnLocationId == 'airport')
assert(spawned[1] == 42 and ready[2].phase == 'spawned')

UP.players[42].phase = 'character_selected'
local expiringAttempt = assert(UP.Players.beginSpawn(42, { id = 'airport' }))
assert(expiringAttempt ~= attemptId)
expireSpawn()
assert(UP.players[42].phase == 'character_selected')
assert(UP.players[42].spawnAttemptId == nil)
assert(UP.players[42].pendingSpawnLocationId == nil)

source = 43
handlers.playerJoining('999')
assert(dropped[1] == 43)
assert(dropped[2]:find('expired', 1, true))

UP.pendingPlayers[8] = {
    account = { id = 'account-1', status = 'active' },
    expiresAt = os.time() + 30,
    token = '8:1'
}
source = 44
handlers.playerJoining('8')
assert(dropped[1] == 44)
assert(dropped[2]:find('already connected', 1, true))

UP.pendingPlayers[9] = {
    account = { id = 'account-2', status = 'active' },
    expiresAt = os.time() - 1,
    token = '9:1'
}
source = 45
handlers.playerJoining('9')
assert(dropped[1] == 45)
assert(dropped[2]:find('expired', 1, true))

source = 42
handlers.playerDropped('test complete')
assert(UP.players[42] == nil)
assert(UP.accountSources['account-1'] == nil)
