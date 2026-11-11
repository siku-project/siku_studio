local INDEX_FILE <const> = 'index.json'
local FLUSH_EVERY <const> = 25
local PHOTO_SUFFIX <const> = '^[%d_]+%.webp$'

local resource <const> = GetCurrentResourceName()
local catalogs <const> = {}

local function indexPath(folder, name)
  return ('%s/catalog/%s/%s.%s'):format(StudioConfig.output.root, folder, name, INDEX_FILE)
end

local function targetByName(name)
  local targets <const> = StudioConfig.catalog.targets

  for i = 1, #targets do
    if targets[i].name == name then
      return targets[i]
    end
  end

  return nil
end

local function modelOf(folder)
  for model, name in pairs(StudioConfig.catalog.folders) do
    if name == folder then
      return model
    end
  end

  return nil
end

local function load(folder, name)
  local id <const> = ('%s/%s'):format(folder, name)
  local catalog = catalogs[id]

  if catalog then
    return catalog
  end

  local raw <const> = LoadResourceFile(resource, indexPath(folder, name))
  local decoded = raw and json.decode(raw) or nil

  if type(decoded) ~= 'table' or type(decoded.entries) ~= 'table' then
    decoded = { entries = {} }
  end

  catalog = { folder = folder, name = name, entries = decoded.entries, dirty = 0 }
  catalogs[id] = catalog

  return catalog
end

--- Whether a model folder name (`male`, `female`) is one the catalog
--- accepts.
---@param folder string
---@return boolean
function Studio.catalogAccepts(folder)
  return modelOf(folder) ~= nil
end

--- The target a catalog photo belongs to, from its file name
--- (`hair_12_0.webp` → `hair`, `beard_7.webp` → `beard`), nil when no
--- target claims it.
---@param file string
---@return string|nil name
function Studio.catalogTargetOf(file)
  local targets <const> = StudioConfig.catalog.targets

  for i = 1, #targets do
    local name <const> = targets[i].name
    local prefix <const> = name .. '_'

    if file:sub(1, #prefix) == prefix and file:sub(#prefix + 1):match(PHOTO_SUFFIX) then
      return name
    end
  end

  return nil
end

--- The CDN folder of a target's photos for a model: the target at the root,
--- the model inside it (`hair/male`).
---@param name string The target name.
---@param folder string The model folder.
---@return string path
function Studio.catalogFolder(name, folder)
  return ('%s/%s'):format(name, folder)
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
    local folder <const> = StudioConfig.catalog.folders[models[m]]

    for i = 1, #targets do
      local catalog <const> = load(folder, targets[i].name)

      for file in pairs(catalog.entries) do
        done[('%s/%s'):format(folder, file)] = true
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

  local folder <const>, name <const> = catalog.folder, catalog.name
  local entry <const> = targetByName(name)

  while catalog.dirty > 0 do
    local dirty <const> = catalog.dirty
    local payload <const> = json.encode({
      model = modelOf(folder),
      folder = folder,
      target = entry and { id = entry.id, name = entry.name, kind = entry.kind, index = entry.index, label = entry.label } or { name = name },
      updatedAt = os.date('!%Y-%m-%dT%H:%M:%SZ'),
      entries = catalog.entries,
    })

    if Studio.cdnEnabled() then
      local path <const> = Studio.catalogFolder(name, folder)
      local result <const> = Studio.cdnPut(path, INDEX_FILE, payload)

      if not result.ok then
        Siku.log.error('studio.cdn_failed', ('Catalog index %s/%s could not be sent to the CDN: %s'):format(path, INDEX_FILE, result.error), {
          folder = path,
          name = INDEX_FILE,
          bytes = #payload,
          status = result.status,
          reason = result.error,
          detail = result.detail,
        }, { outcome = 'failure' })
      end
    end

    if not SaveResourceFile(resource, indexPath(folder, name), payload, #payload) then
      Siku.log.error('studio.results_failed', ('Catalog index of %s/%s could not be written'):format(folder, name), {
        path = indexPath(folder, name),
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
---@param model string The ped model name.
function Studio.catalogFlush(model)
  local folder <const> = StudioConfig.catalog.folders[model]

  for _, catalog in pairs(catalogs) do
    if catalog.folder == folder then
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
---@param key string The key, as <model folder>/<file>.
---@param bytes number
---@param cdn table|nil { name, id, url } when the photo went to the CDN.
function Studio.catalogIndexed(key, bytes, cdn)
  local folder <const>, file <const> = key:match('^([^/]+)/([^/]+)$')

  if not folder or not Studio.catalogAccepts(folder) then
    return
  end

  local name <const> = Studio.catalogTargetOf(file)

  if not name then
    return
  end

  local catalog <const> = load(folder, name)

  catalog.entries[file] = { bytes = bytes, at = os.time(), cdn = cdn }
  catalog.dirty = catalog.dirty + 1

  if catalog.dirty >= FLUSH_EVERY then
    flush(catalog)
  end
end
