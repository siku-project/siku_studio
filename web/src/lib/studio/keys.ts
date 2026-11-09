import type { Axes, Axis } from './types'

interface Binding {
  axis: Axis
  minus: string
  plus: string
}

export const BINDINGS: Binding[] = [
  { axis: 'x', minus: 'ArrowLeft', plus: 'ArrowRight' },
  { axis: 'z', minus: 'ArrowDown', plus: 'ArrowUp' },
  { axis: 'y', minus: 'PageDown', plus: 'PageUp' },
  { axis: 'fov', minus: 'NumpadAdd', plus: 'NumpadSubtract' },
]

interface Controlled {
  input(axes: Axes): void
  nudge(axis: Axis, direction: 1 | -1): void
  close(): void
}

/** Turns held keys into a steady camera input: one message per change, none while nothing moves. */
export const axesOf = (pressed: Record<string, boolean>): Axes => {
  const axes: Axes = { x: 0, y: 0, z: 0, fov: 0 }

  for (const binding of BINDINGS) {
    axes[binding.axis] = (pressed[binding.plus] ? 1 : 0) - (pressed[binding.minus] ? 1 : 0)
  }

  return axes
}

const tracked = (code: string): boolean =>
  BINDINGS.some((binding) => binding.minus === code || binding.plus === code)

const CONTROLS =
  '.sk-select, .sk-stepper, .sk-seg, input, textarea, [role="listbox"], [role="combobox"], [role="spinbutton"]'

/** A form control keeps its own arrows: the camera only listens when none has the focus. */
const inControl = (): boolean => document.activeElement?.closest(CONTROLS) !== null

export const attachCameraKeys = (target: Controlled) => {
  const pressed: Record<string, boolean> = {}
  let last = ''

  const sync = (): void => {
    const axes = axesOf(pressed)
    const signature = `${axes.x}${axes.y}${axes.z}${axes.fov}`

    if (signature !== last) {
      last = signature
      target.input(axes)
    }
  }

  return {
    onkeydown(event: KeyboardEvent): void {
      if (event.key === 'Escape') {
        event.preventDefault()
        target.close()
        return
      }

      if (!tracked(event.code) || inControl()) {
        return
      }

      event.preventDefault()

      if (!pressed[event.code]) {
        pressed[event.code] = true
        sync()
      }
    },

    onkeyup(event: KeyboardEvent): void {
      if (!tracked(event.code)) {
        return
      }

      pressed[event.code] = false
      sync()
    },

    onblur(): void {
      for (const code of Object.keys(pressed)) {
        pressed[code] = false
      }

      sync()
    },

    onwheel(event: WheelEvent): void {
      if ((event.target as HTMLElement | null)?.closest('.studio-scroll')) {
        return
      }

      target.nudge('fov', event.deltaY > 0 ? 1 : -1)
    },
  }
}
