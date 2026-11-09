import { describe, expect, it } from 'vitest'
import { MOCK_PARTS, MOCK_TARGETS } from './mock'
import { store } from './store.svelte'

const action = (name: string) => `siku_studio:nui:setup.${name}`

describe('store', () => {
  it('ignores messages that are not ours', () => {
    expect(store.applyMessage({ action: 'other:thing' })).toBe(false)
    expect(store.applyMessage(null)).toBe(false)
    expect(store.applyMessage({ action: action('unknown') })).toBe(false)
  })

  it('opens with what the game sent', () => {
    expect(
      store.applyMessage({
        action: action('open'),
        model: 'mp_f_freemode_01',
        targets: MOCK_TARGETS,
        parts: MOCK_PARTS,
        camera: { x: 0.1, y: 1.5, z: 0.6, fov: 30, turn: 0 },
        target: 'prop_0',
        index: 3,
        step: 'fine',
      }),
    ).toBe(true)
    expect(store.open).toBe(true)
    expect(store.model).toBe('mp_f_freemode_01')
    expect(store.current?.id).toBe('prop_0')
    expect(store.index).toBe(3)
    expect(store.step).toBe('fine')
  })

  it('patches the camera and the item count on state messages', () => {
    store.applyMessage({
      action: action('state'),
      camera: { x: 0, y: 1, z: 0.5, fov: 20, turn: 180 },
      target: 'component_2',
      index: 7,
      count: 80,
    })
    expect(store.camera.fov).toBe(20)
    expect(store.fromBehind).toBe(true)
    expect(store.current?.id).toBe('component_2')
    expect(store.current?.count).toBe(80)
    expect(store.index).toBe(7)
  })

  it('keeps the generated lines and closes', () => {
    store.applyMessage({ action: action('saved'), snippet: 'x = 1' })
    expect(store.snippet).toBe('x = 1')
    store.applyMessage({ action: action('close') })
    expect(store.open).toBe(false)
  })

  it('refuses a malformed camera', () => {
    const before = store.camera
    store.applyMessage({ action: action('state'), camera: { x: 'a' } })
    expect(store.camera).toBe(before)
  })

  it('turns the subject on itself without moving the camera', () => {
    store.applyMessage({
      action: action('state'),
      camera: { x: 0.1, y: 2, z: 0.3, fov: 35, turn: 0 },
    })
    store.turn(true)
    expect(store.fromBehind).toBe(true)
    expect(store.camera).toMatchObject({ x: 0.1, y: 2, z: 0.3, fov: 35, turn: 180 })
    store.turn(false)
    expect(store.camera.turn).toBe(0)
  })
})
