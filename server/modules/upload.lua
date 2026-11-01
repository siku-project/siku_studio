local UPLOAD_PATH <const> = '/upload'
local HEALTH_PATH <const> = '/health'
local KINDS <const> = { bench = true, probe = true, capture = true }
local KEY_PATTERN <const> = '^[%w_%-/%.]+$'
local PARENT_PATTERN <const> = '%.%.'
local HEADERS <const> = {
  ['Content-Type'] = 'application/json',
  ['Access-Control-Allow-Origin'] = '*',
  ['Access-Control-Allow-Methods'] = 'POST, OPTIONS',
  ['Access-Control-Allow-Headers'] = 'Content-Type',
}

local resource <const> = GetCurrentResourceName()

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

local function refuse(res, status, reason, detail)
  local current <const> = Studio.current()

  Siku.log.warn('studio.upload_refused', ('Upload refused: %s'):format(reason), {
    reason = reason,
    detail = detail,
    status = status,
  }, { outcome = 'denied', source = current and current.player or nil, entities = current and { { type = 'player', id = current.player, role = 'actor' } } or nil })
  reply(res, status, { ok = false, error = reason })
end

--- Creates a folder of the resource, level by level, when it is missing.
---@param path string The path relative to the resource.
function Studio.ensureFolder(path)
  local base <const> = GetResourcePath(resource)
  local current = base

  for part in path:gmatch('[^/]+') do
    current = ('%s/%s'):format(current, part)
    os.createdir(current)
  end
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
    refuse(res, 403, 'invalid_token')
    return
  end

  local kind <const> = params.kind
  local key <const> = params.key

  if not KINDS[kind] then
    refuse(res, 400, 'invalid_kind', tostring(kind))
    return
  end

  if type(key) ~= 'string' or #key == 0 or #key > 200 or not key:match(KEY_PATTERN) or key:find(PARENT_PATTERN) then
    refuse(res, 400, 'invalid_key', tostring(key))
    return
  end

  req.setDataHandler(function(body)
    if type(body) ~= 'string' or #body == 0 then
      refuse(res, 400, 'empty_body', key)
      return
    end

    if #body > StudioConfig.http.maxBytes then
      refuse(res, 413, 'too_large', ('%s: %d bytes'):format(key, #body))
      return
    end

    local target <const> = ('%s/%s/%s'):format(StudioConfig.output.root, kind, key)
    local started <const> = os.clock()
    local ok <const> = SaveResourceFile(resource, target, body, #body)
    local ms <const> = (os.clock() - started) * 1000

    if not ok then
      Siku.log.error('studio.save_failed', ('%s could not be written'):format(target), {
        path = target,
        bytes = #body,
      }, { outcome = 'failure', source = session.player, entities = { { type = 'player', id = session.player, role = 'actor' } } })
      reply(res, 500, { ok = false, error = 'write_failed' })
      return
    end

    Studio.recordWrite(#body, ms)

    Siku.log.debug('studio.saved', ('%s written, %d bytes in %.2f ms'):format(target, #body, ms), {
      path = target,
      kind = kind,
      key = key,
      bytes = #body,
      writeMs = ms,
    }, { source = session.player, entities = { { type = 'player', id = session.player, role = 'actor' } } })

    reply(res, 200, { ok = true, path = target, bytes = #body, writeMs = ms })
  end, 'binary')
end)
