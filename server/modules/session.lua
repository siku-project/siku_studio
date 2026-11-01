local START_EVENT <const> = 'siku_studio:client:start'
local STOP_EVENT <const> = 'siku_studio:client:stop'
local REPORT_EVENT <const> = 'siku_studio:server:report'
local FINISHED_EVENT <const> = 'siku_studio:server:finished'
local TOKEN_LENGTH <const> = 16
local WATCH_INTERVAL_MS <const> = 5000
local CLIENT_BENCHES <const> = { variations = true, readback = true, encode = true, upload = true, full = true, all = true }
local BENCH_NAMES <const> = 'variations, readback, encode, upload, save, full, all'
local RESULTS_FOLDER <const> = 'bench'
local CONSOLE_SOURCE <const> = 0
local FOLDERS <const> = { 'bench', 'bench/upload', 'bench/full', 'bench/save', 'probe' }

local resource <const> = GetCurrentResourceName()
local session = nil

local function tell(src, message)
  if src == CONSOLE_SOURCE then
    Siku.print.info(message)
    return
  end

  Siku.notification.show(src, {
    type = 'info',
    title = T('studio_title'),
    description = message,
  })
end

local function actor(src)
  return { { type = 'player', id = src, role = 'actor' } }
end

local function elapsedSeconds(since)
  return math.floor((GetGameTimer() - since) / 1000)
end

--- The running session when the token matches and it is still alive.
---@param token string The token presented by the client or the interface.
---@return table|nil session The session, refreshed, or nil.
function Studio.touch(token)
  if not session or type(token) ~= 'string' or token ~= session.token then
    return nil
  end

  session.updatedAt = GetGameTimer()

  return session
end

--- The running session, whoever asks.
---@return table|nil session
function Studio.current()
  return session
end

--- Counts one file written for the session, with its cost.
---@param bytes number
---@param ms number
function Studio.recordWrite(bytes, ms)
  if not session then
    return
  end

  local writes <const> = session.writes

  writes.count = writes.count + 1
  writes.bytes = writes.bytes + bytes
  writes.ms = writes.ms + ms

  if ms > writes.maxMs then
    writes.maxMs = ms
  end
end

