Nui = {}

local PREFIX <const> = 'siku_studio:nui:'
local DEFAULT_TIMEOUT_MS <const> = 5000

local pending <const> = {}
local listeners <const> = {}
local sequence = 0

--- Sends a message to the capture page without waiting for anything.
---@param name string The message name, without the resource prefix.
---@param payload table|nil
function Nui.send(name, payload)
  local message <const> = payload or {}

  message.action = PREFIX .. name

  SendNUIMessage(message)
end

--- Sends a message to the capture page and waits for its answer.
---@param name string The message name, without the resource prefix.
---@param payload table|nil
---@param timeoutMs number|nil How long to wait before giving up, 5 s by default.
---@return table reply The answer, with `ok` and whatever the page put in it.
function Nui.request(name, payload, timeoutMs)
  sequence = sequence + 1

  local id <const> = sequence
  local answer <const> = promise.new()
  local message <const> = payload or {}

  pending[id] = answer
  message.id = id

  Nui.send(name, message)

  SetTimeout(timeoutMs or DEFAULT_TIMEOUT_MS, function()
    local waiting <const> = pending[id]

    if waiting then
      pending[id] = nil
      waiting:resolve({ ok = false, error = 'timeout', timeout = true })
    end
  end)

  local reply <const> = Citizen.Await(answer)

  if reply.timeout then
    error(T('error_nui_never_answered', name), 0)
  end

  return reply
end

--- Listens to a notification the capture page sends on its own.
---@param name string The notification name.
---@param handler fun(data: table)
function Nui.on(name, handler)
  listeners[name] = handler
end

--- Registers a callback of the interface by name, answered at once and
--- handled in its own thread.
---@param name string The callback name, without the resource prefix.
---@param handler fun(data: table)
function Nui.callback(name, handler)
  RegisterNUICallback(PREFIX .. name, function(data, cb)
    cb({})

    CreateThread(function()
      handler(type(data) == 'table' and data or {})
    end)
  end)
end

--- Forgets every answer still awaited, resolving them as cancelled.
function Nui.cancelAll()
  for id, waiting in pairs(pending) do
    pending[id] = nil
    waiting:resolve({ ok = false, error = 'cancelled' })
  end
end

RegisterNUICallback(PREFIX .. 'reply', function(data, cb)
  cb({})

  if type(data) ~= 'table' or type(data.id) ~= 'number' then
    return
  end

  local waiting <const> = pending[data.id]

  if waiting then
    pending[data.id] = nil
    waiting:resolve(data)
  end
end)

RegisterNUICallback(PREFIX .. 'event', function(data, cb)
  cb({})

  if type(data) ~= 'table' or type(data.name) ~= 'string' then
    return
  end

  local handler <const> = listeners[data.name]

  if handler then
    CreateThread(function()
      handler(data)
    end)
  end
end)

RegisterNUICallback(PREFIX .. 'ready', function(_, cb)
  cb({
    locale = {
      language = TranslationConfig.language,
      translations = { web = Siku.locale.translations().web or {} },
    },
  })
end)
