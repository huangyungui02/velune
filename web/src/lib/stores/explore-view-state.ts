import type { ExploreSoulerItem } from '$lib/types';

export type ExploreTab = 'featured' | 'latest';

export type ExploreLatestPageState = {
	items: ExploreSoulerItem[];
	hasNextPage: boolean;
};

type ExploreViewState = {
	activeTab: ExploreTab;
	latestPage: number;
	scrollTop: number;
	latestPages: Record<number, ExploreLatestPageState>;
};

const exploreViewState: ExploreViewState = {
	activeTab: 'featured',
	latestPage: 1,
	scrollTop: 0,
	latestPages: {}
};

function cloneLatestPageState(page: ExploreLatestPageState): ExploreLatestPageState {
	return {
		items: page.items.map((item) => ({
			...item,
			tags: [...item.tags]
		})),
		hasNextPage: page.hasNextPage
	};
}

function cloneLatestPages(
	latestPages: Record<number, ExploreLatestPageState>
): Record<number, ExploreLatestPageState> {
	const cloned: Record<number, ExploreLatestPageState> = {};
	for (const [key, value] of Object.entries(latestPages)) {
		const page = Number.parseInt(key, 10);
		if (!Number.isFinite(page) || page < 1) {
			continue;
		}
		cloned[page] = cloneLatestPageState(value);
	}
	return cloned;
}

export function readExploreViewState() {
	return {
		activeTab: exploreViewState.activeTab,
		latestPage: exploreViewState.latestPage,
		scrollTop: exploreViewState.scrollTop,
		latestPages: cloneLatestPages(exploreViewState.latestPages)
	};
}

export function writeExploreViewState(next: Partial<ExploreViewState>) {
	if (next.activeTab === 'featured' || next.activeTab === 'latest') {
		exploreViewState.activeTab = next.activeTab;
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
		exploreViewState.latestPages = cloneLatestPages(next.latestPages);
	}
}
