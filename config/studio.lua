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
    --- placed in front of the subject at the given distance and height,
    --- and points at the bone.
    presets = {
      head = { bone = 'SKEL_Head', distance = 0.9, height = 0.05, fov = 30.0 },
      bust = { bone = 'SKEL_Spine3', distance = 1.8, height = 0.15, fov = 35.0 },
      full = { bone = 'SKEL_Pelvis', distance = 3.6, height = 0.1, fov = 40.0 },
    },

    --- The preset used when none is asked.
    preset = 'bust',
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

  http = {
    --- Where the game client reaches the FXServer HTTP port, without a
    --- trailing slash, like 'http://1.2.3.4:30120'. Leave nil to use the
    --- address the client is connected to.
    endpoint = nil,

    --- Largest upload accepted, in bytes.
    maxBytes = 8 * 1024 * 1024,

    --- How long (ms) a session token stays valid without activity.
    tokenTtlMs = 120000,
  },
}
