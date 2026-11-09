import '@siku/ui/styles.css'
import './app.css'
import { mount } from 'svelte'
import { initSiku } from '@siku/ui'
import App from './App.svelte'
import { startCapture } from './capture/studio.js'

initSiku()
startCapture()

const app = mount(App, {
  target: document.getElementById('app')!,
})

export default app
