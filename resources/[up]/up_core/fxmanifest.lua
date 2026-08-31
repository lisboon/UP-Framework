fx_version 'cerulean'
game 'gta5'

author 'Wendel Lisboa'
description 'UP clean-room roleplay core'
version '0.0.1-dev'
license 'Apache-2.0'

lua54 'yes'

shared_scripts {
    'shared/contracts.lua',
    'shared/config.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/bootstrap.lua',
    'server/validation.lua',
    'server/identifiers.lua',
    'server/permissions.lua',
    'server/players.lua',
    'server/callbacks.lua',
    'server/exports.lua'
}

client_scripts {
    'client/callbacks.lua',
    'client/main.lua'
}

dependencies {
    '/server:8450',
    '/onesync',
    'oxmysql'
}
