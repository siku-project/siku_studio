import { sendNuiEvent } from '@/lib/nui'
import type { Axes, Axis, StepSize } from './types'

/** Every call the framing tool makes to the game, by name. */
export const game = {
  pickModel: (model: string) => sendNuiEvent('setup.model', { model }),
  pickTarget: (id: string) => sendNuiEvent('setup.target', { id }),
  showIndex: (index: number) => sendNuiEvent('setup.index', { index }),
  setStep: (step: StepSize) => sendNuiEvent('setup.step', { step }),
  input: (axes: Axes) => sendNuiEvent('setup.input', axes),
  nudge: (axis: Axis, direction: 1 | -1) => sendNuiEvent('setup.nudge', { axis, direction }),
  togglePart: (kind: 'component' | 'prop', index: number, visible: boolean) =>
    sendNuiEvent('setup.part', { kind, index, visible }),
  turn: (turn: number) => sendNuiEvent('setup.turn', { turn }),
  reset: () => sendNuiEvent('setup.reset'),
  save: () => sendNuiEvent('setup.save'),
  close: () => sendNuiEvent('setup.close'),
}
