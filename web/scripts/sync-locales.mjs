#!/usr/bin/env node
/**
 * The interface strings live in translations/<language>.lua, in the `web`
 * block, like every other resource of the ecosystem. Paraglide compiles its
 * messages from web/messages/<language>.json, so this script derives the
 * JSON files from the Lua ones: the Lua file is the only place a string is
 * written. Run it after editing a translation, and with --check to make
 * sure the two are still in step.
 */
import { readFileSync, writeFileSync } from 'node:fs'
import { resolve } from 'node:path'

const WEB = resolve(import.meta.dirname, '..')
const RESOURCE = resolve(WEB, '..')
const LANGUAGES = ['fr', 'en']
const SCHEMA = 'https://inlang.com/schema/inlang-message-format'

const check = process.argv.includes('--check')

/** Reads one Lua string literal, single or double quoted, with escapes. */
const readString = (raw) => {
  const quote = raw[0]
  const body = raw.slice(1, -1)

  return body.replace(/\\(.)/g, (_, char) => (char === quote || char === '\\' ? char : `\\${char}`))
}

/** The keys and values of the `web` block of a translation file. */
const readWebBlock = (language) => {
  const file = resolve(RESOURCE, 'translations', `${language}.lua`)
  const source = readFileSync(file, 'utf8')
  const start = source.indexOf('web = {')

  if (start < 0) {
    throw new Error(`translations/${language}.lua: no web block`)
  }

  const block = source.slice(start)
  const messages = {}
  const pattern = /\['([^']+)'\]\s*=\s*('(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*")/g

  for (const match of block.matchAll(pattern)) {
    messages[match[1]] = readString(match[2])
  }

  return messages
}

let outdated = false

for (const language of LANGUAGES) {
  const messages = readWebBlock(language)
  const sorted = Object.fromEntries(Object.entries(messages).sort(([a], [b]) => a.localeCompare(b)))
  const content = `${JSON.stringify({ $schema: SCHEMA, ...sorted }, null, 2)}\n`
  const target = resolve(WEB, 'messages', `${language}.json`)

  let current

  try {
    current = readFileSync(target, 'utf8')
  } catch {
    current = ''
  }

  if (current === content) {
    console.log(
      `messages/${language}.json is in step with translations/${language}.lua (${Object.keys(sorted).length} keys)`,
    )
    continue
  }

  if (check) {
    outdated = true
    console.error(
      `messages/${language}.json is behind translations/${language}.lua, run "bun run locales"`,
    )
    continue
  }

  writeFileSync(target, content)
  console.log(
    `messages/${language}.json written from translations/${language}.lua (${Object.keys(sorted).length} keys)`,
  )
}

const reference = Object.keys(readWebBlock(LANGUAGES[0])).sort()

for (const language of LANGUAGES.slice(1)) {
  const keys = Object.keys(readWebBlock(language)).sort()
  const missing = reference.filter((key) => !keys.includes(key))
  const extra = keys.filter((key) => !reference.includes(key))

  if (missing.length > 0 || extra.length > 0) {
    outdated = true
    console.error(
      `translations/${language}.lua differs from translations/${LANGUAGES[0]}.lua: missing ${missing.join(', ') || 'none'}, unknown ${extra.join(', ') || 'none'}`,
    )
  }
}

if (outdated) {
  process.exit(1)
}
