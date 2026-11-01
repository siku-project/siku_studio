Bench = {}

local READBACK_TIMEOUT_MS <const> = 120000
local ENCODE_TIMEOUT_MS <const> = 180000
local UPLOAD_TIMEOUT_MS <const> = 180000
local CAPTURE_TIMEOUT_MS <const> = 15000
local FLUSH_TIMEOUT_MS <const> = 180000
local PROBE_TIMEOUT_MS <const> = 15000
local ORDER <const> = { 'variations', 'readback', 'encode', 'upload', 'full' }

local function waitPreloaded(timeoutMs)
  local frames = 0
  local started <const> = GetGameTimer()

  while not Subject.preloadFinished() do
    if GetGameTimer() - started > timeoutMs then
      error(T('error_change_never_shown'), 0)
    end

    frames = frames + 1
    Wait(0)
  end

  return frames, GetGameTimer() - started
end

local function settle()
  for _ = 1, StudioConfig.capture.settleFrames do
    Wait(0)
  end
end

local function drawableCount(component)
  local available <const> = Subject.drawables(component)
  local wanted <const> = StudioConfig.bench.drawables

  if wanted <= 0 or wanted > available then
    return available
  end

  return wanted
end

local function textureCount(component, drawable)
  local available <const> = Subject.textures(component, drawable)
  local wanted <const> = StudioConfig.bench.textures

  if wanted <= 0 or wanted > available then
    return available
  end

  return wanted
end

--- Measures how many frames a change of drawable needs before its assets
--- are in memory, first with nothing prepared, then with the next drawable
--- preloaded while the current one is on screen.
---@return table result
function Bench.variations()
  local component <const> = StudioConfig.bench.component
  local count <const> = drawableCount(component)
  local timeout <const> = StudioConfig.bench.changeTimeoutMs
  local cold <const> = { frames = 0, ms = 0, maxFrames = 0, instant = 0 }
  local warm <const> = { frames = 0, ms = 0, maxFrames = 0, instant = 0 }

  Siku.log.debug('studio.debug', ('Variations bench: component %d, %d drawables, cold pass'):format(component, count), {
    step = 'variations.cold',
    component = component,
    drawables = count,
  })

  for drawable = 0, count - 1 do
    Session.checkpoint()
    Subject.setVariation(component, drawable, 0)
    Subject.preload(component, drawable, 0)

    local frames <const>, ms <const> = waitPreloaded(timeout)

    Subject.releasePreload()
    cold.frames = cold.frames + frames
    cold.ms = cold.ms + ms

    if frames > cold.maxFrames then
      cold.maxFrames = frames
    end

    if frames == 0 then
      cold.instant = cold.instant + 1
    end

    settle()
  end

  Subject.setVariation(component, 0, 0)
  settle()

  Siku.log.debug('studio.debug', ('Variations bench: warm pass, %d frames total cold'):format(cold.frames), {
    step = 'variations.warm',
    cold = cold,
  })

  Subject.preload(component, 0, 0)
  waitPreloaded(timeout)

  for drawable = 0, count - 1 do
    Session.checkpoint()
    Subject.setVariation(component, drawable, 0)

    local frames <const>, ms <const> = waitPreloaded(timeout)

    Subject.releasePreload()
    warm.frames = warm.frames + frames
    warm.ms = warm.ms + ms

    if frames > warm.maxFrames then
      warm.maxFrames = frames
    end

    if frames == 0 then
      warm.instant = warm.instant + 1
    end

    settle()

    if drawable + 1 < count then
      Subject.preload(component, drawable + 1, 0)
    end
  end

  Subject.setVariation(component, 0, 0)

  local result <const> = {
    method = 'frames until HasPedPreloadVariationDataFinished after SetPedComponentVariation',
    component = component,
    drawables = count,
    cold = {
      averageFrames = cold.frames / count,
      maxFrames = cold.maxFrames,
      averageMs = cold.ms / count,
      instant = cold.instant,
    },
    warm = {
      averageFrames = warm.frames / count,
      maxFrames = warm.maxFrames,
      averageMs = warm.ms / count,
      instant = warm.instant,
    },
  }

  result.summary = ('cold %.1f frames (%.0f ms) avg, warm %.1f frames (%.0f ms) avg over %d drawables'):format(
    result.cold.averageFrames, result.cold.averageMs, result.warm.averageFrames, result.warm.averageMs, count
  )

  return result
end

--- Measures reading the screen back: whole screen, centered crop read
--- synchronously, centered crop read through an asynchronous buffer.
---@return table result
function Bench.readback()
  Siku.log.debug('studio.debug', 'Readback bench asked to the capture page', {
    step = 'readback',
    sizes = StudioConfig.bench.sizes,
    iterations = StudioConfig.bench.iterations,
  })

  local reply <const> = Nui.request('bench.readback', {
    sizes = StudioConfig.bench.sizes,
    iterations = StudioConfig.bench.iterations,
  }, READBACK_TIMEOUT_MS)

  if not reply.ok then
    error(('readback bench failed in the capture page: %s'):format(tostring(reply.error)), 0)
  end

  return reply.result
end

