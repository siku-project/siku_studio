import { baseLocale, getLocale, isLocale, locales, setLocale } from '@/paraglide/runtime'

export type Locale = (typeof locales)[number]

let current = $state<Locale>(getLocale())

/**
 * The language of the interface. Messages are compiled by Paraglide and read
 * the runtime locale on every call; changing it here re-renders the tree
 * keyed on `locale.current`, so every message follows.
 */
export const locale = {
  get current(): Locale {
    return current
  },

  get all(): readonly Locale[] {
    return locales
  },

  get base(): Locale {
    return baseLocale
  },

  set(value: string): boolean {
    if (!isLocale(value) || value === current) {
      return false
    }

    setLocale(value, { reload: false })
    current = value

    return true
  },

  cycle(): Locale {
    const index = locales.indexOf(current)
    const next = locales[(index + 1) % locales.length] ?? baseLocale

    locale.set(next)

    return next
  },
}
