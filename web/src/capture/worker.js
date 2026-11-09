const TRANSPARENT = 0.02
const MIN_DIFFERENCE = 24
const BACKGROUND_SHARE = 0.8

let canvas = null
let context = null

function surface(width, height) {
  if (!canvas || canvas.width !== width || canvas.height !== height) {
    canvas = new OffscreenCanvas(width, height)
    context = canvas.getContext('2d', { alpha: true, willReadFrequently: false })
  }

  return context
}

function clamp(value) {
  return value < 0 ? 0 : value > 255 ? 255 : value
}

function estimateBackgrounds(onA, onB) {
  const count = onA.length / 4
  const diffs = new Float32Array(count)
  let max = 0

  for (let i = 0, p = 0; i < count; i += 1, p += 4) {
    const d =
      Math.abs(onB[p] - onA[p]) +
      Math.abs(onB[p + 1] - onA[p + 1]) +
      Math.abs(onB[p + 2] - onA[p + 2])

    diffs[i] = d

    if (d > max) {
      max = d
    }
  }

  if (max < MIN_DIFFERENCE) {
    return null
  }

  const threshold = max * BACKGROUND_SHARE
  const a = [0, 0, 0]
  const b = [0, 0, 0]
  let n = 0

  for (let i = 0, p = 0; i < count; i += 1, p += 4) {
    if (diffs[i] < threshold) {
      continue
    }

    a[0] += onA[p]
    a[1] += onA[p + 1]
    a[2] += onA[p + 2]
    b[0] += onB[p]
    b[1] += onB[p + 1]
    b[2] += onB[p + 2]
    n += 1
  }

  return {
    a: a.map((v) => Math.round(v / n)),
    b: b.map((v) => Math.round(v / n)),
    difference: Math.round(max),
    samples: n,
  }
}

function matte(onA, onB) {
  const out = new Uint8ClampedArray(onA.length)
  const backgrounds = estimateBackgrounds(onA, onB)

  if (!backgrounds) {
    out.set(onA)

    return { out, stats: { matted: false, transparent: 0, backgrounds: null } }
  }

  const [ar, ag, ab] = backgrounds.a
  const dr = backgrounds.b[0] - ar
  const dg = backgrounds.b[1] - ag
  const db = backgrounds.b[2] - ab
  const dd = dr * dr + dg * dg + db * db
  const count = onA.length / 4
  let transparent = 0

  for (let p = 0; p < onA.length; p += 4) {
    const cr = onB[p] - onA[p]
    const cg = onB[p + 1] - onA[p + 1]
    const cb = onB[p + 2] - onA[p + 2]
    let alpha = 1 - (cr * dr + cg * dg + cb * db) / dd

    if (alpha < 0) {
      alpha = 0
    } else if (alpha > 1) {
      alpha = 1
    }

    if (alpha < TRANSPARENT) {
      transparent += 1
      continue
    }

    const back = 1 - alpha

    out[p] = clamp((onA[p] - back * ar) / alpha)
    out[p + 1] = clamp((onA[p + 1] - back * ag) / alpha)
    out[p + 2] = clamp((onA[p + 2] - back * ab) / alpha)
    out[p + 3] = Math.round(alpha * 255)
  }

  return { out, stats: { matted: true, transparent: transparent / count, backgrounds } }
}

self.onmessage = async (event) => {
  const { id, width, height, pixels, second, quality, lossless, format } = event.data
  const started = performance.now()

  try {
    const ctx = surface(width, height)
    let source = new Uint8ClampedArray(pixels)
    let stats = null

    if (second) {
      const result = matte(source, new Uint8ClampedArray(second))

      source = result.out
      stats = result.stats
    }

    ctx.clearRect(0, 0, width, height)
    ctx.putImageData(new ImageData(source, width, height), 0, 0)

    const blob = await canvas.convertToBlob({
      type: format === 'png' ? 'image/png' : 'image/webp',
      quality: lossless ? 1 : quality,
    })
    const buffer = await blob.arrayBuffer()

    self.postMessage(
      { id, ok: true, buffer, bytes: buffer.byteLength, ms: performance.now() - started, stats },
      [buffer],
    )
  } catch (error) {
    self.postMessage({
      id,
      ok: false,
      error: String((error && error.message) || error),
      ms: performance.now() - started,
    })
  }
}
