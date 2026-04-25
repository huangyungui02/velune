import type { PageServerLoad } from './$types';
import { fetchAvatarMap, normalizeWikiId } from '$lib/server/avatar';
import type { ExploreSoulerItem } from '$lib/types';

type SoulerRow = {
	id: string;
	name: string;
	wiki_id: string | null;
	updated_at: string;
};

type KeywordRow = {
	souler_id: string;
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

export const load: PageServerLoad = async ({ locals }) => {
	const { data: soulersRaw } = await locals.supabase
		.from('soulers')
		.select('id, name, wiki_id, updated_at')
		.eq('checked', true)
		.order('updated_at', { ascending: false });

	const soulers = (soulersRaw ?? []) as SoulerRow[];
	const soulerIds = soulers.map((souler) => souler.id);
	const avatarByWikiId = await fetchAvatarMap(
		locals,
		soulers.map((souler) => souler.wiki_id)
	);
	const keywordBySoulerId = new Map<string, string[]>();

	if (soulerIds.length > 0) {
		const { data: keywordRaw } = await locals.supabase
			.from('souler_keyword')
			.select('souler_id, weight, keywords!inner(word)')
			.in('souler_id', soulerIds)
			.order('weight', { ascending: false });

		for (const item of (keywordRaw ?? []) as KeywordRow[]) {
			const keywordSource = Array.isArray(item.keywords) ? item.keywords[0] : item.keywords;
			const word = keywordSource?.word?.trim();
			if (!word) {
				continue;
			}

			const existing = keywordBySoulerId.get(item.souler_id) ?? [];
			if (existing.length >= 4 || existing.includes(word)) {
				continue;
			}

			existing.push(word);
			keywordBySoulerId.set(item.souler_id, existing);
		}
	}

	const items: ExploreSoulerItem[] = soulers.map((souler) => {
		const wikiId = normalizeWikiId(souler.wiki_id);
		return {
			id: souler.id,
			name: souler.name?.trim() || '未命名人物',
			imageUrl: wikiId ? (avatarByWikiId.get(wikiId) ?? null) : null,
			tags: keywordBySoulerId.get(souler.id) ?? []
		};
	});

	return {
		soulers: items
	};
};
