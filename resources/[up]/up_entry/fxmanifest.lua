fx_version 'cerulean'
game 'gta5'

author 'Wendel Lisboa'
description 'UP entry experience runtime'
version '0.1.0-dev'
license 'Apache-2.0'

lua54 'yes'

shared_scripts {
    'shared/contracts.lua',
    'shared/config.lua'
}

server_script 'server/session.lua'
client_script 'client/session.lua'

dependency 'up_core'
