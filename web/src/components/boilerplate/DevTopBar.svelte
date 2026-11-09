<script lang="ts">
  import { Badge, Button, Divider, Surface } from '@siku/ui'
  import { locale } from '@/lib/locale.svelte'
  import { RESOURCE } from '@/lib/nui'

  const isDev = import.meta.env.DEV
</script>

<div class="fixed left-1/2 top-8 z-overlay -translate-x-1/2">
  <Surface elevated padding="none" radius="lg" class="flex h-control-lg items-center gap-5 px-6">
    <span class="t-caption uppercase tracking-wider text-fg-secondary">{RESOURCE}</span>

    <div class="flex h-4"><Divider vertical /></div>

    <span class="t-caption text-fg-tertiary">Svelte 5</span>

    <div class="flex h-4"><Divider vertical /></div>

    <Badge tone={isDev ? 'live' : 'neutral'} label={isDev ? 'Dev' : 'Prod'} />

    <div class="flex h-4"><Divider vertical /></div>

    <Button variant="quiet" size="sm" icon="globe" onclick={() => locale.cycle()}>
      {locale.current.toUpperCase()}
    </Button>
  </Surface>
</div>
