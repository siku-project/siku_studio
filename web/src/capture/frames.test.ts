import { describe, expect, it } from 'vitest'
import { backgroundSeen, borderPoints, difference, orderings } from './frames.js'

const SIDE = 64

const fill = (color: number[], inside?: number[]): Uint8Array => {
  const out = new Uint8Array(SIDE * SIDE * 4)

  for (let y = 0; y < SIDE; y += 1) {
    for (let x = 0; x < SIDE; x += 1) {
      const centre = inside && y > 16
      const [r, g, b] = centre ? inside : color
      const p = (y * SIDE + x) * 4

      out[p] = r
      out[p + 1] = g
      out[p + 2] = b
      out[p + 3] = 255
    }
  }

  return out
}

describe('difference', () => {
  it('sees no movement between two identical readings', () => {
    const frame = fill([10, 20, 30])

    expect(difference(frame, frame)).toEqual({ mean: 0, moved: 0 })
  })

  it('counts the sampled pixels that moved', () => {
    const before = fill([10, 20, 30])
    const after = fill([10, 20, 30], [200, 200, 200])
    const result = difference(before, after)

    expect(result.moved).toBeGreaterThan(0.2)
    expect(result.mean).toBeGreaterThan(12)
  })
})

describe('backgroundSeen', () => {
  it('samples the top and the upper sides of the frame', () => {
    const points = borderPoints(SIDE, SIDE)

    expect(points).toHaveLength(16)
    points.forEach(([x, y]) => {
      expect(x).toBeGreaterThanOrEqual(0)
      expect(x).toBeLessThan(SIDE)
      expect(y).toBeLessThan(SIDE * 0.6)
    })
  })

  it('derives which channels must dominate from the expected colour', () => {
    expect(orderings([0, 169, 0])).toEqual([
      [1, 0],
      [1, 2],
    ])
    expect(orderings([255, 0, 255])).toEqual([
      [0, 1],
      [2, 1],
    ])
    expect(orderings([24, 26, 30])).toEqual([])
  })

  it('recognises the rendered green even when the game lifts and dims it', () => {
    expect(backgroundSeen(fill([75, 140, 75], [200, 180, 170]), SIDE, SIDE, [0, 169, 0])).toBe(true)
  })

  it('refuses the magenta when the green is expected, and the reverse', () => {
    const magenta = fill([230, 60, 230])

    expect(backgroundSeen(magenta, SIDE, SIDE, [0, 169, 0])).toBe(false)
    expect(backgroundSeen(magenta, SIDE, SIDE, [255, 0, 255])).toBe(true)
    expect(backgroundSeen(fill([75, 140, 75]), SIDE, SIDE, [255, 0, 255])).toBe(false)
  })

  it('accepts any picture when the expected colour has no dominant channel', () => {
    expect(backgroundSeen(fill([10, 10, 10]), SIDE, SIDE, [24, 26, 30])).toBe(true)
  })
})
