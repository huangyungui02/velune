import { redirect } from '@sveltejs/kit';
import { fetchAvatarMap, normalizeWikiId } from '$lib/server/avatar';
import { readBookshelfCache, writeBookshelfCache } from '$lib/server/bookshelf-cache';
import type { LayoutServerLoad } from './$types';
import type { BookshelfItem } from '$lib/types';

type ResonanceRow = {
	id: string;
	souler_id: string;
	souler_name: string | null;
	last_session_id: string | null;
	last_session_title: string | null;
	updated_at: string;
};

type SoulerCoverRow = {
	id: string;
	wiki_id: string | null;
};

type SessionRow = {
	id: string;
	chapter_id: string | null;
};

export const load: LayoutServerLoad = async ({ locals }) => {
	const { session, user } = await locals.safeGetSession();

	if (!session || !user) {
		redirect(303, '/auth');
	}

	const cachedBookshelf = readBookshelfCache(user.id);
	if (cachedBookshelf) {
		return {
			user,
			bookshelf: cachedBookshelf
		};
	}

	const { data: resonancesRaw } = await locals.supabase
		.from('resonances_with_souler')
		.select('id, souler_id, souler_name, last_session_id, last_session_title, updated_at')
		.order('updated_at', { ascending: false })
		.limit(80);

	const resonances = (resonancesRaw ?? []) as ResonanceRow[];
	const soulerIds = [...new Set(resonances.map((item) => item.souler_id).filter(Boolean))];
	const sessionIds = [
		...new Set(resonances.map((item) => item.last_session_id).filter((id): id is string => Boolean(id)))
	];

	const imageBySoulerId = new Map<string, string | null>();
	if (soulerIds.length > 0) {
		const { data: soulersRaw } = await locals.supabase
			.from('soulers')
			.select('id, wiki_id')
			.in('id', soulerIds);

		const soulers = (soulersRaw ?? []) as SoulerCoverRow[];
		const avatarByWikiId = await fetchAvatarMap(
			locals,
			soulers.map((souler) => souler.wiki_id)
		);
		for (const souler of soulers) {
			const wikiId = normalizeWikiId(souler.wiki_id);
			imageBySoulerId.set(souler.id, wikiId ? (avatarByWikiId.get(wikiId) ?? null) : null);
		}
	}

	const chapterBySessionId = new Map<string, string | null>();
	if (sessionIds.length > 0) {
		const { data: sessionsRaw } = await locals.supabase
			.from('sessions')
			.select('id, chapter_id')
			.in('id', sessionIds);

		const sessions = (sessionsRaw ?? []) as SessionRow[];
		for (const session of sessions) {
			chapterBySessionId.set(session.id, session.chapter_id);
		}
	}

	const bookshelf: BookshelfItem[] = resonances.map((item) => ({
		id: item.id,
		soulerId: item.souler_id,
		soulerName: item.souler_name?.trim() || '未命名人物',
		lastSessionId: item.last_session_id ?? null,
		lastChapterId: item.last_session_id ? (chapterBySessionId.get(item.last_session_id) ?? null) : null,
		lastSessionTitle: item.last_session_title?.trim() || '',
		updatedAt: item.updated_at,
		imageUrl: imageBySoulerId.get(item.souler_id) ?? null
	}));

	writeBookshelfCache(user.id, bookshelf);

	return {
		user,
		bookshelf
	};
};
