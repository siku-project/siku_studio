Transport = {}

local UPLOAD_CALLBACK <const> = 'siku_studio:nui:upload'
local UPLOAD_EVENT <const> = 'siku_studio:server:upload'
local STORED_EVENT <const> = 'siku_studio:client:stored'
local JSON_HEADERS <const> = { ['Content-Type'] = 'application/json' }

local queue <const> = {}
local inFlight = nil
local sequence = 0

local function query(path)
  local params <const> = {}
  local raw <const> = path:match('%?(.*)$')

  if not raw then
    return params
  end

  for pair in raw:gmatch('[^&]+') do
    local key <const>, value <const> = pair:match('^([^=]+)=(.*)$')

    if key then
      params[key] = value:gsub('%%(%x%x)', function(hex)
        return string.char(tonumber(hex, 16))
      end)
    end
  end

  return params
end

local function answer(cb, status, result)
  cb({ status = status, headers = JSON_HEADERS, body = json.encode(result) })
end

local function settle(id, result)
  if not inFlight or inFlight.id ~= id then
    return
  end

  local job <const> = inFlight

  inFlight = nil
  job.stored:resolve(result)
end

local function pump()
  if inFlight or #queue == 0 then
    return
  end

  local job <const> = table.remove(queue, 1)

  inFlight = job
  job.sentAt = GetGameTimer()

  TriggerLatentServerEvent(UPLOAD_EVENT, StudioConfig.transport.bytesPerSecond, job.token, job.id, job.kind, job.key, job.body)

  SetTimeout(StudioConfig.transport.ackTimeoutMs, function()
    settle(job.id, { ok = false, error = 'ack_timeout' })
    pump()
  end)
end

RegisterRawNuiCallback(UPLOAD_CALLBACK, function(req, cb)
  CreateThread(function()
    local token <const> = Session.token()

    if not token then
      answer(cb, 409, { ok = false, error = 'no_session' })
      return
    end

    local body <const> = req.body

    if type(body) ~= 'string' or #body == 0 then
      answer(cb, 400, { ok = false, error = 'empty_body' })
      return
    end

    local params <const> = query(req.path)

    sequence = sequence + 1

    local job <const> = {
      id = sequence,
      token = token,
      kind = params.kind,
      key = params.key,
      body = body,
      stored = promise.new(),
      queuedAt = GetGameTimer(),
    }

    queue[#queue + 1] = job
    pump()

    local result <const> = Citizen.Await(job.stored)
    local now <const> = GetGameTimer()

    result.queueMs = (job.sentAt or now) - job.queuedAt
    result.transferMs = now - (job.sentAt or now)
    result.bytes = #body

    answer(cb, result.ok and 200 or 500, result)
  end)
end)

RegisterNetEvent(STORED_EVENT, function(id, result)
  settle(id, type(result) == 'table' and result or { ok = false, error = 'bad_ack' })
  pump()
end)

--- Drops every queued upload, answering them as cancelled, when a session ends.
function Transport.cancelAll()
  while #queue > 0 do
    local job <const> = table.remove(queue, 1)

    job.stored:resolve({ ok = false, error = 'cancelled' })
  end
end
