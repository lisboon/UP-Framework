fx_version 'cerulean'
game 'gta5'

author 'Wendel Lisboa'
description 'UP clean-room roleplay core'
version '0.1.0-dev'
license 'Apache-2.0'

lua54 'yes'

shared_scripts {
    'shared/contracts.lua',
    'shared/config.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/core/bootstrap.lua',
    'server/core/validation.lua',
    'server/identity/identifiers.lua',
    'server/identity/repository.lua',
    'server/identity/service.lua',
    'server/core/permissions.lua',
    'server/core/players.lua',
    'server/core/callbacks.lua',
    'server/characters/repository.lua',
    'server/characters/service.lua',
    'server/characters/callbacks.lua',
    'server/spawn/service.lua',
    'server/spawn/callbacks.lua',
    'server/core/exports.lua'
}

client_scripts {
    'client/core/callbacks.lua',
    'client/core/state.lua',
    'client/spawn/session.lua'
}

dependencies {
    '/server:8450',
    '/onesync',
    'oxmysql',
    'spawnmanager'
}
