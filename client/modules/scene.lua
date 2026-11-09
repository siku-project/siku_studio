Scene = {}

local BONES <const> = {
  SKEL_Head = 31086,
  SKEL_Neck_1 = 39317,
  SKEL_Spine3 = 24818,
  SKEL_Pelvis = 11816,
  SKEL_L_Hand = 18905,
  SKEL_R_Hand = 57005,
  SKEL_L_Foot = 14201,
  SKEL_R_Foot = 52301,
}
local CONTROL_ESCAPE <const> = 200
local CONTROL_BACKSPACE <const> = 202
local FOCUS_TIMEOUT_MS <const> = 10000

local state = nil

local function faces(origin, size)
  local half <const> = size / 2
  local x <const>, y <const>, z <const> = origin.x, origin.y, origin.z
  local low <const>, high <const> = z - half * 0.3, z + half * 0.7
  local points <const> = {
    { x - half, y - half, low }, { x + half, y - half, low }, { x + half, y + half, low }, { x - half, y + half, low },
    { x - half, y - half, high }, { x + half, y - half, high }, { x + half, y + half, high }, { x - half, y + half, high },
  }
  local quads <const> = { { 1, 2, 3, 4 }, { 5, 6, 7, 8 }, { 1, 2, 6, 5 }, { 2, 3, 7, 6 }, { 3, 4, 8, 7 }, { 4, 1, 5, 8 } }
  local list <const> = {}

  for i = 1, #quads do
    local q <const> = quads[i]

    list[i] = { points[q[1]], points[q[2]], points[q[3]], points[q[4]] }
  end

  return list
end

local function drawQuad(a, b, c, d, color)
  local r <const>, g <const>, bl <const> = color[1], color[2], color[3]

  DrawPoly(a[1], a[2], a[3], b[1], b[2], b[3], c[1], c[2], c[3], r, g, bl, 255)
  DrawPoly(a[1], a[2], a[3], c[1], c[2], c[3], d[1], d[2], d[3], r, g, bl, 255)
  DrawPoly(c[1], c[2], c[3], b[1], b[2], b[3], a[1], a[2], a[3], r, g, bl, 255)
  DrawPoly(d[1], d[2], d[3], c[1], c[2], c[3], a[1], a[2], a[3], r, g, bl, 255)
end

--- Builds the studio: focus in the sky, frozen clock and weather, a
--- scripted camera, and a thread drawing the cube and the light while
--- blocking the player's controls. Escape asks the session to stop.
---@param options table|nil { onAbort?: fun() }
function Scene.enter(options)
  if state then
    return
  end

  local config <const> = StudioConfig.scene

  state = {
    background = config.background,
    onAbort = options and options.onAbort or nil,
    cube = faces(config.origin, config.size),
    light = config.origin + config.light.offset,
  }

  FreezeEntityPosition(PlayerPedId(), true)
  SetFocusPosAndVel(config.origin.x, config.origin.y, config.origin.z, 0.0, 0.0, 0.0)
  NetworkOverrideClockTime(config.time.hour, config.time.minute, 0)
  SetOverrideWeather(config.weather)
  SetWeatherTypeNowPersist(config.weather)

  state.camera = Siku.camera.create({
    coords = config.origin + vector3(0.0, -3.0, 0.5),
    rotation = vector3(0.0, 0.0, 0.0),
    fov = StudioConfig.camera.presets[StudioConfig.camera.preset].fov,
  })

  Siku.camera.clearDepthOfField(state.camera)
  Siku.camera.setMotionBlur(state.camera, 0.0)
  Siku.camera.render(state.camera, false, 0)

  CreateThread(function()
    local current <const> = state

    while state == current do
      HideHudAndRadarThisFrame()
      DisableAllControlActions(0)
      DisableAllControlActions(1)
      DisableAllControlActions(2)
      SetPauseMenuActive(false)

      local color <const> = StudioConfig.scene.backgrounds[current.background] or StudioConfig.scene.backgrounds.green

      for i = 1, #current.cube do
        local quad <const> = current.cube[i]

        drawQuad(quad[1], quad[2], quad[3], quad[4], color)
      end

      DrawLightWithRange(current.light.x, current.light.y, current.light.z, config.light.color[1], config.light.color[2], config.light.color[3], config.light.range, config.light.intensity)

      if IsDisabledControlJustPressed(0, CONTROL_ESCAPE) or IsDisabledControlJustPressed(0, CONTROL_BACKSPACE) then
        Scene.abort()
      end

      Wait(0)
    end
  end)

  Siku.waitFor(function()
    return Siku.camera.isRendering(state.camera) or nil
  end, T('error_scene_never_focused'), FOCUS_TIMEOUT_MS)

  Wait(0)
