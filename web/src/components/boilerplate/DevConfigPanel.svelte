<script lang="ts">
  import { Button, Modal, Segmented, Tooltip } from '@siku/ui'
  import { locale } from '@/lib/locale.svelte'
  import { loadMocks } from '@/lib/studio/mock'
  import { store } from '@/lib/studio/store.svelte'

  let open = $state(false)

  const languages = $derived(
    locale.all.map((language) => ({ value: language, label: language.toUpperCase() })),
  )
</script>

<Tooltip text="Simulation">
  <Button
    variant="secondary"
    iconOnly
    icon="settings"
    label="Simulation"
    class="rounded-full"
    onclick={() => (open = true)}
  />
</Tooltip>

<Modal bind:open title="Simulation">
  <div class="flex flex-col gap-5">
    <p class="t-body-sm text-fg-tertiary">
      What the game would send. Nothing here reaches the server.
    </p>

    <div class="sk-field">
      <span class="sk-field__label">Framing tool</span>
      <div class="flex gap-2">
        <Button variant="secondary" size="sm" icon="refresh" onclick={loadMocks}>
          Reload the mock
        </Button>
        <Button
          variant="ghost"
          size="sm"
          icon="code"
          onclick={() =>
            store.applyMessage({
              action: 'siku_studio:nui:setup.saved',
              snippet: 'component_11 = { anchor = vector3(0.000, 2.000, 0.650), fov = 35.0 },',
            })}
        >
          Show a result
        </Button>
      </div>
    </div>

    <div class="sk-field">
      <span class="sk-field__label">Language</span>
      <Segmented
        label="Language"
        block
        value={locale.current}
        options={languages}
        onchange={(value) => locale.set(value)}
      />
    </div>
  </div>

  {#snippet actions()}
    <Button variant="primary" data-autofocus onclick={() => (open = false)}>Done</Button>
  {/snippet}
</Modal>
