<script lang="ts">
	import { browser } from '$app/environment';
	import { page } from '$app/state';
	import { beforeNavigate } from '$app/navigation';
	import { onMount } from 'svelte';
	import { Button } from '$lib/components/ui/button/index.js';
	import { Separator } from '$lib/components/ui/separator/index.js';
	import SoulerBookCard from '$lib/components/souler/SoulerBookCard.svelte';
	import {
		readExploreViewState,
		writeExploreViewState,
		type ExploreLatestPageState,
		type ExploreTab
	} from '$lib/stores/explore-view-state';
	import type { ExploreSection } from '$lib/types';
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();

	function normalizePage(raw: string | null) {
		const value = Number.parseInt(raw ?? '1', 10);
		if (!Number.isFinite(value) || value < 1) {
			return 1;
		}
		return value;
	}

	const memory = browser
		? readExploreViewState()
		: {
				activeTab: 'featured' as ExploreTab,
				featuredSections: null,
				latestPage: 1,
				scrollTop: 0,
				latestPages: {}
			};
	const queryTab = page.url.searchParams.get('tab');
	const queryPage = normalizePage(page.url.searchParams.get('page'));
	const hasQueryTab = queryTab === 'featured' || queryTab === 'latest';

	const initialTab: ExploreTab = hasQueryTab
		? (queryTab as ExploreTab)
		: (memory.activeTab ?? 'featured');
	const initialLatestPage =
		hasQueryTab && queryTab === 'latest'
			? queryPage
			: Number.isFinite(memory.latestPage) && memory.latestPage > 0
				? memory.latestPage
				: 1;

	function getServerLatestPageEntry(): { page: number; state: ExploreLatestPageState } | null {
		if (!data.exploreLatest) {
			return null;
		}
		return {
			page: data.exploreLatest.page,
			state: {
				items: data.exploreLatest.items,
				hasNextPage: data.exploreLatest.hasNextPage
			}
		};
	}

	const serverLatestPageEntry = getServerLatestPageEntry();
	const initialLatestPages: Record<number, ExploreLatestPageState> = {
		...memory.latestPages
	};
	if (serverLatestPageEntry && !initialLatestPages[serverLatestPageEntry.page]) {
		initialLatestPages[serverLatestPageEntry.page] = serverLatestPageEntry.state;
	}
	const resolvedInitialLatestPage = initialLatestPages[initialLatestPage] ? initialLatestPage : 1;

	let activeTab = $state<ExploreTab>(initialTab);
	let featuredSections: ExploreSection[] | null = $derived(
		memory.featuredSections ?? data.exploreFeaturedSections ?? null
	);
	let featuredLoading = $state(false);
	let featuredError = $state('');
	let latestPage = $state(resolvedInitialLatestPage);
	let latestPages = $state<Record<number, ExploreLatestPageState>>(initialLatestPages);
	let latestLoading = $state(false);
	let latestError = $state('');

	const currentLatestPage = $derived(latestPages[latestPage] ?? null);
	const latestItems = $derived(currentLatestPage?.items ?? []);
	const hasLatestNextPage = $derived(currentLatestPage?.hasNextPage ?? false);

	function getMainScrollContainer() {
		if (typeof document === 'undefined') {
			return null;
		}
		return document.querySelector<HTMLElement>('[data-main-scroll-container]');
	}

	function persistExploreViewState() {
		const container = getMainScrollContainer();
		if (!browser) {
			return;
		}
		writeExploreViewState({
			activeTab,
			featuredSections,
			latestPage,
			scrollTop: container?.scrollTop ?? 0,
			latestPages
		});
	}

	async function ensureFeaturedSections() {
		if (featuredSections) {
			return true;
		}

		featuredLoading = true;
		featuredError = '';
		try {
			const response = await fetch('/api/explore/featured');
			if (!response.ok) {
				throw new Error('加载失败');
			}

			const payload = (await response.json()) as {
				featuredSections?: ExploreSection[];
			};
			featuredSections = Array.isArray(payload.featuredSections) ? payload.featuredSections : [];
			return true;
		} catch (error) {
			console.error(error);
			featuredError = '精选列表加载失败，请稍后重试。';
			return false;
		} finally {
			featuredLoading = false;
		}
	}

	async function ensureLatestPage(targetPage: number) {
		if (latestPages[targetPage]) {
			return true;
		}

		latestLoading = true;
		latestError = '';
		try {
			const response = await fetch(`/api/explore/latest?page=${targetPage}`);
			if (!response.ok) {
				throw new Error('加载失败');
			}

			const payload = (await response.json()) as {
				page?: number;
				items?: ExploreLatestPageState['items'];
				hasNextPage?: boolean;
			};
			const pageKey = Number.isFinite(payload.page) ? (payload.page as number) : targetPage;
			latestPages[pageKey] = {
				items: Array.isArray(payload.items) ? payload.items : [],
				hasNextPage: Boolean(payload.hasNextPage)
			};
			return true;
		} catch (error) {
			console.error(error);
			latestError = '最新列表加载失败，请稍后重试。';
			return false;
		} finally {
			latestLoading = false;
		}
	}

	async function onSelectTab(tab: ExploreTab) {
		activeTab = tab;
		featuredError = '';
		latestError = '';
		if (tab === 'featured') {
			await ensureFeaturedSections();
		} else {
			await ensureLatestPage(latestPage);
		}
	}

	async function goToLatestPage(targetPage: number) {
		if (!Number.isFinite(targetPage) || targetPage < 1 || latestLoading) {
			return;
		}

		const ok = await ensureLatestPage(targetPage);
		if (!ok) {
			return;
		}
		latestPage = targetPage;
	}

	onMount(() => {
		requestAnimationFrame(() => {
			const container = getMainScrollContainer();
			if (container) {
				container.scrollTop = memory.scrollTop;
			}
		});

		if (activeTab === 'featured' && !featuredSections) {
			void ensureFeaturedSections();
		} else if (activeTab === 'latest' && !latestPages[latestPage]) {
			void ensureLatestPage(latestPage);
		}

		beforeNavigate(() => {
			persistExploreViewState();
		});

		return () => {
			persistExploreViewState();
		};
	});
