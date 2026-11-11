Subject = {}

local CLONE_TIMEOUT_MS <const> = 3000
local POSE_TIMEOUT_MS <const> = 3000
local DEFAULT_TEXTURE <const> = 0
local DEFAULT_PALETTE <const> = 0
local COMPONENTS <const> = 12
local PROPS <const> = { 0, 1, 2, 6, 7 }
local OVERLAYS <const> = 13
local OVERLAY_OPACITY <const> = 1.0
local COLORED_OVERLAYS <const> = { [1] = 1, [2] = 1, [4] = 2, [5] = 2, [8] = 2, [10] = 1 }
local SET_PED_PRELOAD_PROP_DATA <const> = 0x2B16A3BFF1FBCE49
local HAS_PED_PRELOAD_PROP_DATA_FINISHED <const> = 0x784002A632822099
local RELEASE_PED_PRELOAD_PROP_DATA <const> = 0xF79F9DEF0AADE61A

local ped = nil
local original = nil
local modelName = nil

local function remember()
  local state <const> = { components = {}, props = {}, overlays = {} }

  for component = 0, COMPONENTS - 1 do
    state.components[component] = { GetPedDrawableVariation(ped, component), GetPedTextureVariation(ped, component) }
  end

  for i = 1, #PROPS do
    local prop <const> = PROPS[i]

    state.props[prop] = { GetPedPropIndex(ped, prop), GetPedPropTextureIndex(ped, prop) }
  end

  for overlay = 0, OVERLAYS - 1 do
    local ok <const>, value <const>, colorType <const>, first <const>, second <const>, opacity <const> = GetPedHeadOverlayData(ped, overlay)

    if ok then
      state.overlays[overlay] = { value = value, colorType = colorType, first = first, second = second, opacity = opacity }
    end
  end

  state.hair = { GetPedHairColor(ped), GetPedHairHighlightColor(ped) }
  state.eyes = GetPedEyeColor(ped)

  return state
end

local function pose()
  local config <const> = StudioConfig.pose

  if not config then
    return
  end

  Siku.streaming.requestAnimDict(config.dict)
  TaskPlayAnim(ped, config.dict, config.anim, 8.0, -8.0, -1, 1, 0.0, false, false, false)

  Siku.waitFor(function()
    return IsEntityPlayingAnim(ped, config.dict, config.anim, 3) or nil
  end, 'The pose animation never started', POSE_TIMEOUT_MS)

  SetEntityAnimCurrentTime(ped, config.dict, config.anim, config.time)
  SetEntityAnimSpeed(ped, config.dict, config.anim, 0.0)
end

local function neutralize()
  local colors <const> = StudioConfig.catalog.baseColors

  if not colors then
    return
  end

  if colors.hair then
    SetPedHairColor(ped, colors.hair, colors.hair)
  end

  if colors.overlays then
    for overlay, colorType in pairs(COLORED_OVERLAYS) do
      local ok <const>, value <const>, _, _, _, opacity <const> = GetPedHeadOverlayData(ped, overlay)

      if ok and value ~= 255 then
        SetPedHeadOverlay(ped, overlay, value, opacity)
        SetPedHeadOverlayColor(ped, overlay, colorType, colors.overlays, colors.overlays)
      end
    end
  end
end

local function clonePlayer(config)
  local clone <const> = ClonePed(PlayerPedId(), config.heading, false, false)

  Siku.waitFor(function()
    return (clone ~= 0 and DoesEntityExist(clone)) or nil
  end, T('error_subject_never_cloned'), CLONE_TIMEOUT_MS)

  return clone
end

