<script lang="ts">
	import { Button } from '$lib/components/ui/button/index.js';
	import SoulerBookCard from '$lib/components/souler/SoulerBookCard.svelte';
	import type { ExploreSoulerItem } from '$lib/types';

	let {
		items,
		page,
		hasNextPage,
		loading,
		error,
		onPage
	}: {
		items: ExploreSoulerItem[];
		page: number;
		hasNextPage: boolean;
		loading: boolean;
		error: string;
		onPage: (page: number) => void;
	} = $props();
</script>

{#if items.length > 0}
	<div class="grid grid-cols-3 gap-x-3 gap-y-6 sm:gap-x-4 sm:gap-y-8 lg:grid-cols-4">
		{#each items as souler (souler.id)}
			<SoulerBookCard
				class="mx-auto w-full max-w-[7.25rem] sm:max-w-[8.75rem] lg:max-w-[11.5rem]"
				href={`/bookshelf/${souler.id}`}
				name={souler.name}
				imageUrl={souler.imageUrl}
			/>
		{/each}
	</div>

	<div class="flex items-center justify-between border-t border-border/40 pt-2">
		<p class="text-xs text-muted-foreground/80">第 {page} 页 · 每页 20 人</p>
		<div class="flex items-center gap-2">
			<Button
				type="button"
				variant="outline"
				size="sm"
				class="rounded-xl"
				disabled={page <= 1 || loading}
				onclick={() => onPage(page - 1)}
			>
				上一页
			</Button>
			<Button
				type="button"
				variant="outline"
				size="sm"
				class="rounded-xl"
				disabled={!hasNextPage || loading}
				onclick={() => onPage(page + 1)}
			>
				下一页
			</Button>
		</div>
	</div>

	{#if error}
		<p class="text-sm text-destructive/90">{error}</p>
	{/if}
{:else if loading}
	<div class="px-2 py-8 text-sm text-muted-foreground/70">正在加载最新...</div>
{:else if error}
	<p class="text-sm text-destructive/90">{error}</p>
{:else}
	<div class="px-2 py-8 text-sm text-muted-foreground/70">还没有可发现的人物。</div>
{/if}
