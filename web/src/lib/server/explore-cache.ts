import type { ExploreSoulerItem } from '$lib/types';

const EXPLORE_CACHE_TTL_MS = 45_000;

type ExploreCacheEntry = {
	expiresAt: number;
	items: ExploreSoulerItem[];
};

let exploreCache: ExploreCacheEntry | null = null;

function cloneExploreItems(items: ExploreSoulerItem[]) {
	return items.map((item) => ({
		...item,
		tags: [...item.tags]
	}));
}

export function readExploreCache() {
	if (!exploreCache) {
		return null;
	}

	if (exploreCache.expiresAt <= Date.now()) {
		exploreCache = null;
		return null;
	}

	return cloneExploreItems(exploreCache.items);
}

export function writeExploreCache(items: ExploreSoulerItem[]) {
	exploreCache = {
		expiresAt: Date.now() + EXPLORE_CACHE_TTL_MS,
		items: cloneExploreItems(items)
	};
}

export function clearExploreCache() {
	exploreCache = null;
}