local function spawn(config, model)
  local hash <const> = GetHashKey(model)

  Siku.streaming.requestModel(hash)

  local created <const> = CreatePed(4, hash, config.origin.x, config.origin.y, config.origin.z, config.heading, false, false)

  Siku.waitFor(function()
    return (created ~= 0 and DoesEntityExist(created)) or nil
  end, T('error_subject_never_cloned'), CLONE_TIMEOUT_MS)

  SetModelAsNoLongerNeeded(hash)
  SetPedHeadBlendData(created, 0, 0, 0, 0, 0, 0, 0.5, 0.5, 0.0, false)
  SetPedComponentVariation(created, 0, 0, DEFAULT_TEXTURE, DEFAULT_PALETTE)

  for component, drawable in pairs(StudioConfig.catalog.hidden[model] or {}) do
    SetPedComponentVariation(created, component, drawable, DEFAULT_TEXTURE, DEFAULT_PALETTE)
  end

  for i = 1, #PROPS do
    ClearPedProp(created, PROPS[i])
  end

  return created
end

--- Puts a subject of the given model into the studio, frozen, facing the
--- camera, in a fixed pose, in the studio's base colours, and remembers
--- that look so it can be restored between two targets. The player is
--- cloned when they wear that model, so their own look is the base;
--- otherwise a bare ped of the model is created with a neutral face. An
--- existing subject of another model is removed first.
---@param model string The model folder name, from catalog.models.
---@return number ped The subject handle.
function Subject.create(model)
  if ped and DoesEntityExist(ped) and modelName == model then
    return ped
  end

  Subject.destroy()

  local config <const> = StudioConfig.scene
  local player <const> = PlayerPedId()

  if GetEntityModel(player) == GetHashKey(model) then
    ped = clonePlayer(config)
  else
    ped = spawn(config, model)
  end

  modelName = model

  SetEntityAsMissionEntity(ped, true, true)
  SetEntityCoordsNoOffset(ped, config.origin.x, config.origin.y, config.origin.z, false, false, false)
  SetEntityHeading(ped, config.heading)
  FreezeEntityPosition(ped, true)
  SetEntityInvincible(ped, true)
  SetEntityCollision(ped, false, false)
  SetEntityHasGravity(ped, false)
  SetBlockingOfNonTemporaryEvents(ped, true)
  SetPedCanRagdoll(ped, false)
  SetPedCanPlayAmbientAnims(ped, false)
  SetPedCanPlayAmbientBaseAnims(ped, false)
  SetPedCanPlayGestureAnims(ped, false)
  SetPedCanHeadIk(ped, false)
  SetPedCanArmIk(ped, false)
  SetPedCanLegIk(ped, false)
  SetPedCanTorsoIk(ped, false)
  ClearPedTasksImmediately(ped)
  SetEntityVisible(ped, true, false)
  SetEntityAlpha(ped, 255, false)

  neutralize()

  original = remember()

  pose()

  return ped
end

--- Removes the subject and puts a fresh one of the same model in its
--- place, when the one in the studio stopped answering.
---@param model string The model folder name, from catalog.models.
---@return number ped The new subject handle.
function Subject.recreate(model)
  Subject.destroy()

  return Subject.create(model)
end

--- What the subject looks like right now, for the log of a photo that
--- could not be taken: whether it still exists, still wears its model,
--- what it wears where the photo was asked, whether its look is loaded,
--- and how many streaming requests the game still holds.
---@param kind string|nil 'component' or 'prop', to read what is worn there.
---@param index number|nil The component or prop slot.
---@param asked table|nil { drawable, texture } that was asked.
---@return table
function Subject.diagnose(kind, index, asked)
  local info <const> = {
    model = modelName,
    exists = ped ~= nil and DoesEntityExist(ped) or false,
    streamingRequests = GetNumberOfStreamingRequests(),
  }

  if not info.exists then
    return info
  end

  info.sameModel = GetEntityModel(ped) == GetHashKey(modelName)
  info.visible = IsEntityVisible(ped)
  info.distance = #(GetEntityCoords(ped) - StudioConfig.scene.origin)
  info.loaded = HaveAllStreamingRequestsCompleted(ped)

  if kind == 'component' and index then
    info.worn = { GetPedDrawableVariation(ped, index), GetPedTextureVariation(ped, index) }

    if asked then
      info.valid = IsPedComponentVariationValid(ped, index, asked[1], asked[2])
    end
  elseif kind == 'prop' and index then
    info.worn = { GetPedPropIndex(ped, index), GetPedPropTextureIndex(ped, index) }
  end

  return info
