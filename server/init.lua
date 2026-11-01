local REQUIRED_CORE_VERSION <const> = '1.7.1'

local dependency <const> = Siku.version.checkDependency('siku_core', REQUIRED_CORE_VERSION)

if not dependency.ok then
  error(dependency.message)
end

Siku.version.checkRelease('siku-project/siku_studio')

Studio = {}
