<script lang="ts">
  import { Divider, Switch } from '@siku/ui'
  import { m } from '@/lib/i18n.svelte'
  import { store } from '@/lib/studio/store.svelte'

  const components = $derived(store.parts.filter((part) => part.kind === 'component'))
  const props = $derived(store.parts.filter((part) => part.kind === 'prop'))
</script>

<section class="flex flex-col gap-3">
  <Divider label={m.setup_section_body()} />
  <p class="t-caption text-fg-tertiary">{m.setup_body_help()}</p>
  <div class="flex flex-col gap-2">
    {#each components as part (part.index)}
      <Switch
        label={part.label}
        description={part.worn ? undefined : m.setup_part_bare()}
        checked={part.visible}
        onchange={(value) => store.togglePart(part, value)}
      />
    {/each}
  </div>
  <Divider />
  <div class="flex flex-col gap-2">
    {#each props as part (part.index)}
      <Switch
        label={part.label}
        description={part.worn ? undefined : m.setup_part_none()}
        disabled={!part.worn}
        checked={part.visible && part.worn}
        onchange={(value) => store.togglePart(part, value)}
      />
    {/each}
  </div>
</section>
