import { fileURLToPath, URL } from 'node:url'

import { svelte } from '@sveltejs/vite-plugin-svelte'
import { defineConfig } from 'vite'

export default defineConfig({
  base: './',
  plugins: [svelte()],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
      $lib: fileURLToPath(new URL('./src/lib', import.meta.url)),
    },
  },
  optimizeDeps: {
    exclude: ['@siku/ui'],
  },
  build: {
    outDir: 'dist',
    emptyOutDir: true,
    target: 'chrome103',
    cssTarget: 'chrome103',
    assetsInlineLimit: 0,
  },
})
