local INDEX_FILE <const> = 'index.json'
local FLUSH_EVERY <const> = 25

local resource <const> = GetCurrentResourceName()
local catalogs <const> = {}

local function indexPath(model, target)
  return ('%s/catalog/%s/%s.%s'):format(StudioConfig.output.root, model, target, INDEX_FILE)
end

local function targetById(id)
  local targets <const> = StudioConfig.catalog.targets

  for i = 1, #targets do
    if targets[i].id == id then
      return targets[i]
    end
  end

  return nil
end

local function load(model, target)
  local id <const> = ('%s/%s'):format(model, target)
  local catalog = catalogs[id]

  if catalog then
    return catalog
  end

  local raw <const> = LoadResourceFile(resource, indexPath(model, target))
  local decoded = raw and json.decode(raw) or nil

  if type(decoded) ~= 'table' or type(decoded.entries) ~= 'table' then
    decoded = { entries = {} }
  end

  catalog = { model = model, target = target, entries = decoded.entries, dirty = 0 }
  catalogs[id] = catalog

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

--- The target a catalog photo belongs to, from its file name
--- (`component_11_12_0.webp` → `component_11`), nil when no target claims it.
---@param file string
---@return string|nil target
function Studio.catalogTargetOf(file)
  local targets <const> = StudioConfig.catalog.targets

  for i = 1, #targets do
    local id <const> = targets[i].id

    if file:sub(1, #id + 1) == id .. '_' then
      return id
    end
  end

  return nil
end

--- The CDN folder of a target's photos for a model: the target at the root,
--- the model inside it.
---@param target string
---@param model string
---@return string path
function Studio.catalogFolder(target, model)
  return ('%s/%s'):format(target, model)
end

--- The keys already photographed, for every model, as { [key] = true }.
--- Empty when photos go to the CDN: every session shoots the whole target
--- again and replaces the previous photos, which keeps the CDN the only
--- truth.
---@return table done
---@return number count
function Studio.catalogDone()
  local done <const> = {}
  local count = 0

  if Studio.cdnEnabled() then
    return done, count
  end

  local models <const> = StudioConfig.catalog.models
  local targets <const> = StudioConfig.catalog.targets

  for m = 1, #models do
    for i = 1, #targets do
      local catalog <const> = load(models[m], targets[i].id)

      for file in pairs(catalog.entries) do
        done[('%s/%s'):format(models[m], file)] = true
        count = count + 1
      end
    end
  end

  return done, count
end

local function flush(catalog)
  if catalog.dirty == 0 or catalog.flushing then
    return
  end

  catalog.flushing = true

  local model <const>, target <const> = catalog.model, catalog.target
  local entry <const> = targetById(target)

  while catalog.dirty > 0 do
    local dirty <const> = catalog.dirty
    local payload <const> = json.encode({
      model = model,
      target = entry and { id = entry.id, kind = entry.kind, index = entry.index, label = entry.label } or { id = target },
      updatedAt = os.date('!%Y-%m-%dT%H:%M:%SZ'),
      entries = catalog.entries,
    })

    if Studio.cdnEnabled() then
      local folder <const> = Studio.catalogFolder(target, model)
      local result <const> = Studio.cdnPut(folder, INDEX_FILE, payload)

      if not result.ok then
        Siku.log.error('studio.cdn_failed', ('Catalog index %s/%s could not be sent to the CDN: %s'):format(folder, INDEX_FILE, result.error), {
          folder = folder,
          name = INDEX_FILE,
          bytes = #payload,
          status = result.status,
          reason = result.error,
          detail = result.detail,
        }, { outcome = 'failure' })
      end
    end

    if not SaveResourceFile(resource, indexPath(model, target), payload, #payload) then
      Siku.log.error('studio.results_failed', ('Catalog index of %s/%s could not be written'):format(model, target), {
        path = indexPath(model, target),
        bytes = #payload,
        entries = catalog.dirty,
      }, { outcome = 'failure' })
      break
    end

    catalog.dirty = catalog.dirty - dirty
  end

  catalog.flushing = false
end

--- Writes the indexes of a model when they changed.
---@param model string
function Studio.catalogFlush(model)
  for _, catalog in pairs(catalogs) do
    if catalog.model == model then
      flush(catalog)
    end
  end
end

--- Writes every changed index.
function Studio.catalogFlushAll()
  for _, catalog in pairs(catalogs) do
    flush(catalog)
  end
end

--- Records one stored catalog photo in the index of its target and model.
---@param key string The key, as <model>/<file>.
---@param bytes number
---@param cdn table|nil { name, id, url } when the photo went to the CDN.
function Studio.catalogIndexed(key, bytes, cdn)
  local model <const>, file <const> = key:match('^([^/]+)/([^/]+)$')

  if not model or not Studio.catalogAccepts(model) then
    return
  end

  local target <const> = Studio.catalogTargetOf(file)

  if not target then
    return
  end

  local catalog <const> = load(model, target)

  catalog.entries[file] = { bytes = bytes, at = os.time(), cdn = cdn }
  catalog.dirty = catalog.dirty + 1

  if catalog.dirty >= FLUSH_EVERY then
    flush(catalog)
  end
end
