<script lang="ts">
  import { Button, ButtonGroup, Surface } from '@siku/ui'
  import BodySection from '@/components/setup/BodySection.svelte'
  import CameraSection from '@/components/setup/CameraSection.svelte'
  import ResultSection from '@/components/setup/ResultSection.svelte'
  import TargetSection from '@/components/setup/TargetSection.svelte'
  import { m } from '@/lib/i18n.svelte'
  import { attachCameraKeys } from '@/lib/studio/keys'
  import { store } from '@/lib/studio/store.svelte'

  const keys = attachCameraKeys(store)
</script>

<svelte:window
  onkeydown={keys.onkeydown}
  onkeyup={keys.onkeyup}
  onblur={keys.onblur}
  onwheel={keys.onwheel}
/>

<div class="pointer-events-none fixed inset-0">
  <Surface
    level="raised"
    padding="none"
    elevated
    class="studio-shell pointer-events-auto absolute left-12 top-1/2 flex w-[27rem] -translate-y-1/2 flex-col overflow-hidden"
  >
    <header class="flex items-start justify-between gap-4 px-6 pt-5">
      <div class="flex min-w-0 flex-col gap-1">
        <span class="t-caption text-fg-tertiary">{m.setup_kicker()}</span>
        <h1 class="t-heading text-fg-primary">{m.setup_title()}</h1>
        <span class="t-body-sm text-fg-secondary">{m.setup_model({ model: store.model })}</span>
      </div>
      <Button
        variant="quiet"
        size="sm"
        iconOnly
        icon="close"
        label={m.setup_close()}
        onclick={() => store.close()}
      />
    </header>

    <div class="studio-scroll flex min-h-0 flex-1 flex-col gap-5 overflow-y-auto px-6 py-5">
      <TargetSection />
      <CameraSection />
      <BodySection />
      <ResultSection />
    </div>

    <footer class="border-t border-border-subtle px-6 py-4">
      <ButtonGroup align="between">
        <Button variant="quiet" key="Échap" onclick={() => store.close()}>{m.setup_close()}</Button>
        <Button variant="primary" icon="code" onclick={() => store.save()}>{m.setup_save()}</Button>
      </ButtonGroup>
    </footer>
  </Surface>
</div>
