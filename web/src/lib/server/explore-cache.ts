import type { ExploreSection, ExploreSoulerItem } from '$lib/types';

const EXPLORE_CACHE_TTL_MS = 45_000;

type ExploreCacheEntry<T> = {
	expiresAt: number;
	payload: T;
};

type ExploreLatestCachePayload = {
	items: ExploreSoulerItem[];
	hasNextPage: boolean;
};

const featuredCache = new Map<string, ExploreCacheEntry<ExploreSection[]>>();
const latestCache = new Map<string, ExploreCacheEntry<ExploreLatestCachePayload>>();

function cloneExploreItems(items: ExploreSoulerItem[]) {
	return items.map((item) => ({
		...item,
		tags: [...item.tags]
	}));
}

function cloneExploreSections(sections: ExploreSection[]) {
	return sections.map((section) => ({
		...section,
		soulers: cloneExploreItems(section.soulers)
	}));
}

function isExpired<T>(entry: ExploreCacheEntry<T>) {
	return entry.expiresAt <= Date.now();
}

function getFeaturedKey(lang: string) {
	return lang.trim().toLowerCase() || 'zh';
}

function getLatestKey(lang: string, page: number) {
	return `${getFeaturedKey(lang)}:${page}`;
}

export function readExploreFeaturedCache(lang: string) {
	const key = getFeaturedKey(lang);
	const entry = featuredCache.get(key);
	if (!entry) {
		return null;
	}

	if (isExpired(entry)) {
		featuredCache.delete(key);
		return null;
	}

	return cloneExploreSections(entry.payload);
}

export function writeExploreFeaturedCache(lang: string, sections: ExploreSection[]) {
	featuredCache.set(getFeaturedKey(lang), {
		expiresAt: Date.now() + EXPLORE_CACHE_TTL_MS,
		payload: cloneExploreSections(sections)
	});
}

export function readExploreLatestCache(lang: string, page: number) {
	const key = getLatestKey(lang, page);
	const entry = latestCache.get(key);
	if (!entry) {
		return null;
	}

	if (isExpired(entry)) {
		latestCache.delete(key);
		return null;
	}

	return {
		items: cloneExploreItems(entry.payload.items),
		hasNextPage: entry.payload.hasNextPage
	};
}

export function writeExploreLatestCache(
	lang: string,
	page: number,
	payload: ExploreLatestCachePayload
) {
	latestCache.set(getLatestKey(lang, page), {
		expiresAt: Date.now() + EXPLORE_CACHE_TTL_MS,
		payload: {
			items: cloneExploreItems(payload.items),
			hasNextPage: payload.hasNextPage
		}
	});
}

export function clearExploreCache() {
	featuredCache.clear();
	latestCache.clear();
}
