import { redirect } from '@sveltejs/kit';
import { getAgentApiBaseUrl } from '$lib/server/agent';
import { fetchAvatarMap, normalizeWikiId } from '$lib/server/avatar';
import { isAdminUser } from '$lib/server/roles';
import type {
	AdminDiscoverSectionDetail,
	AdminDiscoverSectionListItem,
	AdminDiscoverSectionSoulerOption,
	AdminSoulerChapter,
	AdminSoulerDetail,
	AdminSoulerListItem
} from '$lib/types';

type SoulerListRow = {
	id: string;
	name: string;
	lang: string;
	checked: boolean;
	wiki_id: string | null;
};

type SoulerDetailRow = {
	id: string;
	name: string;
	lang: string;
	bio: string | null;
	checked: boolean;
	canonical_name: string | null;
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

type ChapterRow = AdminSoulerChapter;

type CanonicalizeResponse = {
	canonical_name?: string;
	error?: string;
};

type DiscoverSectionRow = {
	id: string;
	lang: string;
	key: string;
	title: string;
	subtitle: string | null;
	sort_order: number;
	is_active: boolean;
	updated_at: string;
};

type DiscoverSectionItemRow = {
	souler_id: string;
	sort_order: number;
	soulers:
		| {
				id: string;
				name: string;
				lang: string;
				wiki_id: string | null;
				checked: boolean;
		  }[]
		| {
				id: string;
				name: string;
				lang: string;
				wiki_id: string | null;
				checked: boolean;
		  }
		| null;
};

type SoulerOptionRow = {
	id: string;
	name: string;
	lang: string;
	wiki_id: string | null;
	checked: boolean;
};

export type AdminTab = 'unchecked' | 'checked' | 'create' | 'sections';

export const AVATAR_BUCKET = 'avatars';
export const MAX_AVATAR_BYTES = 5 * 1024 * 1024;

export function normalizeText(value: FormDataEntryValue | null) {
	return typeof value === 'string' ? value.trim() : '';
}

export function normalizeLang(value: FormDataEntryValue | null) {
	const raw = normalizeText(value).toLowerCase();
	return raw || 'zh';
}

export function normalizeNameKey(value: string) {
	return value.trim().toLowerCase();
}

export function normalizeAdminTab(value: string | null): AdminTab {
	const raw = (value ?? '').trim().toLowerCase();
	if (raw === 'checked') {
		return 'checked';
	}
	if (raw === 'create') {
		return 'create';
	}
	if (raw === 'sections') {
		return 'sections';
	}
	return 'unchecked';
}

export function normalizeSectionKey(value: FormDataEntryValue | null) {
	const normalized = normalizeText(value)
		.toLowerCase()
		.replace(/[\s_]+/g, '-')
		.replace(/[^a-z0-9-]/g, '-')
		.replace(/-+/g, '-')
		.replace(/^-+|-+$/g, '');

	return normalized.slice(0, 64);
}

export function clampWeight(value: number) {
	if (!Number.isFinite(value)) {
		return 0.5;
	}
	return Math.max(0, Math.min(1, Number(value.toFixed(4))));
}

export async function assertAdmin(locals: App.Locals) {
	const { session, user } = await locals.safeGetSession();
	if (!session || !user) {
		redirect(303, '/auth');
	}

	const isAdmin = await isAdminUser(locals.supabase, user.id);
	if (!isAdmin) {
		return null;
	}

	return { session, user };
}

export async function fetchSoulerLists(locals: App.Locals) {
	const { data: uncheckedRaw } = await locals.supabase
		.from('soulers')
		.select('id, name, lang, checked, wiki_id')
		.eq('checked', false)
		.order('name', { ascending: true });

	const { data: checkedRaw } = await locals.supabase
		.from('soulers')
		.select('id, name, lang, checked, wiki_id')
		.eq('checked', true)
		.order('name', { ascending: true });

	const rows = [
		...((uncheckedRaw ?? []) as SoulerListRow[]),
		...((checkedRaw ?? []) as SoulerListRow[])
	] as SoulerListRow[];
	const avatarByWikiId = await fetchAvatarMap(
		locals,
		rows.map((row) => row.wiki_id)
	);

	const toItem = (row: SoulerListRow): AdminSoulerListItem => {
		const wikiId = normalizeWikiId(row.wiki_id);
		return {
			id: row.id,
			name: row.name?.trim() || '未命名人物',
			lang: row.lang?.trim() || 'zh',
			checked: row.checked,
			imageUrl: wikiId ? (avatarByWikiId.get(wikiId) ?? null) : null
		};
	};

	return {
		unchecked: ((uncheckedRaw ?? []) as SoulerListRow[]).map(toItem),
		checked: ((checkedRaw ?? []) as SoulerListRow[]).map(toItem)
	};
}

export async function fetchSoulerDetail(locals: App.Locals, soulerId: string) {
	const { data: soulerRaw } = await locals.supabase
		.from('soulers')
		.select('id, name, lang, bio, checked, canonical_name, wiki_id')
		.eq('id', soulerId)
		.maybeSingle();

	if (!soulerRaw) {
		return null;
	}

	const souler = soulerRaw as SoulerDetailRow;
	const wikiId = normalizeWikiId(souler.wiki_id);
	const avatarByWikiId = await fetchAvatarMap(locals, [wikiId]);

	const { data: keywordRaw } = await locals.supabase
		.from('souler_keyword')
		.select('weight, keywords!inner(word)')
		.eq('souler_id', soulerId)
		.order('weight', { ascending: false })
		.limit(30);

	const keywords = ((keywordRaw ?? []) as KeywordRow[])
		.map((item) => {
			const keywordItem = Array.isArray(item.keywords) ? item.keywords[0] : item.keywords;
			return {
				word: keywordItem?.word?.trim() ?? '',
				weight: clampWeight(Number(item.weight ?? 0.5))
			};
		})
		.filter((item) => item.word);

	const { data: chaptersRaw } = await locals.supabase
		.from('chapters')
		.select('id, seq, title, subtitle, role, task')
		.eq('souler_id', soulerId)
		.order('seq', { ascending: true });

	const chapters = (chaptersRaw ?? []) as ChapterRow[];

	const detail: AdminSoulerDetail = {
		id: souler.id,
		name: souler.name?.trim() || '',
		lang: souler.lang?.trim() || 'zh',
		bio: souler.bio ?? '',
		checked: souler.checked,
		canonicalName: souler.canonical_name?.trim() || '',
		wikidata: wikiId ?? '',
		imageUrl: wikiId ? (avatarByWikiId.get(wikiId) ?? null) : null,
		keywords,
		chapters
	};

	return detail;
}

export async function fetchDiscoverSectionCount(locals: App.Locals) {
	const { count } = await locals.supabase
		.from('discover_sections')
		.select('id', { count: 'exact', head: true });

	return count ?? 0;
}

export async function fetchDiscoverSections(locals: App.Locals) {
	const { data: sectionsRaw } = await locals.supabase
		.from('discover_sections')
		.select('id, lang, key, title, subtitle, sort_order, is_active, updated_at')
		.order('lang', { ascending: true })
		.order('sort_order', { ascending: true })
		.order('updated_at', { ascending: false });

	const sections = (sectionsRaw ?? []) as DiscoverSectionRow[];
	const sectionIds = sections.map((section) => section.id);
	const counts = new Map<string, number>();

	if (sectionIds.length > 0) {
		const { data: itemRowsRaw } = await locals.supabase
			.from('discover_section_items')
			.select('section_id')
			.in('section_id', sectionIds);

		for (const row of (itemRowsRaw ?? []) as { section_id: string }[]) {
			const sectionId = row.section_id?.trim();
			if (!sectionId) {
				continue;
			}
			counts.set(sectionId, (counts.get(sectionId) ?? 0) + 1);
		}
	}

	return sections.map(
		(section): AdminDiscoverSectionListItem => ({
			id: section.id,
			lang: section.lang?.trim() || 'zh',
			key: section.key?.trim() || '',
			title: section.title?.trim() || '未命名分组',
			subtitle: section.subtitle?.trim() || '',
			sortOrder: Number(section.sort_order ?? 0),
			isActive: Boolean(section.is_active),
			itemCount: counts.get(section.id) ?? 0,
			updatedAt: section.updated_at
		})
	);
}

export async function fetchDiscoverSectionDetail(locals: App.Locals, sectionId: string) {
	const { data: sectionRaw } = await locals.supabase
		.from('discover_sections')
		.select('id, lang, key, title, subtitle, sort_order, is_active')
		.eq('id', sectionId)
		.maybeSingle();

	if (!sectionRaw) {
		return null;
	}

	const section = sectionRaw as Omit<DiscoverSectionRow, 'updated_at'>;
	const { data: itemsRaw } = await locals.supabase
		.from('discover_section_items')
		.select('souler_id, sort_order, soulers!inner(id, name, lang, wiki_id, checked)')
		.eq('section_id', sectionId)
		.order('sort_order', { ascending: true });

	const itemRows = (itemsRaw ?? []) as DiscoverSectionItemRow[];
	const soulerRows = itemRows
		.map((item) => (Array.isArray(item.soulers) ? item.soulers[0] : item.soulers))
		.filter(Boolean) as {
		id: string;
		name: string;
		lang: string;
		wiki_id: string | null;
		checked: boolean;
	}[];
	const avatarByWikiId = await fetchAvatarMap(
		locals,
		soulerRows.map((row) => row.wiki_id)
	);

	const items = itemRows
		.map((item) => {
			const souler = Array.isArray(item.soulers) ? item.soulers[0] : item.soulers;
			if (!souler) {
				return null;
			}

			const wikiId = normalizeWikiId(souler.wiki_id);
			return {
				soulerId: souler.id,
				soulerName: souler.name?.trim() || '未命名人物',
				lang: souler.lang?.trim() || section.lang?.trim() || 'zh',
				sortOrder: Number(item.sort_order ?? 0),
				imageUrl: wikiId ? (avatarByWikiId.get(wikiId) ?? null) : null
			};
		})
		.filter(Boolean) as AdminDiscoverSectionDetail['items'];

	const includedSoulerIds = new Set(items.map((item) => item.soulerId));
	const { data: candidatesRaw } = await locals.supabase
		.from('soulers')
		.select('id, name, lang, wiki_id, checked')
		.eq('lang', section.lang)
		.eq('checked', true)
		.order('name', { ascending: true });

	const candidateRows = (candidatesRaw ?? []) as SoulerOptionRow[];
	const candidateAvatarByWikiId = await fetchAvatarMap(
		locals,
		candidateRows.map((row) => row.wiki_id)
	);

	const availableSoulers = candidateRows
		.filter((row) => !includedSoulerIds.has(row.id))
		.map((row): AdminDiscoverSectionSoulerOption => {
			const wikiId = normalizeWikiId(row.wiki_id);
			return {
				id: row.id,
				name: row.name?.trim() || '未命名人物',
				lang: row.lang?.trim() || section.lang?.trim() || 'zh',
				imageUrl: wikiId ? (candidateAvatarByWikiId.get(wikiId) ?? null) : null
			};
		});

	return {
		id: section.id,
		lang: section.lang?.trim() || 'zh',
		key: section.key?.trim() || '',
		title: section.title?.trim() || '',
		subtitle: section.subtitle?.trim() || '',
		sortOrder: Number(section.sort_order ?? 0),
		isActive: Boolean(section.is_active),
		items,
		availableSoulers
	} as AdminDiscoverSectionDetail;
}

export async function findPotentialDuplicate(
	locals: App.Locals,
	lang: string,
	candidateName: string,
	excludeSoulerId: string | null = null
) {
	const { data: soulersRaw, error } = await locals.supabase
		.from('soulers')
		.select('id, name, canonical_name, lang')
		.eq('lang', lang);

	if (error) {
		return null;
	}

	const targetKey = normalizeNameKey(candidateName);
	for (const row of soulersRaw ?? []) {
		const soulerId = String((row as { id?: unknown }).id ?? '').trim();
		if (!soulerId || (excludeSoulerId && soulerId === excludeSoulerId)) {
			continue;
		}

		const rowName = normalizeNameKey(String((row as { name?: unknown }).name ?? ''));
		const rowCanonical = normalizeNameKey(
			String((row as { canonical_name?: unknown }).canonical_name ?? '')
		);

		if (rowName === targetKey || rowCanonical === targetKey) {
			return {
				id: soulerId,
				name: String((row as { name?: unknown }).name ?? '').trim()
			};
		}
	}

	return null;
}

export async function canonicalizeWithLlm(
	accessToken: string,
	lang: string,
	name: string
): Promise<string> {
	const baseUrl = getAgentApiBaseUrl();
	const endpoint = `${baseUrl}/${lang}/soulers/canonicalize`;

	const response = await fetch(endpoint, {
		method: 'POST',
		headers: {
			authorization: `Bearer ${accessToken}`,
			accept: 'application/json',
			'content-type': 'application/json'
		},
		body: JSON.stringify({ name })
	});

	const payload = (await response.json().catch(() => null)) as CanonicalizeResponse | null;
	if (!response.ok) {
		throw new Error(payload?.error || 'canonical name 生成失败');
	}

	const canonicalName = payload?.canonical_name?.trim() ?? '';
	if (!canonicalName) {
		throw new Error('canonical name 为空');
	}

	return canonicalName;
}

export function adminNoticeText(code: string | null) {
	switch (code) {
		case 'saved':
			return '人物信息已保存。';
		case 'chapters':
			return '章节信息已保存。';
		case 'avatar':
			return '头像已更新。';
		case 'created':
			return '人物已创建。';
		case 'deleted':
			return '人物已删除，关联数据已清理。';
		case 'section-created':
			return '精选分组已创建。';
		case 'section-saved':
			return '精选分组已保存。';
		case 'section-deleted':
			return '精选分组已删除。';
		case 'section-item-added':
			return '人物已加入分组。';
		case 'section-items-saved':
			return '分组排序已保存。';
		case 'section-item-removed':
			return '人物已移出分组。';
		default:
			return '';
	}
}
