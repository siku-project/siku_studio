const STRIDE = 64 * 4
const MOVED_PIXEL = 6
const EXPECTED_GAP = 64
const SEEN_GAP = 24
const SEEN_SHARE = 0.7
const EDGE = 2
const TOP_POINTS = 8
const SIDE_POINTS = 4
const SIDE_DEPTH = 0.6

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

export function borderPoints(width, height) {
  const points = []

  for (let i = 0; i < TOP_POINTS; i += 1) {
    points.push([Math.round(((i + 0.5) * width) / TOP_POINTS), EDGE])
  }

  for (let i = 0; i < SIDE_POINTS; i += 1) {
    const y = Math.round(((i + 0.5) * height * SIDE_DEPTH) / SIDE_POINTS)

    points.push([EDGE, y], [width - 1 - EDGE, y])
  }

  return points
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

export function backgroundSeen(pixels, width, height, expected) {
  const pairs = orderings(expected)

  if (pairs.length === 0) {
    return true
  }

  const points = borderPoints(width, height)
  let seen = 0

  for (const [x, y] of points) {
    const p = (y * width + x) * 4
    let matches = true

    for (const [i, j] of pairs) {
      if (pixels[p + i] <= pixels[p + j] + SEEN_GAP) {
        matches = false
        break
      }
    }

    if (matches) {
      seen += 1
    }
  }

  return seen / points.length >= SEEN_SHARE
}
