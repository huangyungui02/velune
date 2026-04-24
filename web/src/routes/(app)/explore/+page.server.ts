import type { PageServerLoad } from './$types';
import { fetchAvatarMap, normalizeWikiId } from '$lib/server/avatar';
import type { ExploreSoulerItem } from '$lib/types';

type SoulerRow = {
	id: string;
	name: string;
	wiki_id: string | null;
};

export const load: PageServerLoad = async ({ locals }) => {
	const { data: soulersRaw } = await locals.supabase
		.from('soulers')
		.select('id, name, wiki_id')
		.order('name', { ascending: true });

	const soulers = (soulersRaw ?? []) as SoulerRow[];
	const avatarByWikiId = await fetchAvatarMap(
		locals,
		soulers.map((souler) => souler.wiki_id)
	);

	const items: ExploreSoulerItem[] = soulers.map((souler) => {
		const wikiId = normalizeWikiId(souler.wiki_id);
		return {
			id: souler.id,
			name: souler.name?.trim() || '未命名人物',
			imageUrl: wikiId ? (avatarByWikiId.get(wikiId) ?? null) : null
		};
	});

	return {
		soulers: items
	};
};
