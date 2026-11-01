local UPLOAD_CALLBACK <const> = 'siku_studio:nui:upload'
local UPLOAD_EVENT <const> = 'siku_studio:server:upload'
local STORED_EVENT <const> = 'siku_studio:client:stored'
local JSON_HEADERS <const> = { ['Content-Type'] = 'application/json' }

local pending <const> = {}
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

    local id <const> = sequence
    local stored <const> = promise.new()
    local started <const> = GetGameTimer()

    pending[id] = stored

    TriggerLatentServerEvent(UPLOAD_EVENT, StudioConfig.transport.bytesPerSecond, token, id, params.kind, params.key, body)

    SetTimeout(StudioConfig.transport.ackTimeoutMs, function()
      local waiting <const> = pending[id]

      if waiting then
        pending[id] = nil
        waiting:resolve({ ok = false, error = 'ack_timeout' })
      end
    end)

    local result <const> = Citizen.Await(stored)

    result.transferMs = GetGameTimer() - started
    result.bytes = #body

    answer(cb, result.ok and 200 or 500, result)
  end)
end)

RegisterNetEvent(STORED_EVENT, function(id, result)
  local waiting <const> = pending[id]

  if waiting then
    pending[id] = nil
    waiting:resolve(type(result) == 'table' and result or { ok = false, error = 'bad_ack' })
  end
end)
