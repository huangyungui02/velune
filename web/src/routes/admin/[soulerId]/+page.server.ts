import { error, fail, redirect } from '@sveltejs/kit';
import {
	adminNoticeText,
	assertAdmin,
	deleteSouler,
	fetchSoulerDetail,
	normalizeAdminTab,
	saveChapters,
	saveSouler,
	uploadAvatar
} from '$lib/server/admin';
import type { Actions, PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ locals, params, url }) => {
	if (!(await assertAdmin(locals))) {
		redirect(303, '/bookshelf');
	}

	const soulerId = params.soulerId?.trim() ?? '';
	if (!soulerId) {
		error(404, 'Souler not found');
	}

	const souler = await fetchSoulerDetail(locals, soulerId);
	if (!souler) {
		error(404, 'Souler not found');
	}

	return {
		souler,
		tab: normalizeAdminTab(url.searchParams.get('tab')),
		notice: adminNoticeText(url.searchParams.get('ok'))
	};
};

export const actions: Actions = {
	saveSouler: async ({ request, locals }) => {
		if (!(await assertAdmin(locals))) {
			return fail(403, { action: 'saveSouler', message: '没有权限执行该操作。' });
		}

		const result = await saveSouler(locals, await request.formData());
		if (!result.ok) {
			return fail(result.status, result.data);
		}

		redirect(
			303,
			`/admin/${encodeURIComponent(result.data.soulerId)}?tab=${result.data.tab}&ok=saved`
		);
	},

	saveChapters: async ({ request, locals }) => {
		if (!(await assertAdmin(locals))) {
			return fail(403, { action: 'saveChapters', message: '没有权限执行该操作。' });
		}

		const result = await saveChapters(locals, await request.formData());
		if (!result.ok) {
			return fail(result.status, result.data);
		}

		redirect(
			303,
			`/admin/${encodeURIComponent(result.data.soulerId)}?tab=${result.data.tab}&ok=chapters`
		);
	},

	deleteSouler: async ({ request, locals }) => {
		if (!(await assertAdmin(locals))) {
			return fail(403, { action: 'deleteSouler', message: '没有权限执行该操作。' });
		}

		const result = await deleteSouler(locals, await request.formData());
		if (!result.ok) {
			return fail(result.status, result.data);
		}

		redirect(303, `/admin?tab=${result.data.tab}&ok=deleted`);
	},

	uploadAvatar: async ({ request, locals }) => {
		if (!(await assertAdmin(locals))) {
			return fail(403, { action: 'uploadAvatar', message: '没有权限执行该操作。' });
		}

		const result = await uploadAvatar(locals, await request.formData());
		if (!result.ok) {
			return fail(result.status, result.data);
		}

		redirect(
			303,
			`/admin/${encodeURIComponent(result.data.soulerId)}?tab=${result.data.tab}&ok=avatar`
		);
	}
};
