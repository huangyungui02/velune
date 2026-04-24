import { error } from '@sveltejs/kit';
import { fetchAvatarMap, normalizeWikiId } from '$lib/server/avatar';
import type { PageServerLoad } from './$types';
import type { SoulerChapter } from '$lib/types';

type SoulerRow = {
	id: string;
	name: string;
	bio: string | null;
	wiki_id: string | null;
};

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

type ChapterRow = SoulerChapter;

export const load: PageServerLoad = async ({ locals, params }) => {
	const soulerId = params.soulerId;

	const { data: soulerRaw, error: soulerError } = await locals.supabase
		.from('soulers')
		.select('id, name, bio, wiki_id')
		.eq('id', soulerId)
		.single();

	if (soulerError || !soulerRaw) {
		error(404, '人物不存在');
	}

	const souler = soulerRaw as SoulerRow;
	const wikiId = normalizeWikiId(souler.wiki_id);
	const avatarByWikiId = await fetchAvatarMap(locals, [wikiId]);

	const { data: keywordRaw } = await locals.supabase
		.from('souler_keyword')
		.select('weight, keywords!inner(word)')
		.eq('souler_id', soulerId)
		.order('weight', { ascending: false })
		.limit(10);

	const keywords = ((keywordRaw ?? []) as KeywordRow[])
		.map((item) => {
			if (!item.keywords) {
				return '';
			}

			const row = Array.isArray(item.keywords) ? item.keywords[0] : item.keywords;
			return row?.word?.trim() ?? '';
		})
		.filter(Boolean);

	const { data: chaptersRaw } = await locals.supabase
		.from('chapters')
		.select('id, seq, title, subtitle')
		.eq('souler_id', soulerId)
		.order('seq', { ascending: true });

	const chapters = (chaptersRaw ?? []) as ChapterRow[];

	return {
		souler: {
			id: souler.id,
			name: souler.name,
			bio: souler.bio ?? '',
			imageUrl: wikiId ? (avatarByWikiId.get(wikiId) ?? null) : null
		},
		keywords,
		chapters
	};
};
