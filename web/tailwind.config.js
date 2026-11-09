import siku from '@siku/ui/tailwind-preset'

/** @type {import('tailwindcss').Config} */
export default {
  presets: [siku],
  content: ['./index.html', './src/**/*.{svelte,ts}'],
  corePlugins: { preflight: false },
}
