import { matte } from './matte.js'

let canvas = null
let context = null

function surface(width, height) {
  if (!canvas || canvas.width !== width || canvas.height !== height) {
    canvas = new OffscreenCanvas(width, height)
    context = canvas.getContext('2d', { alpha: true, willReadFrequently: false })
  }

  return context
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
