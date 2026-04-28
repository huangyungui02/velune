<script lang="ts">
	let {
		sessionId,
		options,
		isLoading,
		onSelect
	}: {
		sessionId: string | null;
		options: string[];
		isLoading: boolean;
		onSelect: (option: string) => void;
	} = $props();
</script>

{#if sessionId && options.length > 0}
	<div class="space-y-2 px-2 pt-0.5 md:px-4">
		<p class="px-1 text-[0.72rem] tracking-[0.18em] text-muted-foreground/70">可选回应</p>
		<div class="grid gap-2 sm:grid-cols-2">
			{#each options as option, optionIndex (`${option}-${optionIndex}`)}
				<button
					class="h-auto min-h-11 w-full rounded-2xl border border-primary/22 bg-primary/[0.065] px-4 py-2.5 text-left font-sans text-[0.96rem] leading-7 break-words whitespace-normal text-foreground/90 shadow-[0_1px_0_rgba(0,0,0,0.03)] transition-all hover:border-primary/42 hover:bg-primary/[0.11] hover:text-primary active:scale-[0.997]"
					onclick={() => onSelect(option)}
					disabled={isLoading}
				>
					{option}
				</button>
			{/each}
		</div>
	</div>
{/if}
