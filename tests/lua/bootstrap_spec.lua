UP = nil
UPConfig = {
    schemaVersion = 2
}
UPContracts = {
    version = 1
}

local readyHandler
local stopHandler
local dropped = {}

MySQL = {
    ready = function(handler)
        readyHandler = handler
    end,
    scalar = {
        await = function()
            return 2
        end
    }
}

function GetResourceState(resourceName)
    assert(resourceName == 'oxmysql')
    return 'started'
end

function GetPlayers()
    return { '41', '42', '43', '44' }
end

function DropPlayer(playerSource, reason)
    dropped[playerSource] = reason
end

function AddEventHandler(name, handler)
    assert(name == 'onResourceStop')
    stopHandler = handler
end

function GetCurrentResourceName()
    return 'up_core'
end

function print() end

dofile('resources/[up]/up_core/server/core/bootstrap.lua')

assert(UP.ready == false)
assert(type(readyHandler) == 'function')
readyHandler()
assert(UP.ready == true)

for source = 41, 44 do
    assert(dropped[source] == 'UP core restarted. Please reconnect.')
end

UP.players[41] = { phase = 'account_ready' }
UP.players[42] = { phase = 'character_selected' }
UP.players[43] = { phase = 'spawning' }
UP.players[44] = { phase = 'spawned' }
UP.accountSources.account = 41
UP.rateLimits[41] = {}
UP.characterMutations.character = true
UP.playerMutations[41] = true
UP.pendingPlayers[1] = true
UP.spawnSequence = 8
UP.authorizationSequence = 9

stopHandler('another_resource')
assert(UP.ready == true)
assert(UP.players[41] ~= nil)

stopHandler('up_core')
assert(UP.ready == false)
assert(next(UP.players) == nil)
assert(next(UP.accountSources) == nil)
assert(next(UP.rateLimits) == nil)
assert(next(UP.characterMutations) == nil)
assert(next(UP.playerMutations) == nil)
assert(next(UP.pendingPlayers) == nil)
assert(UP.spawnSequence == 0)
assert(UP.authorizationSequence == 0)
