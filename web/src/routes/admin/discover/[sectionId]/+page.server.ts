import { error, fail, redirect } from '@sveltejs/kit';
import {
	adminNoticeText,
	assertAdmin,
	fetchDiscoverSectionDetail,
	normalizeAdminTab,
	normalizeLang,
	normalizeSectionKey,
	normalizeText
} from '$lib/server/admin';
import type { Actions, PageServerLoad } from './$types';

function parseSortOrder(raw: string) {
	const number = Number(raw);
	if (!Number.isFinite(number)) {
		return null;
	}
	return Math.floor(number);
}

export const load: PageServerLoad = async ({ locals, params, url }) => {
	if (!(await assertAdmin(locals))) {
		redirect(303, '/bookshelf');
	}

	const sectionId = params.sectionId?.trim() ?? '';
	if (!sectionId) {
		error(404, 'Section not found');
	}

	const section = await fetchDiscoverSectionDetail(locals, sectionId);
	if (!section) {
		error(404, 'Section not found');
	}

	return {
		section,
		tab: normalizeAdminTab(url.searchParams.get('tab')),
		notice: adminNoticeText(url.searchParams.get('ok'))
	};
};

export const actions: Actions = {
	saveSection: async ({ request, locals }) => {
		if (!(await assertAdmin(locals))) {
			return fail(403, { action: 'saveSection', message: '没有权限执行该操作。' });
		}

		const formData = await request.formData();
		const sectionId = normalizeText(formData.get('section_id'));
		const tab = normalizeAdminTab(normalizeText(formData.get('tab')));
		const lang = normalizeLang(formData.get('lang'));
		const key = normalizeSectionKey(formData.get('key'));
		const title = normalizeText(formData.get('title'));
		const subtitle = normalizeText(formData.get('subtitle'));
		const sortOrderRaw = normalizeText(formData.get('sort_order'));
		const sortOrder = parseSortOrder(sortOrderRaw || '0');
		const isActive = formData.get('is_active') === 'on';

		if (!sectionId) {
			return fail(400, { action: 'saveSection', message: '缺少 section_id。' });
		}
		if (!title) {
			return fail(400, { action: 'saveSection', message: '请输入分组标题。', sectionId });
		}
		if (!key) {
			return fail(400, {
				action: 'saveSection',
				message: 'key 仅支持英文、数字和连字符。',
				sectionId
			});
		}
		if (sortOrder === null) {
			return fail(400, { action: 'saveSection', message: 'sort_order 必须是数字。', sectionId });
		}

		const { error: updateError } = await locals.supabase
			.from('discover_sections')
			.update({
				lang,
				key,
				title,
				subtitle: subtitle || null,
				sort_order: sortOrder,
				is_active: isActive
			})
			.eq('id', sectionId);

		if (updateError) {
			return fail(400, { action: 'saveSection', message: updateError.message, sectionId });
		}

		redirect(303, `/admin/discover/${encodeURIComponent(sectionId)}?tab=${tab}&ok=section-saved`);
	},

	addItem: async ({ request, locals }) => {
		if (!(await assertAdmin(locals))) {
			return fail(403, { action: 'addItem', message: '没有权限执行该操作。' });
		}

		const formData = await request.formData();
		const sectionId = normalizeText(formData.get('section_id'));
		const soulerId = normalizeText(formData.get('souler_id'));
		const tab = normalizeAdminTab(normalizeText(formData.get('tab')));

		if (!sectionId || !soulerId) {
			return fail(400, { action: 'addItem', message: '请选择要加入分组的人物。' });
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

		const { error: insertError } = await locals.supabase.from('discover_section_items').insert({
			section_id: sectionId,
			souler_id: soulerId,
			sort_order: nextSortOrder
		});

		if (insertError) {
			return fail(400, { action: 'addItem', message: insertError.message, sectionId });
		}

		redirect(
			303,
			`/admin/discover/${encodeURIComponent(sectionId)}?tab=${tab}&ok=section-item-added`
		);
	},

	saveItems: async ({ request, locals }) => {
		if (!(await assertAdmin(locals))) {
			return fail(403, { action: 'saveItems', message: '没有权限执行该操作。' });
		}

		const formData = await request.formData();
		const sectionId = normalizeText(formData.get('section_id'));
		const tab = normalizeAdminTab(normalizeText(formData.get('tab')));
		if (!sectionId) {
			return fail(400, { action: 'saveItems', message: '缺少 section_id。' });
		}

		const soulerIds = formData
			.getAll('item_souler_id')
			.map((entry) => String(entry ?? '').trim())
			.filter(Boolean);
		const sortOrders = formData
			.getAll('item_sort_order')
			.map((entry) => String(entry ?? '').trim());
		const removedSoulerIds = new Set(
			formData
				.getAll('remove_souler_id')
				.map((entry) => String(entry ?? '').trim())
				.filter(Boolean)
		);

		const rows: { section_id: string; souler_id: string; sort_order: number }[] = [];
		for (let index = 0; index < soulerIds.length; index += 1) {
			const soulerId = soulerIds[index];
			if (removedSoulerIds.has(soulerId)) {
				continue;
			}
			const sortOrder = parseSortOrder(sortOrders[index] ?? '');
			if (sortOrder === null) {
				return fail(400, {
					action: 'saveItems',
					message: `第 ${index + 1} 条人物的排序值无效。`,
					sectionId
				});
			}
			rows.push({
				section_id: sectionId,
				souler_id: soulerId,
				sort_order: sortOrder
			});
		}

		if (removedSoulerIds.size > 0) {
			const { error: deleteError } = await locals.supabase
				.from('discover_section_items')
				.delete()
				.eq('section_id', sectionId)
				.in('souler_id', Array.from(removedSoulerIds));

			if (deleteError) {
				return fail(400, { action: 'saveItems', message: deleteError.message, sectionId });
			}
		}

		if (rows.length > 0) {
			const { error: upsertError } = await locals.supabase
				.from('discover_section_items')
				.upsert(rows, { onConflict: 'section_id,souler_id' });

			if (upsertError) {
				return fail(400, { action: 'saveItems', message: upsertError.message, sectionId });
			}
		}

		redirect(
			303,
			`/admin/discover/${encodeURIComponent(sectionId)}?tab=${tab}&ok=section-items-saved`
		);
	},

	deleteSection: async ({ request, locals }) => {
		if (!(await assertAdmin(locals))) {
			return fail(403, { action: 'deleteSection', message: '没有权限执行该操作。' });
		}

		const formData = await request.formData();
		const sectionId = normalizeText(formData.get('section_id'));
		const tab = normalizeAdminTab(normalizeText(formData.get('tab')));

		if (!sectionId) {
			return fail(400, { action: 'deleteSection', message: '缺少 section_id。' });
		}

		const { data: deletedRows, error: deleteError } = await locals.supabase
			.from('discover_sections')
			.delete()
			.eq('id', sectionId)
			.select('id');

		if (deleteError) {
			return fail(400, { action: 'deleteSection', message: deleteError.message, sectionId });
		}

		if (!deletedRows || deletedRows.length === 0) {
			return fail(404, { action: 'deleteSection', message: '分组不存在。', sectionId });
		}

		redirect(303, `/admin?tab=${tab}&ok=section-deleted`);
	}
};
