import type { BookshelfItem } from '$lib/types';

const BOOKSHELF_CACHE_TTL_MS = 12_000;
const MAX_CACHE_USERS = 120;

type BookshelfCacheEntry = {
	expiresAt: number;
	items: BookshelfItem[];
};

const bookshelfCache = new Map<string, BookshelfCacheEntry>();

function cloneBookshelf(items: BookshelfItem[]) {
	return items.map((item) => ({ ...item }));
}

function pruneExpired(now = Date.now()) {
	for (const [key, entry] of bookshelfCache) {
		if (entry.expiresAt <= now) {
			bookshelfCache.delete(key);
		}
	}
}

function keepCacheBounded() {
	if (bookshelfCache.size <= MAX_CACHE_USERS) {
		return;
	}

	const oldestKey = bookshelfCache.keys().next().value;
	if (oldestKey) {
		bookshelfCache.delete(oldestKey);
	}
}

export function readBookshelfCache(userId: string) {
	pruneExpired();
	const cached = bookshelfCache.get(userId);
	if (!cached) {
		return null;
	}

	if (cached.expiresAt <= Date.now()) {
		bookshelfCache.delete(userId);
		return null;
	}

	return cloneBookshelf(cached.items);
}

export function writeBookshelfCache(userId: string, items: BookshelfItem[]) {
	const now = Date.now();
	pruneExpired(now);
	bookshelfCache.set(userId, {
		expiresAt: now + BOOKSHELF_CACHE_TTL_MS,
		items: cloneBookshelf(items)
	});
	keepCacheBounded();
}

export function clearBookshelfCache(userId?: string) {
	if (!userId) {
		bookshelfCache.clear();
		return;
	}

	bookshelfCache.delete(userId);
}
