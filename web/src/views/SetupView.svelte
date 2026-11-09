<script lang="ts">
  import { Button, ButtonGroup, Segmented, Surface } from '@siku/ui'
  import BodySection from '@/components/setup/BodySection.svelte'
  import CameraSection from '@/components/setup/CameraSection.svelte'
  import ResultSection from '@/components/setup/ResultSection.svelte'
  import TargetSection from '@/components/setup/TargetSection.svelte'
  import { m, tr, type MessageKey } from '@/lib/i18n.svelte'
  import { attachCameraKeys } from '@/lib/studio/keys'
  import { store } from '@/lib/studio/store.svelte'

  const keys = attachCameraKeys(store)

  const modelLabel = (model: string): string => {
    const key = `setup_model_${model}` as MessageKey

    return key in m ? tr(key) : model
  }

  const modelOptions = $derived(store.models.map((value) => ({ value, label: modelLabel(value) })))
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
    class="pointer-events-auto absolute bottom-10 left-12 top-10 flex w-[27rem] min-h-0 flex-col overflow-clip"
  >
    <header class="flex flex-none flex-col gap-4 border-b border-border-subtle px-6 pb-5 pt-5">
      <div class="flex items-start justify-between gap-4">
        <div class="flex min-w-0 flex-col gap-1">
          <span class="t-caption text-fg-tertiary">{m.setup_kicker()}</span>
          <h1 class="t-heading text-fg-primary">{m.setup_title()}</h1>
        </div>
        <Button
          variant="quiet"
          size="sm"
          iconOnly
          icon="close"
          label={m.setup_close()}
          onclick={() => store.close()}
        />
      </div>
      <Segmented
        label={m.setup_model()}
        value={store.model}
        options={modelOptions}
        block
        onchange={(value) => store.pickModel(value)}
      />
      <TargetSection />
    </header>

    <div class="studio-scroll flex min-h-0 flex-1 flex-col gap-5 overflow-y-auto px-6 py-5">
      <CameraSection />
      <BodySection />
      <ResultSection />
    </div>

    <footer class="flex-none border-t border-border-subtle px-6 py-4">
      <ButtonGroup align="between">
        <Button variant="quiet" key="Échap" onclick={() => store.close()}>{m.setup_close()}</Button>
        <Button variant="primary" icon="code" onclick={() => store.save()}>{m.setup_save()}</Button>
      </ButtonGroup>
    </footer>
  </Surface>
</div>
