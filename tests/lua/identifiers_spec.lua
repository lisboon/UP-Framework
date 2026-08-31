UP = {}

local rawIdentifiers = {
    'steam:steam-id',
    'license:ros-license',
    'license2:ros-license-2',
    'discord:discord-id',
    'fivem:12345',
    'ip:127.0.0.1',
    'license2:ros-license-2'
}

function GetPlayerIdentifiers()
    return rawIdentifiers
end

dofile('resources/[up]/up_core/server/identity/identifiers.lua')

local identifiers = UP.Identifiers.collect(1)
assert(#identifiers == 5)
assert(identifiers[1].kind == 'license2')
assert(identifiers[2].kind == 'license')
assert(identifiers[3].kind == 'fivem')
assert(identifiers[4].kind == 'steam')
assert(identifiers[5].kind == 'discord')
assert(UP.Identifiers.primary(identifiers).kind == 'license2')
assert(identifiers[1].authoritative)
assert(not identifiers[4].authoritative)
