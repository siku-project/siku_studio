<script lang="ts">
  import { Select, Stepper } from '@siku/ui'
  import { m } from '@/lib/i18n.svelte'
  import { store } from '@/lib/studio/store.svelte'

  const options = $derived(
    store.targets.map((target) => ({ value: target.id, label: target.label, detail: target.id })),
  )
  const count = $derived(store.current?.count ?? 0)
</script>

<section class="flex flex-col gap-3">
  <Select
    label={m.setup_target()}
    value={store.target}
    {options}
    onchange={(value) => store.pickTarget(value)}
  />
  <Stepper
    label={m.setup_preview({ count })}
    value={store.index}
    min={0}
    max={Math.max(0, count - 1)}
    onchange={(value) => store.showIndex(value)}
  />
</section>
