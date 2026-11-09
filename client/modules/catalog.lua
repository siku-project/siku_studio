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
      error(T('error_change_never_shown'), 0)
    end

    Wait(0)
  end
end

local function textureLimit(available)
  local wanted <const> = StudioConfig.catalog.textures

  if wanted <= 0 or wanted > available then
    return available
  end

  return wanted
end

local function targetsFor(job)
  local all <const> = StudioConfig.catalog.targets

  if not job.target or job.target == 'all' then
    return all
  end

  for i = 1, #all do
    if all[i].id == job.target then
      return { all[i] }
    end
  end

  error(('unknown catalog target %s'):format(tostring(job.target)), 0)
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

local function runComponent(state, target, from, to)
  local timeout <const> = StudioConfig.bench.changeTimeoutMs

  for drawable = from, to do
    local textures <const> = textureLimit(Subject.textures(target.index, drawable))

    for texture = 0, textures - 1 do
      local key <const> = ('%s/component_%d_%d_%d.webp'):format(state.model, target.index, drawable, texture)

      if not state.done[key] then
        Subject.setVariation(target.index, drawable, texture)
        Subject.preload(target.index, drawable, texture)
        waitFinished(Subject.preloadFinished, timeout)
        Subject.releasePreload()
      end

      photo(state, key)
    end
  end
end

local function runProp(state, target, from, to)
  local timeout <const> = StudioConfig.bench.changeTimeoutMs

  for drawable = from, to do
    local textures <const> = textureLimit(Subject.propTextures(target.index, drawable))

    for texture = 0, textures - 1 do
      local key <const> = ('%s/prop_%d_%d_%d.webp'):format(state.model, target.index, drawable, texture)

      if not state.done[key] then
        Subject.setProp(target.index, drawable, texture)
        Subject.preloadProp(target.index, drawable, texture)
        waitFinished(Subject.preloadPropFinished, timeout)
        Subject.releasePreloadProp()
      end

      photo(state, key)
    end
  end

  Subject.clearProp(target.index)
end

local function runOverlay(state, target, from, to)
  for value = from, to do
    local key <const> = ('%s/overlay_%d_%d.webp'):format(state.model, target.index, value)

    if not state.done[key] then
      Subject.setOverlay(target.index, value, target.color, StudioConfig.catalog.overlayColor)
      settle(OVERLAY_SETTLE_FRAMES)
    end

    photo(state, key)
  end
end

local function runHairColor(state, target, from, to)
  for color = from, to do
    local key <const> = ('%s/haircolor_%d.webp'):format(state.model, color)

    if not state.done[key] then
      Subject.setHairColor(color)
      settle(OVERLAY_SETTLE_FRAMES)
    end

    photo(state, key)
  end
end

local function runEyeColor(state, target, from, to)
  for color = from, to do
    local key <const> = ('%s/eyecolor_%d.webp'):format(state.model, color)

    if not state.done[key] then
      Subject.setEyeColor(color)
      settle(OVERLAY_SETTLE_FRAMES)
    end

    photo(state, key)
  end
end

local RUNNERS <const> = {
  component = runComponent,
  prop = runProp,
  overlay = runOverlay,
  haircolor = runHairColor,
  eyecolor = runEyeColor,
}

--- Photographs every item of every target of the job, skipping the keys
--- the server already holds, one target after the other.
---@param job table { model, target?, from?, to?, done? }
---@return string summary
function Catalog.run(job)
  local targets <const> = targetsFor(job)
  local list <const>, planned <const>, alreadyDone <const> = inventory(job, targets)
  local state <const> = {
    model = job.model,
    done = job.done or {},
    photos = 0,
    skipped = 0,
    readMs = 0,
    target = nil,
    startedAt = GetGameTimer(),
  }

  Siku.log.info('studio.inventory', ('%s: %d targets, %d photos planned, %d already on the server'):format(job.model, #list, planned, alreadyDone), {
    model = job.model,
    targets = list,
    planned = planned,
    alreadyDone = alreadyDone,
    textures = StudioConfig.catalog.textures,
    matte = StudioConfig.capture.matte,
  })

  for i = 1, #list do
    local entry <const> = list[i]
    local target <const> = targets[i]

    Session.checkpoint()

    state.target = target.id

    if entry.count > 0 then
      Siku.log.debug('studio.debug', ('Capture target %s (%s): %d items from %d to %d, %d photos'):format(target.id, target.label, entry.count, entry.from, entry.to, entry.photos), {
        step = 'capture.target',
        target = entry,
      })

      if target.bare then
        local bare <const> = StudioConfig.catalog.bare[job.model]

        if bare then
          Subject.strip(bare)
        end
      end

      Scene.frame(Subject.ped(), target.preset)
      settle()

      RUNNERS[target.kind](state, target, entry.from, entry.to)

      Subject.restore()
      settle()
    end
  end

  local captureMs <const> = GetGameTimer() - state.startedAt
  local flushed <const> = Nui.request('flush', {}, FLUSH_TIMEOUT_MS)

  if not flushed.ok then
    error(('flush failed in the capture page: %s'):format(tostring(flushed.error)), 0)
  end

  local totalMs <const> = GetGameTimer() - state.startedAt
  local stats <const> = flushed.stats or {}
  local result <const> = {
    model = job.model,
    target = job.target or 'all',
    planned = planned,
    photos = state.photos,
    skipped = state.skipped,
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
  }

  result.summary = ('%s: %d photos taken, %d skipped, %d uploaded, %d failed, %.1f photos/s, %d s'):format(
    job.model, state.photos, state.skipped, result.uploaded, result.failed, result.photosPerSecond, math.floor(totalMs / 1000)
  )

  Session.report('capture', result)

  return result.summary
end
