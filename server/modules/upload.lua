local UPLOAD_PATH <const> = '/upload'
local HEALTH_PATH <const> = '/health'
local UPLOAD_EVENT <const> = 'siku_studio:server:upload'
local STORED_EVENT <const> = 'siku_studio:client:stored'
local KINDS <const> = { bench = true, probe = true, capture = true }
local KEY_PATTERN <const> = '^[%w_%-/%.]+$'
local PARENT_PATTERN <const> = '%.%.'
local KEY_MAX <const> = 200
local HEADERS <const> = {
  ['Content-Type'] = 'application/json',
  ['Access-Control-Allow-Origin'] = '*',
  ['Access-Control-Allow-Methods'] = 'POST, OPTIONS',
  ['Access-Control-Allow-Headers'] = 'Content-Type',
}

local resource <const> = GetCurrentResourceName()

local function actor(src)
  return { { type = 'player', id = src, role = 'actor' } }
end

local function reply(res, status, body)
  res.writeHead(status, HEADERS)
  res.send(json.encode(body))
end

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

local function refuse(src, transport, reason, detail)
  Siku.log.warn('studio.upload_refused', ('Upload refused (%s): %s'):format(transport, reason), {
    transport = transport,
    reason = reason,
    detail = detail,
  }, { outcome = 'denied', source = src, entities = src and actor(src) or nil })
end

local function invalid(kind, key, body)
  if not KINDS[kind] then
    return 'invalid_kind', tostring(kind)
  end

  if type(key) ~= 'string' or #key == 0 or #key > KEY_MAX or not key:match(KEY_PATTERN) or key:find(PARENT_PATTERN) then
    return 'invalid_key', tostring(key)
  end

  if type(body) ~= 'string' or #body == 0 then
    return 'empty_body', key
  end

  if #body > StudioConfig.http.maxBytes then
    return 'too_large', ('%s: %d bytes'):format(key, #body)
  end

  return nil
end

--- Lists the output folders missing from the resource. Folders ship with
--- the resource (a .gitkeep in each) because FXServer cannot create one
--- from Lua: SaveResourceFile needs the parent, and os.createdir crashes
--- the server when it actually creates the folder.
---@param folders string[] Folder paths relative to the output root.
---@return string[] missing The missing folders, relative to the resource.
function Studio.missingFolders(folders)
  local missing <const> = {}

  for i = 1, #folders do
    local path <const> = ('%s/%s'):format(StudioConfig.output.root, folders[i])

    if LoadResourceFile(resource, path .. '/.gitkeep') == nil then
      missing[#missing + 1] = path
    end
  end

  return missing
end

--- Removes a file written under the output folder.
---@param path string The path relative to the resource.
---@return boolean removed
function Studio.remove(path)
  if type(path) ~= 'string' or not path:match(KEY_PATTERN) or path:find(PARENT_PATTERN) then
    return false
  end

  return os.remove(('%s/%s'):format(GetResourcePath(resource), path)) == true
end

--- Writes one capture of the running session under the output folder.
---@param session table The running session.
---@param kind string The output kind: bench, probe or capture.
---@param key string The file path under the kind folder.
---@param body string The file bytes.
---@param transport string Who brought the bytes: http or event, for the logs.
---@return table result { ok, error?, path?, bytes?, writeMs? }
function Studio.store(session, kind, key, body, transport)
  local target <const> = ('%s/%s/%s'):format(StudioConfig.output.root, kind, key)
  local started <const> = os.clock()
  local ok <const> = SaveResourceFile(resource, target, body, #body)
  local ms <const> = (os.clock() - started) * 1000

  if not ok then
    Siku.log.error('studio.save_failed', ('%s could not be written'):format(target), {
      path = target,
      bytes = #body,
      transport = transport,
    }, { outcome = 'failure', source = session.player, entities = actor(session.player) })

    return { ok = false, error = 'write_failed' }
  end

  Studio.recordWrite(#body, ms)

  Siku.log.debug('studio.saved', ('%s written, %d bytes in %.2f ms'):format(target, #body, ms), {
    path = target,
    kind = kind,
    key = key,
    bytes = #body,
    writeMs = ms,
    transport = transport,
  }, { source = session.player, entities = actor(session.player) })

  return { ok = true, path = target, bytes = #body, writeMs = ms }
end

RegisterNetEvent(UPLOAD_EVENT, function(token, id, kind, key, body)
  local src <const> = source
  local session <const> = Studio.touch(token)

  if not session or session.player ~= src then
    refuse(src, 'event', 'invalid_token')
    TriggerClientEvent(STORED_EVENT, src, id, { ok = false, error = 'invalid_token' })
    return
  end

  local reason <const>, detail <const> = invalid(kind, key, body)

  if reason then
    refuse(src, 'event', reason, detail)
    TriggerClientEvent(STORED_EVENT, src, id, { ok = false, error = reason })
    return
  end

  TriggerClientEvent(STORED_EVENT, src, id, Studio.store(session, kind, key, body, 'event'))
end)

SetHttpHandler(function(req, res)
  local path <const> = req.path:match('^[^?]*')

  if req.method == 'OPTIONS' then
    res.writeHead(204, HEADERS)
    res.send('')
    return
  end

  if path == HEALTH_PATH then
    local current <const> = Studio.current()

    reply(res, 200, { ok = true, session = current and { kind = current.kind, bench = current.bench } or nil })
    return
  end

  if path ~= UPLOAD_PATH or req.method ~= 'POST' then
    reply(res, 404, { ok = false, error = 'not_found' })
    return
  end

  local params <const> = query(req.path)
  local session <const> = Studio.touch(params.token)

  if not session then
    refuse(nil, 'http', 'invalid_token')
    reply(res, 403, { ok = false, error = 'invalid_token' })
    return
  end

  req.setDataHandler(function(body)
    local reason <const>, detail <const> = invalid(params.kind, params.key, body)

    if reason then
      refuse(session.player, 'http', reason, detail)
      reply(res, reason == 'too_large' and 413 or 400, { ok = false, error = reason })
      return
    end

    local result <const> = Studio.store(session, params.kind, params.key, body, 'http')

    reply(res, result.ok and 200 or 500, result)
  end, 'binary')
end)
