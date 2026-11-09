StudioConfig = {
  --- Permission required to use the studio. Granted to the owner role by
  --- the core's wildcard; add it to any role that should run captures.
  permission = 'studio.use',

  --- Delay (ms) between two /studio commands from the same player.
  cooldownMs = 1000,

  scene = {
    --- Where the studio is built: high above the map, where nothing is
    --- streamed and nobody walks by. The player stays where they are,
    --- only a clone and the camera go there.
    origin = vector3(0.0, 0.0, 1000.0),

    --- Edge of the cube drawn around the subject, in meters. Big enough
    --- for the camera to never see an edge, small enough to stay cheap.
    size = 40.0,

    --- Heading of the subject, facing the camera.
    heading = 180.0,

    --- Backgrounds the cube can take, by name.
    backgrounds = {
      green = { 0, 255, 0 },
      magenta = { 255, 0, 255 },
      black = { 0, 0, 0 },
      white = { 255, 255, 255 },
      neutral = { 24, 26, 30 },
    },

    --- The background used when none is asked.
    background = 'green',

    --- Point light placed in front of the subject.
    light = {
      offset = vector3(0.0, -3.0, 2.0),
      color = { 255, 255, 255 },
      range = 12.0,
      intensity = 2.5,
    },

    --- Game clock and weather frozen for the whole session, so two
    --- captures made an hour apart look the same.
    time = { hour = 12, minute = 0 },
    weather = 'EXTRASUNNY',
  },

  camera = {
    --- Framing presets, relative to a bone of the subject. The camera is
    --- placed at the given distance from the bone, turned by yaw degrees
    --- around the subject (0 = facing the subject), raised by height, and
    --- points at the bone moved by offset (right, forward, up in meters).
    presets = {
      head = { bone = 'SKEL_Head', distance = 0.75, height = 0.03, fov = 25.0 },
      head_wide = { bone = 'SKEL_Head', distance = 1.0, height = 0.05, fov = 30.0 },
      eyes = { bone = 'SKEL_Head', distance = 0.4, height = 0.05, fov = 15.0 },
      mouth = { bone = 'SKEL_Head', distance = 0.45, height = -0.03, fov = 15.0 },
      neck = { bone = 'SKEL_Neck_1', distance = 0.9, height = 0.0, fov = 25.0 },
      bust = { bone = 'SKEL_Spine3', distance = 2.0, height = 0.3, fov = 35.0 },
      bust_bare = { bone = 'SKEL_Spine3', distance = 1.6, height = 0.1, fov = 30.0 },
      back = { bone = 'SKEL_Spine3', distance = 2.0, height = 0.3, fov = 35.0, yaw = 180.0 },
      legs = { bone = 'SKEL_Pelvis', distance = 2.4, height = -0.35, fov = 35.0 },
      shoes = { bone = 'SKEL_L_Foot', distance = 1.1, height = 0.15, fov = 30.0, offset = vector3(0.1, 0.0, 0.0) },
      wrist = { bone = 'SKEL_L_Hand', distance = 0.5, height = 0.05, fov = 20.0 },
      full = { bone = 'SKEL_Pelvis', distance = 3.6, height = 0.1, fov = 40.0 },
      component_2 = { anchor = vector3(-0.055, 1.025, 0.665), fov = 30.0 },
      overlay_2 = { anchor = vector3(-0.065, 1.025, 0.675), fov = 15.0 },
      overlay_1 = { anchor = vector3(-0.065, 0.775, 0.675), fov = 20.0 },
      overlay_10 = { anchor = vector3(-0.071, 1.578, 0.288), fov = 26.0 },
      overlay_8 = { anchor = vector3(-0.065, 0.575, 0.615), fov = 15.0 },
      overlay_4 = { anchor = vector3(-0.065, 0.775, 0.675), fov = 20.0 },
      overlay_5 = { anchor = vector3(-0.055, 0.675, 0.675), fov = 25.0 },
      component_11 = { anchor = vector3(-0.051, 1.978, 0.228), fov = 21.0 },
      component_8 = { anchor = vector3(-0.071, 1.978, 0.278), fov = 22.0 },
      component_3 = { anchor = vector3(-0.071, 1.978, 0.158), fov = 30.0 },
      component_4 = { anchor = vector3(-0.060, 2.384, -0.464), fov = 28.0 },
    },

    --- A preset can also be written as `{ anchor = vector3(right, forward,
    --- up), fov }`: the camera stands at that point of the subject's own
    --- frame, in meters from its feet, and looks straight back at it
    --- without tilting. `/studio setup` generates presets in that form.

    --- The preset used when none is asked.
    preset = 'bust',
  },

  setup = {
    --- Target shown when the framing tool opens.
    target = 'component_11',

    --- Camera speed while a key is held, in meters per second, per step
    --- size chosen in the tool.
    speeds = { fine = 0.08, normal = 0.3, large = 0.9 },

    --- Camera move for one click on an arrow button, in meters.
    nudges = { fine = 0.01, normal = 0.05, large = 0.2 },

    --- Field of view change per second while a zoom key is held, and per
    --- click on a zoom button, in degrees.
    fovSpeed = 12.0,
    fovNudge = 1.0,
  },

  --- Animation frozen on the subject so every photo shows the same pose,
  --- and two readings of the same frame match pixel for pixel. Set to
  --- false to leave the subject on its idle animation.
  pose = {
    dict = 'anim@mp_corona_idles@male_a@idle_a',
    anim = 'idle_a',
    time = 0.3,
  },

  catalog = {
    --- Ped models the catalog accepts. Each one has its folder under
    --- output/catalog, shipped with the resource.
    models = { 'mp_m_freemode_01', 'mp_f_freemode_01' },

    --- Components set to their naked drawable while photographing skin
    --- overlays, per model folder: { [component] = drawable }.
    bare = {
      mp_m_freemode_01 = { [3] = 15, [8] = 15, [11] = 15 },
      mp_f_freemode_01 = { [3] = 15, [8] = 15, [11] = 15 },
    },

    --- Empty drawable of every component, per model: what a hidden part
    --- becomes (`hide` on a target, or the framing tool). Hidden props are
    --- simply removed.
    hidden = {
      mp_m_freemode_01 = { [1] = 0, [2] = 0, [3] = 15, [4] = 14, [5] = 0, [6] = 34, [7] = 0, [8] = 15, [9] = 0, [10] = 0, [11] = 15 },
      mp_f_freemode_01 = { [1] = 0, [2] = 0, [3] = 15, [4] = 15, [5] = 0, [6] = 35, [7] = 0, [8] = 14, [9] = 0, [10] = 0, [11] = 15 },
    },

    --- Textures photographed per drawable, 0 for all of them.
    textures = 0,

    --- Colour applied to coloured overlays (beard, eyebrows, makeup...)
    --- while photographing their shapes.
    overlayColor = 0,

    --- Colours given to the clone when it enters the studio, so every photo
    --- starts from the same base: the hair colour, and the colour of every
    --- overlay that takes one (facial hair, eyebrows, makeup, blush,
    --- lipstick, chest hair). nil keeps the player's own colours. The
    --- player's character is never touched, only the clone.
    baseColors = { hair = 0, overlays = 0 },

    --- Number of eye colours the game offers.
    eyeColors = 32,

    --- Photos handed to the page before the capture loop waits for the
    --- upload queue to drain a little.
    backlog = 8,

    --- Everything photographed, in order. kind: component, prop, overlay,
    --- haircolor, eyecolor. preset: a camera preset. bare: strip the torso
    --- first. color: overlays taking a colour (1 hair colours, 2 makeup).
    --- hide: `{ components = { … }, props = { … } }` taken off the subject
    --- for this target, as generated by `/studio setup`.
    targets = {
      { id = 'component_0', kind = 'component', index = 0, label = 'Face', preset = 'head' },
      { id = 'component_1', kind = 'component', index = 1, label = 'Mask', preset = 'head_wide' },
      { id = 'component_2', kind = 'component', index = 2, label = 'Hair', preset = 'component_2', hide = { components = { 1, 4, 5, 6, 7, 8, 9, 10, 11 }, props = { 0 } } },
      { id = 'component_3', kind = 'component', index = 3, label = 'Torso', preset = 'component_3', hide = { components = { 1, 2, 5, 6, 7, 8, 9, 10, 11 }, props = { 0 } } },
      { id = 'component_4', kind = 'component', index = 4, label = 'Legs', preset = 'component_4', hide = { components = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11 }, props = { 0 } } },
      { id = 'component_5', kind = 'component', index = 5, label = 'Bag', preset = 'back' },
      { id = 'component_6', kind = 'component', index = 6, label = 'Shoes', preset = 'shoes' },
      { id = 'component_7', kind = 'component', index = 7, label = 'Accessory', preset = 'neck' },
      { id = 'component_8', kind = 'component', index = 8, label = 'Undershirt', preset = 'component_8', hide = { components = { 1, 2, 3, 5, 6, 7, 9, 10, 11 }, props = { 0 } } },
      { id = 'component_9', kind = 'component', index = 9, label = 'Armor', preset = 'bust' },
      { id = 'component_10', kind = 'component', index = 10, label = 'Decal', preset = 'bust' },
      { id = 'component_11', kind = 'component', index = 11, label = 'Top', preset = 'component_11', hide = { components = { 1, 2, 3, 5, 6, 7, 8, 9, 10 }, props = { 0 } } },
      { id = 'prop_0', kind = 'prop', index = 0, label = 'Hat', preset = 'head_wide' },
      { id = 'prop_1', kind = 'prop', index = 1, label = 'Glasses', preset = 'head' },
      { id = 'prop_2', kind = 'prop', index = 2, label = 'Ear', preset = 'head' },
      { id = 'prop_6', kind = 'prop', index = 6, label = 'Watch', preset = 'wrist' },
      { id = 'prop_7', kind = 'prop', index = 7, label = 'Bracelet', preset = 'wrist' },
      { id = 'overlay_0', kind = 'overlay', index = 0, label = 'Blemishes', preset = 'head' },
      { id = 'overlay_1', kind = 'overlay', index = 1, label = 'Facial hair', preset = 'overlay_1', color = 1, hide = { components = { 1, 4, 5, 6, 7, 8, 9, 10, 11 }, props = { 0 } } },
      { id = 'overlay_2', kind = 'overlay', index = 2, label = 'Eyebrows', preset = 'overlay_2', color = 1, hide = { components = { 1, 4, 5, 6, 7, 8, 9, 10, 11 }, props = { 0 } } },
      { id = 'overlay_3', kind = 'overlay', index = 3, label = 'Ageing', preset = 'head' },
      { id = 'overlay_4', kind = 'overlay', index = 4, label = 'Makeup', preset = 'overlay_4', color = 2, hide = { components = { 1, 4, 5, 6, 7, 8, 9, 10, 11 }, props = { 0 } } },
      { id = 'overlay_5', kind = 'overlay', index = 5, label = 'Blush', preset = 'overlay_5', color = 2, hide = { components = { 1, 4, 5, 6, 7, 8, 9, 10, 11 }, props = { 0 } } },
      { id = 'overlay_6', kind = 'overlay', index = 6, label = 'Complexion', preset = 'head' },
      { id = 'overlay_7', kind = 'overlay', index = 7, label = 'Sun damage', preset = 'head' },
      { id = 'overlay_8', kind = 'overlay', index = 8, label = 'Lipstick', preset = 'overlay_8', color = 2, hide = { components = { 1, 4, 5, 6, 7, 8, 9, 10, 11 }, props = { 0 } } },
      { id = 'overlay_9', kind = 'overlay', index = 9, label = 'Moles', preset = 'head' },
      { id = 'overlay_10', kind = 'overlay', index = 10, label = 'Chest hair', preset = 'overlay_10', color = 1, bare = true, hide = { components = { 1, 4, 5, 6, 7, 8, 9, 10, 11 }, props = { 0 } } },
      { id = 'overlay_11', kind = 'overlay', index = 11, label = 'Body blemishes', preset = 'bust_bare', bare = true },
      { id = 'overlay_12', kind = 'overlay', index = 12, label = 'Extra body blemishes', preset = 'bust_bare', bare = true },
      { id = 'haircolor', kind = 'haircolor', label = 'Hair colour', preset = 'head_wide' },
      { id = 'eyecolor', kind = 'eyecolor', label = 'Eye colour', preset = 'eyes' },
    },
  },

  capture = {
    --- Side of the square cut from the center of the screen, as a fraction
    --- of the screen height. The capture reads only this rectangle.
    frame = 0.9,

    --- Output image side in pixels, format, and WebP settings.
    size = 512,
    format = 'webp',
    quality = 0.92,
    lossless = false,

    --- Frames rendered after a change of subject before reading the screen.
    settleFrames = 2,

    --- How the subject is cut from the background. 'double' photographs
    --- every item twice, on the green then the magenta background, and
    --- computes an exact alpha from the difference. 'none' keeps the
    --- background.
    matte = 'double',

    --- Encoding workers running in the interface, in parallel of the captures.
    workers = 3,
  },

  bench = {
    --- Ped component measured by the variations and full benchmarks
    --- (11 = tops).
    component = 11,

    --- Drawables walked by the variations and full benchmarks.
    drawables = 30,

    --- Textures walked per drawable by the full benchmark, 0 for all.
    textures = 2,

    --- Iterations of the readback and encode benchmarks.
    iterations = 40,

    --- Image sides and WebP qualities measured by the readback and encode
    --- benchmarks.
    sizes = { 256, 512, 1024 },
    qualities = { 0.8, 0.92 },

    --- Blobs sent by the upload benchmark, and their size in bytes.
    uploadCount = 50,
    uploadBytes = 40000,

    --- Files written by the save benchmark, and their size in bytes.
    saveCount = 500,
    saveBytes = 40000,

    --- Longest wait (ms) for a subject change to show on screen.
    changeTimeoutMs = 3000,
  },

  output = {
    --- Folder of the resource where every file is written. Nothing in it
    --- is declared in the manifest: players never download it.
    root = 'output',
  },

  cdn = {
    --- Where every photo goes: the Siku CDN. The API key is read from the
    --- convar below, set in server.cfg (`set siku_studio_cdn_key "cdn_…"`),
    --- never from this file. Without a key the photos stay on disk under
    --- output/.
    url = 'https://cdn.heliony.com',

    --- Folder of the CDN that receives the photos (its id or its path).
    folder = '01a1bc58-a574-7e63-98e1-03fb1dd489a9',

    --- Convar holding the API key. The key needs the write permission on
    --- the folder above.
    keyConvar = 'siku_studio_cdn_key',

    --- Photos are named 1.webp, 2.webp… in the order they are taken, and a
    --- new session replaces the photos of the previous one. The catalog
    --- index.json travels with them and maps each number to its item.
    numbered = true,
    overwrite = true,

    --- Longest wait (ms) for the CDN to confirm one photo.
    timeoutMs = 30000,
  },

  transport = {
    --- How captures travel from the page to the server. 'event' hands the
    --- bytes to the client script through a NUI callback, which forwards
    --- them in a latent net event: the only way that works out of the box,
    --- because NUI pages are https and the browser refuses plain http to
    --- the FXServer port. 'http' posts straight to http.endpoint, which
    --- must then be an https reverse proxy in front of the FXServer port.
    mode = 'event',

    --- Throughput of the latent events, in bytes per second. FXServer cuts
    --- them in fragments of 2047 bytes and accepts 75 fragments per second
    --- per player, 125 in a burst, and kicks the player above 150. The
    --- client sends one file at a time; 120000 keeps about 59 fragments
    --- per second, under the limit with a margin.
    bytesPerSecond = 120000,

    --- Longest wait (ms) for the server to confirm one stored file.
    ackTimeoutMs = 30000,
  },

  http = {
    --- Where the page reaches the FXServer HTTP handler in 'http' mode,
    --- without a trailing slash, like 'https://studio.example.com'. Leave
    --- nil to use the address the client is connected to, in plain http.
    endpoint = nil,

    --- Largest upload accepted, in bytes.
    maxBytes = 8 * 1024 * 1024,

    --- How long (ms) a session token stays valid without activity.
    tokenTtlMs = 120000,
  },
}
