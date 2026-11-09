import { defineConfig, globalIgnores } from 'eslint/config'
import js from '@eslint/js'
import tseslint from 'typescript-eslint'
import svelte from 'eslint-plugin-svelte'
import pluginOxlint from 'eslint-plugin-oxlint'
import prettier from 'eslint-config-prettier/flat'
import globals from 'globals'
import svelteConfig from './svelte.config.js'

export default defineConfig(
  globalIgnores(['**/dist/**', '**/node_modules/**']),

  js.configs.recommended,
  ...tseslint.configs.recommended,
  ...svelte.configs.recommended,

  {
    name: 'app/browser',
    files: ['**/*.{ts,svelte}'],
    languageOptions: {
      globals: { ...globals.browser },
    },
  },

  {
    name: 'app/capture',
    files: ['src/capture/**/*.js'],
    languageOptions: {
      globals: { ...globals.browser, ...globals.worker, GetParentResourceName: 'readonly' },
    },
  },

  {
    name: 'app/svelte',
    files: ['**/*.svelte', '**/*.svelte.ts'],
    languageOptions: {
      parserOptions: {
        projectService: true,
        extraFileExtensions: ['.svelte'],
        parser: tseslint.parser,
        svelteConfig,
      },
    },
  },

  ...pluginOxlint.buildFromOxlintConfigFile('.oxlintrc.json'),

  prettier,
  ...svelte.configs.prettier,
)
