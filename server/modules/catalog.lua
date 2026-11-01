local INDEX_FILE <const> = 'index.json'
local FLUSH_EVERY <const> = 25

local resource <const> = GetCurrentResourceName()
local catalogs <const> = {}

local function indexPath(model)
  return ('%s/catalog/%s/%s'):format(StudioConfig.output.root, model, INDEX_FILE)
end

local function load(model)
  local catalog = catalogs[model]

  if catalog then
    return catalog
  end

  local raw <const> = LoadResourceFile(resource, indexPath(model))
  local decoded = raw and json.decode(raw) or nil

  if type(decoded) ~= 'table' or type(decoded.entries) ~= 'table' then
    decoded = { model = model, entries = {} }
  end

  catalog = { model = model, entries = decoded.entries, dirty = 0 }
  catalogs[model] = catalog

  return catalog
end

--- Whether a model folder name is one the catalog accepts.
---@param model string
---@return boolean
function Studio.catalogAccepts(model)
  local models <const> = StudioConfig.catalog.models

  for i = 1, #models do
    if models[i] == model then
      return true
    end
  end

  return false
end

--- The model folder name of a player's ped, nil when the catalog does not accept it.
---@param src number
---@return string|nil model
function Studio.catalogModelOf(src)
  local hash <const> = GetEntityModel(GetPlayerPed(src))
  local models <const> = StudioConfig.catalog.models

  for i = 1, #models do
    if joaat(models[i]) == hash then
      return models[i]
    end
  end

  return nil
end

--- The keys already photographed for a model, as { [key] = true }.
---@param model string
---@return table done
---@return number count
function Studio.catalogDone(model)
  local catalog <const> = load(model)
  local done <const> = {}
  local count = 0

  for file in pairs(catalog.entries) do
    done[('%s/%s'):format(model, file)] = true
    count = count + 1
  end

  return done, count
end

--- Writes the index of a model to disk when it changed.
---@param model string
function Studio.catalogFlush(model)
  local catalog <const> = catalogs[model]

  if not catalog or catalog.dirty == 0 then
    return
  end

  local payload <const> = json.encode({
    model = model,
    updatedAt = os.date('!%Y-%m-%dT%H:%M:%SZ'),
    entries = catalog.entries,
  })

  if SaveResourceFile(resource, indexPath(model), payload, #payload) then
    catalog.dirty = 0
    return
  end

  Siku.log.error('studio.results_failed', ('Catalog index of %s could not be written'):format(model), {
    path = indexPath(model),
    bytes = #payload,
    entries = catalog.dirty,
  }, { outcome = 'failure' })
end

--- Writes every changed index to disk.
function Studio.catalogFlushAll()
  for model in pairs(catalogs) do
    Studio.catalogFlush(model)
  end
end

--- Records one stored catalog photo in the index of its model.
---@param key string The key, as <model>/<file>.
---@param bytes number
function Studio.catalogIndexed(key, bytes)
  local model <const>, file <const> = key:match('^([^/]+)/([^/]+)$')

  if not model or not Studio.catalogAccepts(model) then
    return
  end

  local catalog <const> = load(model)

  catalog.entries[file] = { bytes = bytes, at = os.time() }
  catalog.dirty = catalog.dirty + 1

  if catalog.dirty >= FLUSH_EVERY then
    Studio.catalogFlush(model)
  end
end
