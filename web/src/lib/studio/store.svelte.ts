import { RESOURCE } from '@/lib/nui'
import { game } from './bridge'
import {
  isCamera,
  isStepSize,
  type Axes,
  type Axis,
  type Camera,
  type PartInfo,
  type StepSize,
  type TargetInfo,
} from './types'

const PREFIX = `${RESOURCE}:nui:setup.`

let open = $state(false)
let model = $state('')
let models = $state<string[]>([])
let targets = $state<TargetInfo[]>([])
let parts = $state<PartInfo[]>([])
const DEFAULT_CAMERA: Camera = { x: 0, y: 0, z: 0, fov: 30, turn: 0 }

let camera = $state<Camera>({ ...DEFAULT_CAMERA })
let target = $state('')
let index = $state(0)
let step = $state<StepSize>('normal')
let snippet = $state('')

interface SetupMessage {
  action?: unknown
  model?: unknown
  models?: unknown
  targets?: unknown
  parts?: unknown
  camera?: unknown
  target?: unknown
  index?: unknown
  count?: unknown
  step?: unknown
  snippet?: unknown
}

const isTargets = (value: unknown): value is TargetInfo[] =>
  Array.isArray(value) && value.every((entry) => typeof entry?.id === 'string')

const isParts = (value: unknown): value is PartInfo[] =>
  Array.isArray(value) && value.every((entry) => typeof entry?.index === 'number')

const isModels = (value: unknown): value is string[] =>
  Array.isArray(value) && value.every((entry) => typeof entry === 'string')

const applyState = (message: SetupMessage): void => {
  if (typeof message.model === 'string') model = message.model
  if (isTargets(message.targets)) targets = message.targets
  if (isCamera(message.camera)) camera = message.camera
  if (isParts(message.parts)) parts = message.parts
  if (typeof message.target === 'string') target = message.target
  if (typeof message.index === 'number') index = message.index
  if (typeof message.count === 'number') {
    const found = targets.find((entry) => entry.id === target)
    if (found) found.count = message.count
  }
}

/** What the game shows in the framing tool. The game patches it, the interface reads it. */
export const store = {
  get open(): boolean {
    return open
  },
  get model(): string {
    return model
  },
  get models(): string[] {
    return models
  },
  get targets(): TargetInfo[] {
    return targets
  },
  get parts(): PartInfo[] {
    return parts
  },
  get camera(): Camera {
    return camera
  },
  get target(): string {
    return target
  },
  get current(): TargetInfo | null {
    return targets.find((entry) => entry.id === target) ?? null
  },
  get index(): number {
    return index
  },
  get step(): StepSize {
    return step
  },
  get fromBehind(): boolean {
    return camera.turn !== 0
  },
  get snippet(): string {
    return snippet
  },

  /** Handles one message from the game; false when it was not ours. */
  applyMessage(data: unknown): boolean {
    if (!data || typeof data !== 'object') {
      return false
    }

    const message = data as SetupMessage

    if (typeof message.action !== 'string' || !message.action.startsWith(PREFIX)) {
      return false
    }

    switch (message.action.slice(PREFIX.length)) {
      case 'open':
        store.load(message)
        open = true
        break
      case 'state':
        applyState(message)
        break
      case 'saved':
        snippet = typeof message.snippet === 'string' ? message.snippet : ''
        break
      case 'close':
        open = false
        break
      default:
        return false
    }

    return true
  },

  /** Fills the tool with what the game, or a mock, describes. */
  load(message: SetupMessage): void {
    model = typeof message.model === 'string' ? message.model : ''
    models = isModels(message.models) ? message.models : model ? [model] : []
    targets = isTargets(message.targets) ? message.targets : []
    parts = isParts(message.parts) ? message.parts : []
    camera = isCamera(message.camera) ? message.camera : { ...DEFAULT_CAMERA }
    target = typeof message.target === 'string' ? message.target : (targets[0]?.id ?? '')
    index = typeof message.index === 'number' ? message.index : 0
    step = isStepSize(message.step) ? message.step : 'normal'
    snippet = ''
  },

  pickModel(id: string): void {
    if (id === model) return
    model = id
    snippet = ''
    void game.pickModel(id)
  },

  pickTarget(id: string): void {
    target = id
    index = 0
    snippet = ''
    void game.pickTarget(id)
  },

  showIndex(value: number): void {
    index = value
    void game.showIndex(value)
  },

  setStep(value: StepSize): void {
    step = value
    void game.setStep(value)
  },

  input(axes: Axes): void {
    void game.input(axes)
  },

  nudge(axis: Axis, direction: 1 | -1): void {
    void game.nudge(axis, direction)
  },

  togglePart(part: PartInfo, visible: boolean): void {
    part.visible = visible
    void game.togglePart(part.kind, part.index, visible)
  },

  turn(fromBehind: boolean): void {
    const turn = fromBehind ? 180 : 0
    camera = { ...camera, turn }
    void game.turn(turn)
  },

  reset(): void {
    void game.reset()
  },

  save(): void {
    void game.save()
  },

  close(): void {
    open = false
    void game.close()
  },
}
