--[[ FX Information ]] --
fx_version 'cerulean'
use_experimental_fxv2_oal 'yes'
lua54 'yes'
game 'gta5'
author 'Katoteki'
repository 'https://github.com/uniqscripts/uniq_vending_standalone'
version '1.0.0'


dependencies {
    '/server:6116',
    '/onesync',
    'oxmysql',
    'ox_lib',
	-- brain
}

shared_scripts {
	'@ox_lib/init.lua',
	'locales.lua',
	'locales/*.lua',
	'bridge/framework.lua',
}
server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'bridge/**/server.lua',
	'server/*'
}
client_scripts {
	'bridge/**/client.lua',
	'client/main.lua'
}

files { 'config/config.lua', 'client/**' }