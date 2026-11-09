<script lang="ts">
  import {
    Button,
    ButtonGroup,
    Code,
    CodeBlock,
    Divider,
    Hint,
    Notice,
    Segmented,
    Select,
    Stepper,
    Surface,
    Switch,
    type IconName,
  } from '@siku/ui'
  import { setup, type Axes, type StepSize } from '@/lib/setup.svelte'

  const AXES: {
    axis: keyof Axes
    key: string
    minus: string
    plus: string
    icons: [IconName, IconName]
  }[] = [
    {
      axis: 'x',
      key: 'setup_axis_x',
      minus: 'ArrowLeft',
      plus: 'ArrowRight',
      icons: ['chevl', 'chev'],
    },
    {
      axis: 'z',
      key: 'setup_axis_z',
      minus: 'ArrowDown',
      plus: 'ArrowUp',
      icons: ['arrow-down', 'arrow-up'],
    },
    { axis: 'y', key: 'setup_axis_y', minus: 'PageDown', plus: 'PageUp', icons: ['minus', 'plus'] },
    {
      axis: 'fov',
      key: 'setup_axis_fov',
      minus: 'NumpadAdd',
      plus: 'NumpadSubtract',
      icons: ['expand', 'collapse'],
    },
  ]

  const pressed: Record<string, boolean> = {}
  let last = ''

  const t = (key: string, values?: Record<string, string | number>) => setup.t(key, values)

  const targetOptions = $derived(
    setup.targets.map((target) => ({ value: target.id, label: target.label, detail: target.id })),
  )
  const stepOptions = $derived(
    (['fine', 'normal', 'large'] as StepSize[]).map((value) => ({
      value,
      label: t(`setup_step_${value}`),
    })),
  )
  const count = $derived(setup.current?.count ?? 0)
  const readout = $derived(
    `x ${setup.camera.x.toFixed(2)}  y ${setup.camera.y.toFixed(2)}  z ${setup.camera.z.toFixed(2)}  fov ${setup.camera.fov.toFixed(1)}`,
  )
  const components = $derived(setup.parts.filter((part) => part.kind === 'component'))
  const props = $derived(setup.parts.filter((part) => part.kind === 'prop'))

  function axes(): Axes {
    const value: Axes = { x: 0, y: 0, z: 0, fov: 0 }

    for (const entry of AXES) {
      value[entry.axis] = (pressed[entry.plus] ? 1 : 0) - (pressed[entry.minus] ? 1 : 0)
    }

    return value
  }

  function sync(): void {
    const value = axes()
    const signature = `${value.x}${value.y}${value.z}${value.fov}`

    if (signature !== last) {
      last = signature
      setup.input(value)
    }
  }

  function tracked(code: string): boolean {
    return AXES.some((entry) => entry.minus === code || entry.plus === code)
  }

  function onkeydown(event: KeyboardEvent): void {
    if (event.key === 'Escape') {
      event.preventDefault()
      setup.close()
      return
    }

    if (!tracked(event.code)) {
      return
    }

    event.preventDefault()

    if (!pressed[event.code]) {
      pressed[event.code] = true
      sync()
    }
  }

  function onkeyup(event: KeyboardEvent): void {
    if (!tracked(event.code)) {
      return
    }

    pressed[event.code] = false
    sync()
  }

  function onblur(): void {
    for (const code of Object.keys(pressed)) {
      pressed[code] = false
    }

    sync()
  }

  function onwheel(event: WheelEvent): void {
    if ((event.target as HTMLElement | null)?.closest('.studio-scroll')) {
      return
    }

    setup.nudge('fov', event.deltaY > 0 ? 1 : -1)
  }
</script>

<svelte:window {onkeydown} {onkeyup} {onblur} {onwheel} />

