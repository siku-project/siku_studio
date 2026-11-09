export function startCapture() {
  const PREFIX = 'siku_studio:nui:'
  const PLACEHOLDER = [0, 0, 255, 255]
  const CHANGE_RETRIES = 12
  const CHANGE_STRIDE = 64 * 4
  const CHANGE_THRESHOLD = 12
  const CONCURRENT_UPLOADS = 20
  const RANDOM_CHUNK = 65536
  const HEALTH_TIMEOUT_MS = 3000

  const resource =
    typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'siku_studio'
  const canvas = document.createElement('canvas')

  canvas.className = 'studio-capture'
  document.body.appendChild(canvas)

  let gl = null
  let texCoordBuffer = null
  let gameView = false
  let target = { framebuffer: null, texture: null, width: 0, height: 0 }
  let packBuffer = { buffer: null, bytes: 0 }
  let config = null
  let workers = []
  let workerIndex = 0
  let nextJob = 1
  const jobs = new Map()
  let pipeline = emptyPipeline()
  let flushWaiters = []
  let drainWaiters = []
  const snaps = new Map()
  let nextSnap = 1
  let mainCanvas = null
  let mainContext = null

  function emptyPipeline() {
    return {
      pending: 0,
      encoded: 0,
      uploaded: 0,
      failed: 0,
      encodeMs: 0,
      uploadMs: 0,
      bytes: 0,
      errors: [],
      matted: 0,
      unmatted: 0,
      transparent: 0,
      retries: 0,
      backgrounds: null,
    }
  }

  function post(name, body) {
    return fetch(`https://${resource}/${PREFIX}${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(body),
    }).catch(() => {})
  }

  function reply(id, data) {
    return post('reply', Object.assign({}, data, { id }))
  }

  function notify(name, data) {
    return post('event', Object.assign({ name }, data))
  }

  function nextFrame() {
    return new Promise((resolve) => requestAnimationFrame(() => resolve()))
  }

  function changed(before, after) {
    let total = 0
    let n = 0

    for (let p = 0; p < before.length; p += CHANGE_STRIDE) {
      total +=
        Math.abs(after[p] - before[p]) +
        Math.abs(after[p + 1] - before[p + 1]) +
        Math.abs(after[p + 2] - before[p + 2])
      n += 1
    }

    return total / n >= CHANGE_THRESHOLD
  }

  function nextTick() {
    return new Promise((resolve) => setTimeout(resolve, 0))
  }

  function compile(type, source) {
    const shader = gl.createShader(type)

    gl.shaderSource(shader, source)
    gl.compileShader(shader)

    if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
      throw new Error(`shader: ${gl.getShaderInfoLog(shader)}`)
    }

    return shader
  }

  function initGl() {
    if (gl) {
      return
    }

    gl = canvas.getContext('webgl2', {
      antialias: false,
      depth: false,
      alpha: false,
      stencil: false,
      desynchronized: true,
      preserveDrawingBuffer: false,
      powerPreference: 'high-performance',
    })

    if (!gl) {
      throw new Error('webgl2 unavailable')
    }

    const program = gl.createProgram()

    gl.attachShader(
      program,
      compile(
        gl.VERTEX_SHADER,
        `#version 300 es
      in vec2 a_position;
      in vec2 a_texcoord;
      out vec2 v_texcoord;
      void main() {
        gl_Position = vec4(a_position, 0.0, 1.0);
        v_texcoord = a_texcoord;
      }`,
      ),
    )
    gl.attachShader(
      program,
      compile(
        gl.FRAGMENT_SHADER,
        `#version 300 es
      precision highp float;
      in vec2 v_texcoord;
      uniform sampler2D u_game;
      out vec4 fragColor;
      void main() {
        fragColor = vec4(texture(u_game, v_texcoord).rgb, 1.0);
      }`,
      ),
    )
    gl.linkProgram(program)

    if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
      throw new Error(`program: ${gl.getProgramInfoLog(program)}`)
    }

    gl.useProgram(program)
    gl.uniform1i(gl.getUniformLocation(program, 'u_game'), 0)

    const texture = gl.createTexture()

    gl.bindTexture(gl.TEXTURE_2D, texture)
    gl.texImage2D(
      gl.TEXTURE_2D,
      0,
      gl.RGBA,
      1,
      1,
      0,
      gl.RGBA,
      gl.UNSIGNED_BYTE,
      new Uint8Array(PLACEHOLDER),
    )
    gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
    gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
    gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)

    if (typeof gl.CFX_BIND_GAME_VIEW !== 'undefined') {
      gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CFX_BIND_GAME_VIEW)
      gameView = true
    }

    gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)

    const vao = gl.createVertexArray()

    gl.bindVertexArray(vao)

    const positions = gl.createBuffer()

    gl.bindBuffer(gl.ARRAY_BUFFER, positions)
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, -1, 1, 1, 1]), gl.STATIC_DRAW)

    const positionLocation = gl.getAttribLocation(program, 'a_position')

    gl.enableVertexAttribArray(positionLocation)
    gl.vertexAttribPointer(positionLocation, 2, gl.FLOAT, false, 0, 0)

    texCoordBuffer = gl.createBuffer()
    gl.bindBuffer(gl.ARRAY_BUFFER, texCoordBuffer)
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(8), gl.DYNAMIC_DRAW)

    const texCoordLocation = gl.getAttribLocation(program, 'a_texcoord')

    gl.enableVertexAttribArray(texCoordLocation)
    gl.vertexAttribPointer(texCoordLocation, 2, gl.FLOAT, false, 0, 0)
    gl.pixelStorei(gl.PACK_ALIGNMENT, 1)
  }

  function setRegion(u0, vTop, u1, vBottom) {
    gl.bindBuffer(gl.ARRAY_BUFFER, texCoordBuffer)
    gl.bufferSubData(
      gl.ARRAY_BUFFER,
      0,
      new Float32Array([u0, vTop, u1, vTop, u0, vBottom, u1, vBottom]),
    )
  }

  function cropRegion() {
    const { width, height } = config.screen
    const side = config.frame * height
    const uHalf = side / width / 2
    const vHalf = config.frame / 2

    return [0.5 - uHalf, 0.5 - vHalf, 0.5 + uHalf, 0.5 + vHalf]
  }

  function ensureTarget(width, height) {
    if (target.width === width && target.height === height) {
      gl.bindFramebuffer(gl.FRAMEBUFFER, target.framebuffer)
      gl.viewport(0, 0, width, height)
      return
    }

    if (target.framebuffer) {
      gl.deleteFramebuffer(target.framebuffer)
      gl.deleteTexture(target.texture)
    }

    const texture = gl.createTexture()

    gl.activeTexture(gl.TEXTURE1)
    gl.bindTexture(gl.TEXTURE_2D, texture)
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA8, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, null)
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
    gl.activeTexture(gl.TEXTURE0)

    const framebuffer = gl.createFramebuffer()

    gl.bindFramebuffer(gl.FRAMEBUFFER, framebuffer)
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, texture, 0)

    if (gl.checkFramebufferStatus(gl.FRAMEBUFFER) !== gl.FRAMEBUFFER_COMPLETE) {
      throw new Error('framebuffer incomplete')
    }

    gl.viewport(0, 0, width, height)
    target = { framebuffer, texture, width, height }
  }

  function render(width, height, region) {
    ensureTarget(width, height)
    setRegion(region[0], region[1], region[2], region[3])
    gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4)
  }

  function readSync(width, height, region) {
    render(width, height, region)

    const pixels = new Uint8Array(width * height * 4)

    gl.readPixels(0, 0, width, height, gl.RGBA, gl.UNSIGNED_BYTE, pixels)

    return pixels
  }

  async function readAsync(width, height, region) {
    render(width, height, region)

    const bytes = width * height * 4

    if (!packBuffer.buffer || packBuffer.bytes !== bytes) {
      if (packBuffer.buffer) {
        gl.deleteBuffer(packBuffer.buffer)
      }

      packBuffer = { buffer: gl.createBuffer(), bytes }
      gl.bindBuffer(gl.PIXEL_PACK_BUFFER, packBuffer.buffer)
      gl.bufferData(gl.PIXEL_PACK_BUFFER, bytes, gl.STREAM_READ)
    } else {
      gl.bindBuffer(gl.PIXEL_PACK_BUFFER, packBuffer.buffer)
    }

    gl.readPixels(0, 0, width, height, gl.RGBA, gl.UNSIGNED_BYTE, 0)

    const sync = gl.fenceSync(gl.SYNC_GPU_COMMANDS_COMPLETE, 0)

    gl.flush()

    for (;;) {
      const status = gl.clientWaitSync(sync, 0, 0)

      if (status === gl.ALREADY_SIGNALED || status === gl.CONDITION_SATISFIED) {
        break
      }

      if (status === gl.WAIT_FAILED) {
        gl.deleteSync(sync)
        gl.bindBuffer(gl.PIXEL_PACK_BUFFER, null)
        throw new Error('fence wait failed')
      }

      await nextTick()
    }

    gl.deleteSync(sync)

    const pixels = new Uint8Array(bytes)

    gl.getBufferSubData(gl.PIXEL_PACK_BUFFER, 0, pixels)
    gl.bindBuffer(gl.PIXEL_PACK_BUFFER, null)

    return pixels
  }

  function isPlaceholder(pixels) {
    return (
      pixels[0] === PLACEHOLDER[0] && pixels[1] === PLACEHOLDER[1] && pixels[2] === PLACEHOLDER[2]
    )
  }

  function startWorkers(count) {
    stopWorkers()

    for (let i = 0; i < count; i += 1) {
      const worker = new Worker(new URL('./worker.js', import.meta.url))

      worker.onmessage = (event) => {
        const job = jobs.get(event.data.id)

        if (!job) {
          return
        }

        jobs.delete(event.data.id)

        if (event.data.ok) {
          job.resolve({
            buffer: event.data.buffer,
            bytes: event.data.bytes,
            ms: event.data.ms,
            stats: event.data.stats || null,
          })
        } else {
          job.reject(new Error(event.data.error))
        }
      }

      worker.onerror = (event) => {
        notify('error', {
          message: `worker: ${event.message}`,
          stack: `${event.filename}:${event.lineno}`,
        })
      }

      workers.push(worker)
    }
  }

  function stopWorkers() {
    for (const worker of workers) {
      worker.terminate()
    }

    workers = []
    workerIndex = 0

    for (const job of jobs.values()) {
      job.reject(new Error('workers stopped'))
    }

    jobs.clear()
  }

  function encodeInWorker(pixels, width, height, quality, lossless, second) {
    if (workers.length === 0) {
      return Promise.reject(new Error('no worker'))
    }

    const id = nextJob
    const worker = workers[workerIndex]
    const transfer = [pixels.buffer]
    const message = {
      id,
      width,
      height,
      pixels: pixels.buffer,
      quality,
      lossless,
      format: config.format,
    }

    if (second) {
      message.second = second.buffer
      transfer.push(second.buffer)
    }

    nextJob += 1
    workerIndex = (workerIndex + 1) % workers.length

    return new Promise((resolve, reject) => {
      jobs.set(id, { resolve, reject })
      worker.postMessage(message, transfer)
    })
  }

  async function encodeOnMain(pixels, width, height, quality, lossless) {
    const started = performance.now()

    if (!mainCanvas || mainCanvas.width !== width || mainCanvas.height !== height) {
      mainCanvas = new OffscreenCanvas(width, height)
      mainContext = mainCanvas.getContext('2d', { alpha: true })
    }

    mainContext.putImageData(
      new ImageData(new Uint8ClampedArray(pixels.buffer), width, height),
      0,
      0,
    )

    const blob = await mainCanvas.convertToBlob({
      type: 'image/webp',
      quality: lossless ? 1 : quality,
    })
    const buffer = await blob.arrayBuffer()

    return { buffer, bytes: buffer.byteLength, ms: performance.now() - started }
  }

  function uploadUrl(kind, key) {
    const params = `kind=${encodeURIComponent(kind)}&key=${encodeURIComponent(key)}`

    if (config.transport === 'http') {
      return `${config.endpoint}/upload?token=${encodeURIComponent(config.token)}&${params}`
    }

    return `https://${resource}/${PREFIX}upload?${params}`
  }

  async function upload(kind, key, buffer) {
    const started = performance.now()
    const url = uploadUrl(kind, key)
    let response

    try {
      response = await fetch(url, { method: 'POST', body: buffer })
    } catch (error) {
      throw new Error(`${error.message} (POST ${url.split('?')[0]})`, { cause: error })
    }

    const body = await response
      .json()
      .catch(() => ({ ok: false, error: `http ${response.status}` }))

    if (!response.ok || !body.ok) {
      throw new Error(body.error || `http ${response.status}`)
    }

    return {
      ms: performance.now() - started,
      bytes: buffer.byteLength,
      writeMs: body.writeMs,
      transferMs: body.transferMs,
      queueMs: body.queueMs,
    }
  }

  async function health() {
    if (config.transport !== 'http') {
      return { reachable: true, transport: config.transport }
    }

    const controller = new AbortController()
    const timer = setTimeout(() => controller.abort(), HEALTH_TIMEOUT_MS)
    const started = performance.now()

    try {
      const response = await fetch(`${config.endpoint}/health`, {
        method: 'GET',
        signal: controller.signal,
      })
      const body = await response.json().catch(() => null)

      return {
        reachable: true,
        transport: 'http',
        status: response.status,
        session: body && body.session ? true : false,
        ms: performance.now() - started,
      }
    } catch (error) {
      return {
        reachable: false,
        transport: 'http',
        error: String((error && error.message) || error),
        ms: performance.now() - started,
      }
    } finally {
      clearTimeout(timer)
    }
  }

  async function webpSupported() {
    const probe = new OffscreenCanvas(2, 2)

    probe.getContext('2d')

    const blob = await probe.convertToBlob({ type: 'image/webp', quality: 0.8 })

    return blob.type === 'image/webp'
  }

  function stats(samples) {
    let total = 0
    let min = Infinity
    let max = 0

    for (const value of samples) {
      total += value
      min = Math.min(min, value)
      max = Math.max(max, value)
    }

    const count = samples.length || 1

    return { averageMs: total / count, minMs: samples.length ? min : 0, maxMs: max, totalMs: total }
  }

  function randomBuffer(bytes) {
    const buffer = new Uint8Array(bytes)

    for (let offset = 0; offset < bytes; offset += RANDOM_CHUNK) {
      crypto.getRandomValues(buffer.subarray(offset, Math.min(offset + RANDOM_CHUNK, bytes)))
    }

    return buffer
  }

  function settlePipeline() {
    if (pipeline.pending <= (config ? config.backlog : 0)) {
      const waiters = drainWaiters

      drainWaiters = []

      for (const waiter of waiters) {
        waiter()
      }
    }

    if (pipeline.pending === 0) {
      const waiters = flushWaiters

      flushWaiters = []

      for (const waiter of waiters) {
        waiter()
      }
    }
  }

  function drained() {
    if (pipeline.pending <= config.backlog) {
      return Promise.resolve()
    }

    return new Promise((resolve) => drainWaiters.push(resolve))
  }

  function enqueue(kind, key, pixels, width, height, second) {
    pipeline.pending += 1

    encodeInWorker(pixels, width, height, config.quality, config.lossless, second)
      .then((encoded) => {
        pipeline.encoded += 1
        pipeline.encodeMs += encoded.ms
        pipeline.bytes += encoded.bytes

        if (encoded.stats) {
          if (encoded.stats.matted) {
            pipeline.matted += 1
            pipeline.transparent += encoded.stats.transparent
            pipeline.backgrounds = encoded.stats.backgrounds
          } else {
            pipeline.unmatted += 1
          }
        }

        return upload(kind, key, encoded.buffer)
      })
      .then((uploaded) => {
        pipeline.uploaded += 1
        pipeline.uploadMs += uploaded.ms
      })
      .catch((error) => {
        pipeline.failed += 1

        if (pipeline.errors.length < 10) {
          pipeline.errors.push(`${key}: ${error.message}`)
        }
      })
      .finally(() => {
        pipeline.pending -= 1
        settlePipeline()
      })
  }

  const handlers = {
    async configure(message) {
      config = {
        token: message.token,
        transport: message.transport,
        endpoint: message.endpoint,
        screen: message.screen,
        frame: message.frame,
        size: message.size,
        quality: message.quality,
        lossless: message.lossless,
        backlog: typeof message.backlog === 'number' ? message.backlog : 0,
        format: 'webp',
      }

      initGl()
      startWorkers(message.workers)
      pipeline = emptyPipeline()

      const sample = readSync(2, 2, cropRegion())

      return {
        server: await health(),
        gl: {
          renderer: gl.getParameter(gl.RENDERER),
          version: gl.getParameter(gl.VERSION),
          maxTexture: gl.getParameter(gl.MAX_TEXTURE_SIZE),
          gameView,
          placeholder: isPlaceholder(sample),
          webp: await webpSupported(),
          workers: workers.length,
        },
      }
    },

    reset() {
      stopWorkers()
      pipeline = emptyPipeline()
      snaps.clear()
      settlePipeline()
      config = null

      return {}
    },

    async snap() {
      const size = config.size
      const started = performance.now()
      const pixels = readSync(size, size, cropRegion())
      const id = nextSnap

      nextSnap += 1
      snaps.set(id, pixels)

      return { snap: id, readMs: performance.now() - started }
    },

    async probe(message) {
      const size = config.size
      const readStarted = performance.now()
      const pixels = await readAsync(size, size, cropRegion())
      const readMs = performance.now() - readStarted
      const placeholder = isPlaceholder(pixels)
      const encoded = await encodeInWorker(pixels, size, size, config.quality, config.lossless)
      const uploaded = await upload('probe', message.key, encoded.buffer)
      const result = {
        size,
        gameView,
        placeholder,
        webp: await webpSupported(),
        readMs,
        encodeMs: encoded.ms,
        uploadMs: uploaded.ms,
        writeMs: uploaded.writeMs,
        bytes: encoded.bytes,
        key: message.key,
      }

      result.summary = `${gameView && !placeholder ? 'game view bound' : 'GAME VIEW NOT BOUND'}, ${size}px read ${readMs.toFixed(1)} ms, encoded ${encoded.bytes} B in ${encoded.ms.toFixed(1)} ms, uploaded in ${uploaded.ms.toFixed(1)} ms`

      return { result }
    },

    async 'bench.readback'(message) {
      const { width, height } = config.screen
      const full = [0, 0, 1, 1]
      const crop = cropRegion()
      const fullSamples = []

      readSync(width, height, full)

      for (let i = 0; i < message.iterations; i += 1) {
        const started = performance.now()

        readSync(width, height, full)
        fullSamples.push(performance.now() - started)
        await nextFrame()
      }

      const sizes = []

      for (const size of message.sizes) {
        const syncSamples = []
        const asyncSamples = []

        readSync(size, size, crop)

        for (let i = 0; i < message.iterations; i += 1) {
          const started = performance.now()

          readSync(size, size, crop)
          syncSamples.push(performance.now() - started)
          await nextFrame()
        }

        await readAsync(size, size, crop)

        for (let i = 0; i < message.iterations; i += 1) {
          const started = performance.now()

          await readAsync(size, size, crop)
          asyncSamples.push(performance.now() - started)
          await nextFrame()
        }

        sizes.push({ size, sync: stats(syncSamples), async: stats(asyncSamples) })
      }

      const result = {
        iterations: message.iterations,
        screen: { width, height },
        full: stats(fullSamples),
        sizes,
      }

      result.summary =
        `full ${width}x${height} ${result.full.averageMs.toFixed(2)} ms, ` +
        sizes
          .map(
            (entry) =>
              `${entry.size}px sync ${entry.sync.averageMs.toFixed(2)} ms / async ${entry.async.averageMs.toFixed(2)} ms`,
          )
          .join(', ')

      return { result }
    },

    async 'bench.encode'(message) {
      const crop = cropRegion()
      const sizes = []

      for (const size of message.sizes) {
        const source = readSync(size, size, crop)
        const qualities = []

        for (const quality of message.qualities) {
          const mainSamples = []
          let bytes = 0

          for (let i = 0; i < message.iterations; i += 1) {
            const encoded = await encodeOnMain(source.slice(), size, size, quality, false)

            mainSamples.push(encoded.ms)
            bytes = encoded.bytes
            await nextTick()
          }

          const poolStarted = performance.now()
          const poolJobs = []

          for (let i = 0; i < message.iterations; i += 1) {
            poolJobs.push(encodeInWorker(source.slice(), size, size, quality, false))
          }

          const poolResults = await Promise.all(poolJobs)
          const poolWallMs = performance.now() - poolStarted
          const poolSamples = poolResults.map((entry) => entry.ms)

          qualities.push({
            quality,
            bytes,
            main: stats(mainSamples),
            workers: Object.assign(stats(poolSamples), {
              wallMs: poolWallMs,
              perSecond: message.iterations / (poolWallMs / 1000),
            }),
          })
        }

        sizes.push({ size, qualities })
      }

      const result = { iterations: message.iterations, workers: workers.length, sizes }

      result.summary = sizes
        .map((entry) =>
          entry.qualities
            .map(
              (q) =>
                `${entry.size}px q${q.quality}: ${q.bytes} B, main ${q.main.averageMs.toFixed(1)} ms, ${workers.length} workers ${q.workers.perSecond.toFixed(1)} img/s`,
            )
            .join(', '),
        )
        .join('; ')

      return { result }
    },

    async 'bench.upload'(message) {
      const payload = randomBuffer(message.bytes)
      const sequentialSamples = []
      let failures = 0

      for (let i = 0; i < message.count; i += 1) {
        try {
          const uploaded = await upload(
            'bench',
            `upload/${String(i + 1).padStart(6, '0')}.bin`,
            payload,
          )

          sequentialSamples.push(uploaded.ms)
        } catch {
          failures += 1
        }
      }

      const concurrentStarted = performance.now()

      for (let offset = 0; offset < message.count; offset += CONCURRENT_UPLOADS) {
        const batch = []

        for (let i = offset; i < Math.min(offset + CONCURRENT_UPLOADS, message.count); i += 1) {
          batch.push(
            upload('bench', `upload/${String(i + 1).padStart(6, '0')}.bin`, payload).catch(() => {
              failures += 1
            }),
          )
        }

        await Promise.all(batch)
      }

      const concurrentMs = performance.now() - concurrentStarted
      const sequential = stats(sequentialSamples)
      const result = {
        transport: config.transport,
        count: message.count,
        bytes: message.bytes,
        failures,
        sequential: Object.assign(sequential, {
          perSecond:
            sequential.totalMs > 0 ? sequentialSamples.length / (sequential.totalMs / 1000) : 0,
        }),
        concurrent: {
          batch: CONCURRENT_UPLOADS,
          totalMs: concurrentMs,
          perSecond: concurrentMs > 0 ? message.count / (concurrentMs / 1000) : 0,
        },
      }

      result.summary = `${config.transport}: ${message.count} x ${message.bytes} B, sequential ${result.sequential.averageMs.toFixed(1)} ms each (${result.sequential.perSecond.toFixed(1)}/s, ${((result.sequential.perSecond * message.bytes) / 1024).toFixed(0)} KB/s), ${CONCURRENT_UPLOADS} handed at once ${result.concurrent.perSecond.toFixed(1)}/s, ${failures} failures`

      return { result }
    },

    async capture(message) {
      const size = config.size
      const started = performance.now()
      let first = null

      if (typeof message.first === 'number') {
        first = snaps.get(message.first)
        snaps.delete(message.first)

        if (!first) {
          throw new Error(`unknown snap ${message.first}`)
        }
      }

      let pixels = readSync(size, size, cropRegion())
      let retries = 0

      while (first && retries < CHANGE_RETRIES && !changed(first, pixels)) {
        retries += 1
        await nextFrame()
        pixels = readSync(size, size, cropRegion())
      }

      pipeline.retries += retries

      const readMs = performance.now() - started

      enqueue(
        message.kind || 'bench',
        message.key,
        first || pixels,
        size,
        size,
        first ? pixels : null,
      )

      await drained()

      return { readMs, retries, pending: pipeline.pending }
    },

    async flush() {
      if (pipeline.pending > 0) {
        await new Promise((resolve) => flushWaiters.push(resolve))
      }

      const snapshot = Object.assign({}, pipeline, {
        averageEncodeMs: pipeline.encoded ? pipeline.encodeMs / pipeline.encoded : 0,
        averageUploadMs: pipeline.uploaded ? pipeline.uploadMs / pipeline.uploaded : 0,
        averageBytes: pipeline.encoded ? Math.round(pipeline.bytes / pipeline.encoded) : 0,
        averageTransparent: pipeline.matted ? pipeline.transparent / pipeline.matted : 0,
      })

      pipeline = emptyPipeline()

      return { stats: snapshot }
    },
  }

  window.addEventListener('message', (event) => {
    const message = event.data

    if (!message || typeof message.action !== 'string' || !message.action.startsWith(PREFIX)) {
      return
    }

    const name = message.action.slice(PREFIX.length)
    const handler = handlers[name]

    if (!handler) {
      if (typeof message.id === 'number') {
        reply(message.id, { ok: false, error: `unknown message ${name}` })
      }

      return
    }

    Promise.resolve()
      .then(() => {
        if (name !== 'configure' && name !== 'reset' && !config) {
          throw new Error('page not configured')
        }

        return handler(message)
      })
      .then((data) => {
        if (typeof message.id === 'number') {
          reply(message.id, Object.assign({ ok: true }, data))
        }
      })
      .catch((error) => {
        const detail = {
          message: String((error && error.message) || error),
          stack: String((error && error.stack) || ''),
          handler: name,
        }

        notify('error', detail)

        if (typeof message.id === 'number') {
          reply(message.id, { ok: false, error: detail.message })
        }
      })
  })

  window.addEventListener('error', (event) => {
    notify('error', {
      message: String(event.message),
      stack: `${event.filename}:${event.lineno}:${event.colno}`,
      handler: 'window',
    })
  })

  window.addEventListener('unhandledrejection', (event) => {
    const reason = event.reason

    notify('error', {
      message: String((reason && reason.message) || reason),
      stack: String((reason && reason.stack) || ''),
      handler: 'promise',
    })
  })
}
