import { fail, redirect } from '@sveltejs/kit';
import {
	adminNoticeText,
	assertAdmin,
	createSection,
	createSouler,
	fetchDiscoverSections,
	normalizeAdminTab
} from '$lib/server/admin';
import type { Actions, PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ parent, url, locals }) => {
	const parentData = await parent();
	const activeTab = normalizeAdminTab(url.searchParams.get('tab'));
	const discoverSections = activeTab === 'sections' ? await fetchDiscoverSections(locals) : [];

	return {
		activeTab,
		visibleSoulers:
			activeTab === 'unchecked' || activeTab === 'checked' ? parentData.visibleSoulers : [],
		discoverSections,
		notice: adminNoticeText(url.searchParams.get('ok'))
	};
};

export const actions: Actions = {
	createSouler: async ({ request, locals }) => {
		const adminContext = await assertAdmin(locals);
		if (!adminContext) {
			return fail(403, {
				action: 'createSouler',
				message: '没有权限执行该操作。',
				name: '',
				language: 'zh'
			});
		}

		const { session } = await locals.safeGetSession();
		const accessToken = session?.access_token;
		if (!accessToken) {
			return fail(401, {
				action: 'createSouler',
				message: '登录状态已失效。',
				name: '',
				language: 'zh'
			});
		}

		const result = await createSouler(await request.formData(), accessToken);
		if (!result.ok) {
			return fail(result.status, result.data);
		}

		if (result.data.id) {
			redirect(303, `/admin/${encodeURIComponent(result.data.id)}?tab=create&ok=created`);
		}

		return {
			...result.data,
			message: '人物正在创建中，请稍候。'
		};
	},

	createSection: async ({ request, locals }) => {
		if (!(await assertAdmin(locals))) {
			return fail(403, { action: 'createSection', message: '没有权限执行该操作。' });
		}

		const result = await createSection(locals, await request.formData());
		if (!result.ok) {
			return fail(result.status, result.data);
		}

		redirect(
			303,
			`/admin/discover/${encodeURIComponent(result.data.id ?? '')}?tab=sections&ok=section-created`
		);
	}
};
