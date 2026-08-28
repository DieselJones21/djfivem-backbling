fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'dj-backbling'
author 'DieselJones21'
description 'Synced melee weapons on your back, like back blings'
version '1.0.0'

shared_scripts {
    'config.lua',
    'shared/utils.lua',
}

client_scripts {
    'client/inventory.lua',
    'client/main.lua',
    'client/editor.lua',
}

server_scripts {
    'server/main.lua',
}

provide 'dj-backbling'
