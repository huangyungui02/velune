import type { ExploreSection, ExploreSoulerItem } from '$lib/types';

export type ExploreTab = 'featured' | 'latest';

export type ExploreLatestPageState = {
	items: ExploreSoulerItem[];
	hasNextPage: boolean;
};

export type ExploreSearchState = {
	items: ExploreSoulerItem[];
};

type ExploreViewState = {
	activeTab: ExploreTab;
	featuredSections: ExploreSection[] | null;
	latestPage: number;
	scrollTop: number;
	latestPages: Record<number, ExploreLatestPageState>;
	searchQuery: string;
	searchResults: Record<string, ExploreSearchState>;
};

const exploreViewState: ExploreViewState = {
	activeTab: 'featured',
	featuredSections: null,
	latestPage: 1,
	scrollTop: 0,
	latestPages: {},
	searchQuery: '',
	searchResults: {}
};

export function readExploreViewState() {
	return {
		activeTab: exploreViewState.activeTab,
		featuredSections: exploreViewState.featuredSections,
		latestPage: exploreViewState.latestPage,
		scrollTop: exploreViewState.scrollTop,
		latestPages: exploreViewState.latestPages,
		searchQuery: exploreViewState.searchQuery,
		searchResults: exploreViewState.searchResults
	};
}

export function writeExploreViewState(next: Partial<ExploreViewState>) {
	if (next.activeTab === 'featured' || next.activeTab === 'latest') {
		exploreViewState.activeTab = next.activeTab;
	}

	if (Array.isArray(next.featuredSections)) {
		exploreViewState.featuredSections = next.featuredSections;
	}

	if (
		typeof next.latestPage === 'number' &&
		Number.isFinite(next.latestPage) &&
		next.latestPage > 0
	) {
		exploreViewState.latestPage = Math.trunc(next.latestPage);
	}

	if (
		typeof next.scrollTop === 'number' &&
		Number.isFinite(next.scrollTop) &&
		next.scrollTop >= 0
	) {
		exploreViewState.scrollTop = next.scrollTop;
	}

	if (next.latestPages) {
		exploreViewState.latestPages = next.latestPages;
	}

	if (typeof next.searchQuery === 'string') {
		exploreViewState.searchQuery = next.searchQuery;
	}

	if (next.searchResults) {
		exploreViewState.searchResults = next.searchResults;
	}
}
