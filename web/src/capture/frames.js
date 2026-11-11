const STRIDE = 64 * 4
const MOVED_PIXEL = 6
const EXPECTED_GAP = 64
const SEEN_GAP = 24
const BUCKET_SHIFT = 3
const BACKGROUND_SHARE = 0.15

export function difference(before, after) {
  let total = 0
  let moved = 0
  let n = 0

  for (let p = 0; p < before.length; p += STRIDE) {
    const d =
      Math.abs(after[p] - before[p]) +
      Math.abs(after[p + 1] - before[p + 1]) +
      Math.abs(after[p + 2] - before[p + 2])

    total += d

    if (d > MOVED_PIXEL) {
      moved += 1
    }

    n += 1
  }

  return { mean: total / n, moved: moved / n }
}

export function orderings(expected) {
  const pairs = []

  for (let i = 0; i < 3; i += 1) {
    for (let j = 0; j < 3; j += 1) {
      if (expected[i] > expected[j] + EXPECTED_GAP) {
        pairs.push([i, j])
      }
    }
  }

  return pairs
}

export function looksLike(color, pairs) {
  if (pairs.length === 0) {
    return false
  }

  for (const [i, j] of pairs) {
    if (color[i] <= color[j] + SEEN_GAP) {
      return false
    }
  }

  return true
}

export function dominant(pixels) {
  const buckets = new Map()
  let n = 0

  for (let p = 0; p < pixels.length; p += STRIDE) {
    const key =
      ((pixels[p] >> BUCKET_SHIFT) << 10) |
      ((pixels[p + 1] >> BUCKET_SHIFT) << 5) |
      (pixels[p + 2] >> BUCKET_SHIFT)
    let bucket = buckets.get(key)

    if (!bucket) {
      bucket = { count: 0, sum: [0, 0, 0] }
      buckets.set(key, bucket)
    }

    bucket.count += 1
    bucket.sum[0] += pixels[p]
    bucket.sum[1] += pixels[p + 1]
    bucket.sum[2] += pixels[p + 2]
    n += 1
  }

  let best = null

  for (const bucket of buckets.values()) {
    if (!best || bucket.count > best.count) {
      best = bucket
    }
  }

  if (!best) {
    return { color: [0, 0, 0], share: 0 }
  }

  return { color: best.sum.map((v) => Math.round(v / best.count)), share: best.count / n }
}

export function backgroundSeen(pixels, expected, previous) {
  const top = dominant(pixels)

  if (top.share < BACKGROUND_SHARE) {
    return true
  }

  if (looksLike(top.color, orderings(expected))) {
    return true
  }

  return !looksLike(top.color, orderings(previous || []))
}