end

--- The clone handle, nil before create or after destroy.
---@return number|nil
function Subject.ped()
  return ped
end

--- The model hash of the subject.
---@return number
function Subject.model()
  return GetEntityModel(ped)
end

--- The model folder name the subject was created for, nil without a subject.
---@return string|nil
function Subject.modelName()
  return modelName
end

--- The model folder name the player wears when the catalog accepts it,
--- the first catalog model otherwise.
---@return string model
function Subject.playerModel()
  local hash <const> = GetEntityModel(PlayerPedId())
  local models <const> = StudioConfig.catalog.models

  for i = 1, #models do
    if GetHashKey(models[i]) == hash then
      return models[i]
    end
  end

  return models[1]
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

--- How many drawables a prop slot offers on the clone.
---@param prop number
---@return number
function Subject.propDrawables(prop)
  return GetNumberOfPedPropDrawableVariations(ped, prop)
end

--- How many textures a prop drawable offers on the clone.
---@param prop number
---@param drawable number
---@return number
function Subject.propTextures(prop, drawable)
  return GetNumberOfPedPropTextureVariations(ped, prop, drawable)
end

--- How many values a head overlay offers.
---@param overlay number
---@return number
function Subject.overlayValues(overlay)
  return GetNumHeadOverlayValues(overlay)
end

--- How many hair colours the game offers.
---@return number
function Subject.hairColors()
  return GetNumHairColors()
end

--- Dresses the clone with one component variation.
---@param component number
---@param drawable number
---@param texture number|nil
function Subject.setVariation(component, drawable, texture)
  SetPedComponentVariation(ped, component, drawable, texture or DEFAULT_TEXTURE, DEFAULT_PALETTE)
end

--- Puts one prop on the clone.
---@param prop number
---@param drawable number
---@param texture number|nil
function Subject.setProp(prop, drawable, texture)
  SetPedPropIndex(ped, prop, drawable, texture or DEFAULT_TEXTURE, true)
end

--- Removes a prop from the clone.
---@param prop number
function Subject.clearProp(prop)
  ClearPedProp(ped, prop)
end

--- Applies one head overlay value, fully opaque, with a colour when the
--- overlay takes one.
---@param overlay number
---@param value number
---@param colorType number|nil 1 for hair colours, 2 for makeup colours.
---@param color number|nil
function Subject.setOverlay(overlay, value, colorType, color)
  SetPedHeadOverlay(ped, overlay, value, OVERLAY_OPACITY)

  if colorType then
    SetPedHeadOverlayColor(ped, overlay, colorType, color or 0, color or 0)
  end
end

--- Colours the clone's hair.
---@param color number
function Subject.setHairColor(color)
  SetPedHairColor(ped, color, color)
end

--- Colours the clone's eyes.
---@param color number
function Subject.setEyeColor(color)
  SetPedEyeColor(ped, color)
end

--- Strips the torso of the clone with the naked drawables of its model.
---@param bare table { [component] = drawable }
function Subject.strip(bare)
  for component, drawable in pairs(bare) do
    SetPedComponentVariation(ped, component, drawable, DEFAULT_TEXTURE, DEFAULT_PALETTE)
  end
end

--- Hides parts of the clone for a photo: components take the empty
--- drawable of the model, props are removed.
---@param hide table { components?: number[], props?: number[] }
---@param hidden table { [component] = drawable } The empty drawables of the model.
function Subject.hide(hide, hidden)
  for i = 1, #(hide.components or {}) do
    local component <const> = hide.components[i]

    SetPedComponentVariation(ped, component, hidden[component] or 0, DEFAULT_TEXTURE, DEFAULT_PALETTE)
  end

  for i = 1, #(hide.props or {}) do
    ClearPedProp(ped, hide.props[i])
  end
end

--- Puts one component back to what the player wears.
---@param component number
function Subject.show(component)
  local pair <const> = original and original.components[component]

  if pair then
    SetPedComponentVariation(ped, component, pair[1], pair[2], DEFAULT_PALETTE)
  end
