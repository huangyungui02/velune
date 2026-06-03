import type { AdminActionResult } from '$lib/server/admin-common';
import {
	parseCreateSectionForm,
	parseSaveSectionForm,
	parseSaveSectionItemsForm,
	parseSectionIdForm,
	parseSectionItemForm,
	parseSortOrder
} from '$lib/server/admin-forms';
import { createAvatarResolver, normalizeWikiId } from '$lib/server/avatar';
import { searchCheckedSoulers } from '$lib/server/souler-search';
import type {
	AdminDiscoverSectionDetail,
	AdminDiscoverSectionListItem,
	AdminDiscoverSectionSoulerOption
} from '$lib/types';

type DiscoverSectionRow = {
	id: string;
	sort_order: number;
	is_active: boolean;
	updated_at: string;
	discover_section_profile:
		| {
				lang: string;
				title: string;
				subtitle: string | null;
		  }[]
		| null;
};

type DiscoverSectionItemRow = {
	souler_id: string;
	sort_order: number;
	soulers:
		| {
				id: string;
				wiki_id: string | null;
				checked: boolean;
				souler_profile:
					| {
							name: string;
							lang: string;
					  }[]
					| null;
		  }[]
		| {
				id: string;
				wiki_id: string | null;
				checked: boolean;
				souler_profile:
					| {
							name: string;
							lang: string;
					  }[]
					| null;
		  }
		| null;
};

type SoulerOptionRow = {
	id: string;
	wiki_id: string | null;
	checked: boolean;
	souler_profile:
		| {
				name: string;
				lang: string;
		  }[]
		| null;
};

const candidateSearchLimit = 12;

export async function fetchDiscoverSectionCount(locals: App.Locals) {
	const { count } = await locals.supabase
		.from('discover_sections')
		.select('id', { count: 'exact', head: true });

	return count ?? 0;
}

export async function fetchDiscoverSections(locals: App.Locals) {
	const { data: sectionsRaw } = await locals.supabase
		.from('discover_sections')
		.select('id, sort_order, is_active, updated_at, discover_section_profile!inner(lang, title, subtitle)')
		.eq('discover_section_profile.lang', 'zh')
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
			if (sectionId) {
				counts.set(sectionId, (counts.get(sectionId) ?? 0) + 1);
			}
		}
	}

	return sections.map(
		(section): AdminDiscoverSectionListItem => {
			const profile = section.discover_section_profile?.[0];
			return {
				id: section.id,
				lang: profile?.lang?.trim() || 'zh',
				title: profile?.title?.trim() || '未命名分组',
				subtitle: profile?.subtitle?.trim() || '',
				sortOrder: Number(section.sort_order ?? 0),
				isActive: Boolean(section.is_active),
				itemCount: counts.get(section.id) ?? 0,
				updatedAt: section.updated_at
			};
		}
	);
}

export async function fetchDiscoverSectionDetail(locals: App.Locals, sectionId: string) {
	const { data: sectionRaw } = await locals.supabase
		.from('discover_sections')
		.select('id, sort_order, is_active, discover_section_profile!inner(lang, title, subtitle)')
		.eq('id', sectionId)
		.eq('discover_section_profile.lang', 'zh')
		.maybeSingle();

	if (!sectionRaw) {
		return null;
	}

	const section = sectionRaw as Omit<DiscoverSectionRow, 'updated_at'>;
	const sectionProfile = section.discover_section_profile?.[0];
	const lang = sectionProfile?.lang?.trim() || 'zh';
	const { data: itemsRaw } = await locals.supabase
		.from('discover_section_items')
		.select('souler_id, sort_order, soulers!inner(id, wiki_id, checked, souler_profile!inner(name, lang))')
		.eq('section_id', sectionId)
		.eq('soulers.souler_profile.lang', lang)
		.order('sort_order', { ascending: true });

	const itemRows = (itemsRaw ?? []) as DiscoverSectionItemRow[];
	const itemSoulerRows = itemRows
		.map((item) => (Array.isArray(item.soulers) ? item.soulers[0] : item.soulers))
		.filter(Boolean) as SoulerOptionRow[];

	const avatarResolver = createAvatarResolver(locals);
	const avatarByWikiId = await avatarResolver.map(itemSoulerRows.map((row) => row.wiki_id));

	const items = itemRows
		.map((item) => {
			const souler = Array.isArray(item.soulers) ? item.soulers[0] : item.soulers;
			if (!souler) {
				return null;
			}

			const wikiId = normalizeWikiId(souler.wiki_id);
			const profile = souler.souler_profile?.[0];
			return {
				soulerId: souler.id,
				soulerName: profile?.name?.trim() || '未命名人物',
				lang: profile?.lang?.trim() || lang,
				sortOrder: Number(item.sort_order ?? 0),
				imageUrl: wikiId ? (avatarByWikiId.get(wikiId) ?? null) : null
			};
		})
		.filter(Boolean) as AdminDiscoverSectionDetail['items'];

	return {
		id: section.id,
		lang,
		title: sectionProfile?.title?.trim() || '',
		subtitle: sectionProfile?.subtitle?.trim() || '',
		sortOrder: Number(section.sort_order ?? 0),
		isActive: Boolean(section.is_active),
		items,
		availableSoulers: []
	} as AdminDiscoverSectionDetail;
}

