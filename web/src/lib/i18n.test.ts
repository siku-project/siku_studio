import { describe, expect, it } from 'vitest'
import { applyTranslations, m, tr } from './i18n.svelte'
import { locale } from './locale.svelte'

describe('i18n', () => {
  it('serves the compiled message when the game sent nothing', () => {
    expect(m.setup_close()).toBe('Fermer')
  })

  it('prefers the string the game pushed for the running language', () => {
    applyTranslations(locale.current, { setup_close: 'Quitter' })

    expect(m.setup_close()).toBe('Quitter')
  })

  it('fills placeholders in a pushed string', () => {
    applyTranslations(locale.current, { setup_model: 'Ped {model}' })

    expect(m.setup_model({ model: 'mp_m_freemode_01' })).toBe('Ped mp_m_freemode_01')
  })

  it('reads a message by runtime key', () => {
    expect(tr('setup_axis_x')).toBe(m.setup_axis_x())
  })

  it('switches the language along with the strings', () => {
    applyTranslations('en', { setup_close: 'Leave' })

    expect(locale.current).toBe('en')
    expect(m.setup_close()).toBe('Leave')
    expect(m.setup_title()).toBe('Framing tool')
  })
})
