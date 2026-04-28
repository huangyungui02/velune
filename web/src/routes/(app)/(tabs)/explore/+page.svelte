<script lang="ts">
	import { browser } from '$app/environment';
	import { page } from '$app/state';
	import { beforeNavigate } from '$app/navigation';
	import { onMount } from 'svelte';
	import ExploreTabs from '$lib/components/explore/ExploreTabs.svelte';
	import FeaturedSections from '$lib/components/explore/FeaturedSections.svelte';
	import LatestGrid from '$lib/components/explore/LatestGrid.svelte';
	import { Separator } from '$lib/components/ui/separator/index.js';
	import {
		readExploreViewState,
		writeExploreViewState,
		type ExploreLatestPageState,
		type ExploreTab
	} from '$lib/stores/explore-view-state';
	import type { ExploreSection } from '$lib/types';

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
			<ExploreTabs {activeTab} onSelect={(tab) => void onSelectTab(tab)} />
		</div>
		<Separator class="mt-3" />
	</header>

	{#if activeTab === 'featured'}
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
