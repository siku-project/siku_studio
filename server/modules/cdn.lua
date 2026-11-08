local UPLOAD_PATH <const> = '/api/v1/files'
local MIMES <const> = {
  webp = 'image/webp',
  png = 'image/png',
  jpg = 'image/jpeg',
  jpeg = 'image/jpeg',
  gif = 'image/gif',
  json = 'application/json',
}

local function key()
  return GetConvar(StudioConfig.cdn.keyConvar, '')
end

local function encode(value)
  return tostring(value):gsub('[^%w%-%._~]', function(char)
    return ('%%%02X'):format(char:byte())
  end)
end

--- Whether photos go to the CDN: a url, a folder and an API key are set.
---@return boolean
function Studio.cdnEnabled()
  local cdn <const> = StudioConfig.cdn

  return type(cdn) == 'table' and type(cdn.url) == 'string' and #cdn.url > 0
    and type(cdn.folder) == 'string' and #cdn.folder > 0 and #key() > 0
end

--- The MIME type of a file, from its extension.
---@param name string
---@return string mime
function Studio.cdnMime(name)
  return MIMES[(name:match('%.(%w+)$') or ''):lower()] or 'application/octet-stream'
end

--- Sends one file to the CDN folder and waits for its answer.
---@param name string The file name in the folder.
---@param body string The file bytes.
---@return table result { ok, status, id?, url?, error? }
function Studio.cdnPut(name, body)
  local cdn <const> = StudioConfig.cdn
  local url <const> = ('%s%s?folder=%s&name=%s&overwrite=%s&mkdir=0'):format(
    cdn.url, UPLOAD_PATH, encode(cdn.folder), encode(name), cdn.overwrite and '1' or '0'
  )
  local done <const> = promise.new()
  local settled = false

  PerformHttpRequest(url, function(status, text)
    if settled then
      return
    end

    settled = true

    local decoded <const> = type(text) == 'string' and #text > 0 and json.decode(text) or nil

    if status >= 200 and status < 300 and type(decoded) == 'table' then
      done:resolve({ ok = true, status = status, id = decoded.id, url = decoded.absoluteUrl or decoded.url, name = decoded.name })
      return
    end

    done:resolve({
      ok = false,
      status = status,
      error = type(decoded) == 'table' and type(decoded.error) == 'table' and decoded.error.code or ('http_%d'):format(status),
      detail = type(decoded) == 'table' and type(decoded.error) == 'table' and decoded.error.message or nil,
    })
  end, 'PUT', body, {
    Authorization = 'Bearer ' .. key(),
    ['Content-Type'] = Studio.cdnMime(name),
  })

  SetTimeout(cdn.timeoutMs or 30000, function()
    if not settled then
      settled = true
      done:resolve({ ok = false, status = 0, error = 'timeout' })
    end
  end)

  return Citizen.Await(done)
end
