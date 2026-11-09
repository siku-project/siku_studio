export type TargetKind = 'component' | 'prop' | 'overlay' | 'haircolor' | 'eyecolor'

export interface TargetInfo {
  id: string
  label: string
  kind: TargetKind
  index?: number
  count: number
}

export interface PartInfo {
  kind: 'component' | 'prop'
  index: number
  label: string
  icon: string
  worn: boolean
  visible: boolean
}

export interface Camera {
  x: number
  y: number
  z: number
  fov: number
}

export interface Axes {
  x: number
  y: number
  z: number
  fov: number
}

export type Axis = keyof Axes

export type StepSize = 'fine' | 'normal' | 'large'

export const STEP_SIZES: StepSize[] = ['fine', 'normal', 'large']

export const isStepSize = (value: unknown): value is StepSize =>
  typeof value === 'string' && (STEP_SIZES as string[]).includes(value)

export const isCamera = (value: unknown): value is Camera =>
  typeof value === 'object' &&
  value !== null &&
  ['x', 'y', 'z', 'fov'].every((key) => typeof (value as Record<string, unknown>)[key] === 'number')
