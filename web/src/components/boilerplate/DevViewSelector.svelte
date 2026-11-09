<script lang="ts">
  import { Button, EmptyState, Modal, NavList, Tooltip } from '@siku/ui'

  let {
    views,
    currentView,
    onSelect,
  }: { views: string[]; currentView: string; onSelect: (view: string) => void } = $props()

  let open = $state(false)

  const items = $derived(
    views.map((view) => ({ value: view, label: view, icon: 'columns' as const })),
  )

  const choose = (view: string): void => {
    onSelect(view)
    open = false
  }
</script>

<Tooltip text="Interfaces">
  <Button
    variant="secondary"
    iconOnly
    icon="layers"
    label="Interfaces"
    class="rounded-full"
    onclick={() => (open = true)}
  />
</Tooltip>

<Modal bind:open title="Interfaces">
  {#if views.length > 0}
    <NavList value={currentView} {items} label="Interfaces" onchange={choose} />
  {:else}
    <EmptyState title="No interface yet"
      >Create a view and register it in BoilerplateView.</EmptyState
    >
  {/if}

  {#snippet actions()}
    {#if currentView !== 'none'}
      <Button variant="quiet" onclick={() => choose('none')}>Hide the interface</Button>
    {/if}
    <Button variant="primary" data-autofocus onclick={() => (open = false)}>Done</Button>
  {/snippet}
</Modal>
