<script lang="ts">
	import { invalidateAll } from '$app/navigation';
	import { base } from '$app/paths';
	import RotateCw from '@lucide/svelte/icons/rotate-cw';
	import { Button } from '$lib/components/ui/button/index.js';
	import { Separator } from '$lib/components/ui/separator/index.js';
	import SoulerBookCard from '$lib/components/souler/SoulerBookCard.svelte';
	import type { BookshelfItem } from '$lib/types';
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();
	let refreshing = $state(false);

	function getMobileBookshelfHref(item: BookshelfItem) {
		if (!item.lastSessionId || !item.lastChapterId) {
			return `/bookshelf/${item.soulerId}`;
		}
		const query = new URLSearchParams({ session: item.lastSessionId });
		return `/bookshelf/${item.soulerId}/chapter/${item.lastChapterId}?${query.toString()}`;
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
		<div class="space-y-3 md:hidden">
				{#each data.bookshelf as item (item.id)}
					<a
						href={`${base}${getMobileBookshelfHref(item)}`}
						class="group flex items-start gap-4 rounded-2xl px-2 py-2 transition hover:bg-primary/5"
					>
					<div
						class="relative h-[7.5rem] w-[5.625rem] shrink-0 overflow-hidden rounded-xl bg-muted/20"
					>
						{#if item.imageUrl}
							<img
								src={item.imageUrl}
								alt={item.soulerName}
								class="h-full w-full object-cover transition duration-500 group-hover:scale-[1.02]"
							/>
						{:else}
							<div class="grid h-full place-items-center text-xs text-muted-foreground/60">
								无图
							</div>
						{/if}
					</div>
					<div class="min-w-0 flex-1 py-1">
						<h2 class="truncate font-serif text-xl leading-7 text-foreground transition group-hover:text-primary">
							{item.soulerName}
						</h2>
						<p class="mt-8 truncate text-sm leading-6 text-muted-foreground/80">
							章节 · {item.lastSessionTitle || '点击开始阅读章节'}
						</p>
					</div>
				</a>
			{/each}
		</div>

		<div class="hidden gap-x-6 gap-y-9 md:grid md:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-4">
			{#each data.bookshelf as item (item.id)}
				<SoulerBookCard
					href={`/bookshelf/${item.soulerId}`}
					name={item.soulerName}
					imageUrl={item.imageUrl}
					subtitle={item.lastSessionTitle}
					fallbackSubtitle="点击开始阅读章节"
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
