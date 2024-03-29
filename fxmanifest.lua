fx_version 'cerulean'

author 'Randolio'
description 'Submarine Heist'
game 'gta5'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts{
    'bridge/client/**.lua',
    'cl_subheist.lua',
}

server_scripts{
    '@oxmysql/lib/MySQL.lua',
    'bridge/server/**.lua',
    'sv_config.lua',
    'sv_subheist.lua',
}

lua54 'yes'