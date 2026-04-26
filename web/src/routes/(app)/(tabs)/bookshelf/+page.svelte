<script lang="ts">
	import { invalidateAll } from '$app/navigation';
	import { resolve } from '$app/paths';
	import RotateCw from '@lucide/svelte/icons/rotate-cw';
	import { Button } from '$lib/components/ui/button/index.js';
	import { Separator } from '$lib/components/ui/separator/index.js';
	import SoulerBookCard from '$lib/components/souler/SoulerBookCard.svelte';
	import type { BookshelfItem } from '$lib/types';
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();
	let refreshing = $state(false);

	function getBookshelfHref(item: BookshelfItem) {
		if (item.lastSessionId && item.lastChapterId) {
			return `${resolve(`/bookshelf/${item.soulerId}/chapter/${item.lastChapterId}`)}?${new URLSearchParams({
				session: item.lastSessionId
			}).toString()}`;
		}
		return resolve(`/bookshelf/${item.soulerId}`);
	}

	async function refreshBookshelf() {
		if (refreshing) {
			return;
		}
		refreshing = true;
		try {
			await invalidateAll();
		} finally {
			refreshing = false;
		}
	}
</script>

<svelte:head>
	<title>Velune · 书架</title>
</svelte:head>

<section class="space-y-8">
	<header class="space-y-2">
		<div class="flex items-center justify-between gap-3">
			<h1 class="text-2xl leading-tight text-primary">书架</h1>
			<Button
				type="button"
				variant="ghost"
				size="icon-sm"
				class="size-9 rounded-full text-muted-foreground/80 hover:text-primary"
				onclick={refreshBookshelf}
				disabled={refreshing}
				aria-label="刷新书架"
			>
				<RotateCw class={refreshing ? 'size-4 animate-spin' : 'size-4'} />
			</Button>
		</div>
		<Separator class="mt-3" />
	</header>

	{#if data.bookshelf?.length}
		<div class="grid grid-cols-3 gap-x-3 gap-y-6 sm:gap-x-4 sm:gap-y-8 md:hidden">
			{#each data.bookshelf as item (item.id)}
				<SoulerBookCard
					class="mx-auto w-full max-w-[7.25rem] sm:max-w-[8.75rem]"
					href={getBookshelfHref(item)}
					name={item.soulerName}
					imageUrl={item.imageUrl}
				/>
			{/each}
		</div>

		<div class="hidden gap-x-6 gap-y-9 md:grid md:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-4">
			{#each data.bookshelf as item (item.id)}
				<SoulerBookCard
					href={getBookshelfHref(item)}
					name={item.soulerName}
					imageUrl={item.imageUrl}
					subtitle={item.lastSessionTitle}
					fallbackSubtitle="点击开始阅读"
				/>
			{/each}
		</div>
	{:else}
		<div
			class="grid min-h-[calc(100svh-14rem)] place-items-center px-2 text-sm text-muted-foreground/70 md:min-h-0 md:place-items-start md:py-8"
		>
			书架为空
		</div>
	{/if}
</section>
