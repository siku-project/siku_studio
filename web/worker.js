let canvas = null;
let context = null;

function surface(width, height) {
  if (!canvas || canvas.width !== width || canvas.height !== height) {
    canvas = new OffscreenCanvas(width, height);
    context = canvas.getContext('2d', { alpha: true, willReadFrequently: false });
  }

  return context;
}

self.onmessage = async (event) => {
  const { id, width, height, pixels, quality, lossless, format } = event.data;
  const started = performance.now();

  try {
    const ctx = surface(width, height);
    const image = new ImageData(new Uint8ClampedArray(pixels), width, height);

    ctx.putImageData(image, 0, 0);

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
