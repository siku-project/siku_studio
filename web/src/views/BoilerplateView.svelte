<script lang="ts">
  import type { Component } from 'svelte'
  import backgroundUrl from '@/assets/boilerplate-background.jpg'
  import DevConfigPanel from '@/components/boilerplate/DevConfigPanel.svelte'
  import DevFab from '@/components/boilerplate/DevFab.svelte'
  import DevTopBar from '@/components/boilerplate/DevTopBar.svelte'
  import DevViewSelector from '@/components/boilerplate/DevViewSelector.svelte'
  import SetupView from '@/views/SetupView.svelte'

  const NONE = 'none'
  const STORAGE_KEY = 'siku_studio:dev:view'

  /** Every interface of the resource, by the name the selector shows. */
  const views: Record<string, Component> = {
    Setup: SetupView,
  }

  /** The view asked for in the URL wins, then the last one picked, then none. */
  const initialView = (): string => {
    const fromUrl = new URLSearchParams(window.location.search).get('view')
    const fromStorage = window.localStorage.getItem(STORAGE_KEY)
    const wanted = fromUrl ?? fromStorage ?? NONE

    return wanted in views ? wanted : NONE
  }

  let currentView = $state(initialView())

  const Active = $derived(currentView === NONE ? null : (views[currentView] ?? null))

  const select = (view: string): void => {
    currentView = view
    window.localStorage.setItem(STORAGE_KEY, view)
  }
</script>

<div
  class="fixed inset-0 bg-bg-void bg-cover bg-center bg-no-repeat"
  style:background-image="url({backgroundUrl})"
>
  {#if Active}
    <Active />
  {/if}

  <DevTopBar />
  <DevFab {currentView} />

  <div class="fixed bottom-8 left-8 z-overlay flex items-center gap-3">
    <DevViewSelector views={Object.keys(views)} {currentView} onSelect={select} />
    <DevConfigPanel />
  </div>
</div>
