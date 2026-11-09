import { store } from './store.svelte'
import type { PartInfo, TargetInfo } from './types'

export const MOCK_TARGETS: TargetInfo[] = [
  { id: 'component_2', label: 'Hair', kind: 'component', index: 2, count: 78 },
  { id: 'component_11', label: 'Top', kind: 'component', index: 11, count: 412 },
  { id: 'prop_0', label: 'Hat', kind: 'prop', index: 0, count: 160 },
  { id: 'overlay_1', label: 'Facial hair', kind: 'overlay', index: 1, count: 29 },
]

export const MOCK_PARTS: PartInfo[] = [
  { kind: 'component', index: 1, label: 'Mask', icon: 'mask', worn: true, visible: true },
  { kind: 'component', index: 2, label: 'Hair', icon: 'head', worn: true, visible: true },
  { kind: 'component', index: 3, label: 'Torso', icon: 'arm', worn: true, visible: true },
  { kind: 'component', index: 4, label: 'Legs', icon: 'pants', worn: true, visible: true },
  { kind: 'component', index: 11, label: 'Top', icon: 'hanger', worn: true, visible: true },
  { kind: 'prop', index: 0, label: 'Hat', icon: 'hat', worn: true, visible: true },
  { kind: 'prop', index: 1, label: 'Glasses', icon: 'glasses', worn: false, visible: false },
]

/** Fills the store the way the game would, for the browser. */
export const loadMocks = (): void => {
  store.load({
    model: 'mp_m_freemode_01',
    targets: MOCK_TARGETS,
    parts: MOCK_PARTS,
    camera: { x: 0, y: 2.0, z: 0.65, fov: 35, turn: 0 },
    target: 'component_11',
    index: 12,
    step: 'normal',
  })
}
