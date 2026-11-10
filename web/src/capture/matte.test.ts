import { describe, expect, it } from 'vitest'
import { estimateBackgrounds, matte } from './matte.js'

const GREEN = [0, 169, 0]
const MAGENTA = [255, 0, 255]
const SIDE = 8

type Pixel = (x: number, y: number) => { color: number[]; alpha: number }

const mix = (color: number[], alpha: number, background: number[], bleed: number): number[] =>
  color.map((value, i) =>
    Math.round(alpha * value + (1 - alpha) * background[i] + bleed * background[i]),
  )

const frame = (pixel: Pixel, background: number[], bleed = 0): Uint8ClampedArray => {
  const out = new Uint8ClampedArray(SIDE * SIDE * 4)

  for (let y = 0; y < SIDE; y += 1) {
    for (let x = 0; x < SIDE; x += 1) {
      const { color, alpha } = pixel(x, y)
      const [r, g, b] = mix(color, alpha, background, alpha > 0 ? bleed : 0)
      const p = (y * SIDE + x) * 4

      out[p] = r
      out[p + 1] = g
      out[p + 2] = b
      out[p + 3] = 255
    }
  }

  return out
}

const at = (pixels: Uint8ClampedArray, x: number, y: number): number[] =>
  Array.from(pixels.subarray((y * SIDE + x) * 4, (y * SIDE + x) * 4 + 4))

const scene: Pixel = (x, y) => {
  if (x < 2) {
    return { color: [0, 0, 0], alpha: 0 }
  }

  if (x === 2) {
    return { color: [40, 40, 40], alpha: 0.5 }
  }

  return y < 4 ? { color: [200, 200, 200], alpha: 1 } : { color: [120, 60, 30], alpha: 1 }
}

const tint = (pixel: number[]): number =>
  Math.max(...pixel.slice(0, 3)) - Math.min(...pixel.slice(0, 3))

const unmixFromFirstOnly = (
  onA: Uint8ClampedArray,
  onB: Uint8ClampedArray,
  x: number,
  y: number,
): number[] => {
  const d = MAGENTA.map((v, i) => v - GREEN[i])
  const dd = d.reduce((sum, v) => sum + v * v, 0)
  const pa = at(onA, x, y)
  const pb = at(onB, x, y)
  const c = pb.map((v, i) => v - pa[i])
  const alpha = 1 - (c[0] * d[0] + c[1] * d[1] + c[2] * d[2]) / dd

  return pa.slice(0, 3).map((v, i) => (v - (1 - alpha) * GREEN[i]) / alpha)
}

describe('estimateBackgrounds', () => {
  it('reads both rendered backgrounds from the pixels that changed the most', () => {
    const found = estimateBackgrounds(frame(scene, GREEN), frame(scene, MAGENTA))

    expect(found).not.toBeNull()
    expect(found?.a).toEqual(GREEN)
    expect(found?.b).toEqual(MAGENTA)
  })

  it('gives up when the two readings are the same picture', () => {
    expect(estimateBackgrounds(frame(scene, GREEN), frame(scene, GREEN))).toBeNull()
  })
})

describe('matte', () => {
  it('recovers the colour and the coverage when only the background changes', () => {
    const { out, stats } = matte(frame(scene, GREEN), frame(scene, MAGENTA))

    expect(stats.matted).toBe(true)
    expect(at(out, 0, 0)).toEqual([0, 0, 0, 0])
    expect(at(out, 5, 1)).toEqual([200, 200, 200, 255])
    expect(at(out, 5, 6)).toEqual([120, 60, 30, 255])

    const edge = at(out, 2, 3)

    expect(edge[3]).toBeGreaterThanOrEqual(126)
    expect(edge[3]).toBeLessThanOrEqual(129)
    edge.slice(0, 3).forEach((value) => {
      expect(Math.abs(value - 40)).toBeLessThanOrEqual(2)
    })
  })

  it('cancels a glow the two backgrounds cast alike on the subject', () => {
    const { out } = matte(frame(scene, GREEN, 0.1), frame(scene, MAGENTA, 0.1))

    expect(tint(at(out, 5, 1))).toBeLessThanOrEqual(1)
    expect(at(out, 5, 1)[3]).toBeGreaterThanOrEqual(225)
  })

  it('turns an uneven glow into a neutral shift rather than a tint', () => {
    const onA = frame(scene, GREEN, 0.12)
    const onB = frame(scene, MAGENTA, 0.06)
    const { out } = matte(onA, onB)
    const grey = at(out, 5, 1)

    expect(tint(grey)).toBeLessThan(tint(unmixFromFirstOnly(onA, onB, 5, 1)))
    expect(tint(grey)).toBeLessThanOrEqual(6)
  })

  it('keeps the first reading untouched when nothing changed', () => {
    const onA = frame(scene, GREEN)
    const { out, stats } = matte(onA, frame(scene, GREEN))

    expect(stats.matted).toBe(false)
    expect(Array.from(out)).toEqual(Array.from(onA))
  })
})
