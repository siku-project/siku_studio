import { notify } from './nui'

export type TargetInfo = { id: string; label: string; kind: string; index?: number; count: number }
export type PartInfo = {
  kind: 'component' | 'prop'
  index: number
  label: string
  icon: string
  worn: boolean
  visible: boolean
}
export type Camera = { x: number; y: number; z: number; fov: number }
export type Axes = { x: number; y: number; z: number; fov: number }
export type StepSize = 'fine' | 'normal' | 'large'

type OpenMessage = {
  translations?: Record<string, string>
  model?: string
  targets?: TargetInfo[]
  parts?: PartInfo[]
  camera?: Camera
  target?: string
  index?: number
  step?: StepSize
}

type StateMessage = {
  camera?: Camera
  parts?: PartInfo[]
  target?: string
  index?: number
  count?: number
}

const PREFIX = 'siku_studio:nui:setup.'

class SetupStore {
  open = $state(false)
  model = $state('')
  targets = $state<TargetInfo[]>([])
  parts = $state<PartInfo[]>([])
  camera = $state<Camera>({ x: 0, y: 0, z: 0, fov: 30 })
  target = $state('')
  index = $state(0)
  step = $state<StepSize>('normal')
  snippet = $state('')
  translations = $state<Record<string, string>>({})

  readonly current = $derived(this.targets.find((t) => t.id === this.target) ?? null)

  t(key: string, values: Record<string, string | number> = {}): string {
    const raw = this.translations[key] ?? key

    return raw.replace(/\{(\w+)\}/g, (_, name: string) => String(values[name] ?? `{${name}}`))
  }

  applyMessage(data: unknown): void {
    if (!data || typeof data !== 'object') {
      return
    }

    const message = data as { action?: string } & OpenMessage & StateMessage & { snippet?: string }

    if (typeof message.action !== 'string' || !message.action.startsWith(PREFIX)) {
      return
    }

    const name = message.action.slice(PREFIX.length)

    if (name === 'open') {
      this.translations = message.translations ?? {}
      this.model = message.model ?? ''
      this.targets = message.targets ?? []
      this.parts = message.parts ?? []
      this.camera = message.camera ?? this.camera
      this.target = message.target ?? this.targets[0]?.id ?? ''
      this.index = message.index ?? 0
      this.step = message.step ?? 'normal'
      this.snippet = ''
      this.open = true
    } else if (name === 'state') {
      if (message.camera) this.camera = message.camera
      if (message.parts) this.parts = message.parts
      if (typeof message.target === 'string') this.target = message.target
      if (typeof message.index === 'number') this.index = message.index
      if (typeof message.count === 'number') {
        const found = this.targets.find((t) => t.id === this.target)
        if (found) found.count = message.count
      }
    } else if (name === 'saved') {
      this.snippet = message.snippet ?? ''
    } else if (name === 'close') {
      this.open = false
    }
  }

  pick(id: string): void {
    this.target = id
    this.index = 0
    this.snippet = ''
    notify('setup.target', { id })
  }

  setIndex(index: number): void {
    this.index = index
    notify('setup.index', { index })
  }

  setStep(step: StepSize): void {
    this.step = step
    notify('setup.step', { step })
  }

  input(axes: Axes): void {
    notify('setup.input', axes)
  }

  nudge(axis: keyof Axes, direction: 1 | -1): void {
    notify('setup.nudge', { axis, direction })
  }

  togglePart(part: PartInfo, visible: boolean): void {
    part.visible = visible
    notify('setup.part', { kind: part.kind, index: part.index, visible })
  }

  reset(): void {
    notify('setup.reset')
  }

  save(): void {
    notify('setup.save')
  }

  close(): void {
    this.open = false
    notify('setup.close')
  }
}

export const setup = new SetupStore()
