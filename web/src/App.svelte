<script lang="ts">
  import { onMount } from 'svelte'
  import { setup } from '@/lib/setup.svelte'
  import SetupView from '@/views/SetupView.svelte'

  onMount(() => {
    const handle = (event: MessageEvent): void => setup.applyMessage(event.data)

    window.addEventListener('message', handle)

    return () => window.removeEventListener('message', handle)
  })
</script>

{#if setup.open}
  <SetupView />
{/if}
