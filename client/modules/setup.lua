Setup = {}

local PUSH_EVERY_MS <const> = 100
local FOV_MIN <const> = 5.0
local FOV_MAX <const> = 90.0
local COMPONENT_ICONS <const> = { [1] = 'mask', [2] = 'head', [3] = 'arm', [4] = 'pants', [5] = 'bag', [6] = 'shoe', [7] = 'necklace', [8] = 'shirt', [9] = 'vest', [10] = 'shirt', [11] = 'hanger' }
local PROP_ICONS <const> = { [0] = 'hat', [1] = 'glasses', [2] = 'ear', [6] = 'watch', [7] = 'ring' }
local PROPS <const> = { 0, 1, 2, 6, 7 }

local state = nil

local function targetById(id)
  local targets <const> = StudioConfig.catalog.targets

  for i = 1, #targets do
    if targets[i].id == id then
      return targets[i]
    end
  end

  return nil
end

local function modelName()
  local hash <const> = Subject.model()
  local models <const> = StudioConfig.catalog.models

  for i = 1, #models do
    if GetHashKey(models[i]) == hash then
      return models[i]
    end
  end

  return models[1]
end

local function labelOf(kind, index)
  local target <const> = targetById(('%s_%d'):format(kind, index))

  return target and target.label or ('%s %d'):format(kind, index)
end

local function countOf(target)
  if target.kind == 'component' then
    return Subject.drawables(target.index)
  elseif target.kind == 'prop' then
    return Subject.propDrawables(target.index)
  elseif target.kind == 'overlay' then
    return Subject.overlayValues(target.index)
  elseif target.kind == 'haircolor' then
    return Subject.hairColors()
  elseif target.kind == 'eyecolor' then
    return StudioConfig.catalog.eyeColors
  end

  return 0
end

