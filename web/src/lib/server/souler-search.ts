import { createAvatarResolver, normalizeWikiId } from '$lib/server/avatar';
import type { ExploreSoulerItem } from '$lib/types';

export type SoulerSearchItem = ExploreSoulerItem & {
	lang: string;
};

type SearchableSoulerRow = {
	id: string;
	wiki_id: string | null;
	souler_profile:
		| {
				name: string;
				lang: string;
		  }[]
		| null;
};

type SearchCheckedSoulersOptions = {
	query: string;
	lang?: string | null;
	excludeIds?: Iterable<string>;
	limit?: number;
};

const defaultSearchLimit = 24;

function escapeSearchPattern(value: string) {
	return value.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_');
}

function normalizeSearchQuery(query: string) {
	return query.trim().replace(/\s+/g, ' ').slice(0, 80);
}

async function fetchSearchRows(
	locals: App.Locals,
	options: {
		pattern: string;
		lang: string | null;
		excludeIds: Set<string>;
		limit: number;
	}
) {
	let builder = locals.supabase
		.from('soulers')
		.select('id, wiki_id, souler_profile!inner(name, lang)')
		.eq('checked', true)
		.ilike('souler_profile.name', options.pattern)
		.order('updated_at', { ascending: false })
		.limit(options.limit);

	if (options.lang) {
		builder = builder.eq('souler_profile.lang', options.lang);
	}

	if (options.excludeIds.size > 0) {
		builder = builder.not('id', 'in', `(${Array.from(options.excludeIds).join(',')})`);
	}

	const { data } = await builder;
	return (data ?? []) as SearchableSoulerRow[];
}

export async function searchCheckedSoulers(
	locals: App.Locals,
	options: SearchCheckedSoulersOptions
) {
	const normalizedQuery = normalizeSearchQuery(options.query);
	if (!normalizedQuery) {
		return [] satisfies SoulerSearchItem[];
	}

	const limit =
		Number.isFinite(options.limit) && options.limit && options.limit > 0
			? Math.min(Math.trunc(options.limit), 50)
			: defaultSearchLimit;
	const lang = options.lang?.trim() || null;
	const excludeIds = new Set(
		Array.from(options.excludeIds ?? [])
			.map((id) => id.trim())
			.filter(Boolean)
	);
	const escapedQuery = escapeSearchPattern(normalizedQuery);
	const prefixRows = await fetchSearchRows(locals, {
		pattern: `${escapedQuery}%`,
		lang,
		excludeIds,
		limit
	});

	const rowsById = new Map(prefixRows.map((row) => [row.id, row]));
	if (rowsById.size < limit) {
		for (const row of prefixRows) {
			excludeIds.add(row.id);
		}

		const fuzzyRows = await fetchSearchRows(locals, {
			pattern: `%${escapedQuery}%`,
			lang,
			excludeIds,
			limit: limit - rowsById.size
		});

		for (const row of fuzzyRows) {
			rowsById.set(row.id, row);
		}
	}

	const rows = Array.from(rowsById.values());
	const avatarResolver = createAvatarResolver(locals);
	const avatarByWikiId = await avatarResolver.map(rows.map((row) => row.wiki_id));

	return rows.map((row): SoulerSearchItem => {
		const wikiId = normalizeWikiId(row.wiki_id);
		return {
			id: row.id,
			name: row.souler_profile?.[0]?.name?.trim() || '未命名人物',
			lang: row.souler_profile?.[0]?.lang?.trim() || lang || 'zh',
			imageUrl: wikiId ? (avatarByWikiId.get(wikiId) ?? null) : null,
			tags: []
		};
	});
}
