<script lang="ts">
	import { browser } from '$app/environment';
	import { resolve } from '$app/paths';
	import { onMount } from 'svelte';
	import RotateCw from '@lucide/svelte/icons/rotate-cw';
	import { Button } from '$lib/components/ui/button/index.js';
	import { Separator } from '$lib/components/ui/separator/index.js';
	import SoulerBookCard from '$lib/components/souler/SoulerBookCard.svelte';
	import SoulerBookCardSkeleton from '$lib/components/souler/SoulerBookCardSkeleton.svelte';
	import {
		hasPendingBookshelfRefresh,
		listenForBookshelfRefresh,
		readBookshelfViewState,
		writeBookshelfViewState
	} from '$lib/stores/bookshelf-view-state';
	import type { BookshelfItem } from '$lib/types';

	const cachedBookshelf = browser
		? readBookshelfViewState()
		: { items: null, refreshToken: 0, dataToken: 0 };
	let bookshelf = $state.raw<BookshelfItem[]>(cachedBookshelf.items ?? []);
	let loading = $state(!cachedBookshelf.items);
	let refreshing = $state(false);
	let error = $state('');

	const mobileSkeletonItems = Array.from({ length: 9 }, (_, index) => `mobile-${index}`);
	const desktopSkeletonItems = Array.from({ length: 8 }, (_, index) => `desktop-${index}`);

	function getBookshelfHref(item: BookshelfItem) {
		return resolve(`/bookshelf/${item.soulerId}`);
	}

	async function loadBookshelf({ refresh = false }: { refresh?: boolean } = {}) {
		if (refreshing) {
			return;
		}
		refreshing = refresh;
		loading = !refresh && bookshelf.length === 0;
		error = '';
		try {
			const response = await fetch(`/api/bookshelf${refresh ? '?refresh=1' : ''}`);
			if (!response.ok) {
				throw new Error('加载失败');
			}
			const payload = (await response.json()) as { bookshelf?: BookshelfItem[] };
			bookshelf = Array.isArray(payload.bookshelf) ? payload.bookshelf : [];
			if (browser) {
				writeBookshelfViewState(bookshelf);
			}
		} catch (refreshError) {
			console.error(refreshError);
			error = refresh ? '书架刷新失败，请稍后重试。' : '书架加载失败，请稍后重试。';
		} finally {
			loading = false;
			refreshing = false;
		}
	}

	onMount(() => {
		const stopListeningForRefresh = listenForBookshelfRefresh(() => {
			void loadBookshelf({ refresh: true });
		});

		if (cachedBookshelf.items) {
			if (hasPendingBookshelfRefresh()) {
				void loadBookshelf({ refresh: true });
			}
			return stopListeningForRefresh;
		}

		void loadBookshelf();
		return stopListeningForRefresh;
	});
</script>

<svelte:head>
	<title>Velune Folio · 书架</title>
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
				disabled={refreshing}
				aria-label="刷新书架"
				onclick={() => void loadBookshelf({ refresh: true })}
			>
				<RotateCw class={refreshing ? 'size-4 animate-spin' : 'size-4'} />
			</Button>
		</div>
		<Separator class="mt-3" />
	</header>

	{#if bookshelf.length}
		<div class="grid grid-cols-3 gap-x-3 gap-y-6 sm:gap-x-4 sm:gap-y-8 md:hidden">
			{#each bookshelf as item (item.id)}
				<SoulerBookCard
					class="mx-auto w-full max-w-[7.25rem] sm:max-w-[8.75rem]"
					href={getBookshelfHref(item)}
					name={item.soulerName}
					imageUrl={item.imageUrl}
				/>
			{/each}
		</div>

		<div class="hidden gap-x-6 gap-y-9 md:grid md:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-4">
			{#each bookshelf as item (item.id)}
				<SoulerBookCard
					href={getBookshelfHref(item)}
					name={item.soulerName}
					imageUrl={item.imageUrl}
					subtitle={item.lastSessionTitle}
					fallbackSubtitle="点击开始阅读"
				/>
			{/each}
		</div>
		{#if error}
			<p class="text-sm text-destructive/90">{error}</p>
		{/if}
	{:else if loading}
		<div aria-label="正在加载书架">
			<div class="grid grid-cols-3 gap-x-3 gap-y-6 sm:gap-x-4 sm:gap-y-8 md:hidden">
				{#each mobileSkeletonItems as item (item)}
					<SoulerBookCardSkeleton class="mx-auto w-full max-w-[7.25rem] sm:max-w-[8.75rem]" />
				{/each}
			</div>

			<div class="hidden gap-x-6 gap-y-9 md:grid md:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-4">
				{#each desktopSkeletonItems as item (item)}
					<SoulerBookCardSkeleton showSubtitle />
				{/each}
			</div>
		</div>
	{:else}
		<div
			class="grid min-h-[calc(100svh-14rem)] place-items-center px-2 text-sm text-muted-foreground/70 md:min-h-0 md:place-items-start md:py-8"
		>
			{error || '书架为空'}
		</div>
	{/if}
</section>