export async function searchDiscoverSectionCandidates(
	locals: App.Locals,
	sectionId: string,
	query: string
) {
	const normalizedQuery = query.trim();
	if (normalizedQuery.length === 0) {
		return [] satisfies AdminDiscoverSectionSoulerOption[];
	}

	const { data: sectionRaw } = await locals.supabase
		.from('discover_sections')
		.select('id, discover_section_profile!inner(lang)')
		.eq('id', sectionId)
		.eq('discover_section_profile.lang', 'zh')
		.maybeSingle();

	if (!sectionRaw) {
		return null;
	}

	const section = sectionRaw as Pick<DiscoverSectionRow, 'id' | 'discover_section_profile'>;
	const lang = section.discover_section_profile?.[0]?.lang?.trim() || 'zh';
	const { data: itemRowsRaw } = await locals.supabase
		.from('discover_section_items')
		.select('souler_id')
		.eq('section_id', sectionId);
	const includedSoulerIds = new Set(
		((itemRowsRaw ?? []) as { souler_id: string | null }[])
			.map((row) => row.souler_id?.trim())
			.filter(Boolean) as string[]
	);

	const candidates = await searchCheckedSoulers(locals, {
		query: normalizedQuery,
		lang,
		excludeIds: includedSoulerIds,
		limit: candidateSearchLimit
	});

	return candidates.map((row): AdminDiscoverSectionSoulerOption => {
		return {
			id: row.id,
			name: row.name,
			lang: row.lang || lang,
			imageUrl: row.imageUrl
		};
	});
}

export async function createSection(
	locals: App.Locals,
	formData: FormData
): Promise<
	AdminActionResult<{
		action: 'createSection';
		lang?: string;
		title?: string;
		subtitle?: string;
		sort_order?: string;
		id?: string;
	}>
> {
	const parsed = parseCreateSectionForm(formData);
	const draft = {
		action: 'createSection' as const,
		lang: parsed.lang,
		title: parsed.title,
		subtitle: parsed.subtitle,
		sort_order: parsed.sortOrderRaw
	};

	if (!parsed.title) {
		return { ok: false, status: 400, data: { ...draft, message: '请输入分组标题。' } };
	}
	if (!Number.isFinite(parsed.sortOrder)) {
		return { ok: false, status: 400, data: { ...draft, message: 'sort_order 必须是数字。' } };
	}

	const { data: insertedRaw, error } = await locals.supabase
		.from('discover_sections')
		.insert({
			sort_order: Math.floor(parsed.sortOrder),
			is_active: true
		})
		.select('id')
		.single();

	if (error || !insertedRaw) {
		return {
			ok: false,
			status: 400,
			data: { ...draft, message: error?.message || '创建精选分组失败。' }
		};
	}

	const sectionId = (insertedRaw as { id: string }).id;
	const { error: profileError } = await locals.supabase.from('discover_section_profile').insert({
		section_id: sectionId,
		lang: parsed.lang,
		title: parsed.title,
		subtitle: parsed.subtitle || null
	});
	if (profileError) {
		return {
			ok: false,
			status: 400,
			data: { ...draft, message: profileError.message }
		};
	}

	return { ok: true, data: { ...draft, id: sectionId } };
}

export async function saveSection(
	locals: App.Locals,
	formData: FormData
): Promise<AdminActionResult<{ action: 'saveSection'; sectionId: string }>> {
	const parsed = parseSaveSectionForm(formData);
	if (!parsed.sectionId) {
		return {
			ok: false,
			status: 400,
			data: { action: 'saveSection', message: '缺少 section_id。', sectionId: parsed.sectionId }
		};
	}
	if (!parsed.title) {
		return {
			ok: false,
			status: 400,
			data: { action: 'saveSection', message: '请输入分组标题。', sectionId: parsed.sectionId }
		};
	}
	if (parsed.sortOrder === null) {
		return {
			ok: false,
			status: 400,
			data: {
				action: 'saveSection',
				message: 'sort_order 必须是数字。',
				sectionId: parsed.sectionId
			}
		};
	}

	const { error } = await locals.supabase
		.from('discover_sections')
		.update({
			sort_order: parsed.sortOrder,
			is_active: parsed.isActive
		})
		.eq('id', parsed.sectionId);

	if (error) {
		return {
			ok: false,
			status: 400,
			data: { action: 'saveSection', message: error.message, sectionId: parsed.sectionId }
		};
	}

	const { error: profileError } = await locals.supabase.from('discover_section_profile').upsert(
		{
			section_id: parsed.sectionId,
			lang: parsed.lang,
			title: parsed.title,
			subtitle: parsed.subtitle || null
		},
		{ onConflict: 'section_id,lang' }
	);
	if (profileError) {
		return {
			ok: false,
			status: 400,
			data: { action: 'saveSection', message: profileError.message, sectionId: parsed.sectionId }
		};
	}

	return { ok: true, data: { action: 'saveSection', sectionId: parsed.sectionId } };
}

