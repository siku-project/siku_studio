Session = {}

local START_EVENT <const> = 'siku_studio:client:start'
local STOP_EVENT <const> = 'siku_studio:client:stop'
local REPORT_EVENT <const> = 'siku_studio:server:report'
local FINISHED_EVENT <const> = 'siku_studio:server:finished'
local CONFIGURE_TIMEOUT_MS <const> = 10000

local resource <const> = GetCurrentResourceName()
local state = nil

local function endpoint()
  if StudioConfig.http.endpoint then
    return ('%s/%s'):format(StudioConfig.http.endpoint, resource)
  end

  return ('http://%s/%s'):format(GetCurrentServerEndpoint(), resource)
end

--- Whether a session is running and has not been asked to stop.
---@return boolean
function Session.running()
  return state ~= nil and not state.stopped
end

--- Throws when the session was asked to stop, so a bench unwinds between two steps.
function Session.checkpoint()
  if not state or state.stopped then
    error('stopped', 0)
  end
end

--- The token of the running session, nil when none runs.
---@return string|nil
function Session.token()
  return state and state.token or nil
end

--- Sends one bench result to the server, which logs and keeps it.
---@param name string The bench name.
---@param result table The result, with a `summary` string.
function Session.report(name, result)
  if not state then
    return
  end

  Siku.log.debug('studio.debug', ('Bench %s reported: %s'):format(name, tostring(result.summary)), {
    step = 'report',
    bench = name,
    result = result,
  })

  TriggerServerEvent(REPORT_EVENT, state.token, name, result)
end

local function cleanup()
  Nui.cancelAll()
  Transport.cancelAll()
  Nui.send('reset')
  Subject.destroy()
  Scene.leave()
end

local function run(token, kind, bench)
  local started <const> = GetGameTimer()

  Siku.log.debug('studio.debug', ('Session %s starting on the client, transport %s'):format(bench or kind, StudioConfig.transport.mode), {
    step = 'start',
    kind = kind,
    bench = bench,
    transport = StudioConfig.transport.mode,
    bytesPerSecond = StudioConfig.transport.bytesPerSecond,
    endpoint = endpoint(),
  })

  Scene.enter({
    onAbort = function()
      Session.stop('escape')
    end,
  })

  Siku.log.debug('studio.debug', 'Scene built, camera rendering', { step = 'scene' })

  local ped <const> = Subject.create()

  Scene.frame(ped, nil)

  Siku.log.debug('studio.debug', ('Subject cloned (%d) and framed'):format(ped), {
    step = 'subject',
    ped = ped,
    model = GetEntityModel(ped),
  })

  local width <const>, height <const> = GetActiveScreenResolution()
  local configured <const> = Nui.request('configure', {
    token = token,
    transport = StudioConfig.transport.mode,
    endpoint = endpoint(),
    screen = { width = width, height = height },
    frame = StudioConfig.capture.frame,
    size = StudioConfig.capture.size,
    quality = StudioConfig.capture.quality,
    lossless = StudioConfig.capture.lossless,
    workers = StudioConfig.capture.workers,
  }, CONFIGURE_TIMEOUT_MS)

  if not configured.ok then
    error(('capture page refused the configuration: %s'):format(tostring(configured.error)), 0)
  end

  Siku.log.debug('studio.debug', ('Capture page configured, server %s'):format(configured.server and configured.server.reachable and 'reachable' or 'UNREACHABLE'), {
    step = 'configure',
    screen = { width = width, height = height },
    endpoint = endpoint(),
    server = configured.server,
    gl = configured.gl,
  })

  if not configured.server or not configured.server.reachable then
    error(('capture page cannot reach %s: %s'):format(endpoint(), tostring(configured.server and configured.server.error)), 0)
  end

  Session.checkpoint()

  local summary

  if kind == 'probe' then
    summary = Bench.probe()
  elseif bench == 'all' then
    summary = Bench.all()
  else
    summary = Bench.run(bench)
  end

  Siku.log.debug('studio.debug', ('Session %s done on the client in %d ms'):format(bench or kind, GetGameTimer() - started), {
    step = 'done',
    durationMs = GetGameTimer() - started,
    summary = summary,
  })

  return summary
end

--- Stops the running session; the bench unwinds at its next checkpoint.
---@param reason string Who or what asked.
function Session.stop(reason)
  if not state or state.stopped then
    return
  end

  state.stopped = true

  Siku.log.debug('studio.debug', ('Session stop asked: %s'):format(reason), {
    step = 'stop',
    reason = reason,
  })

  Nui.cancelAll()
end

RegisterNetEvent(START_EVENT, function(token, kind, bench)
  if state then
    Siku.log.warn('studio.command_refused', 'Start received while a session is already running on this client', {
      reason = 'client_busy',
      kind = kind,
      bench = bench,
    })
    return
  end

  state = { token = token, kind = kind, bench = bench, stopped = false }

  CreateThread(function()
    local ok <const>, result <const> = xpcall(run, function(err)
      return { message = tostring(err), stack = debug.traceback(tostring(err), 2) }
    end, token, kind, bench)

    local current <const> = state

    state = nil

    pcall(cleanup)

    if ok then
      TriggerServerEvent(FINISHED_EVENT, current.token, true, result, nil, nil)
      return
    end

    if result.message == 'stopped' or (current.stopped and result.message:find('cancelled', 1, true)) then
      TriggerServerEvent(FINISHED_EVENT, current.token, false, nil, 'stopped', nil)
      return
    end

    Siku.log.debug('studio.debug', ('Session failed on the client: %s'):format(result.message), {
      step = 'failed',
      error = result.message,
    }, { stack = result.stack })

    TriggerServerEvent(FINISHED_EVENT, current.token, false, nil, result.message, result.stack)
  end)
end)

Nui.on('error', function(data)
  Siku.log.error('studio.page_error', ('Capture page error in %s: %s'):format(tostring(data.handler), tostring(data.message)), {
    handler = data.handler,
    error = data.message,
    kind = state and state.kind or nil,
    bench = state and state.bench or nil,
  }, { stack = type(data.stack) == 'string' and data.stack or nil })
end)

RegisterNetEvent(STOP_EVENT, function(token)
  if state and state.token == token then
    Session.stop('server')
  end
end)

AddEventHandler('onResourceStop', function(name)
  if name == resource and state then
    state.stopped = true
    pcall(cleanup)
  end
end)