</script>

<svelte:head>
	<title>Velune · 发现</title>
</svelte:head>

<section class="space-y-8">
	<header class="space-y-2">
		<div class="flex flex-wrap items-start justify-between gap-4">
			<h1 class="text-2xl leading-tight text-primary">发现</h1>
			<div class="inline-flex rounded-2xl border border-border/50 bg-muted/20 p-1">
				<Button
					type="button"
					variant={activeTab === 'featured' ? 'default' : 'ghost'}
					size="sm"
					class="rounded-xl px-4"
					onclick={() => onSelectTab('featured')}
				>
					精选
				</Button>
				<Button
					type="button"
					variant={activeTab === 'latest' ? 'default' : 'ghost'}
					size="sm"
					class="rounded-xl px-4"
					onclick={() => onSelectTab('latest')}
				>
					最新
				</Button>
			</div>
		</div>
		<Separator class="mt-3" />
	</header>

	{#if activeTab === 'featured'}
		{#if featuredSections && featuredSections.length > 0}
			<div class="space-y-10">
				{#each featuredSections as section (section.id)}
					<section class="space-y-4">
						<div class="px-1">
							<h2 class="font-serif text-xl leading-tight text-primary md:text-2xl">
								{section.title}
							</h2>
							{#if section.subtitle}
								<p class="mt-1 text-sm text-muted-foreground/80">{section.subtitle}</p>
							{/if}
						</div>

						<div class="scrollbar-soft -mx-1 overflow-x-auto overscroll-x-contain pb-3 pl-1">
							<div
								class="grid min-w-max auto-cols-[minmax(7.25rem,7.75rem)] grid-flow-col gap-3 pr-4 md:auto-cols-[minmax(10rem,11.5rem)] md:gap-4"
							>
								{#each section.soulers as souler (souler.id)}
									<SoulerBookCard
										href={`/bookshelf/${souler.id}`}
										name={souler.name}
										imageUrl={souler.imageUrl}
									/>
								{/each}
							</div>
						</div>
					</section>
				{/each}
			</div>
		{:else if featuredLoading}
			<div class="px-2 py-8 text-sm text-muted-foreground/70">正在加载精选...</div>
		{:else if featuredError}
			<p class="text-sm text-destructive/90">{featuredError}</p>
		{:else}
			<div class="px-2 py-8 text-sm text-muted-foreground/70">还没有可展示的精选分组。</div>
		{/if}
	{:else if latestItems.length > 0}
		<div class="grid grid-cols-3 gap-x-3 gap-y-6 sm:gap-x-4 sm:gap-y-8 lg:grid-cols-4">
			{#each latestItems as souler (souler.id)}
				<SoulerBookCard
					class="mx-auto w-full max-w-[7.25rem] sm:max-w-[8.75rem] lg:max-w-[11.5rem]"
					href={`/bookshelf/${souler.id}`}
					name={souler.name}
					imageUrl={souler.imageUrl}
				/>
			{/each}
		</div>

		<div class="flex items-center justify-between border-t border-border/40 pt-2">
			<p class="text-xs text-muted-foreground/80">第 {latestPage} 页 · 每页 20 人</p>
			<div class="flex items-center gap-2">
				<Button
					type="button"
					variant="outline"
					size="sm"
					class="rounded-xl"
					disabled={latestPage <= 1 || latestLoading}
					onclick={() => goToLatestPage(latestPage - 1)}
				>
					上一页
				</Button>
				<Button
					type="button"
					variant="outline"
					size="sm"
					class="rounded-xl"
					disabled={!hasLatestNextPage || latestLoading}
					onclick={() => goToLatestPage(latestPage + 1)}
				>
					下一页
				</Button>
			</div>
		</div>

		{#if latestError}
			<p class="text-sm text-destructive/90">{latestError}</p>
		{/if}
	{:else if latestLoading}
		<div class="px-2 py-8 text-sm text-muted-foreground/70">正在加载最新...</div>
	{:else if latestError}
		<p class="text-sm text-destructive/90">{latestError}</p>
	{:else}
		<div class="px-2 py-8 text-sm text-muted-foreground/70">还没有可发现的人物。</div>
	{/if}
</section>
