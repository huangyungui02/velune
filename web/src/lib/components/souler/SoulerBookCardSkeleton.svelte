<script lang="ts">
	import { Skeleton } from '$lib/components/ui/skeleton/index.js';
	import { cn } from '$lib/utils';

	let {
		class: className,
		showSubtitle = false
	}: {
		class?: string;
		showSubtitle?: boolean;
	} = $props();
</script>

<div class={cn('block', className)} aria-hidden="true">
	<Skeleton class="aspect-[3/4] w-full rounded-2xl" />
	<div class="space-y-2 px-1 pt-4 pb-2.5">
		<Skeleton class="mx-auto h-5 w-4/5 rounded-full" />
		{#if showSubtitle}
			<Skeleton class="mx-auto h-3.5 w-2/3 rounded-full" />
		{/if}
	</div>
</div>