export async function addSectionItem(
	locals: App.Locals,
	formData: FormData
): Promise<AdminActionResult<{ action: 'addItem'; sectionId: string }>> {
	const { sectionId, soulerId } = parseSectionItemForm(formData);
	if (!sectionId || !soulerId) {
		return {
			ok: false,
			status: 400,
			data: { action: 'addItem', message: '请选择要加入分组的人物。', sectionId }
		};
	}

	const { data: lastRaw } = await locals.supabase
		.from('discover_section_items')
		.select('sort_order')
		.eq('section_id', sectionId)
		.order('sort_order', { ascending: false })
		.limit(1)
		.maybeSingle();
	const lastSortOrder = Number((lastRaw as { sort_order?: number } | null)?.sort_order ?? -1);
	const nextSortOrder = Number.isFinite(lastSortOrder) ? lastSortOrder + 1 : 0;

	const { error } = await locals.supabase.from('discover_section_items').insert({
		section_id: sectionId,
		souler_id: soulerId,
		sort_order: nextSortOrder
	});

	if (error) {
		return {
			ok: false,
			status: 400,
			data: { action: 'addItem', message: error.message, sectionId }
		};
	}

	return { ok: true, data: { action: 'addItem', sectionId } };
}

export async function saveSectionItems(
	locals: App.Locals,
	formData: FormData
): Promise<AdminActionResult<{ action: 'saveItems'; sectionId: string }>> {
	const parsed = parseSaveSectionItemsForm(formData);
	if (!parsed.sectionId) {
		return {
			ok: false,
			status: 400,
			data: { action: 'saveItems', message: '缺少 section_id。', sectionId: parsed.sectionId }
		};
	}

	const rows: { section_id: string; souler_id: string; sort_order: number }[] = [];
	for (let index = 0; index < parsed.soulerIds.length; index += 1) {
		const soulerId = parsed.soulerIds[index];
		if (parsed.removedSoulerIds.has(soulerId)) {
			continue;
		}
		const sortOrder = parseSortOrder(parsed.sortOrders[index] ?? '');
		if (sortOrder === null) {
			return {
				ok: false,
				status: 400,
				data: {
					action: 'saveItems',
					message: `第 ${index + 1} 条人物的排序值无效。`,
					sectionId: parsed.sectionId
				}
			};
		}
		rows.push({ section_id: parsed.sectionId, souler_id: soulerId, sort_order: sortOrder });
	}

	if (parsed.removedSoulerIds.size > 0) {
		const { error } = await locals.supabase
			.from('discover_section_items')
			.delete()
			.eq('section_id', parsed.sectionId)
			.in('souler_id', Array.from(parsed.removedSoulerIds));

		if (error) {
			return {
				ok: false,
				status: 400,
				data: { action: 'saveItems', message: error.message, sectionId: parsed.sectionId }
			};
		}
	}

	if (rows.length > 0) {
		const { error } = await locals.supabase
			.from('discover_section_items')
			.upsert(rows, { onConflict: 'section_id,souler_id' });

		if (error) {
			return {
				ok: false,
				status: 400,
				data: { action: 'saveItems', message: error.message, sectionId: parsed.sectionId }
			};
		}
	}

	return { ok: true, data: { action: 'saveItems', sectionId: parsed.sectionId } };
}

export async function deleteSection(
	locals: App.Locals,
	formData: FormData
): Promise<AdminActionResult<{ action: 'deleteSection'; sectionId: string }>> {
	const { sectionId } = parseSectionIdForm(formData);
	if (!sectionId) {
		return {
			ok: false,
			status: 400,
			data: { action: 'deleteSection', message: '缺少 section_id。', sectionId }
		};
	}

	const { data: deletedRows, error } = await locals.supabase
		.from('discover_sections')
		.delete()
		.eq('id', sectionId)
		.select('id');

	if (error) {
		return {
			ok: false,
			status: 400,
			data: { action: 'deleteSection', message: error.message, sectionId }
		};
	}
	if (!deletedRows || deletedRows.length === 0) {
		return {
			ok: false,
			status: 404,
			data: { action: 'deleteSection', message: '分组不存在。', sectionId }
		};
	}

	return { ok: true, data: { action: 'deleteSection', sectionId } };
}
