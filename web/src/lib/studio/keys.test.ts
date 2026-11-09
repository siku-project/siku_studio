import { describe, expect, it } from 'vitest'
import { axesOf } from './keys'

describe('camera keys', () => {
  it('maps held keys to axes', () => {
    expect(axesOf({ ArrowRight: true, PageUp: true })).toEqual({ x: 1, y: 1, z: 0, fov: 0 })
    expect(axesOf({ ArrowDown: true, NumpadAdd: true })).toEqual({ x: 0, y: 0, z: -1, fov: -1 })
  })

  it('cancels opposite keys', () => {
    expect(axesOf({ ArrowLeft: true, ArrowRight: true })).toEqual({ x: 0, y: 0, z: 0, fov: 0 })
  })
})
