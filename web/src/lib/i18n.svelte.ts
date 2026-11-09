import { m as compiled } from '@/paraglide/messages'
import { locale, type Locale } from '@/lib/locale.svelte'

type Messages = typeof compiled
export type MessageKey = keyof Messages
type Inputs = Record<string, string | number>

/**
 * The strings the game pushed, by language and key. They win over the
 * compiled messages, so a wording edited in translations/<language>.lua
 * shows without a rebuild. The compiled messages, generated from the same
 * Lua files, cover the browser and any key the game did not send.
 */
const pushed = $state<Partial<Record<Locale, Record<string, string>>>>({})

/** Fills `{name}` placeholders the way the compiled messages do. */
const interpolate = (text: string, inputs?: Inputs): string =>
  inputs ? text.replace(/\{(\w+)\}/g, (match, name) => String(inputs[name] ?? match)) : text

/** Keeps the strings the game sent for a language. */
export const applyTranslations = (language: string, web: Record<string, string>): void => {
  if (!locale.set(language) && locale.current !== language) {
    return
  }

  pushed[language as Locale] = { ...web }
}

/**
 * The messages the interface calls, `m.menu_title()` and the like, typed
 * from the compiled ones. Each call reads the pushed strings first.
 */
export const m: Messages = new Proxy(compiled, {
  get(target, key) {
    const override = pushed[locale.current]?.[key as string]

    if (override !== undefined) {
      return (inputs?: Inputs) => interpolate(override, inputs)
    }

    return target[key as MessageKey]
  },
})

/** Reads a message by key when the key only exists at runtime (catalogue labels). */
export const tr = (key: MessageKey, inputs: Inputs = {}): string =>
  (m[key] as unknown as (inputs: Inputs) => string)(inputs)
