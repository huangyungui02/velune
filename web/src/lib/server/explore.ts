import { fetchAvatarMap, normalizeWikiId } from '$lib/server/avatar';
import type { ExploreSection, ExploreSoulerItem } from '$lib/types';

type SoulerRow = {
	id: string;
	name: string;
	wiki_id: string | null;
	updated_at: string;
};

type DiscoverSectionRow = {
	id: string;
	lang: string;
	key: string;
	title: string;
	subtitle: string | null;
	sort_order: number;
};

type DiscoverSectionItemRow = {
	section_id: string;
	sort_order: number;
	soulers:
		| {
				id: string;
				name: string;
				wiki_id: string | null;
				checked: boolean;
		  }[]
		| {
				id: string;
				name: string;
				wiki_id: string | null;
				checked: boolean;
		  }
		| null;
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

const LATEST_PAGE_SIZE = 20;
const MAX_TAGS_PER_SOULER = 4;

function normalizeLang(raw: string | null | undefined) {
	const value = raw?.trim().toLowerCase();
	if (!value) {
		return null;
	}

	const [segment] = value.split(/[-_]/);
	return segment?.trim() || null;
}

export function resolveExploreLang(user: unknown, acceptLanguage: string | null) {
	if (user && typeof user === 'object') {
		const metadata =
			(user as { user_metadata?: { lang?: string; language?: string } }).user_metadata ?? {};
		const fromMetadata = normalizeLang(metadata.lang) ?? normalizeLang(metadata.language);
		if (fromMetadata) {
			return fromMetadata;
		}
	}

	const fromHeader = normalizeLang(acceptLanguage?.split(',')[0] ?? null);
	return fromHeader ?? 'zh';
}

async function fetchKeywordMap(locals: App.Locals, soulerIds: string[]) {
	const keywordBySoulerId = new Map<string, string[]>();
	if (soulerIds.length === 0) {
		return keywordBySoulerId;
	}

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
		if (existing.length >= MAX_TAGS_PER_SOULER || existing.includes(word)) {
			continue;
		}

		existing.push(word);
		keywordBySoulerId.set(item.souler_id, existing);
	}

	return keywordBySoulerId;
}

function buildExploreSoulerItems(
	soulers: SoulerRow[],
	avatarByWikiId: Map<string, string | null>,
	keywordBySoulerId: Map<string, string[]>
) {
	return soulers.map((souler) => {
		const wikiId = normalizeWikiId(souler.wiki_id);
		return {
			id: souler.id,
			name: souler.name?.trim() || '未命名人物',
			imageUrl: wikiId ? (avatarByWikiId.get(wikiId) ?? null) : null,
			tags: keywordBySoulerId.get(souler.id) ?? []
		} satisfies ExploreSoulerItem;
	});
}

async function fetchSectionRowsByLang(locals: App.Locals, lang: string) {
	const { data: rows } = await locals.supabase
		.from('discover_sections')
		.select('id, lang, key, title, subtitle, sort_order')
		.eq('is_active', true)
		.eq('lang', lang)
		.order('sort_order', { ascending: true })
		.order('updated_at', { ascending: false });

	return (rows ?? []) as DiscoverSectionRow[];
}

export async function fetchFeaturedSections(locals: App.Locals, preferredLang: string) {
	let sections = await fetchSectionRowsByLang(locals, preferredLang);
	if (sections.length === 0 && preferredLang !== 'zh') {
		sections = await fetchSectionRowsByLang(locals, 'zh');
	}

	if (sections.length === 0) {
		const { data: allRows } = await locals.supabase
			.from('discover_sections')
			.select('id, lang, key, title, subtitle, sort_order')
			.eq('is_active', true)
			.order('lang', { ascending: true })
			.order('sort_order', { ascending: true })
			.order('updated_at', { ascending: false });

		const allSections = (allRows ?? []) as DiscoverSectionRow[];
		if (allSections.length === 0) {
			return [] satisfies ExploreSection[];
		}

		const fallbackLang = allSections[0]?.lang?.trim() || 'zh';
		sections = allSections.filter((section) => (section.lang?.trim() || 'zh') === fallbackLang);
	}

	const sectionIds = sections.map((section) => section.id);
	if (sectionIds.length === 0) {
		return [] satisfies ExploreSection[];
	}

	const { data: itemRowsRaw } = await locals.supabase
		.from('discover_section_items')
		.select('section_id, sort_order, soulers!inner(id, name, wiki_id, checked)')
		.in('section_id', sectionIds)
		.eq('soulers.checked', true)
		.order('sort_order', { ascending: true });

	const itemRows = (itemRowsRaw ?? []) as DiscoverSectionItemRow[];
	const orderedSoulerRows: SoulerRow[] = [];
	for (const item of itemRows) {
		const souler = Array.isArray(item.soulers) ? item.soulers[0] : item.soulers;
		if (!souler) {
			continue;
		}
		orderedSoulerRows.push({
			id: souler.id,
			name: souler.name,
			wiki_id: souler.wiki_id,
			updated_at: ''
		});
	}

	const avatarByWikiId = await fetchAvatarMap(
		locals,
		orderedSoulerRows.map((souler) => souler.wiki_id)
	);
	const keywordBySoulerId = await fetchKeywordMap(locals, [
		...new Set(orderedSoulerRows.map((souler) => souler.id))
	]);
	const soulerById = new Map<string, ExploreSoulerItem>(
		buildExploreSoulerItems(orderedSoulerRows, avatarByWikiId, keywordBySoulerId).map((souler) => [
			souler.id,
			souler
		])
	);
	const soulerIdsBySectionId = new Map<string, string[]>();

	for (const item of itemRows) {
		const souler = Array.isArray(item.soulers) ? item.soulers[0] : item.soulers;
		if (!souler) {
			continue;
		}
		const list = soulerIdsBySectionId.get(item.section_id) ?? [];
		list.push(souler.id);
		soulerIdsBySectionId.set(item.section_id, list);
	}

	return sections
		.map((section) => {
			const soulerIds = soulerIdsBySectionId.get(section.id) ?? [];
			const soulers = soulerIds
				.map((soulerId) => soulerById.get(soulerId))
				.filter((souler): souler is ExploreSoulerItem => Boolean(souler));

			return {
				id: section.id,
				key: section.key?.trim() || section.id,
				title: section.title?.trim() || '未命名分组',
				subtitle: section.subtitle?.trim() || '',
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
		.select('id, name, wiki_id, updated_at', { count: 'exact' })
		.eq('checked', true)
		.order('updated_at', { ascending: false })
		.range(from, to);

	const soulers = (soulersRaw ?? []) as SoulerRow[];
	const soulerIds = soulers.map((souler) => souler.id);
	const avatarByWikiId = await fetchAvatarMap(
		locals,
		soulers.map((souler) => souler.wiki_id)
	);
	const keywordBySoulerId = await fetchKeywordMap(locals, soulerIds);
	const items = buildExploreSoulerItems(soulers, avatarByWikiId, keywordBySoulerId);
	const hasNextPage =
		typeof count === 'number' ? from + items.length < count : items.length === LATEST_PAGE_SIZE;

	return {
		page: normalizedPage,
		items,
		hasNextPage
	};
}

export async function fetchExploreInitial(locals: App.Locals, exploreLang: string) {
	const [featuredSections, latest] = await Promise.all([
		fetchFeaturedSections(locals, exploreLang),
		fetchLatestSoulersPage(locals, 1)
	]);

	return {
		exploreLang,
		featuredSections,
		latest
	};
}