end

--- Changes the colour of the cube, by name from the configuration.
---@param name string
function Scene.setBackground(name)
  if state and StudioConfig.scene.backgrounds[name] then
    state.background = name
  end
end

local function axes(ped)
  local forward <const> = GetEntityForwardVector(ped)

  return GetEntityCoords(ped), vector3(forward.x, forward.y, 0.0), vector3(forward.y, -forward.x, 0.0)
end

local function presetOf(presetName)
  return StudioConfig.camera.presets[presetName or StudioConfig.camera.preset] or StudioConfig.camera.presets[StudioConfig.camera.preset]
end

local function boneCamera(ped, preset)
  local bone <const> = BONES[preset.bone] or BONES.SKEL_Spine3
  local offset <const> = preset.offset or vector3(0.0, 0.0, 0.0)
  local target <const> = GetPedBoneCoords(ped, bone, offset.x, offset.y, offset.z)
  local forward <const> = GetEntityForwardVector(ped)
  local yaw <const> = math.rad(preset.yaw or 0.0)
  local direction <const> = vector3(
    forward.x * math.cos(yaw) - forward.y * math.sin(yaw),
    forward.x * math.sin(yaw) + forward.y * math.cos(yaw),
    0.0
  )

  return target + direction * preset.distance + vector3(0.0, 0.0, preset.height), target
end

--- Puts the camera at a point of the subject's own frame (right, forward,
--- up in meters from its feet), looking straight back at the subject
--- without any tilt, with the given field of view.
---@param ped number
---@param anchor vector3
---@param fov number
function Scene.place(ped, anchor, fov)
  if not state then
    return
  end

  local origin <const>, forward <const>, right <const> = axes(ped)
  local coords <const> = origin + right * anchor.x + forward * anchor.y + vector3(0.0, 0.0, anchor.z)
  local heading <const> = math.deg(math.atan(-forward.y, -forward.x)) - 90.0

  Siku.camera.stopPointing(state.camera)
  Siku.camera.setCoords(state.camera, coords)
  Siku.camera.setRotation(state.camera, vector3(0.0, 0.0, heading))
  Siku.camera.setFov(state.camera, fov)
end

--- The anchor and field of view a preset gives, in the subject's frame,
--- so a bone preset can be adjusted by hand from where it stands.
---@param ped number
---@param presetName string|nil
---@return vector3 anchor
---@return number fov
function Scene.anchorOf(ped, presetName)
  local preset <const> = presetOf(presetName)

  if preset.anchor then
    return preset.anchor, preset.fov
  end

  local origin <const>, forward <const>, right <const> = axes(ped)
  local coords <const> = boneCamera(ped, preset)
  local delta <const> = coords - origin

  return vector3(delta.x * right.x + delta.y * right.y, delta.x * forward.x + delta.y * forward.y, delta.z), preset.fov
end

--- Places the camera in front of a subject with a framing preset.
---@param ped number The subject ped.
---@param presetName string|nil A preset name from the configuration, the default one when nil.
function Scene.frame(ped, presetName)
  if not state then
    return
  end

  local preset <const> = presetOf(presetName)

  if preset.anchor then
    Scene.place(ped, preset.anchor, preset.fov)
    return
  end

  local coords <const>, target <const> = boneCamera(ped, preset)

  Siku.camera.setCoords(state.camera, coords)
  Siku.camera.pointAtCoords(state.camera, target)
  Siku.camera.setFov(state.camera, preset.fov)
end

--- The camera handle of the scene, nil when no scene is built.
---@return number|nil
function Scene.camera()
  return state and state.camera or nil
end

--- Tells the session the user wants out.
function Scene.abort()
  if state and state.onAbort then
    local handler <const> = state.onAbort

    state.onAbort = nil
    handler()
  end
end

--- Tears the studio down and gives the world back to the player.
function Scene.leave()
  if not state then
    return
  end

  local current <const> = state

  state = nil

  if current.camera and Siku.camera.exists(current.camera) then
    Siku.camera.destroy(current.camera)
  end

  ClearFocus()
  FreezeEntityPosition(PlayerPedId(), false)
  NetworkClearClockTimeOverride()
  ClearOverrideWeather()
  ClearWeatherTypePersist()
end
