Catalog = {}

local SNAP_TIMEOUT_MS <const> = 10000
local CAPTURE_TIMEOUT_MS <const> = 120000
local FLUSH_TIMEOUT_MS <const> = 600000
local PROGRESS_EVERY <const> = 100
local OVERLAY_SETTLE_FRAMES <const> = 2

local function settle(extra)
  for _ = 1, StudioConfig.capture.settleFrames + (extra or 0) do
    Wait(0)
  end
end

local function waitFinished(check, timeoutMs)
  local started <const> = GetGameTimer()

  while not check() do
    if GetGameTimer() - started > timeoutMs then
      return false
    end

    Wait(0)
  end

  return true
end

local function dressed(components, drawables)
  if #components == 0 then
    return
  end

  Subject.preloadComponents(components, drawables)
  waitFinished(Subject.preloadFinished, StudioConfig.catalog.changeTimeoutMs)
  Subject.releasePreload()
end

local function textureLimit(available)
  local wanted <const> = StudioConfig.catalog.textures

  if wanted <= 0 or wanted > available then
    return available
  end

  return wanted
end

local function targetById(id)
  local all <const> = StudioConfig.catalog.targets

  for i = 1, #all do
    if all[i].id == id then
      return all[i]
    end
  end

  return nil
end

local function targetsFor(job)
  local all <const> = StudioConfig.catalog.targets

  if not job.target or job.target == 'all' then
    return all
  end

  local set <const> = (StudioConfig.catalog.sets or {})[job.target]

  if set then
    local list <const> = {}

    for i = 1, #set do
      list[#list + 1] = targetById(set[i]) or error(('set %s names an unknown target %s'):format(job.target, tostring(set[i])), 0)
    end

    return list
  end

  for i = 1, #all do
    if all[i].name == job.target then
      return { all[i] }
    end
  end

  return { targetById(job.target) or error(('unknown catalog target %s'):format(tostring(job.target)), 0) }
end

local function range(job, count)
  local from <const> = math.max(0, job.from or 0)
  local to <const> = math.min(count - 1, (job.to and job.to >= 0) and job.to or count - 1)

  return from, to
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

local function photosOf(target, from, to)
  if target.kind == 'component' then
    local total = 0

    for drawable = from, to do
      total = total + textureLimit(Subject.textures(target.index, drawable))
    end

    return total
  elseif target.kind == 'prop' then
    local total = 0

    for drawable = from, to do
      total = total + textureLimit(Subject.propTextures(target.index, drawable))
    end

    return total
  end

  return math.max(0, to - from + 1)
end

local function inventory(job, targets)
  local list <const> = {}
  local planned, alreadyDone = 0, 0

  for i = 1, #targets do
    local target <const> = targets[i]
    local count <const> = countOf(target)
    local from <const>, to <const> = range(job, count)
    local photos <const> = count > 0 and photosOf(target, from, to) or 0

    list[#list + 1] = {
      id = target.id,
      label = target.label,
      kind = target.kind,
      index = target.index,
      count = count,
      from = from,
      to = to,
      photos = photos,
    }

    planned = planned + photos
  end

  for _ in pairs(job.done or {}) do
    alreadyDone = alreadyDone + 1
  end

  return list, planned, alreadyDone
end

local function photo(state, key)
  if state.done[key] then
    state.skipped = state.skipped + 1
    return
  end

  Session.checkpoint()

  local first = nil

  if StudioConfig.capture.matte == 'double' then
    Scene.setBackground('green')
    settle()

    local snapped <const> = Nui.request('snap', {
      background = StudioConfig.scene.backgrounds.green,
      previous = StudioConfig.scene.backgrounds.magenta,
    }, SNAP_TIMEOUT_MS)

    if not snapped.ok then
      error(('snap failed for %s: %s'):format(key, tostring(snapped.error)), 0)
    end

    first = snapped.snap

    Scene.setBackground('magenta')
    settle()
  else
    settle()
  end

  local reply <const> = Nui.request('capture', {
    kind = 'catalog',
    key = key,
    first = first,
    background = first and StudioConfig.scene.backgrounds.magenta or nil,
    previous = first and StudioConfig.scene.backgrounds.green or nil,
  }, CAPTURE_TIMEOUT_MS)

  if not reply.ok then
    error(('capture failed for %s: %s'):format(key, tostring(reply.error)), 0)
  end

  state.photos = state.photos + 1
  state.readMs = state.readMs + (reply.readMs or 0)

  if state.photos % PROGRESS_EVERY == 0 then
    Siku.log.debug('studio.debug', ('Capture: %d photos, %d skipped, target %s'):format(state.photos, state.skipped, state.target), {
      step = 'capture.progress',
      photos = state.photos,
      skipped = state.skipped,
      target = state.target,
      elapsedMs = GetGameTimer() - state.startedAt,
    })
  end
end

local function shoot(state, key, prepare, retry)
  if state.done[key] then
    state.skipped = state.skipped + 1
    return true
  end

  Session.checkpoint()

  local ok <const>, err <const> = pcall(function()
    if not prepare() then
      error(T('error_change_never_shown'), 0)
    end

    photo(state, key)
  end)

  if ok then
    state.streak = 0

    if retry then
      state.missed = state.missed - 1
      state.retaken = state.retaken + 1
    end

    return true
  end

  if err == 'stopped' then
    error(err, 0)
  end

  local reason <const> = tostring(err)

  if not retry then
    state.missed = state.missed + 1
    state.streak = state.streak + 1
  end

  Session.alive()

  Siku.log.warn('studio.photo_skipped', ('Photo %s %s: %s'):format(key, retry and 'skipped again' or 'skipped', reason), {
    key = key,
    model = state.model,
    target = state.target,
    reason = reason,
    retry = retry or nil,
    streak = state.streak,
    missed = state.missed,
    subject = Subject.diagnose(state.kind, state.index, state.asked),
    cameraRendering = Scene.camera() ~= nil and Siku.camera.isRendering(Scene.camera()),
  })

  if retry or state.streak < StudioConfig.catalog.failuresInARow then
    return false
  end

  if not state.recovered then
    state.recovered = true
    state.streak = 0
    state.recover(key, reason)

    return false
  end

  error(('%d photos failed in a row, the last one %s: %s'):format(state.streak, key, reason), 0)
end

local function runItems(state, items)
  local missed <const> = {}

  for i = 1, #items do
    if not shoot(state, items[i].key, items[i].prepare) then
      missed[#missed + 1] = items[i]
    end
  end

  for i = 1, #missed do
    shoot(state, missed[i].key, missed[i].prepare, true)
  end
end

local function componentItems(state, target, from, to)
  local timeout <const> = StudioConfig.catalog.changeTimeoutMs
  local items <const> = {}

  for drawable = from, to do
    local textures <const> = textureLimit(Subject.textures(target.index, drawable))

    for texture = 0, textures - 1 do
      items[#items + 1] = {
        key = ('%s/%s_%d_%d.webp'):format(state.folder, target.name, drawable, texture),
        prepare = function()
          state.asked = { drawable, texture }
          Subject.setVariation(target.index, drawable, texture)
          Subject.preload(target.index, drawable, texture)

          local shown <const> = waitFinished(Subject.preloadFinished, timeout)

          Subject.releasePreload()

          return shown
        end,
      }
    end
  end

  return items
end

local function propItems(state, target, from, to)
  local timeout <const> = StudioConfig.catalog.changeTimeoutMs
  local items <const> = {}

  for drawable = from, to do
    local textures <const> = textureLimit(Subject.propTextures(target.index, drawable))

    for texture = 0, textures - 1 do
      items[#items + 1] = {
        key = ('%s/%s_%d_%d.webp'):format(state.folder, target.name, drawable, texture),
        prepare = function()
          state.asked = { drawable, texture }
          Subject.setProp(target.index, drawable, texture)
          Subject.preloadProp(target.index, drawable, texture)

          local shown <const> = waitFinished(Subject.preloadPropFinished, timeout)

          Subject.releasePreloadProp()

          return shown
        end,
      }
    end
  end

  return items
end

local function valueItems(state, target, from, to, apply)
  local items <const> = {}

  for value = from, to do
    items[#items + 1] = {
      key = ('%s/%s_%d.webp'):format(state.folder, target.name, value),
      prepare = function()
        state.asked = { value }
        apply(value)
        settle(OVERLAY_SETTLE_FRAMES)

        return true
      end,
    }
  end

  return items
end

local function runComponent(state, target, from, to)
  runItems(state, componentItems(state, target, from, to))
end

local function runProp(state, target, from, to)
  runItems(state, propItems(state, target, from, to))
  Subject.clearProp(target.index)
end

local function runOverlay(state, target, from, to)
  runItems(state, valueItems(state, target, from, to, function(value)
    Subject.setOverlay(target.index, value, target.color, StudioConfig.catalog.overlayColor)
  end))
end

local function runHairColor(state, target, from, to)
  runItems(state, valueItems(state, target, from, to, Subject.setHairColor))
end

local function runEyeColor(state, target, from, to)
  runItems(state, valueItems(state, target, from, to, Subject.setEyeColor))
end

local RUNNERS <const> = {
  component = runComponent,
  prop = runProp,
  overlay = runOverlay,
  haircolor = runHairColor,
  eyecolor = runEyeColor,
}

local function dress(target, model)
  if target.bare then
    local bare <const> = StudioConfig.catalog.bare[model]

    if bare then
      local components <const> = {}

      for component in pairs(bare) do
        components[#components + 1] = component
      end

      Subject.strip(bare)
      dressed(components, bare)
    end
  end

  if target.hide then
    local hidden <const> = StudioConfig.catalog.hidden[model] or {}

    Subject.hide(target.hide, hidden)
    dressed(target.hide.components or {}, hidden)
  end

  Scene.frame(Subject.ped(), target.preset, model)
  settle()
end

local function runModel(job, model, targets, state)
  local ped <const> = Subject.create(model)

  Scene.frame(ped, nil, model)
  settle()

  local list <const>, planned <const> = inventory(job, targets)
  local before <const> = state.photos
  local givenUp = 0

  Siku.log.info('studio.inventory', ('%s: %d targets, %d photos planned'):format(model, #list, planned), {
    model = model,
    targets = list,
    planned = planned,
    textures = StudioConfig.catalog.textures,
    matte = StudioConfig.capture.matte,
  })

  for i = 1, #list do
    local entry <const> = list[i]
    local target <const> = targets[i]

    Session.checkpoint()

    state.target = target.id
    state.kind = target.kind
    state.index = target.index
    state.asked = nil
    state.recovered = false
    state.recover = function(key, reason)
      local was <const> = Subject.diagnose(target.kind, target.index, state.asked)

      Siku.log.warn('studio.subject_recreated', ('Subject %s recreated after %d photos failed in a row, the last one %s: %s'):format(model, StudioConfig.catalog.failuresInARow, key, reason), {
        model = model,
        target = target.id,
        key = key,
        reason = reason,
        subject = was,
      })

      Subject.recreate(model)
      dress(target, model)
    end

    if entry.count > 0 then
      Siku.log.debug('studio.debug', ('Capture target %s (%s) on %s: %d items from %d to %d, %d photos'):format(target.id, target.label, model, entry.count, entry.from, entry.to, entry.photos), {
        step = 'capture.target',
        model = model,
        target = entry,
      })

      dress(target, model)

      local ok <const>, err <const> = pcall(RUNNERS[target.kind], state, target, entry.from, entry.to)

      if ok then
        givenUp = 0
      else
        if err == 'stopped' then
          error(err, 0)
        end

        givenUp = givenUp + 1
        state.streak = 0

        Siku.log.warn('studio.target_skipped', ('Target %s on %s given up: %s'):format(target.id, model, tostring(err)), {
          model = model,
          target = target.id,
          reason = tostring(err),
          missed = state.missed,
          givenUp = givenUp,
        })

        if givenUp >= StudioConfig.catalog.targetsInARow then
          error(('%d targets given up in a row on %s, the last one %s: %s'):format(givenUp, model, target.id, tostring(err)), 0)
        end
      end

      Subject.restore()
      settle()
    end
  end

  return { model = model, targets = #list, planned = planned, photos = state.photos - before }
end

--- Photographs every item of every target of the job on every model of
--- the catalog, one model after the other, skipping the keys the server
--- already holds.
---@param job table { models?, target?, from?, to?, done? }
---@return string summary
function Catalog.run(job)
  local targets <const> = targetsFor(job)
  local models <const> = job.models or StudioConfig.catalog.models
  local state <const> = {
    model = nil,
    folder = nil,
    done = job.done or {},
    photos = 0,
    skipped = 0,
    missed = 0,
    retaken = 0,
    streak = 0,
    readMs = 0,
    target = nil,
    startedAt = GetGameTimer(),
  }
  local runs <const> = {}
  local planned = 0

  local finished <const>, failure <const> = pcall(function()
    for i = 1, #models do
      Session.checkpoint()

      state.model = models[i]
      state.folder = StudioConfig.catalog.folders[models[i]] or models[i]
      runs[i] = runModel(job, models[i], targets, state)
      planned = planned + runs[i].planned
    end
  end)

  if not finished and failure == 'stopped' then
    error(failure, 0)
  end

  local captureMs <const> = GetGameTimer() - state.startedAt
  local flushed <const> = Nui.request('flush', {}, FLUSH_TIMEOUT_MS)

  if not flushed.ok then
    error(('flush failed in the capture page: %s'):format(tostring(flushed.error)), 0)
  end

  local totalMs <const> = GetGameTimer() - state.startedAt
  local stats <const> = flushed.stats or {}
  local parts <const> = {}

  for i = 1, #runs do
    parts[i] = ('%s %d'):format(runs[i].model, runs[i].photos)
  end

  local result <const> = {
    models = runs,
    target = job.target or 'all',
    planned = planned,
    photos = state.photos,
    skipped = state.skipped,
    missed = state.missed,
    retaken = state.retaken,
    error = (not finished) and tostring(failure) or nil,
    uploaded = stats.uploaded or 0,
    failed = stats.failed or 0,
    errors = stats.errors,
    bytes = stats.bytes or 0,
    captureMs = captureMs,
    totalMs = totalMs,
    photosPerSecond = totalMs > 0 and state.photos / (totalMs / 1000) or 0,
    averageReadMs = state.photos > 0 and state.readMs / state.photos or 0,
    averageEncodeMs = stats.averageEncodeMs,
    averageUploadMs = stats.averageUploadMs,
    matted = stats.matted or 0,
    unmatted = stats.unmatted or 0,
    retries = stats.retries or 0,
    averageSettled = stats.averageSettled,
    averageTransparent = stats.averageTransparent,
    backgrounds = stats.backgrounds,
  }

  result.summary = ('%d photos taken (%s), %d skipped, %d never shown, %d retaken, %d uploaded, %d failed, %.1f photos/s, %d s%s'):format(
    state.photos, table.concat(parts, ', '), state.skipped, state.missed, state.retaken, result.uploaded, result.failed, result.photosPerSecond, math.floor(totalMs / 1000),
    finished and '' or (', stopped early: ' .. tostring(failure))
  )

  Session.report('capture', result)

  if not finished then
    error(tostring(failure), 0)
  end

  return result.summary
end
