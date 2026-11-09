import { fileURLToPath, URL } from 'node:url'

import { paraglideVitePlugin } from '@inlang/paraglide-js'
import { svelte } from '@sveltejs/vite-plugin-svelte'
import { defineConfig } from 'vitest/config'

export default defineConfig({
  base: './',
  plugins: [
    paraglideVitePlugin({
      project: './project.inlang',
      outdir: './src/paraglide',
      strategy: ['globalVariable', 'baseLocale'],
    }),
    svelte(),
  ],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
      $lib: fileURLToPath(new URL('./src/lib', import.meta.url)),
    },
  },
  optimizeDeps: {
    exclude: ['@siku/ui'],
  },
  server: {
    watch: {
      ignored: ['!**/node_modules/@siku/ui/**'],
    },
    headers: {
      'Cache-Control': 'no-cache',
    },
  },
  build: {
    outDir: 'dist',
    emptyOutDir: true,
    target: 'chrome103',
    cssTarget: 'chrome103',
    assetsInlineLimit: 0,
  },
  test: {
    environment: 'jsdom',
    include: ['src/**/*.{test,spec}.ts'],
  },
})
