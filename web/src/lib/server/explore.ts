import { fetchAvatarMap, normalizeWikiId } from '$lib/server/avatar';
import type { ExploreSection, ExploreSoulerItem } from '$lib/types';

type SoulerRow = {
	id: string;
	wiki_id: string | null;
	updated_at: string;
	souler_profile:
		| {
				name: string;
				lang: string;
		  }[]
		| null;
};

type DiscoverSectionRow = {
	id: string;
	sort_order: number;
	discover_section_profile:
		| {
				title: string;
				subtitle: string | null;
		  }[]
		| null;
};

type DiscoverSectionItemRow = {
	section_id: string;
	souler_id: string;
	sort_order: number;
};

const LATEST_PAGE_SIZE = 20;

function buildExploreSoulerItems(soulers: SoulerRow[], avatarByWikiId: Map<string, string | null>) {
	return soulers.map((souler) => {
		const wikiId = normalizeWikiId(souler.wiki_id);
		return {
			id: souler.id,
			name: souler.souler_profile?.[0]?.name?.trim() || '未命名人物',
			imageUrl: wikiId ? (avatarByWikiId.get(wikiId) ?? null) : null,
			tags: []
		} satisfies ExploreSoulerItem;
	});
}

async function fetchSectionRowsByLang(locals: App.Locals, lang: string) {
	const { data: rows } = await locals.supabase
		.from('discover_sections')
		.select('id, sort_order, discover_section_profile!inner(title, subtitle, lang)')
		.eq('is_active', true)
		.eq('discover_section_profile.lang', lang)
		.order('sort_order', { ascending: true })
		.order('updated_at', { ascending: false });

	return (rows ?? []) as DiscoverSectionRow[];
}

export async function fetchFeaturedSections(locals: App.Locals) {
	const sections = await fetchSectionRowsByLang(locals, 'zh');
	if (sections.length === 0) {
		return [] satisfies ExploreSection[];
	}

	const sectionIds = sections.map((section) => section.id);
	if (sectionIds.length === 0) {
		return [] satisfies ExploreSection[];
	}

	const { data: itemRowsRaw } = await locals.supabase
		.from('discover_section_items')
		.select('section_id, souler_id, sort_order')
		.in('section_id', sectionIds)
		.order('sort_order', { ascending: true });

	const itemRows = (itemRowsRaw ?? []) as DiscoverSectionItemRow[];
	const soulerIds = [...new Set(itemRows.map((item) => item.souler_id).filter(Boolean))];
	if (soulerIds.length === 0) {
		return [] satisfies ExploreSection[];
	}

	const { data: soulerRowsRaw } = await locals.supabase
		.from('soulers')
		.select('id, wiki_id, updated_at, souler_profile!inner(name, lang)')
		.in('id', soulerIds)
		.eq('checked', true)
		.eq('souler_profile.lang', 'zh');

	const soulerRows = (soulerRowsRaw ?? []) as SoulerRow[];
	const avatarByWikiId = await fetchAvatarMap(
		locals,
		soulerRows.map((souler) => souler.wiki_id)
	);
	const soulerById = new Map<string, ExploreSoulerItem>(
		buildExploreSoulerItems(soulerRows, avatarByWikiId).map((souler) => [souler.id, souler])
	);
	const soulerIdsBySectionId = new Map<string, string[]>();

	for (const item of itemRows) {
		if (!soulerById.has(item.souler_id)) {
			continue;
		}
		const list = soulerIdsBySectionId.get(item.section_id) ?? [];
		list.push(item.souler_id);
		soulerIdsBySectionId.set(item.section_id, list);
	}

	return sections
		.map((section) => {
			const profile = section.discover_section_profile?.[0];
			const soulerIds = soulerIdsBySectionId.get(section.id) ?? [];
			const soulers = soulerIds
				.map((soulerId) => soulerById.get(soulerId))
				.filter((souler): souler is ExploreSoulerItem => Boolean(souler));

			return {
				id: section.id,
				title: profile?.title?.trim() || '未命名分组',
				subtitle: profile?.subtitle?.trim() || '',
				soulers
			} satisfies ExploreSection;
		})
		.filter((section) => section.soulers.length > 0);
}

export async function fetchLatestSoulersPage(locals: App.Locals, page: number) {
	const normalizedPage = Number.isFinite(page) && page > 0 ? Math.trunc(page) : 1;
	const from = (normalizedPage - 1) * LATEST_PAGE_SIZE;
	const to = from + LATEST_PAGE_SIZE - 1;
	const { data: soulersRaw, count } = await locals.supabase
		.from('soulers')
		.select('id, wiki_id, updated_at, souler_profile!inner(name, lang)', { count: 'exact' })
		.eq('checked', true)
		.eq('souler_profile.lang', 'zh')
		.order('updated_at', { ascending: false })
		.range(from, to);

	const soulers = (soulersRaw ?? []) as SoulerRow[];
	const avatarByWikiId = await fetchAvatarMap(
		locals,
		soulers.map((souler) => souler.wiki_id)
	);
	const items = buildExploreSoulerItems(soulers, avatarByWikiId);
	const hasNextPage =
		typeof count === 'number' ? from + items.length < count : items.length === LATEST_PAGE_SIZE;

	return {
		page: normalizedPage,
		items,
		hasNextPage
	};
}
