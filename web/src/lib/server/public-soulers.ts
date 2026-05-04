import { createAvatarResolver, normalizeWikiId } from '$lib/server/avatar';
import type { ConversationMessage, SoulerChapter } from '$lib/types';

type PublicSoulerRow = {
	id: string;
	name: string;
	bio: string | null;
	wiki_id: string | null;
};

type ChapterRow = SoulerChapter;

type KeywordRow = {
	weight: number;
	keywords:
		| {
				word: string;
		  }[]
		| {
				word: string;
		  }
		| null;
};

type ConversationSoulerRow = {
	id: string;
	name: string;
};

type ConversationChapterRow = {
	id: string;
	seq: number;
	title: string;
	subtitle: string;
};

type SessionRow = {
	id: string;
	souler_id: string;
	chapter_id: string | null;
};

type ChapterSessionRow = {
	id: string;
	chapter_id: string | null;
};

export async function fetchPublicSoulerDetail(locals: App.Locals, soulerId: string) {
	const { user } = await locals.safeGetSession();
	const { data: soulerRaw, error } = await locals.supabase
		.from('soulers')
		.select('id, name, bio, wiki_id')
		.eq('id', soulerId)
		.single();

	if (error || !soulerRaw) {
		return null;
	}

	const souler = soulerRaw as PublicSoulerRow;
	const wikiId = normalizeWikiId(souler.wiki_id);
	const avatarResolver = createAvatarResolver(locals);

	const [{ data: keywordRaw }, { data: chaptersRaw }] = await Promise.all([
		locals.supabase
			.from('souler_keyword')
			.select('weight, keywords!inner(word)')
			.eq('souler_id', soulerId)
			.order('weight', { ascending: false })
			.limit(10),
		locals.supabase
			.from('chapters')
			.select('id, seq, title, subtitle')
			.eq('souler_id', soulerId)
			.order('seq', { ascending: true })
	]);

	const keywords = ((keywordRaw ?? []) as KeywordRow[])
		.map((item) => {
			const row = Array.isArray(item.keywords) ? item.keywords[0] : item.keywords;
			return row?.word?.trim() ?? '';
		})
		.filter(Boolean);

	const chapters = (chaptersRaw ?? []) as ChapterRow[];
	const chapterIds = chapters.map((chapter) => chapter.id);
	const sessionByChapterId = new Map<string, string>();

	if (user && chapterIds.length > 0) {
		const { data: sessionRaw } = await locals.supabase
			.from('sessions')
			.select('id, chapter_id')
			.eq('user_id', user.id)
			.eq('souler_id', soulerId)
			.in('chapter_id', chapterIds)
			.order('updated_at', { ascending: false });

		for (const session of (sessionRaw ?? []) as ChapterSessionRow[]) {
			if (session.chapter_id && !sessionByChapterId.has(session.chapter_id)) {
				sessionByChapterId.set(session.chapter_id, session.id);
			}
		}
	}

	return {
		souler: {
			id: souler.id,
			name: souler.name,
			bio: souler.bio ?? '',
			imageUrl: await avatarResolver.get(wikiId)
		},
		keywords,
		chapters: chapters.map((chapter) => ({
			...chapter,
			sessionId: sessionByChapterId.get(chapter.id) ?? null
		}))
	};
}

export async function fetchChapterConversation(
	locals: App.Locals,
	soulerId: string,
	chapterId: string,
	routeSessionId: string | null
) {
	const [{ data: soulerRaw, error: soulerError }, { data: chapterRaw, error: chapterError }] =
		await Promise.all([
			locals.supabase.from('soulers').select('id, name').eq('id', soulerId).single(),
			locals.supabase
				.from('chapters')
				.select('id, seq, title, subtitle')
				.eq('id', chapterId)
				.eq('souler_id', soulerId)
				.single()
		]);

	if (soulerError || !soulerRaw || chapterError || !chapterRaw) {
		return null;
	}

	let initialSessionId: string | null = null;
	let initialMessages: ConversationMessage[] = [];

	if (routeSessionId) {
		const { data: sessionRaw } = await locals.supabase
			.from('sessions')
			.select('id, souler_id, chapter_id')
			.eq('id', routeSessionId)
			.maybeSingle();

		const session = sessionRaw as SessionRow | null;
		const isValidSession =
			session && session.souler_id === soulerId && session.chapter_id === chapterId;

		if (isValidSession) {
			const { data: messageRows } = await locals.supabase
				.from('messages')
				.select('role, content')
				.eq('session_id', routeSessionId)
				.order('created_at', { ascending: true });

			initialSessionId = routeSessionId;
			initialMessages = (messageRows ?? []) as ConversationMessage[];
		}
	}

	return {
		souler: soulerRaw as ConversationSoulerRow,
		chapter: chapterRaw as ConversationChapterRow,
		initialSessionId,
		initialMessages
	};
}
