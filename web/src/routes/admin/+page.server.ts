import { fail, redirect } from '@sveltejs/kit';
import {
	adminNoticeText,
	assertAdmin,
	canonicalizeWithLlm,
	findPotentialDuplicate,
	normalizeAdminTab,
	normalizeLang,
	normalizeText
} from '$lib/server/admin';
import type { Actions, PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ parent, url }) => {
	const parentData = await parent();
	const activeTab = normalizeAdminTab(url.searchParams.get('tab'));

	return {
		activeTab,
		visibleSoulers:
			activeTab === 'unchecked'
				? parentData.uncheckedSoulers
				: activeTab === 'checked'
					? parentData.checkedSoulers
					: [],
		notice: adminNoticeText(url.searchParams.get('ok'))
	};
};

export const actions: Actions = {
	createSouler: async ({ request, locals }) => {
		const adminContext = await assertAdmin(locals);
		if (!adminContext) {
			return fail(403, { action: 'createSouler', message: '没有权限执行该操作。', name: '', language: 'zh' });
		}

		const formData = await request.formData();
		const name = normalizeText(formData.get('name'));
		const lang = normalizeLang(formData.get('language'));

		if (!name) {
			return fail(400, { action: 'createSouler', message: '请输入 souler 名字。', name, language: lang });
		}

		const duplicateByName = await findPotentialDuplicate(locals, lang, name);
		if (duplicateByName) {
			return fail(409, {
				action: 'createSouler',
				message: `已存在重复人物：${duplicateByName.name || duplicateByName.id}`,
				name,
				language: lang
			});
		}

		let canonicalName = '';
		try {
			canonicalName = await canonicalizeWithLlm(adminContext.session.access_token, lang, name);
		} catch (err) {
			const message = err instanceof Error ? err.message : 'canonical name 生成失败';
			return fail(400, { action: 'createSouler', message, name, language: lang });
		}

		const duplicateByCanonical = await findPotentialDuplicate(locals, lang, canonicalName);
		if (duplicateByCanonical) {
			return fail(409, {
				action: 'createSouler',
				message: `canonical 重复：${duplicateByCanonical.name || duplicateByCanonical.id}`,
				name,
				language: lang
			});
		}

		const { data: insertedRaw, error: insertError } = await locals.supabase
			.from('soulers')
			.insert({
				name,
				canonical_name: canonicalName,
				lang,
				checked: false
			})
			.select('id')
			.single();

		if (insertError || !insertedRaw) {
			return fail(400, {
				action: 'createSouler',
				message: insertError?.message || '创建失败。',
				name,
				language: lang
			});
		}

		const inserted = insertedRaw as { id: string };
		redirect(303, `/admin/${encodeURIComponent(inserted.id)}?tab=create&ok=created`);
	}
};
