<script lang="ts">
  import { Button, Code, Divider, Hint, Segmented, Switch, type IconName } from '@siku/ui'
  import { m, tr } from '@/lib/i18n.svelte'
  import type { MessageKey } from '@/lib/i18n.svelte'
  import { store } from '@/lib/studio/store.svelte'
  import { STEP_SIZES, type Axis, type StepSize } from '@/lib/studio/types'

  interface AxisRow {
    axis: Axis
    key: MessageKey
    keys: [string, string]
    icons: [IconName, IconName]
  }

  const AXES: AxisRow[] = [
    { axis: 'x', key: 'setup_axis_x', keys: ['←', '→'], icons: ['chevl', 'chev'] },
    { axis: 'z', key: 'setup_axis_z', keys: ['↓', '↑'], icons: ['arrow-down', 'arrow-up'] },
    { axis: 'y', key: 'setup_axis_y', keys: ['⇟', '⇞'], icons: ['minus', 'plus'] },
    { axis: 'fov', key: 'setup_axis_fov', keys: ['+', '−'], icons: ['expand', 'collapse'] },
  ]

  const stepOptions = $derived(
    STEP_SIZES.map((value) => ({ value, label: tr(`setup_step_${value}` as MessageKey) })),
  )
  const readout = $derived(
    `x ${store.camera.x.toFixed(2)}  y ${store.camera.y.toFixed(2)}  z ${store.camera.z.toFixed(2)}  fov ${store.camera.fov.toFixed(1)}` +
      (store.fromBehind ? `  turn ${store.camera.turn.toFixed(0)}` : ''),
  )
</script>

<section class="flex flex-col gap-3">
  <Divider label={m.setup_section_camera()} />
  <Segmented
    label={m.setup_step()}
    value={store.step}
    options={stepOptions}
    block
    onchange={(value) => store.setStep(value as StepSize)}
  />
  <div class="flex flex-col gap-2">
    {#each AXES as row (row.axis)}
      <div class="studio-axis grid items-center gap-2">
        <span class="t-body-sm text-fg-secondary">{tr(row.key)}</span>
        <Button
          variant="ghost"
          size="sm"
          iconOnly
          icon={row.icons[0]}
          label={tr(`${row.key}_minus` as MessageKey)}
          onclick={() => store.nudge(row.axis, -1)}
        />
        <Button
          variant="ghost"
          size="sm"
          iconOnly
          icon={row.icons[1]}
          label={tr(`${row.key}_plus` as MessageKey)}
          onclick={() => store.nudge(row.axis, 1)}
        />
      </div>
    {/each}
  </div>
  <Switch
    label={m.setup_turn()}
    description={m.setup_turn_help()}
    checked={store.fromBehind}
    onchange={(value) => store.turn(value)}
  />
  <div class="flex items-center justify-between gap-3">
    <Code text={readout} />
    <Button variant="ghost" size="sm" icon="refresh" onclick={() => store.reset()}>
      {m.setup_reset()}
    </Button>
  </div>
  <div class="flex flex-wrap gap-x-4 gap-y-1">
    {#each AXES as row (row.axis)}
      <Hint keys={row.keys} label={tr(row.key)} />
    {/each}
  </div>
</section>