<div class="pointer-events-none fixed inset-0">
  <Surface
    level="raised"
    padding="none"
    elevated
    class="studio-shell pointer-events-auto absolute left-12 top-1/2 flex w-[27rem] -translate-y-1/2 flex-col overflow-hidden"
  >
    <header class="flex items-start justify-between gap-4 px-6 pt-5">
      <div class="flex min-w-0 flex-col gap-1">
        <span class="t-caption text-fg-tertiary">{t('setup_kicker')}</span>
        <h1 class="t-heading text-fg-primary">{t('setup_title')}</h1>
        <span class="t-body-sm text-fg-secondary">{t('setup_model', { model: setup.model })}</span>
      </div>
      <Button
        variant="quiet"
        size="sm"
        iconOnly
        icon="close"
        label={t('setup_close')}
        onclick={() => setup.close()}
      />
    </header>

    <div class="studio-scroll flex min-h-0 flex-1 flex-col gap-5 overflow-y-auto px-6 py-5">
      <section class="flex flex-col gap-3">
        <Divider label={t('setup_section_target')} />
        <Select
          label={t('setup_target')}
          value={setup.target}
          options={targetOptions}
          onchange={(value) => setup.pick(value)}
        />
        <Stepper
          label={t('setup_preview', { count })}
          value={setup.index}
          min={0}
          max={Math.max(0, count - 1)}
          onchange={(value) => setup.setIndex(value)}
        />
      </section>

      <section class="flex flex-col gap-3">
        <Divider label={t('setup_section_camera')} />
        <Segmented
          label={t('setup_step')}
          value={setup.step}
          options={stepOptions}
          block
          onchange={(value) => setup.setStep(value as StepSize)}
        />
        <div class="flex flex-col gap-2">
          {#each AXES as entry (entry.axis)}
            <div class="studio-axis grid items-center gap-2">
              <span class="t-body-sm text-fg-secondary">{t(entry.key)}</span>
              <Button
                variant="ghost"
                size="sm"
                iconOnly
                icon={entry.icons[0]}
                label={t(`${entry.key}_minus`)}
                onclick={() => setup.nudge(entry.axis, -1)}
              />
              <Button
                variant="ghost"
                size="sm"
                iconOnly
                icon={entry.icons[1]}
                label={t(`${entry.key}_plus`)}
                onclick={() => setup.nudge(entry.axis, 1)}
              />
            </div>
          {/each}
        </div>
        <div class="flex items-center justify-between gap-3">
          <Code text={readout} />
          <Button variant="ghost" size="sm" icon="refresh" onclick={() => setup.reset()}
            >{t('setup_reset')}</Button
          >
        </div>
        <div class="flex flex-wrap gap-x-4 gap-y-1">
          <Hint keys={['←', '→']} label={t('setup_axis_x')} />
          <Hint keys={['↑', '↓']} label={t('setup_axis_z')} />
          <Hint keys={['⇞', '⇟']} label={t('setup_axis_y')} />
          <Hint keys={['−', '+']} label={t('setup_axis_fov')} />
        </div>
      </section>

      <section class="flex flex-col gap-3">
        <Divider label={t('setup_section_body')} />
        <p class="t-caption text-fg-tertiary">{t('setup_body_help')}</p>
        <div class="flex flex-col gap-2">
          {#each components as part (part.index)}
            <Switch
              label={part.label}
              description={part.worn ? undefined : t('setup_part_bare')}
              checked={part.visible}
              onchange={(value) => setup.togglePart(part, value)}
            />
          {/each}
        </div>
        <Divider />
        <div class="flex flex-col gap-2">
          {#each props as part (part.index)}
            <Switch
              label={part.label}
              description={part.worn ? undefined : t('setup_part_none')}
              disabled={!part.worn}
              checked={part.visible && part.worn}
              onchange={(value) => setup.togglePart(part, value)}
            />
          {/each}
        </div>
      </section>

      {#if setup.snippet}
        <section class="flex flex-col gap-3">
          <Divider label={t('setup_section_result')} />
          <Notice tone="success" text={t('setup_saved')} />
          <CodeBlock
            code={setup.snippet}
            language="lua"
            copy
            copyLabel={t('setup_copy')}
            copiedLabel={t('setup_copied')}
          />
        </section>
      {/if}
    </div>

    <footer class="border-t border-border-subtle px-6 py-4">
      <ButtonGroup align="between">
        <Button variant="quiet" key="Échap" onclick={() => setup.close()}>{t('setup_close')}</Button
        >
        <Button variant="primary" icon="code" onclick={() => setup.save()}>{t('setup_save')}</Button
        >
      </ButtonGroup>
    </footer>
  </Surface>
</div>
