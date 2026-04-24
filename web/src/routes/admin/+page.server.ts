import { fail, redirect } from '@sveltejs/kit';
import { getAgentApiBaseUrl } from '$lib/server/agent';
import { isAdminUser } from '$lib/server/roles';
import type { Actions, PageServerLoad } from './$types';
import type { AdminSoulerDetail, AdminSoulerListItem, SoulerChapter } from '$lib/types';

type SoulerListRow = {
	id: string;
	name: string;
	lang: string;
	checked: boolean;
	image_path: string | null;
};

type SoulerDetailRow = {
	id: string;
	name: string;
	lang: string;
	bio: string | null;
	checked: boolean;
	canonical_name: string | null;
	image_path: string | null;
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

type ChapterRow = SoulerChapter;

type CanonicalizeResponse = {
	canonical_name?: string;
	error?: string;
};

const AVATAR_BUCKET = 'avatars';
const MAX_AVATAR_BYTES = 5 * 1024 * 1024;

function normalizeText(value: FormDataEntryValue | null) {
	return typeof value === 'string' ? value.trim() : '';
}

function normalizeLang(value: FormDataEntryValue | null) {
	const raw = normalizeText(value).toLowerCase();
	return raw || 'zh';
}

function resolveImageUrl(rawPath: string | null) {
	if (!rawPath) {
		return null;
	}

	const value = rawPath.trim();
	if (!value) {
		return null;
	}

	if (value.startsWith('http://') || value.startsWith('https://') || value.startsWith('/')) {
		return value;
	}

	return null;
}

function normalizeNameKey(value: string) {
	return value.trim().toLowerCase();
}

function parseKeywordInput(raw: string) {
	const unique = new Map<string, string>();

	for (const token of raw.split(/[,，\n]/g)) {
		const cleaned = token.trim();
		if (!cleaned) {
			continue;
		}

		const key = cleaned.toLowerCase();
		if (!unique.has(key)) {
			unique.set(key, cleaned);
		}
	}

	return Array.from(unique.values()).slice(0, 10);
}

function chapterWeight(index: number, total: number) {
	if (total <= 1) {
		return 1;
	}
	const value = 1 - index / (total - 1);
	return Number(Math.max(0.1, value).toFixed(4));
}

function inferFileExt(filename: string) {
	const cleaned = filename.trim().toLowerCase();
	const dotIndex = cleaned.lastIndexOf('.');
	if (dotIndex < 0) {
		return 'jpg';
	}

	const ext = cleaned.slice(dotIndex + 1).replace(/[^a-z0-9]/g, '');
	return ext || 'jpg';
}

async function assertAdmin(locals: App.Locals) {
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

async function fetchSoulerLists(locals: App.Locals) {
	const { data: uncheckedRaw } = await locals.supabase
		.from('soulers')
		.select('id, name, lang, checked, image_path')
		.eq('checked', false)
		.order('name', { ascending: true });

	const { data: checkedRaw } = await locals.supabase
		.from('soulers')
		.select('id, name, lang, checked, image_path')
		.eq('checked', true)
		.order('name', { ascending: true });

	const toItem = (row: SoulerListRow): AdminSoulerListItem => ({
		id: row.id,
		name: row.name?.trim() || '未命名人物',
		lang: row.lang?.trim() || 'zh',
		checked: row.checked,
		imageUrl: resolveImageUrl(row.image_path)
	});

	return {
		unchecked: ((uncheckedRaw ?? []) as SoulerListRow[]).map(toItem),
		checked: ((checkedRaw ?? []) as SoulerListRow[]).map(toItem)
	};
}

async function fetchSoulerDetail(locals: App.Locals, soulerId: string) {
	const { data: soulerRaw } = await locals.supabase
		.from('soulers')
		.select('id, name, lang, bio, checked, canonical_name, image_path')
		.eq('id', soulerId)
		.maybeSingle();

	if (!soulerRaw) {
		return null;
	}

	const souler = soulerRaw as SoulerDetailRow;

	const { data: keywordRaw } = await locals.supabase
		.from('souler_keyword')
		.select('weight, keywords!inner(word)')
		.eq('souler_id', soulerId)
		.order('weight', { ascending: false })
		.limit(10);

	const keywords = ((keywordRaw ?? []) as KeywordRow[])
		.map((item) => {
			const keywordItem = Array.isArray(item.keywords) ? item.keywords[0] : item.keywords;
			return keywordItem?.word?.trim() ?? '';
		})
		.filter(Boolean);

	const { data: chaptersRaw } = await locals.supabase
		.from('chapters')
		.select('id, seq, title, subtitle')
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
		imageUrl: resolveImageUrl(souler.image_path),
		keywords,
		chapters
	};

	return detail;
}

async function findPotentialDuplicate(
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

async function canonicalizeWithLlm(
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

function noticeText(code: string | null) {
	switch (code) {
		case 'saved':
			return '人物信息已保存。';
		case 'chapters':
			return '章节信息已保存。';
		case 'avatar':
			return '头像已更新。';
		case 'created':
			return '人物已创建。';
		default:
			return '';
	}
}

export const load: PageServerLoad = async ({ locals, url }) => {
	if (!(await assertAdmin(locals))) {
		redirect(303, '/bookshelf');
	}

	const lists = await fetchSoulerLists(locals);
	const requestedSoulerId = url.searchParams.get('souler')?.trim() ?? '';
	const fallbackSoulerId = lists.unchecked[0]?.id ?? lists.checked[0]?.id ?? '';
	const selectedSoulerId = requestedSoulerId || fallbackSoulerId;

	const selectedSouler = selectedSoulerId ? await fetchSoulerDetail(locals, selectedSoulerId) : null;

	return {
		uncheckedSoulers: lists.unchecked,
		checkedSoulers: lists.checked,
		selectedSouler,
		selectedSoulerId: selectedSouler?.id ?? '',
		notice: noticeText(url.searchParams.get('ok'))
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
		const lang = normalizeLang(formData.get('lang'));
		const checked = formData.get('checked') === 'on';
		const keywordsInput = normalizeText(formData.get('keywords'));

		if (!soulerId || !name) {
			return fail(400, { action: 'saveSouler', message: '请填写人物名。', soulerId });
		}

		const { error: soulerError } = await locals.supabase
			.from('soulers')
			.update({
				name,
				bio,
				checked
			})
			.eq('id', soulerId);

		if (soulerError) {
			return fail(400, { action: 'saveSouler', message: soulerError.message, soulerId });
		}

		const { error: clearKeywordError } = await locals.supabase
			.from('souler_keyword')
			.delete()
			.eq('souler_id', soulerId);

		if (clearKeywordError) {
			return fail(400, { action: 'saveSouler', message: clearKeywordError.message, soulerId });
		}

		const keywords = parseKeywordInput(keywordsInput);
		if (keywords.length > 0) {
			const { data: keywordRowsRaw, error: keywordUpsertError } = await locals.supabase
				.from('keywords')
				.upsert(
					keywords.map((word) => ({
						word,
						language: lang
					})),
					{ onConflict: 'word,language' }
				)
				.select('id, word')
				.limit(10);

			if (keywordUpsertError) {
				return fail(400, { action: 'saveSouler', message: keywordUpsertError.message, soulerId });
			}

			const keywordRows = (keywordRowsRaw ?? []) as { id: string; word: string }[];
			const keywordByWord = new Map<string, string>();
			for (const row of keywordRows) {
				keywordByWord.set(row.word.trim().toLowerCase(), row.id);
			}

			const relationRows: { souler_id: string; keyword_id: string; weight: number }[] = [];
			for (let index = 0; index < keywords.length; index += 1) {
				const word = keywords[index];
				const keywordId = keywordByWord.get(word.toLowerCase());
				if (!keywordId) {
					continue;
				}

				relationRows.push({
					souler_id: soulerId,
					keyword_id: keywordId,
					weight: chapterWeight(index, keywords.length)
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

		redirect(303, `/admin?souler=${encodeURIComponent(soulerId)}&ok=saved`);
	},

	saveChapters: async ({ request, locals }) => {
		if (!(await assertAdmin(locals))) {
			return fail(403, { action: 'saveChapters', message: '没有权限执行该操作。' });
		}

		const formData = await request.formData();
		const soulerId = normalizeText(formData.get('souler_id'));
		if (!soulerId) {
			return fail(400, { action: 'saveChapters', message: '缺少 souler_id。' });
		}

		const chapterIds = formData
			.getAll('chapter_id')
			.map((item) => (typeof item === 'string' ? item.trim() : ''))
			.filter(Boolean);
		const chapterTitles = formData.getAll('chapter_title').map((item) => String(item ?? '').trim());
		const chapterSubtitles = formData.getAll('chapter_subtitle').map((item) => String(item ?? '').trim());

		for (let index = 0; index < chapterIds.length; index += 1) {
			const chapterId = chapterIds[index];
			const title = chapterTitles[index] ?? '';
			const subtitle = chapterSubtitles[index] ?? '';

			if (!title || !subtitle) {
				return fail(400, {
					action: 'saveChapters',
					message: `第 ${index + 1} 条章节缺少标题或副标题。`,
					soulerId
				});
			}

			const { error: updateError } = await locals.supabase
				.from('chapters')
				.update({ title, subtitle })
				.eq('id', chapterId)
				.eq('souler_id', soulerId);

			if (updateError) {
				return fail(400, { action: 'saveChapters', message: updateError.message, soulerId });
			}
		}

		redirect(303, `/admin?souler=${encodeURIComponent(soulerId)}&ok=chapters`);
	},

	uploadAvatar: async ({ request, locals }) => {
		if (!(await assertAdmin(locals))) {
			return fail(403, { action: 'uploadAvatar', message: '没有权限执行该操作。' });
		}

		const formData = await request.formData();
		const soulerId = normalizeText(formData.get('souler_id'));
		const avatar = formData.get('avatar');

		if (!soulerId) {
			return fail(400, { action: 'uploadAvatar', message: '缺少 souler_id。' });
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
		const objectPath = `${soulerId}/${Date.now()}-${crypto.randomUUID()}.${extension}`;

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

		const { error: updateError } = await locals.supabase
			.from('soulers')
			.update({ image_path: imageUrl })
			.eq('id', soulerId);

		if (updateError) {
			return fail(400, { action: 'uploadAvatar', message: updateError.message, soulerId });
		}

		redirect(303, `/admin?souler=${encodeURIComponent(soulerId)}&ok=avatar`);
	},

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
		redirect(303, `/admin?souler=${encodeURIComponent(inserted.id)}&ok=created`);
	}
};
