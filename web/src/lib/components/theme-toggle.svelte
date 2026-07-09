<script lang="ts">
  import { Button } from '$lib/components/ui/button';
  import * as Tooltip from '$lib/components/ui/tooltip';
  import Moon from '@lucide/svelte/icons/moon';
  import Sun from '@lucide/svelte/icons/sun';
  import { mode, toggleMode } from 'mode-watcher';

  const label = $derived(mode.current === 'dark' ? '切换到日间模式' : '切换到夜间模式');
</script>

<Tooltip.Provider>
  <Tooltip.Root>
    <Tooltip.Trigger>
      {#snippet child({ props })}
        <Button
          {...props}
          variant="outline"
          size="icon-sm"
          class="rounded-full bg-background/70 backdrop-blur"
          aria-label={label}
          title={label}
          onclick={toggleMode}
        >
          {#if mode.current === 'dark'}
            <Sun />
          {:else}
            <Moon />
          {/if}
        </Button>
      {/snippet}
    </Tooltip.Trigger>
    <Tooltip.Content sideOffset={8}>{label}</Tooltip.Content>
  </Tooltip.Root>
</Tooltip.Provider>