end

--- Puts one prop back to what the player wears, if any.
---@param prop number
function Subject.showProp(prop)
  local pair <const> = original and original.props[prop]

  if pair and pair[1] >= 0 then
    SetPedPropIndex(ped, prop, pair[1], pair[2], true)
  end
end

--- Whether the player wears something in a prop slot.
---@param prop number
---@return boolean
function Subject.wearsProp(prop)
  local pair <const> = original and original.props[prop]

  return pair ~= nil and pair[1] >= 0
end

--- Asks the game to stream one component variation ahead of time.
---@param component number
---@param drawable number
---@param texture number|nil
function Subject.preload(component, drawable, texture)
  SetPedPreloadVariationData(ped, component, drawable, texture or DEFAULT_TEXTURE)
end

--- Asks the game to stream the drawables the subject was just given by
--- hide or strip, so the bare parts show before the next photo: the
--- preload data takes one drawable per component.
---@param components number[] The components changed.
---@param drawables table { [component] = drawable }
function Subject.preloadComponents(components, drawables)
  for i = 1, #components do
    local component <const> = components[i]

    SetPedPreloadVariationData(ped, component, drawables[component] or 0, DEFAULT_TEXTURE)
  end
end

--- Whether everything the subject's current look needs is in memory: the
--- game's own signal that a variation or prop change has been applied.
---@return boolean
function Subject.loaded()
  return HaveAllStreamingRequestsCompleted(ped)
end

--- Whether the component variation asked by preload is in memory.
---@return boolean
function Subject.preloadFinished()
  return HasPedPreloadVariationDataFinished(ped)
end

--- Lets the game forget the preloaded component variation.
function Subject.releasePreload()
  ReleasePedPreloadVariationData(ped)
end

--- Asks the game to stream one prop ahead of time.
---@param prop number
---@param drawable number
---@param texture number|nil
function Subject.preloadProp(prop, drawable, texture)
  Citizen.InvokeNative(SET_PED_PRELOAD_PROP_DATA, ped, prop, drawable, texture or DEFAULT_TEXTURE)
end

--- Whether the prop asked by preloadProp is in memory.
---@return boolean
function Subject.preloadPropFinished()
  return Citizen.InvokeNative(HAS_PED_PRELOAD_PROP_DATA_FINISHED, ped, Citizen.ReturnResultAnyway(), Citizen.ResultAsInteger()) == 1
end

--- Lets the game forget the preloaded prop.
function Subject.releasePreloadProp()
  Citizen.InvokeNative(RELEASE_PED_PRELOAD_PROP_DATA, ped)
end

--- Puts the clone back in the look it had when created.
function Subject.restore()
  if not ped or not original then
    return
  end

  for component, pair in pairs(original.components) do
    SetPedComponentVariation(ped, component, pair[1], pair[2], DEFAULT_PALETTE)
  end

  for prop, pair in pairs(original.props) do
    if pair[1] < 0 then
      ClearPedProp(ped, prop)
    else
      SetPedPropIndex(ped, prop, pair[1], pair[2], true)
    end
  end

  for overlay, data in pairs(original.overlays) do
    SetPedHeadOverlay(ped, overlay, data.value, data.opacity)

    if data.colorType > 0 then
      SetPedHeadOverlayColor(ped, overlay, data.colorType, data.first, data.second)
    end
  end

  SetPedHairColor(ped, original.hair[1], original.hair[2])
  SetPedEyeColor(ped, original.eyes)
end

--- Removes the clone.
function Subject.destroy()
  if not ped then
    return
  end

  if DoesEntityExist(ped) then
    ReleasePedPreloadVariationData(ped)
    Citizen.InvokeNative(RELEASE_PED_PRELOAD_PROP_DATA, ped)
    ClearPedTasksImmediately(ped)
    SetEntityAsMissionEntity(ped, true, true)
    DeleteEntity(ped)
  end

  ped = nil
  original = nil
  modelName = nil
end