local function sortedKeys(set)
  local list <const> = {}

  for key in pairs(set) do
    list[#list + 1] = key
  end

  table.sort(list)

  return list
end

local function applyLook()
  local target <const> = state.target
  local count <const> = countOf(target)

  if count > 0 and state.index > count - 1 then
    state.index = count - 1
  end

  Subject.restore()

  if target.bare then
    local bare <const> = StudioConfig.catalog.bare[state.model]

    if bare then
      Subject.strip(bare)
    end
  end

  Subject.hide({ components = sortedKeys(state.hiddenComponents), props = sortedKeys(state.hiddenProps) }, StudioConfig.catalog.hidden[state.model] or {})

  if count == 0 then
    return
  end

  if target.kind == 'component' then
    Subject.setVariation(target.index, state.index, 0)
  elseif target.kind == 'prop' then
    Subject.setProp(target.index, state.index, 0)
  elseif target.kind == 'overlay' then
    Subject.setOverlay(target.index, state.index, target.color, StudioConfig.catalog.overlayColor)
  elseif target.kind == 'haircolor' then
    Subject.setHairColor(state.index)
  elseif target.kind == 'eyecolor' then
    Subject.setEyeColor(state.index)
  end
end

local function parts()
  local list <const> = {}

  for component = 1, 11 do
    list[#list + 1] = {
      kind = 'component',
      index = component,
      label = labelOf('component', component),
      icon = COMPONENT_ICONS[component],
      worn = true,
      visible = not state.hiddenComponents[component],
    }
  end

  for i = 1, #PROPS do
    local prop <const> = PROPS[i]
    local worn <const> = Subject.wearsProp(prop)

    list[#list + 1] = {
      kind = 'prop',
      index = prop,
      label = labelOf('prop', prop),
      icon = PROP_ICONS[prop],
      worn = worn,
      visible = worn and not state.hiddenProps[prop],
    }
  end

  return list
end

local function camera()
  return { x = state.anchor.x, y = state.anchor.y, z = state.anchor.z, fov = state.fov }
end

local function frame()
  Scene.place(Subject.ped(), state.anchor, state.fov)
end

local function move(right, closer, up)
  state.anchor = state.anchor + vector3(-right, -closer, up)
end

local function push()
  state.lastPush = GetGameTimer()

  Nui.send('setup.state', {
    camera = camera(),
    parts = parts(),
    target = state.target.id,
    index = state.index,
    count = countOf(state.target),
  })
end

local function recenter()
  state.anchor, state.fov = Scene.anchorOf(Subject.ped(), state.target.preset)
end

local function setTarget(target)
  state.target = target
  state.index = 0
  recenter()
  applyLook()
  frame()
  push()
end

local function quote(value)
  return ("'%s'"):format((tostring(value):gsub("'", "\\'")))
end

local function luaList(list)
  local items <const> = {}

  for i = 1, #list do
    items[i] = tostring(list[i])
  end

  return ('{ %s }'):format(table.concat(items, ', '))
end

local function snippet()
  local target <const> = state.target
  local name <const> = target.id
  local components <const> = sortedKeys(state.hiddenComponents)
  local props <const> = sortedKeys(state.hiddenProps)
  local fields <const> = {
    ('id = %s'):format(quote(target.id)),
    ('kind = %s'):format(quote(target.kind)),
  }

  if target.index then
    fields[#fields + 1] = ('index = %d'):format(target.index)
  end

  fields[#fields + 1] = ('label = %s'):format(quote(target.label))
  fields[#fields + 1] = ('preset = %s'):format(quote(name))

  if target.color then
    fields[#fields + 1] = ('color = %d'):format(target.color)
  end

  if target.bare then
    fields[#fields + 1] = 'bare = true'
  end

  if #components > 0 or #props > 0 then
    local hide <const> = {}

    if #components > 0 then
      hide[#hide + 1] = ('components = %s'):format(luaList(components))
    end

    if #props > 0 then
      hide[#hide + 1] = ('props = %s'):format(luaList(props))
    end

    fields[#fields + 1] = ('hide = { %s }'):format(table.concat(hide, ', '))
  end

  return table.concat({
    ('-- siku_studio · /studio setup · %s · %s'):format(target.id, state.model),
    '-- config/studio.lua, camera.presets :',
    ('%s = { anchor = vector3(%.3f, %.3f, %.3f), fov = %.1f },'):format(name, state.anchor.x, state.anchor.y, state.anchor.z, state.fov),
    ('-- config/studio.lua, catalog.targets, à la place de la ligne %s :'):format(target.id),
    ('{ %s },'):format(table.concat(fields, ', ')),
  }, '\n')
end

local function handle(name, handler)
  Nui.on(name, function(data)
    if state and not state.closed then
      handler(data)
    end
  end)
end

--- Runs the framing tool until the player closes it: the subject is
--- dressed for one target, the camera moves on three axes without turning,
--- parts of the body can be hidden, and the result comes out as the lines
--- to paste in config/studio.lua.
---@return string summary
function Setup.run()
  local config <const> = StudioConfig.setup

  state = {
    model = modelName(),
    target = nil,
    index = 0,
    anchor = vector3(0.0, 0.0, 0.0),
    fov = 30.0,
    hiddenComponents = {},
    hiddenProps = {},
    input = { x = 0, y = 0, z = 0, fov = 0 },
    step = 'normal',
    closed = false,
    saved = 0,
    lastPush = 0,
  }

  local target <const> = targetById(config.target) or StudioConfig.catalog.targets[1]

  state.target = target
  recenter()
  applyLook()
  frame()

  local targets <const> = {}

  for i = 1, #StudioConfig.catalog.targets do
    local entry <const> = StudioConfig.catalog.targets[i]

    targets[i] = { id = entry.id, label = entry.label, kind = entry.kind, index = entry.index, count = countOf(entry) }
  end

  SetNuiFocus(true, true)
  Nui.send('setup.open', {
    translations = Siku.locale.translations().web or {},
    model = state.model,
    targets = targets,
    parts = parts(),
    camera = camera(),
    target = target.id,
    index = 0,
    step = state.step,
  })

  while state and not state.closed do
    Session.checkpoint()

    local input <const> = state.input

    if input.x ~= 0 or input.y ~= 0 or input.z ~= 0 or input.fov ~= 0 then
      local dt <const> = GetFrameTime()
      local speed <const> = config.speeds[state.step] or config.speeds.normal

      move(input.x * speed * dt, input.y * speed * dt, input.z * speed * dt)
      state.fov = math.min(FOV_MAX, math.max(FOV_MIN, state.fov - input.fov * config.fovSpeed * dt))
      frame()

      if GetGameTimer() - state.lastPush >= PUSH_EVERY_MS then
        push()
      end
    end

    Wait(0)
  end

  local saved <const> = state and state.saved or 0

  Setup.cleanup()

  return ('setup closed, %d framing(s) generated'):format(saved)
end

--- Closes the tool and gives the keyboard back, from anywhere.
function Setup.cleanup()
  if not state then
    return
  end

  state.closed = true
  state = nil

  SetNuiFocus(false, false)
  Nui.send('setup.close')
end

handle('setup.input', function(data)
  state.input = {
    x = tonumber(data.x) or 0,
    y = tonumber(data.y) or 0,
    z = tonumber(data.z) or 0,
    fov = tonumber(data.fov) or 0,
  }
end)

handle('setup.nudge', function(data)
  local direction <const> = tonumber(data.direction) or 0
  local config <const> = StudioConfig.setup

  if data.axis == 'fov' then
    state.fov = math.min(FOV_MAX, math.max(FOV_MIN, state.fov - direction * config.fovNudge))
  else
    local step <const> = (config.nudges[state.step] or config.nudges.normal) * direction

    if data.axis == 'x' then
      move(step, 0.0, 0.0)
    elseif data.axis == 'y' then
      move(0.0, step, 0.0)
    elseif data.axis == 'z' then
      move(0.0, 0.0, step)
    end
  end

  frame()
  push()
end)

handle('setup.step', function(data)
  if StudioConfig.setup.speeds[data.step] then
    state.step = data.step
  end
end)

handle('setup.target', function(data)
  local target <const> = targetById(data.id)

  if target then
    setTarget(target)
  end
end)

handle('setup.index', function(data)
  state.index = math.max(0, math.floor(tonumber(data.index) or 0))
  applyLook()
  push()
end)

handle('setup.part', function(data)
  local index <const> = math.floor(tonumber(data.index) or -1)
  local set <const> = data.kind == 'prop' and state.hiddenProps or state.hiddenComponents

  if index < 0 then
    return
  end

  set[index] = (not data.visible) or nil
  applyLook()
  push()
end)

handle('setup.reset', function()
  recenter()
  frame()
  push()
end)

handle('setup.save', function()
  local lines <const> = snippet()

  state.saved = state.saved + 1

  print(('\n%s\n'):format(lines))
  Session.report('setup', {
    summary = ('framing %s'):format(state.target.id),
    target = state.target.id,
    snippet = lines,
    anchor = camera(),
    hide = { components = sortedKeys(state.hiddenComponents), props = sortedKeys(state.hiddenProps) },
  })
  Nui.send('setup.saved', { snippet = lines })
end)

handle('setup.close', function()
  state.closed = true
end)
