fx_version 'cerulean'
game 'gta5'

author 'Reestructurado para qbox'
description 'Sistema de taxis modernizado para QBox y ox_lib'
version '3.0.0'
lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua', -- Inicialización de ox_lib
    'shared/config.lua', -- Configuración
    'shared/locales.lua' -- Idiomas
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua', -- Base de datos (si aplica)
    'server/payment.lua',
    'server/main.lua'
}
