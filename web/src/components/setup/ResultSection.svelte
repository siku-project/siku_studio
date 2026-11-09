<script lang="ts">
  import { CodeBlock, Divider, Notice } from '@siku/ui'
  import { m } from '@/lib/i18n.svelte'
  import { store } from '@/lib/studio/store.svelte'
</script>

{#if store.snippet}
  <section class="flex flex-col gap-3">
    <Divider label={m.setup_section_result()} />
    <Notice tone="success" text={m.setup_saved()} />
    <CodeBlock
      code={store.snippet}
      language="lua"
      copy
      copyLabel={m.setup_copy()}
      copiedLabel={m.setup_copied()}
    />
  </section>
{/if}
