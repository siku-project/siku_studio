import { describe, expect, it } from 'vitest'
import { backgroundSeen, backgroundShares, difference, orderings } from './frames.js'

const SIDE = 64
const GREEN = [0, 169, 0]
const MAGENTA = [255, 0, 255]
const SHOWN_GREEN = [75, 140, 75]
const SHOWN_MAGENTA = [230, 60, 230]
const SKIN = [200, 180, 170]

const paint = (color: number[], inside?: number[], from = 16): Uint8Array => {
  const out = new Uint8Array(SIDE * SIDE * 4)

  for (let y = 0; y < SIDE; y += 1) {
    for (let x = 0; x < SIDE; x += 1) {
      const [r, g, b] = inside && y >= from ? inside : color
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
    const frame = paint([10, 20, 30])

    expect(difference(frame, frame)).toEqual({ mean: 0, moved: 0 })
  })

  it('counts the sampled pixels that moved', () => {
    const result = difference(paint([10, 20, 30]), paint([10, 20, 30], [200, 200, 200]))

    expect(result.moved).toBeGreaterThan(0.2)
    expect(result.mean).toBeGreaterThan(12)
  })
})

describe('backgroundSeen', () => {
  it('derives which channels must dominate from the expected colour', () => {
    expect(orderings(GREEN)).toEqual([
      [1, 0],
      [1, 2],
    ])
    expect(orderings(MAGENTA)).toEqual([
      [0, 1],
      [2, 1],
    ])
    expect(orderings([24, 26, 30])).toEqual([])
  })

  it('tells the share of the picture showing each background', () => {
    const shares = backgroundShares(paint(SHOWN_GREEN, SKIN, 32), GREEN, MAGENTA)

    expect(shares.seen).toBeCloseTo(0.5, 1)
    expect(shares.left).toBe(0)
  })

  it('accepts the green once the magenta is gone, even dimmed by the game', () => {
    expect(backgroundSeen(paint(SHOWN_GREEN, SKIN), GREEN, MAGENTA)).toBe(true)
  })

  it('waits while the previous background still shows', () => {
    expect(backgroundSeen(paint(SHOWN_MAGENTA, SKIN), GREEN, MAGENTA)).toBe(false)
    expect(backgroundSeen(paint(SHOWN_GREEN, SKIN), MAGENTA, GREEN)).toBe(false)
  })

  it('accepts a close-up that shows no background at all', () => {
    expect(backgroundSeen(paint(SKIN), GREEN, MAGENTA)).toBe(true)
    expect(backgroundSeen(paint(SKIN), MAGENTA, GREEN)).toBe(true)
  })

  it('tolerates a few pixels of the other colour on the subject', () => {
    const frame = paint(SHOWN_GREEN, SHOWN_MAGENTA, 60)

    expect(backgroundSeen(frame, GREEN, MAGENTA)).toBe(true)
  })

  it('accepts any picture when the expected colour has no dominant channel', () => {
    expect(backgroundSeen(paint([10, 10, 10]), [24, 26, 30], MAGENTA)).toBe(true)
  })
})
