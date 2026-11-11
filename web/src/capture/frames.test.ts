import { describe, expect, it } from 'vitest'
import { backgroundSeen, difference, dominant, orderings } from './frames.js'

const SIDE = 64
const GREEN = [0, 169, 0]
const MAGENTA = [255, 0, 255]
const SHOWN_GREEN = [75, 140, 75]
const SHOWN_MAGENTA = [230, 60, 230]
const SKIN = [200, 180, 170]

type Shade = (y: number) => number[]

const flat =
  (color: number[]): Shade =>
  () =>
    color

const shaded =
  (color: number[]): Shade =>
  (y) =>
    color.map((v) => Math.max(0, Math.min(255, v - 60 + ((y * 7) % 120))))

const paint = (background: number[], subject?: Shade, from = 16): Uint8Array => {
  const out = new Uint8Array(SIDE * SIDE * 4)

  for (let y = 0; y < SIDE; y += 1) {
    for (let x = 0; x < SIDE; x += 1) {
      const [r, g, b] = subject && y >= from ? subject(y) : background
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
    const result = difference(paint([10, 20, 30]), paint([10, 20, 30], flat([200, 200, 200])))

    expect(result.moved).toBeGreaterThan(0.2)
    expect(result.mean).toBeGreaterThan(12)
  })
})

describe('dominant', () => {
  it('finds the flat colour that covers most of the picture', () => {
    const top = dominant(paint(SHOWN_GREEN, shaded(SKIN), 32))

    expect(top.color).toEqual(SHOWN_GREEN)
    expect(top.share).toBeCloseTo(0.5, 1)
  })

  it('is not fooled by a large shaded garment', () => {
    const top = dominant(paint(SHOWN_GREEN, shaded([200, 40, 200]), 24))

    expect(top.color).toEqual(SHOWN_GREEN)
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

  it('accepts the green once it is the background, even dimmed by the game', () => {
    expect(backgroundSeen(paint(SHOWN_GREEN, shaded(SKIN)), GREEN, MAGENTA)).toBe(true)
  })

  it('waits while the previous background still fills the picture', () => {
    expect(backgroundSeen(paint(SHOWN_MAGENTA, shaded(SKIN)), GREEN, MAGENTA)).toBe(false)
    expect(backgroundSeen(paint(SHOWN_GREEN, shaded(SKIN)), MAGENTA, GREEN)).toBe(false)
  })

  it('accepts a purple garment on the green, and a green one on the magenta', () => {
    expect(backgroundSeen(paint(SHOWN_GREEN, shaded([200, 40, 200]), 24), GREEN, MAGENTA)).toBe(
      true,
    )
    expect(backgroundSeen(paint(SHOWN_MAGENTA, shaded([40, 160, 40]), 24), MAGENTA, GREEN)).toBe(
      true,
    )
  })

  it('accepts a close-up that shows no background at all', () => {
    expect(backgroundSeen(paint(SKIN, shaded(SKIN), 0), GREEN, MAGENTA)).toBe(true)
    expect(backgroundSeen(paint(SKIN, shaded(SKIN), 0), MAGENTA, GREEN)).toBe(true)
  })

  it('accepts any picture when the expected colour has no dominant channel', () => {
    expect(backgroundSeen(paint([10, 10, 10]), [24, 26, 30], MAGENTA)).toBe(true)
  })
})
