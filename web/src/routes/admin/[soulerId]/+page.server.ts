import { error, fail, redirect } from '@sveltejs/kit';
import {
	AVATAR_BUCKET,
	MAX_AVATAR_BYTES,
	adminNoticeText,
	assertAdmin,
	clampWeight,
	fetchSoulerDetail,
	inferFileExt,
	normalizeAdminTab,
	normalizeText
} from '$lib/server/admin';
import { normalizeWikiId } from '$lib/server/avatar';
import type { Actions, PageServerLoad } from './$types';

type KeywordInput = {
	word: string;
	weight: number;
};

function parseKeywordRows(formData: FormData) {
	const words = formData.getAll('keyword_word').map((item) => String(item ?? '').trim());
	const weights = formData.getAll('keyword_weight').map((item) => String(item ?? '').trim());

	const unique = new Map<string, KeywordInput>();

	for (let index = 0; index < words.length; index += 1) {
		const word = words[index];
		if (!word) {
			continue;
		}

		const weightRaw = weights[index] ?? '';
		const weightNumber = weightRaw ? Number(weightRaw) : 0.5;
		if (!Number.isFinite(weightNumber)) {
			return {
				error: `关键词「${word}」的 weight 无效。`
			};
		}

		unique.set(word.toLowerCase(), {
			word,
			weight: clampWeight(weightNumber)
		});
	}

	return {
		rows: Array.from(unique.values()).slice(0, 30)
	};
}

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

		const formData = await request.formData();
		const soulerId = normalizeText(formData.get('souler_id'));
		const name = normalizeText(formData.get('name'));
		const bio = typeof formData.get('bio') === 'string' ? String(formData.get('bio')).trim() : '';
		const lang = normalizeText(formData.get('lang')) || 'zh';
		const wikidata = normalizeText(formData.get('wikidata'));
		const checked = formData.get('checked') === 'on';
		const tab = normalizeAdminTab(normalizeText(formData.get('tab')));

		if (!soulerId || !name) {
			return fail(400, { action: 'saveSouler', message: '请填写人物名。', soulerId });
		}

		const { error: soulerError } = await locals.supabase
			.from('soulers')
			.update({
				name,
				bio,
				wiki_id: wikidata || null,
				checked
			})
			.eq('id', soulerId);

		if (soulerError) {
			return fail(400, { action: 'saveSouler', message: soulerError.message, soulerId });
		}

		const parsedKeywords = parseKeywordRows(formData);
		if ('error' in parsedKeywords) {
			return fail(400, { action: 'saveSouler', message: parsedKeywords.error, soulerId });
		}

		const { error: clearKeywordError } = await locals.supabase
			.from('souler_keyword')
			.delete()
			.eq('souler_id', soulerId);

		if (clearKeywordError) {
			return fail(400, { action: 'saveSouler', message: clearKeywordError.message, soulerId });
		}

		if (parsedKeywords.rows.length > 0) {
			const { data: keywordRowsRaw, error: keywordUpsertError } = await locals.supabase
				.from('keywords')
				.upsert(
					parsedKeywords.rows.map((item) => ({
						word: item.word,
						language: lang
					})),
					{ onConflict: 'word,language' }
				)
				.select('id, word');

			if (keywordUpsertError) {
				return fail(400, { action: 'saveSouler', message: keywordUpsertError.message, soulerId });
			}

			const keywordRows = (keywordRowsRaw ?? []) as { id: string; word: string }[];
			const keywordByWord = new Map<string, string>();
			for (const row of keywordRows) {
				keywordByWord.set(row.word.trim().toLowerCase(), row.id);
			}

			const relationRows: { souler_id: string; keyword_id: string; weight: number }[] = [];
			for (const item of parsedKeywords.rows) {
				const keywordId = keywordByWord.get(item.word.toLowerCase());
				if (!keywordId) {
					continue;
				}

				relationRows.push({
					souler_id: soulerId,
					keyword_id: keywordId,
					weight: item.weight
				});
			}

			if (relationRows.length > 0) {
				const { error: relationInsertError } = await locals.supabase
					.from('souler_keyword')
					.insert(relationRows);

				if (relationInsertError) {
					return fail(400, { action: 'saveSouler', message: relationInsertError.message, soulerId });
				}
			}
		}

		redirect(303, `/admin/${encodeURIComponent(soulerId)}?tab=${tab}&ok=saved`);
	},

	saveChapters: async ({ request, locals }) => {
		if (!(await assertAdmin(locals))) {
			return fail(403, { action: 'saveChapters', message: '没有权限执行该操作。' });
		}

		const formData = await request.formData();
		const soulerId = normalizeText(formData.get('souler_id'));
		const tab = normalizeAdminTab(normalizeText(formData.get('tab')));

		if (!soulerId) {
			return fail(400, { action: 'saveChapters', message: '缺少 souler_id。' });
		}

		const chapterIds = formData
			.getAll('chapter_id')
			.map((item) => (typeof item === 'string' ? item.trim() : ''))
			.filter(Boolean);
		const chapterTitles = formData.getAll('chapter_title').map((item) => String(item ?? '').trim());
		const chapterSubtitles = formData.getAll('chapter_subtitle').map((item) => String(item ?? '').trim());
		const chapterRoles = formData.getAll('chapter_role').map((item) => String(item ?? '').trim());
		const chapterTasks = formData.getAll('chapter_task').map((item) => String(item ?? '').trim());

		for (let index = 0; index < chapterIds.length; index += 1) {
			const chapterId = chapterIds[index];
			const title = chapterTitles[index] ?? '';
			const subtitle = chapterSubtitles[index] ?? '';
			const role = chapterRoles[index] ?? '';
			const task = chapterTasks[index] ?? '';

			if (!title || !subtitle || !role || !task) {
				return fail(400, {
					action: 'saveChapters',
					message: `第 ${index + 1} 条章节缺少必填字段。`,
					soulerId
				});
			}

			const { error: updateError } = await locals.supabase
				.from('chapters')
				.update({ title, subtitle, role, task })
				.eq('id', chapterId)
				.eq('souler_id', soulerId);

			if (updateError) {
				return fail(400, { action: 'saveChapters', message: updateError.message, soulerId });
			}
		}

		redirect(303, `/admin/${encodeURIComponent(soulerId)}?tab=${tab}&ok=chapters`);
	},

	uploadAvatar: async ({ request, locals }) => {
		if (!(await assertAdmin(locals))) {
			return fail(403, { action: 'uploadAvatar', message: '没有权限执行该操作。' });
		}

		const formData = await request.formData();
		const soulerId = normalizeText(formData.get('souler_id'));
		const tab = normalizeAdminTab(normalizeText(formData.get('tab')));
		const avatar = formData.get('avatar');

		if (!soulerId) {
			return fail(400, { action: 'uploadAvatar', message: '缺少 souler_id。' });
		}

		const { data: soulerRaw, error: soulerError } = await locals.supabase
			.from('soulers')
			.select('wiki_id')
			.eq('id', soulerId)
			.maybeSingle();
		if (soulerError || !soulerRaw) {
			return fail(404, { action: 'uploadAvatar', message: '人物不存在。', soulerId });
		}

		const wikiId = normalizeWikiId((soulerRaw as { wiki_id: string | null }).wiki_id);
		if (!wikiId) {
			return fail(400, {
				action: 'uploadAvatar',
				message: '请先填写 Wikidata（wiki_id）再上传头像。',
				soulerId
			});
		}

		if (!(avatar instanceof File) || avatar.size <= 0) {
			return fail(400, { action: 'uploadAvatar', message: '请选择头像文件。', soulerId });
		}

		if (!avatar.type.startsWith('image/')) {
			return fail(400, { action: 'uploadAvatar', message: '头像文件必须是图片。', soulerId });
		}

		if (avatar.size > MAX_AVATAR_BYTES) {
			return fail(400, { action: 'uploadAvatar', message: '头像不能超过 5MB。', soulerId });
		}

		const extension = inferFileExt(avatar.name);
		const wikiSegment = wikiId.replace(/[^a-zA-Z0-9._-]/g, '_');
		const objectPath = `${wikiSegment}/${Date.now()}-${crypto.randomUUID()}.${extension}`;

		const { error: uploadError } = await locals.supabase.storage.from(AVATAR_BUCKET).upload(objectPath, avatar, {
			contentType: avatar.type || undefined,
			cacheControl: '3600',
			upsert: false
		});

		if (uploadError) {
			return fail(400, { action: 'uploadAvatar', message: uploadError.message, soulerId });
		}

		const { data: publicUrlData } = locals.supabase.storage.from(AVATAR_BUCKET).getPublicUrl(objectPath);
		const imageUrl = publicUrlData.publicUrl?.trim();
		if (!imageUrl) {
			return fail(400, { action: 'uploadAvatar', message: '头像地址生成失败。', soulerId });
		}

		const { error: avatarUpsertError } = await locals.supabase
			.from('souler_avatars')
			.upsert(
				{
					wiki_id: wikiId,
					image_path: imageUrl
				},
				{ onConflict: 'wiki_id' }
			);

		if (avatarUpsertError) {
			return fail(400, { action: 'uploadAvatar', message: avatarUpsertError.message, soulerId });
		}

		redirect(303, `/admin/${encodeURIComponent(soulerId)}?tab=${tab}&ok=avatar`);
	}
};
