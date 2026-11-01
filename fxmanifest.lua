fx_version 'cerulean'
game 'gta5'

author 'Siku Studio'
description 'In-game capture studio for FiveM. Create screenshots, GIFs and video clips of clothing, animations, vehicles and props using customizable backdrops, camera controls and automated capture workflows.'
version '0.0.1'

name 'siku_studio'

lua54 'yes'

shared_scripts {
  '@siku_core/init.lua',
  'config/*.lua',
}

server_scripts {
  'server/init.lua',
  'server/modules/*.lua',
}

client_scripts {
  'client/modules/*.lua',
}

files {
  'translations/*.lua',
}

dependencies {
  'siku_core',
}
