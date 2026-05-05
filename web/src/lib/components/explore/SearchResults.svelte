<script lang="ts">
	import { X } from '@lucide/svelte';
	import { Button } from '$lib/components/ui/button/index.js';
	import { Skeleton } from '$lib/components/ui/skeleton/index.js';
	import SoulerBookCard from '$lib/components/souler/SoulerBookCard.svelte';
	import SoulerBookCardSkeleton from '$lib/components/souler/SoulerBookCardSkeleton.svelte';
	import type { ExploreSoulerItem } from '$lib/types';

	let {
		query,
		items,
		loading,
		error,
		onClear
	}: {
		query: string;
		items: ExploreSoulerItem[];
		loading: boolean;
		error: string;
		onClear: () => void;
	} = $props();

	const skeletonItems = Array.from({ length: 12 }, (_, index) => `search-${index}`);
</script>

<div class="space-y-5">
	<div class="flex items-center justify-between gap-3 px-1">
		<div class="min-w-0">
			<p class="text-sm text-muted-foreground/75">搜索</p>
			<h2 class="truncate font-serif text-xl leading-tight text-primary md:text-2xl">{query}</h2>
		</div>
		<Button type="button" variant="ghost" size="icon" class="rounded-full" onclick={onClear}>
			<X class="size-4" />
			<span class="sr-only">清除搜索</span>
		</Button>
	</div>

	{#if items.length > 0}
		<div class="grid grid-cols-3 gap-x-3 gap-y-6 sm:gap-x-4 sm:gap-y-8 lg:grid-cols-4">
			{#each items as souler (souler.id)}
				<SoulerBookCard
					class="mx-auto w-full max-w-[7.25rem] sm:max-w-[8.75rem] lg:max-w-[11.5rem]"
					href={`/explore/${souler.id}`}
					name={souler.name}
					imageUrl={souler.imageUrl}
				/>
			{/each}
		</div>
		{#if error}
			<p class="text-sm text-destructive/90">{error}</p>
		{/if}
	{:else if loading}
		<div class="space-y-7" aria-label="正在搜索">
			<div class="grid grid-cols-3 gap-x-3 gap-y-6 sm:gap-x-4 sm:gap-y-8 lg:grid-cols-4">
				{#each skeletonItems as item (item)}
					<SoulerBookCardSkeleton
						class="mx-auto w-full max-w-[7.25rem] sm:max-w-[8.75rem] lg:max-w-[11.5rem]"
					/>
				{/each}
			</div>
			<Skeleton class="h-4 w-36 rounded-full" />
		</div>
	{:else if error}
		<p class="text-sm text-destructive/90">{error}</p>
	{:else}
		<div class="px-2 py-8 text-sm text-muted-foreground/70">没有找到匹配的人物。</div>
	{/if}
</div>
