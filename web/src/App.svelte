<script lang="ts">
  import { onMount } from 'svelte'
  import type { Component } from 'svelte'
  import { applyTranslations } from '@/lib/i18n.svelte'
  import { locale } from '@/lib/locale.svelte'
  import { RESOURCE, sendNuiCallback } from '@/lib/nui'
  import { store } from '@/lib/studio/store.svelte'
  import SetupView from '@/views/SetupView.svelte'

  interface LocalePayload {
    language?: string
    translations?: { web?: Record<string, string> }
  }

  interface ReadyResponse {
    locale?: LocalePayload
  }

  interface NuiMessage {
    action?: string
    locale?: LocalePayload
  }

  let Shell = $state<Component | null>(null)

  /** The game's language, and the strings it carries when it sends them. */
  const applyLocale = (payload?: LocalePayload): void => {
    if (!payload?.language) {
      return
    }

    const web = payload.translations?.web

    if (web && typeof web === 'object') {
      applyTranslations(payload.language, web)
    } else {
      locale.set(payload.language)
    }
  }

  const handleMessage = (event: MessageEvent<NuiMessage>): void => {
    const data = event.data

    if (data?.action === `${RESOURCE}:nui:setLocale`) {
      applyLocale(data.locale)
      return
    }

    store.applyMessage(data)
  }

  onMount(() => {
    window.addEventListener('message', handleMessage)

    void sendNuiCallback<ReadyResponse>('ready').then((answer) => {
      if (answer) {
        applyLocale(answer.locale)
      }
    })

    if (import.meta.env.DEV) {
      void Promise.all([
        import('@/lib/studio/mock'),
        import('@/views/BoilerplateView.svelte'),
      ]).then(([mock, module]) => {
        mock.loadMocks()
        Shell = module.default
      })
    }

    return () => window.removeEventListener('message', handleMessage)
  })
</script>

{#key locale.current}
  {#if Shell}
    <Shell />
  {:else if store.open}
    <SetupView />
  {/if}
{/key}
