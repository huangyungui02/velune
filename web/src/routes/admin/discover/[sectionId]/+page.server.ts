import { error, fail, redirect } from '@sveltejs/kit';
import {
	addSectionItem,
	adminNoticeText,
	assertAdmin,
	deleteSection,
	fetchDiscoverSectionDetail,
	normalizeAdminTab,
	saveSection,
	saveSectionItems
} from '$lib/server/admin';
import type { Actions, PageServerLoad } from './$types';

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

		const result = await saveSection(locals, await request.formData());
		if (!result.ok) {
			return fail(result.status, result.data);
		}

		redirect(
			303,
			`/admin/discover/${encodeURIComponent(result.data.sectionId)}?tab=sections&ok=section-saved`
		);
	},

	addItem: async ({ request, locals }) => {
		if (!(await assertAdmin(locals))) {
			return fail(403, { action: 'addItem', message: '没有权限执行该操作。' });
		}

		const result = await addSectionItem(locals, await request.formData());
		if (!result.ok) {
			return fail(result.status, result.data);
		}

		redirect(
			303,
			`/admin/discover/${encodeURIComponent(result.data.sectionId)}?tab=sections&ok=section-item-added`
		);
	},

	saveItems: async ({ request, locals }) => {
		if (!(await assertAdmin(locals))) {
			return fail(403, { action: 'saveItems', message: '没有权限执行该操作。' });
		}

		const result = await saveSectionItems(locals, await request.formData());
		if (!result.ok) {
			return fail(result.status, result.data);
		}

		redirect(
			303,
			`/admin/discover/${encodeURIComponent(result.data.sectionId)}?tab=sections&ok=section-items-saved`
		);
	},

	deleteSection: async ({ request, locals }) => {
		if (!(await assertAdmin(locals))) {
			return fail(403, { action: 'deleteSection', message: '没有权限执行该操作。' });
		}

		const result = await deleteSection(locals, await request.formData());
		if (!result.ok) {
			return fail(result.status, result.data);
		}

		redirect(303, '/admin?tab=sections&ok=section-deleted');
	}
};
