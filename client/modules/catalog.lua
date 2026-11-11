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

    local snapped <const> = Nui.request('snap', {}, SNAP_TIMEOUT_MS)

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

local function shoot(state, key, prepare)
  if state.done[key] then
    state.skipped = state.skipped + 1
    return
  end

  local ok <const>, err <const> = pcall(function()
    if not prepare() then
      error(T('error_change_never_shown'), 0)
    end

    photo(state, key)
  end)

  if ok then
    state.streak = 0
    return
  end

  if err == 'stopped' then
    error(err, 0)
  end

  local reason <const> = tostring(err)

  state.missed = state.missed + 1
  state.streak = state.streak + 1

  Siku.log.warn('studio.photo_skipped', ('Photo %s skipped: %s'):format(key, reason), {
    key = key,
    model = state.model,
    target = state.target,
    reason = reason,
    streak = state.streak,
    missed = state.missed,
  })

  if state.streak >= StudioConfig.catalog.failuresInARow then
    error(('%d photos failed in a row, the last one %s: %s'):format(state.streak, key, reason), 0)
  end
end

local function runComponent(state, target, from, to)
  local timeout <const> = StudioConfig.catalog.changeTimeoutMs

  for drawable = from, to do
    local textures <const> = textureLimit(Subject.textures(target.index, drawable))

    for texture = 0, textures - 1 do
      local key <const> = ('%s/%s_%d_%d.webp'):format(state.folder, target.name, drawable, texture)

      shoot(state, key, function()
        Subject.setVariation(target.index, drawable, texture)
        Subject.preload(target.index, drawable, texture)

        local shown <const> = waitFinished(Subject.preloadFinished, timeout)

        Subject.releasePreload()

        return shown
      end)
    end
  end
end

local function runProp(state, target, from, to)
  local timeout <const> = StudioConfig.catalog.changeTimeoutMs

  for drawable = from, to do
    local textures <const> = textureLimit(Subject.propTextures(target.index, drawable))

    for texture = 0, textures - 1 do
      local key <const> = ('%s/%s_%d_%d.webp'):format(state.folder, target.name, drawable, texture)

      shoot(state, key, function()
        Subject.setProp(target.index, drawable, texture)
        Subject.preloadProp(target.index, drawable, texture)

        local shown <const> = waitFinished(Subject.preloadPropFinished, timeout)

        Subject.releasePreloadProp()

        return shown
      end)
    end
  end

  Subject.clearProp(target.index)
end

local function runOverlay(state, target, from, to)
  for value = from, to do
    local key <const> = ('%s/%s_%d.webp'):format(state.folder, target.name, value)

    shoot(state, key, function()
      Subject.setOverlay(target.index, value, target.color, StudioConfig.catalog.overlayColor)
      settle(OVERLAY_SETTLE_FRAMES)

      return true
    end)
  end
end

local function runHairColor(state, target, from, to)
  for color = from, to do
    local key <const> = ('%s/%s_%d.webp'):format(state.folder, target.name, color)

    shoot(state, key, function()
      Subject.setHairColor(color)
      settle(OVERLAY_SETTLE_FRAMES)

      return true
    end)
  end
end

local function runEyeColor(state, target, from, to)
  for color = from, to do
    local key <const> = ('%s/%s_%d.webp'):format(state.folder, target.name, color)

    shoot(state, key, function()
      Subject.setEyeColor(color)
      settle(OVERLAY_SETTLE_FRAMES)

      return true
    end)
  end
end

local RUNNERS <const> = {
  component = runComponent,
  prop = runProp,
  overlay = runOverlay,
  haircolor = runHairColor,
  eyecolor = runEyeColor,
}

local function runModel(job, model, targets, state)
  local ped <const> = Subject.create(model)

  Scene.frame(ped, nil, model)
  settle()

  local list <const>, planned <const> = inventory(job, targets)
  local before <const> = state.photos

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

    if entry.count > 0 then
      Siku.log.debug('studio.debug', ('Capture target %s (%s) on %s: %d items from %d to %d, %d photos'):format(target.id, target.label, model, entry.count, entry.from, entry.to, entry.photos), {
        step = 'capture.target',
        model = model,
        target = entry,
      })

      if target.bare then
        local bare <const> = StudioConfig.catalog.bare[model]

        if bare then
          Subject.strip(bare)
        end
      end

      if target.hide then
        Subject.hide(target.hide, StudioConfig.catalog.hidden[model] or {})
      end

      Scene.frame(Subject.ped(), target.preset, model)
      settle()

      RUNNERS[target.kind](state, target, entry.from, entry.to)

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
    streak = 0,
    readMs = 0,
    target = nil,
    startedAt = GetGameTimer(),
  }
  local runs <const> = {}
  local planned = 0

  for i = 1, #models do
    Session.checkpoint()

    state.model = models[i]
    state.folder = StudioConfig.catalog.folders[models[i]] or models[i]
    runs[i] = runModel(job, models[i], targets, state)
    planned = planned + runs[i].planned
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

  result.summary = ('%d photos taken (%s), %d skipped, %d never shown, %d uploaded, %d failed, %.1f photos/s, %d s'):format(
    state.photos, table.concat(parts, ', '), state.skipped, state.missed, result.uploaded, result.failed, result.photosPerSecond, math.floor(totalMs / 1000)
  )

  Session.report('capture', result)

  return result.summary
end
