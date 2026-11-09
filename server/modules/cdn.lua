local UPLOAD_PATH <const> = '/api/v1/files'
local MIMES <const> = {
  webp = 'image/webp',
  png = 'image/png',
  jpg = 'image/jpeg',
  jpeg = 'image/jpeg',
  gif = 'image/gif',
  json = 'application/json',
}

local CHARS <const> = {}

for i = 0, 63 do
  CHARS[i] = ('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'):sub(i + 1, i + 1)
end

local function key()
  return GetConvar(StudioConfig.cdn.keyConvar, '')
end

--- Base64 of a byte string. PerformHttpRequest hands its body to curl as a
--- C string, so any byte string holding a zero is cut there: every photo
--- travels encoded and the CDN decodes it on arrival.
---@param data string
---@return string
local function base64(data)
  local out <const> = {}
  local n = 0
  local len <const> = #data

  for i = 1, len - 2, 3 do
    local a <const>, b <const>, c <const> = data:byte(i, i + 2)
    local v <const> = (a << 16) | (b << 8) | c

    n = n + 1
    out[n] = CHARS[v >> 18] .. CHARS[(v >> 12) & 63] .. CHARS[(v >> 6) & 63] .. CHARS[v & 63]
  end

  local rest <const> = len % 3

  if rest == 1 then
    local v <const> = data:byte(len) << 16

    n = n + 1
    out[n] = CHARS[v >> 18] .. CHARS[(v >> 12) & 63] .. '=='
  elseif rest == 2 then
    local a <const>, b <const> = data:byte(len - 1, len)
    local v <const> = (a << 16) | (b << 8)

    n = n + 1
    out[n] = CHARS[v >> 18] .. CHARS[(v >> 12) & 63] .. CHARS[(v >> 6) & 63] .. '='
  end

  return table.concat(out)
end

Studio.base64 = base64

local function encode(value)
  return tostring(value):gsub('[^%w%-%._~]', function(char)
    return ('%%%02X'):format(char:byte())
  end)
end

--- Whether photos go to the CDN: a url and an API key are set.
---@return boolean
function Studio.cdnEnabled()
  local cdn <const> = StudioConfig.cdn

  return type(cdn) == 'table' and type(cdn.url) == 'string' and #cdn.url > 0 and #key() > 0
end

--- The MIME type of a file, from its extension.
---@param name string
---@return string mime
function Studio.cdnMime(name)
  return MIMES[(name:match('%.(%w+)$') or ''):lower()] or 'application/octet-stream'
end

--- Sends one file to a folder of the CDN, created on the way when it is
--- missing, and waits for the answer.
---@param path string The folder path under the configured root folder, '' for the root itself.
---@param name string The file name in that folder.
---@param body string The file bytes.
---@return table result { ok, status, id?, url?, error? }
function Studio.cdnPut(path, name, body)
  local cdn <const> = StudioConfig.cdn
  local url <const> = ('%s%s?folder=%s&path=%s&name=%s&overwrite=%s&mkdir=1'):format(
    cdn.url, UPLOAD_PATH, encode(cdn.folder or ''), encode(path or ''), encode(name), cdn.overwrite and '1' or '0'
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
  end, 'PUT', base64(body), {
    Authorization = 'Bearer ' .. key(),
    ['Content-Type'] = Studio.cdnMime(name),
    ['Content-Transfer-Encoding'] = 'base64',
  })

  SetTimeout(cdn.timeoutMs or 30000, function()
    if not settled then
      settled = true
      done:resolve({ ok = false, status = 0, error = 'timeout' })
    end
  end)

  return Citizen.Await(done)
end
