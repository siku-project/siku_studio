const GREEN = [0, 255, 0];
const MAGENTA = [255, 0, 255];
const TRANSPARENT = 0.01;

let canvas = null;
let context = null;

function surface(width, height) {
  if (!canvas || canvas.width !== width || canvas.height !== height) {
    canvas = new OffscreenCanvas(width, height);
    context = canvas.getContext('2d', { alpha: true, willReadFrequently: false });
  }

  return context;
}

function clamp(value) {
  return value < 0 ? 0 : value > 255 ? 255 : value;
}

function matte(onGreen, onMagenta) {
  const out = new Uint8ClampedArray(onGreen.length);

  for (let i = 0; i < onGreen.length; i += 4) {
    const r1 = onGreen[i];
    const g1 = onGreen[i + 1];
    const b1 = onGreen[i + 2];
    const r2 = onMagenta[i];
    const g2 = onMagenta[i + 1];
    const b2 = onMagenta[i + 2];
    let alpha = 1 - ((r2 - r1) + (g1 - g2) + (b2 - b1)) / (3 * 255);

    if (alpha < 0) {
      alpha = 0;
    } else if (alpha > 1) {
      alpha = 1;
    }

    if (alpha < TRANSPARENT) {
      continue;
    }

    const back = 1 - alpha;

    out[i] = clamp((r1 - back * GREEN[0]) / alpha);
    out[i + 1] = clamp((g1 - back * GREEN[1]) / alpha);
    out[i + 2] = clamp((b1 - back * GREEN[2]) / alpha);
    out[i + 3] = Math.round(alpha * 255);
  }

  return out;
}

self.onmessage = async (event) => {
  const { id, width, height, pixels, second, quality, lossless, format } = event.data;
  const started = performance.now();

  try {
    const ctx = surface(width, height);
    const source = second
      ? matte(new Uint8ClampedArray(pixels), new Uint8ClampedArray(second))
      : new Uint8ClampedArray(pixels);

    ctx.clearRect(0, 0, width, height);
    ctx.putImageData(new ImageData(source, width, height), 0, 0);

    const blob = await canvas.convertToBlob({
      type: format === 'png' ? 'image/png' : 'image/webp',
      quality: lossless ? 1 : quality,
    });
    const buffer = await blob.arrayBuffer();

    self.postMessage({ id, ok: true, buffer, bytes: buffer.byteLength, ms: performance.now() - started }, [buffer]);
  } catch (error) {
    self.postMessage({ id, ok: false, error: String(error && error.message || error), ms: performance.now() - started });
  }
};