local function writeResults(current, ok, errorText)
  local stamp <const> = os.date('!%Y%m%d-%H%M%S')
  local path <const> = ('%s/%s/%s_%s.json'):format(StudioConfig.output.root, RESULTS_FOLDER, stamp, current.bench or current.kind)
  local payload <const> = json.encode({
    kind = current.kind,
    bench = current.bench,
    player = current.player,
    startedAt = current.startedAtDate,
    durationSeconds = elapsedSeconds(current.startedAt),
    ok = ok,
    error = errorText,
    results = current.results,
    writes = current.writes,
  })

  if not SaveResourceFile(resource, path, payload, #payload) then
    Siku.log.error('studio.results_failed', ('Results could not be written to %s'):format(path), {
      path = path,
      bytes = #payload,
    }, { outcome = 'failure', source = current.player, entities = actor(current.player) })
    return nil
  end

  return path
end

local function finish(ok, summary, errorText, stack)
  local current <const> = session

  if not current then
    return
  end

  session = nil

  local duration <const> = elapsedSeconds(current.startedAt)
  local path <const> = writeResults(current, ok, errorText)

  if ok then
    Siku.log.info('studio.session_finished', ('Session %s finished in %ds: %s'):format(current.bench or current.kind, duration, summary or 'done'), {
      kind = current.kind,
      bench = current.bench,
      durationSeconds = duration,
      summary = summary,
      results = current.results,
      writes = current.writes,
      resultsFile = path,
    }, { outcome = 'success', source = current.player, entities = actor(current.player) })
    tell(current.player, T('studio_finished', current.bench or current.kind, duration))
    return
  end

  if errorText == 'stopped' then
    Siku.log.info('studio.session_finished', ('Session %s stopped after %ds'):format(current.bench or current.kind, duration), {
      kind = current.kind,
      bench = current.bench,
      durationSeconds = duration,
      stopped = true,
      results = current.results,
      writes = current.writes,
      resultsFile = path,
    }, { outcome = 'cancelled', source = current.player, entities = actor(current.player) })
    tell(current.player, T('studio_stopped'))
    return
  end

  Siku.log.error('studio.session_failed', ('Session %s failed after %ds: %s'):format(current.bench or current.kind, duration, tostring(errorText)), {
    kind = current.kind,
    bench = current.bench,
    durationSeconds = duration,
    error = tostring(errorText),
    results = current.results,
    writes = current.writes,
    resultsFile = path,
  }, { outcome = 'failure', stack = stack, source = current.player, entities = actor(current.player) })
  tell(current.player, T('studio_failed', current.bench or current.kind, tostring(errorText)))
end

local function start(src, kind, bench)
  local token <const> = Siku.math.randomHex(TOKEN_LENGTH)

  local missing <const> = Studio.missingFolders(FOLDERS)

  if #missing > 0 then
    Siku.log.error('studio.output_missing', ('Output folders missing, session refused: %s'):format(table.concat(missing, ', ')), {
      folders = missing,
      kind = kind,
      bench = bench,
    }, { outcome = 'failure', source = src, entities = actor(src) })
    tell(src, T('studio_output_missing'))
    return
  end

  session = {
    token = token,
    player = src,
    kind = kind,
    bench = bench,
    startedAt = GetGameTimer(),
    startedAtDate = os.date('!%Y-%m-%dT%H:%M:%SZ'),
    updatedAt = GetGameTimer(),
    results = {},
    writes = { count = 0, bytes = 0, ms = 0, maxMs = 0 },
  }

  Siku.log.info('studio.session_started', ('%s started a %s session%s'):format(GetPlayerName(tostring(src)) or src, kind, bench and (' (' .. bench .. ')') or ''), {
    kind = kind,
    bench = bench,
    component = StudioConfig.bench.component,
    drawables = StudioConfig.bench.drawables,
    size = StudioConfig.capture.size,
    quality = StudioConfig.capture.quality,
  }, { source = src, entities = actor(src) })

  TriggerClientEvent(START_EVENT, src, token, kind, bench)
  tell(src, T('studio_started', bench or kind))
end

local function runSaveBench(src)
  local count <const> = StudioConfig.bench.saveCount
  local bytes <const> = StudioConfig.bench.saveBytes
  local folder <const> = ('%s/%s/save'):format(StudioConfig.output.root, RESULTS_FOLDER)
  local body <const> = string.rep('x', bytes)
  local total, maxMs, failures = 0.0, 0.0, 0

  Siku.log.debug('studio.debug', ('Save bench: writing %d files of %d bytes'):format(count, bytes), {
    step = 'save.start',
    count = count,
    bytes = bytes,
  }, { source = src, entities = actor(src) })

  for index = 1, count do
    local path <const> = ('%s/%06d.bin'):format(folder, index)
    local started <const> = os.clock()
    local ok <const> = SaveResourceFile(resource, path, body, #body)
    local ms <const> = (os.clock() - started) * 1000

    if ok then
      total = total + ms

      if ms > maxMs then
        maxMs = ms
      end
    else
      failures = failures + 1
    end

    if index % 50 == 0 then
      Wait(0)
    end
  end

  local removeStarted <const> = os.clock()

  for index = 1, count do
    Studio.remove(('%s/%06d.bin'):format(folder, index))
  end

  local removeMs <const> = (os.clock() - removeStarted) * 1000
  local result <const> = {
    count = count,
    bytes = bytes,
    failures = failures,
    averageMs = count > 0 and total / count or 0,
    maxMs = maxMs,
    totalMs = total,
    filesPerSecond = total > 0 and math.floor(count / (total / 1000)) or 0,
    removeMs = removeMs,
  }

  session.results.save = result

  Siku.log.info('studio.bench', ('Bench save: %d files of %d bytes, %.2f ms average, %.2f ms max, %d files/s'):format(count, bytes, result.averageMs, maxMs, result.filesPerSecond), {
    bench = 'save',
    result = result,
  }, { source = src, entities = actor(src) })

  finish(true, ('%d files/s'):format(result.filesPerSecond))
end

Siku.command.register('studio', function(src, args)
  local action <const> = args.action

  if action == 'status' then
    if not session then
      tell(src, T('studio_nothing'))
    else
      tell(src, T('studio_status', session.bench or session.kind, GetPlayerName(tostring(session.player)) or session.player, elapsedSeconds(session.startedAt)))
    end

    return
  end

  if action == 'stop' then
    if not session then
      tell(src, T('studio_nothing'))
      return
    end

    Siku.log.debug('studio.debug', ('Stop asked by %s'):format(GetPlayerName(tostring(src)) or src), {
      step = 'stop',
      kind = session.kind,
      bench = session.bench,
    }, { source = src, entities = actor(src) })

    TriggerClientEvent(STOP_EVENT, session.player, session.token)
    return
  end

  if session then
    Siku.log.warn('studio.command_refused', ('%s asked for %s while a session is running'):format(GetPlayerName(tostring(src)) or src, action), {
      action = action,
      reason = 'busy',
      runningKind = session.kind,
      runningBench = session.bench,
      runningPlayer = session.player,
    }, { outcome = 'denied', source = src, entities = actor(src) })
    tell(src, T('studio_busy', GetPlayerName(tostring(session.player)) or session.player))
    return
  end

  if src == CONSOLE_SOURCE then
    tell(src, T('studio_in_game'))
    return
  end

  if action == 'probe' then
    start(src, 'probe', nil)
    return
  end

  local bench <const> = (args.target or 'all'):lower()

  if bench == 'save' then
    start(src, 'bench', bench)

    if session then
      CreateThread(function()
        runSaveBench(src)
      end)
    end

    return
  end

  if not CLIENT_BENCHES[bench] then
    Siku.log.warn('studio.command_refused', ('%s asked for an unknown bench: %s'):format(GetPlayerName(tostring(src)) or src, bench), {
      action = action,
      reason = 'unknown_bench',
      bench = bench,
    }, { outcome = 'denied', source = src, entities = actor(src) })
    tell(src, T('studio_unknown_bench', bench, BENCH_NAMES))
    return
  end

  start(src, 'bench', bench)
end, {
  permission = StudioConfig.permission,
  cooldown = StudioConfig.cooldownMs,
  description = 'Studio de capture : bench, probe, status, stop.',
  arguments = {
    { name = 'action', type = 'string', choices = { 'bench', 'probe', 'status', 'stop' }, help = 'bench, probe, status ou stop' },
    { name = 'target', type = 'string', optional = true, help = 'bench : variations, readback, encode, upload, save, full, all' },
  },
})

RegisterNetEvent(REPORT_EVENT, function(token, name, result)
  local src <const> = source
  local current <const> = Studio.touch(token)

  if not current or current.player ~= src or type(name) ~= 'string' or type(result) ~= 'table' then
    return
  end

  current.results[name] = result

  Siku.log.info('studio.bench', ('Bench %s: %s'):format(name, tostring(result.summary or 'done')), {
    bench = name,
    result = result,
  }, { source = src, entities = actor(src) })

  if name == 'upload' then
    local removed = 0

    for index = 1, StudioConfig.bench.uploadCount do
      if Studio.remove(('%s/bench/upload/%06d.bin'):format(StudioConfig.output.root, index)) then
        removed = removed + 1
      end
    end

    Siku.log.debug('studio.debug', ('Upload bench files removed: %d'):format(removed), {
      step = 'upload.cleanup',
      removed = removed,
    }, { source = src, entities = actor(src) })
  end
end)

RegisterNetEvent(FINISHED_EVENT, function(token, ok, summary, errorText, stack)
  local src <const> = source
  local current <const> = Studio.touch(token)

  if not current or current.player ~= src then
    return
  end

  finish(ok == true, type(summary) == 'string' and summary or nil, errorText, type(stack) == 'string' and stack or nil)
end)

AddEventHandler('playerDropped', function(reason)
  local src <const> = source

  if not session or session.player ~= src then
    return
  end

  local current <const> = session

  session = nil

  Siku.log.warn('studio.session_abandoned', ('%s left during a %s session: %s'):format(GetPlayerName(tostring(src)) or src, current.bench or current.kind, tostring(reason)), {
    kind = current.kind,
    bench = current.bench,
    durationSeconds = elapsedSeconds(current.startedAt),
    reason = tostring(reason),
    results = current.results,
  }, { outcome = 'failure', source = src, entities = actor(src) })
end)

CreateThread(function()
  local missing <const> = Studio.missingFolders(FOLDERS)

  if #missing > 0 then
    Siku.log.error('studio.output_missing', ('Output folders missing at start: %s'):format(table.concat(missing, ', ')), {
      folders = missing,
    }, { outcome = 'failure' })
  end

  while true do
    Wait(WATCH_INTERVAL_MS)

    if session and GetGameTimer() - session.updatedAt > StudioConfig.http.tokenTtlMs then
      local current <const> = session

      TriggerClientEvent(STOP_EVENT, current.player, current.token)
      finish(false, nil, ('no activity for %d seconds'):format(math.floor(StudioConfig.http.tokenTtlMs / 1000)), nil)
    end
  end
end)