--- Measures WebP encoding of a crop, on the page thread and in workers.
---@return table result
function Bench.encode()
  Siku.log.debug('studio.debug', 'Encode bench asked to the capture page', {
    step = 'encode',
    sizes = StudioConfig.bench.sizes,
    qualities = StudioConfig.bench.qualities,
    iterations = StudioConfig.bench.iterations,
  })

  local reply <const> = Nui.request('bench.encode', {
    sizes = StudioConfig.bench.sizes,
    qualities = StudioConfig.bench.qualities,
    iterations = StudioConfig.bench.iterations,
  }, ENCODE_TIMEOUT_MS)

  if not reply.ok then
    error(('encode bench failed in the capture page: %s'):format(tostring(reply.error)), 0)
  end

  return reply.result
end

--- Measures uploads to the server, one at a time then many at once.
---@return table result
function Bench.upload()
  Siku.log.debug('studio.debug', 'Upload bench asked to the capture page', {
    step = 'upload',
    count = StudioConfig.bench.uploadCount,
    bytes = StudioConfig.bench.uploadBytes,
  })

  local reply <const> = Nui.request('bench.upload', {
    count = StudioConfig.bench.uploadCount,
    bytes = StudioConfig.bench.uploadBytes,
  }, UPLOAD_TIMEOUT_MS)

  if not reply.ok then
    error(('upload bench failed in the capture page: %s'):format(tostring(reply.error)), 0)
  end

  return reply.result
end

--- Runs the whole pipeline on real variations: preload, dress, settle,
--- read the crop, encode in a worker, upload, and counts photos per second.
---@return table result
function Bench.full()
  local component <const> = StudioConfig.bench.component
  local count <const> = drawableCount(component)
  local timeout <const> = StudioConfig.bench.changeTimeoutMs
  local started <const> = GetGameTimer()
  local photos, readMs, changeFrames = 0, 0, 0

  Siku.log.debug('studio.debug', ('Full bench: component %d, %d drawables'):format(component, count), {
    step = 'full.start',
    component = component,
    drawables = count,
    textures = StudioConfig.bench.textures,
  })

  Subject.preload(component, 0, 0)
  waitPreloaded(timeout)

  for drawable = 0, count - 1 do
    local textures <const> = textureCount(component, drawable)

    for texture = 0, textures - 1 do
      Session.checkpoint()
      Subject.setVariation(component, drawable, texture)

      local frames <const> = waitPreloaded(timeout)

      Subject.releasePreload()
      changeFrames = changeFrames + frames

      if texture + 1 < textures then
        Subject.preload(component, drawable, texture + 1)
      elseif drawable + 1 < count then
        Subject.preload(component, drawable + 1, 0)
      end

      settle()

      local reply <const> = Nui.request('capture', {
        key = ('full/%d_%d_%d.webp'):format(component, drawable, texture),
      }, CAPTURE_TIMEOUT_MS)

      if not reply.ok then
        error(('capture failed for %d/%d_%d: %s'):format(component, drawable, texture, tostring(reply.error)), 0)
      end

      photos = photos + 1
      readMs = readMs + (reply.readMs or 0)
    end

    if drawable % 10 == 9 then
      Siku.log.debug('studio.debug', ('Full bench: %d photos after %d drawables'):format(photos, drawable + 1), {
        step = 'full.progress',
        photos = photos,
        drawable = drawable,
        elapsedMs = GetGameTimer() - started,
      })
    end
  end

  Subject.setVariation(component, 0, 0)

  local captureMs <const> = GetGameTimer() - started
  local flushed <const> = Nui.request('flush', {}, FLUSH_TIMEOUT_MS)

  if not flushed.ok then
    error(('flush failed in the capture page: %s'):format(tostring(flushed.error)), 0)
  end

  local totalMs <const> = GetGameTimer() - started
  local result <const> = {
    component = component,
    drawables = count,
    photos = photos,
    captureMs = captureMs,
    totalMs = totalMs,
    averageChangeFrames = photos > 0 and changeFrames / photos or 0,
    averageReadMs = photos > 0 and readMs / photos or 0,
    photosPerSecondCapture = captureMs > 0 and photos / (captureMs / 1000) or 0,
    photosPerSecondTotal = totalMs > 0 and photos / (totalMs / 1000) or 0,
    pipeline = flushed.stats,
  }

  result.summary = ('%d photos, %.1f photos/s while capturing, %.1f photos/s end to end, %d upload failures'):format(
    photos, result.photosPerSecondCapture, result.photosPerSecondTotal, flushed.stats and flushed.stats.failed or 0
  )

  return result
end

--- Checks the whole chain once: page, game view binding, one photo saved.
---@return string summary
function Bench.probe()
  local reply <const> = Nui.request('probe', {
    key = ('%d.webp'):format(GetCloudTimeAsInt()),
  }, PROBE_TIMEOUT_MS)

  if not reply.ok then
    error(('probe failed in the capture page: %s'):format(tostring(reply.error)), 0)
  end

  Session.report('probe', reply.result)

  return reply.result.summary
end

--- Runs one bench by name and reports it.
---@param name string
---@return string summary
function Bench.run(name)
  local runner <const> = Bench[name]

  if not runner or name == 'run' or name == 'all' or name == 'probe' then
    error(('unknown bench %s'):format(tostring(name)), 0)
  end

  local started <const> = GetGameTimer()
  local result <const> = runner()

  result.durationMs = GetGameTimer() - started

  Session.report(name, result)

  return result.summary
end

--- Runs every bench in order and reports each one.
---@return string summary
function Bench.all()
  local summaries <const> = {}

  for i = 1, #ORDER do
    Session.checkpoint()
    summaries[#summaries + 1] = ('%s: %s'):format(ORDER[i], Bench.run(ORDER[i]))
  end

  return table.concat(summaries, ' | ')
end
