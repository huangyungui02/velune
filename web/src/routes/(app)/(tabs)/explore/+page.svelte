<script lang="ts">
	import { browser } from '$app/environment';
	import { page } from '$app/state';
	import { beforeNavigate } from '$app/navigation';
	import { onDestroy, onMount } from 'svelte';
	import { Search } from '@lucide/svelte';
	import ExploreTabs from '$lib/components/explore/ExploreTabs.svelte';
	import FeaturedSections from '$lib/components/explore/FeaturedSections.svelte';
	import LatestGrid from '$lib/components/explore/LatestGrid.svelte';
	import SearchResults from '$lib/components/explore/SearchResults.svelte';
	import { Input } from '$lib/components/ui/input/index.js';
	import { Separator } from '$lib/components/ui/separator/index.js';
	import {
		readExploreViewState,
		writeExploreViewState,
		type ExploreLatestPageState,
		type ExploreSearchState,
		type ExploreTab
	} from '$lib/stores/explore-view-state';
	import type { ExploreSection, ExploreSoulerItem } from '$lib/types';

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
				latestPages: {},
				searchQuery: '',
				searchResults: {}
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

	const initialLatestPages: Record<number, ExploreLatestPageState> = {
		...memory.latestPages
	};
	const resolvedInitialLatestPage = initialLatestPage;

	let activeTab = $state<ExploreTab>(initialTab);
	let featuredSections = $state.raw<ExploreSection[] | null>(memory.featuredSections ?? null);
	let featuredLoading = $state(false);
	let featuredError = $state('');
	let latestPage = $state(resolvedInitialLatestPage);
	let latestPages = $state.raw<Record<number, ExploreLatestPageState>>(initialLatestPages);
	let latestLoading = $state(false);
	let latestError = $state('');
	let searchQuery = $state(memory.searchQuery ?? '');
	let searchResults = $state.raw<Record<string, ExploreSearchState>>({ ...memory.searchResults });
	let searchLoading = $state(false);
	let searchError = $state('');
	let searchTimer: ReturnType<typeof setTimeout> | null = null;
	let searchAbort: AbortController | null = null;
	let searchRequestId = 0;

	const currentLatestPage = $derived(latestPages[latestPage] ?? null);
	const latestItems = $derived(currentLatestPage?.items ?? []);
	const hasLatestNextPage = $derived(currentLatestPage?.hasNextPage ?? false);
	const normalizedSearchQuery = $derived(normalizeSearchQuery(searchQuery));
	const currentSearchItems = $derived(searchResults[normalizedSearchQuery]?.items ?? []);

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
			latestPages,
			searchQuery,
			searchResults
		});
	}

	function normalizeSearchQuery(value: string) {
		return value.trim().replace(/\s+/g, ' ').slice(0, 80);
	}

	function clearSearchTimer() {
		if (searchTimer) {
			clearTimeout(searchTimer);
			searchTimer = null;
		}
	}

	function cancelSearchRequest() {
		searchRequestId += 1;
		searchAbort?.abort();
		searchAbort = null;
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
			latestPages = {
				...latestPages,
				[pageKey]: {
					items: Array.isArray(payload.items) ? payload.items : [],
					hasNextPage: Boolean(payload.hasNextPage)
				}
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

	function onSelectTab(tab: ExploreTab) {
		activeTab = tab;
		featuredError = '';
		latestError = '';
		if (tab === 'featured') {
			void ensureFeaturedSections();
		} else {
			void ensureLatestPage(latestPage);
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

	function onSearchInput(event: Event) {
		searchQuery = (event.currentTarget as HTMLInputElement).value;
		const query = normalizedSearchQuery;
		searchError = '';
		clearSearchTimer();

		if (!query) {
			searchLoading = false;
			cancelSearchRequest();
			return;
		}

		if (searchResults[query]) {
			searchLoading = false;
			return;
		}

		searchLoading = true;
		searchTimer = setTimeout(() => {
			void ensureSearchResults(query);
		}, 180);
	}

	async function ensureSearchResults(query: string) {
		if (!query || searchResults[query]) {
			searchLoading = false;
			return true;
		}

		cancelSearchRequest();
		searchAbort = new AbortController();
		const requestId = searchRequestId;
		searchLoading = true;
		searchError = '';

		try {
			const params = new URLSearchParams({ q: query, limit: '24' });
			const response = await fetch(`/api/explore/search?${params.toString()}`, {
				signal: searchAbort.signal
			});
			if (!response.ok) {
				throw new Error('搜索失败');
			}

			const payload = (await response.json()) as { items?: ExploreSoulerItem[] };
			if (requestId !== searchRequestId) {
				return false;
			}

			searchResults = {
				...searchResults,
				[query]: {
					items: Array.isArray(payload.items) ? payload.items : []
				}
			};
			return true;
		} catch (error) {
			if (error instanceof DOMException && error.name === 'AbortError') {
				return false;
			}
			if (requestId !== searchRequestId) {
				return false;
			}
			console.error(error);
			searchError = '搜索失败，请稍后重试。';
			return false;
		} finally {
			if (requestId === searchRequestId) {
				searchLoading = false;
			}
		}
	}

	function clearSearch() {
		searchQuery = '';
		searchError = '';
		searchLoading = false;
		clearSearchTimer();
		cancelSearchRequest();
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

		if (normalizedSearchQuery && !searchResults[normalizedSearchQuery]) {
			void ensureSearchResults(normalizedSearchQuery);
		}

		beforeNavigate(() => {
			persistExploreViewState();
		});

		return () => {
			persistExploreViewState();
		};
	});

	onDestroy(() => {
		clearSearchTimer();
		cancelSearchRequest();
	});
</script>

<svelte:head>
	<title>Velune · 发现</title>
</svelte:head>

<section class="space-y-8">
	<header class="space-y-2">
		<div class="flex flex-wrap items-start justify-between gap-4">
			<h1 class="text-2xl leading-tight text-primary">发现</h1>
			<ExploreTabs {activeTab} onSelect={(tab) => void onSelectTab(tab)} />
		</div>
		<div class="relative max-w-xl">
			<Search
				class="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-muted-foreground/70"
			/>
			<Input
				type="search"
				bind:value={searchQuery}
				placeholder="搜索人物"
				class="rounded-2xl border-border/60 bg-background/70 pl-9"
				oninput={onSearchInput}
			/>
		</div>
		<Separator class="mt-3" />
	</header>

	{#if normalizedSearchQuery}
		<SearchResults
			query={normalizedSearchQuery}
			items={currentSearchItems}
			loading={searchLoading}
			error={searchError}
			onClear={clearSearch}
		/>
	{:else if activeTab === 'featured'}
		<FeaturedSections sections={featuredSections} loading={featuredLoading} error={featuredError} />
	{:else}
		<LatestGrid
			items={latestItems}
			page={latestPage}
			hasNextPage={hasLatestNextPage}
			loading={latestLoading}
			error={latestError}
			onPage={(targetPage) => void goToLatestPage(targetPage)}
		/>
	{/if}
</section>
