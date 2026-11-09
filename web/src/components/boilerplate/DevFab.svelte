<script lang="ts">
  import { Button, Divider, Surface } from '@siku/ui'
  import { RESOURCE } from '@/lib/nui'
  import { stack } from '@/lib/stack'

  let { currentView }: { currentView: string } = $props()

  let expanded = $state(false)
</script>

<div
  class="fixed right-8 top-8 z-overlay"
  role="presentation"
  onmouseenter={() => (expanded = true)}
  onmouseleave={() => (expanded = false)}
>
  {#if expanded}
    <Surface elevated padding="md" radius="lg" class="flex w-[16rem] flex-col gap-4">
      <span class="t-caption text-center uppercase tracking-wider text-fg-secondary">
        {RESOURCE}
      </span>

      <Divider />

      <div class="flex flex-col gap-2">
        {#each stack as entry (entry.name)}
          <div class="flex items-center justify-between gap-4">
            <span class="t-caption text-fg-tertiary">{entry.name}</span>
            <span class="t-code text-fg-secondary">{entry.version}</span>
          </div>
        {/each}
      </div>

      <Divider />

      <div class="flex items-center justify-between gap-4">
        <span class="t-caption text-fg-tertiary">View</span>
        <span class="t-caption {currentView !== 'none' ? 'text-fg-primary' : 'text-fg-disabled'}">
          {currentView !== 'none' ? currentView : 'None'}
        </span>
      </div>
    </Surface>
  {:else}
    <Button
      variant="secondary"
      iconOnly
      icon="code"
      label="Stack"
      class="rounded-full"
      onclick={() => (expanded = true)}
    />
  {/if}
</div>
