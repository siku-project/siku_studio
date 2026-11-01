Subject = {}

local CLONE_TIMEOUT_MS <const> = 3000
local DEFAULT_TEXTURE <const> = 0
local DEFAULT_PALETTE <const> = 0

local ped = nil

--- Clones the player into the studio, frozen, facing the camera.
---@return number ped The clone handle.
function Subject.create()
  if ped and DoesEntityExist(ped) then
    return ped
  end

  local config <const> = StudioConfig.scene
  local clone <const> = ClonePed(PlayerPedId(), config.heading, false, false)

  Siku.waitFor(function()
    return (clone ~= 0 and DoesEntityExist(clone)) or nil
  end, T('error_subject_never_cloned'), CLONE_TIMEOUT_MS)

  ped = clone

  SetEntityAsMissionEntity(ped, true, true)
  SetEntityCoordsNoOffset(ped, config.origin.x, config.origin.y, config.origin.z, false, false, false)
  SetEntityHeading(ped, config.heading)
  FreezeEntityPosition(ped, true)
  SetEntityInvincible(ped, true)
  SetEntityCollision(ped, false, false)
  SetEntityHasGravity(ped, false)
  SetBlockingOfNonTemporaryEvents(ped, true)
  SetPedCanRagdoll(ped, false)
  ClearPedTasksImmediately(ped)
  SetEntityVisible(ped, true, false)
  SetEntityAlpha(ped, 255, false)

  return ped
end

--- The clone handle, nil before create or after destroy.
---@return number|nil
function Subject.ped()
  return ped
end

--- How many drawables a component offers on the clone.
---@param component number
---@return number
function Subject.drawables(component)
  return GetNumberOfPedDrawableVariations(ped, component)
end

--- How many textures a drawable of a component offers on the clone.
---@param component number
---@param drawable number
---@return number
function Subject.textures(component, drawable)
  return GetNumberOfPedTextureVariations(ped, component, drawable)
end

--- Dresses the clone with one variation.
---@param component number
---@param drawable number
---@param texture number|nil
function Subject.setVariation(component, drawable, texture)
  SetPedComponentVariation(ped, component, drawable, texture or DEFAULT_TEXTURE, DEFAULT_PALETTE)
end

--- Asks the game to stream one variation ahead of time.
---@param component number
---@param drawable number
---@param texture number|nil
function Subject.preload(component, drawable, texture)
  SetPedPreloadVariationData(ped, component, drawable, texture or DEFAULT_TEXTURE)
end

--- Whether the variation asked by preload is in memory.
---@return boolean
function Subject.preloadFinished()
  return HasPedPreloadVariationDataFinished(ped)
end

--- Lets the game forget the preloaded variation.
function Subject.releasePreload()
  ReleasePedPreloadVariationData(ped)
end

--- Removes the clone.
function Subject.destroy()
  if not ped then
    return
  end

  if DoesEntityExist(ped) then
    ReleasePedPreloadVariationData(ped)
    ClearPedTasksImmediately(ped)
    SetEntityAsMissionEntity(ped, true, true)
    DeleteEntity(ped)
  end

  ped = nil
end
