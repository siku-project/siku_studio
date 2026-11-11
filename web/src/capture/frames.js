const STRIDE = 64 * 4
const MOVED_PIXEL = 6
const EXPECTED_GAP = 64
const SEEN_GAP = 24
const GONE_SHARE = 0.002
const GONE_RATIO = 4

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

function looksLike(pixels, p, pairs) {
  for (const [i, j] of pairs) {
    if (pixels[p + i] <= pixels[p + j] + SEEN_GAP) {
      return false
    }
  }

  return true
}

export function backgroundShares(pixels, expected, other) {
  const wanted = orderings(expected)
  const unwanted = Array.isArray(other) ? orderings(other) : []
  let seen = 0
  let left = 0
  let n = 0

  for (let p = 0; p < pixels.length; p += STRIDE) {
    if (wanted.length > 0 && looksLike(pixels, p, wanted)) {
      seen += 1
    } else if (unwanted.length > 0 && looksLike(pixels, p, unwanted)) {
      left += 1
    }

    n += 1
  }

  return { seen: seen / n, left: left / n }
}

export function backgroundSeen(pixels, expected, other) {
  const { seen, left } = backgroundShares(pixels, expected, other)

  return left <= Math.max(GONE_SHARE, seen / GONE_RATIO)
}
