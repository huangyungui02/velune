<script lang="ts">
	import { browser } from '$app/environment';
	import { page } from '$app/state';
	import { onMount } from 'svelte';
	import ChevronDown from '@lucide/svelte/icons/chevron-down';
	import LibraryBig from '@lucide/svelte/icons/library-big';
	import SoulerSidebarItem from '$lib/components/souler/SoulerSidebarItem.svelte';
	import { Button } from '$lib/components/ui/button/index.js';
	import { Skeleton } from '$lib/components/ui/skeleton/index.js';
	import {
		hasPendingBookshelfRefresh,
		listenForBookshelfRefresh,
		readBookshelfViewState,
		writeBookshelfViewState
	} from '$lib/stores/bookshelf-view-state';
	import { cn } from '$lib/utils';
	import type { BookshelfItem } from '$lib/types';

	const cachedBookshelf = browser
		? readBookshelfViewState()
		: { items: null, refreshToken: 0, dataToken: 0 };
	let expanded = $state(true);
	let items = $state.raw<BookshelfItem[] | null>(cachedBookshelf.items);
	let loading = $state(false);
	let refreshing = $state(false);
	let error = $state('');

	const rowSkeletons = ['row-a', 'row-b', 'row-c', 'row-d'];

	function isActive(href: string) {
		return page.url.pathname === href || page.url.pathname.startsWith(`${href}/`);
	}

	function getResonanceHref(item: BookshelfItem) {
		if (!item.lastSessionId || !item.lastChapterId) {
			return `/bookshelf/${item.soulerId}`;
		}
		const query = new URLSearchParams({ session: item.lastSessionId });
		return `/bookshelf/${item.soulerId}/chapter/${item.lastChapterId}?${query.toString()}`;
	}

	async function loadBookshelf(options: { refresh?: boolean } = {}) {
		if (loading || refreshing) {
			return;
		}
		if (!options.refresh && items) {
			return;
		}

		loading = !options.refresh;
		refreshing = Boolean(options.refresh);
		error = '';
		try {
			const response = await fetch(`/api/bookshelf${options.refresh ? '?refresh=1' : ''}`);
			if (!response.ok) {
				throw new Error('加载失败');
			}
			const payload = (await response.json()) as { bookshelf?: BookshelfItem[] };
			items = Array.isArray(payload.bookshelf) ? payload.bookshelf : [];
			writeBookshelfViewState(items);
		} catch (loadError) {
			console.error(loadError);
			error = '书架加载失败';
		} finally {
			loading = false;
			refreshing = false;
		}
	}

	onMount(() => {
		const media = window.matchMedia('(min-width: 1024px)');
		const loadIfVisible = () => {
			if (expanded && media.matches) {
				void loadBookshelf();
			}
		};
		const refreshIfVisible = () => {
			if (expanded && media.matches) {
				void loadBookshelf({ refresh: true });
			}
		};

		loadIfVisible();
		const stopListeningForRefresh = listenForBookshelfRefresh(refreshIfVisible);
		media.addEventListener('change', loadIfVisible);
		return () => {
			stopListeningForRefresh();
			media.removeEventListener('change', loadIfVisible);
		};
	});
</script>

<div class="space-y-2">
	<div class="flex items-center gap-1.5">
		<Button
			type="button"
			variant={isActive('/bookshelf') ? 'default' : 'ghost'}
			size="sm"
			class="h-10 flex-1 justify-start gap-2 rounded-xl px-3"
			aria-label="切换书架展开状态"
			aria-expanded={expanded}
			onclick={() => {
				expanded = !expanded;
				if (expanded) {
					void loadBookshelf({ refresh: hasPendingBookshelfRefresh() });
				}
			}}
		>
			<LibraryBig class="size-4" />
			<span>书架</span>
			<ChevronDown
				class={cn('ml-auto size-4 transition-transform duration-200', expanded ? 'rotate-180' : '')}
			/>
		</Button>
	</div>

	{#if expanded}
		<div class="grid gap-2 pt-1">
			{#if items?.length}
				{#each items as item (item.id)}
					<SoulerSidebarItem
						href={getResonanceHref(item)}
						name={item.soulerName}
						imageUrl={item.imageUrl}
						lastSessionTitle={item.lastSessionTitle}
						active={page.url.pathname.startsWith(`/bookshelf/${item.soulerId}`)}
					/>
				{/each}
			{:else if loading}
				<div class="grid gap-2 px-1 py-1" aria-label="正在加载书架">
					{#each rowSkeletons as row (row)}
						<div class="flex items-center gap-3 rounded-xl px-2 py-2">
							<Skeleton class="size-10 shrink-0 rounded-lg" />
							<div class="min-w-0 flex-1 space-y-2">
								<Skeleton class="h-4 w-3/4 rounded-full" />
								<Skeleton class="h-3 w-1/2 rounded-full" />
							</div>
						</div>
					{/each}
				</div>
			{:else if error}
				<p class="px-3 py-4 text-sm text-destructive/80">{error}</p>
			{:else}
				<p class="px-3 py-4 text-sm text-muted-foreground/60">书架为空</p>
			{/if}
		</div>
	{/if}
</div>
