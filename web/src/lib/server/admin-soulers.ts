import {
	AVATAR_BUCKET,
	MAX_AVATAR_BYTES,
	normalizeNameKey,
	type AdminActionResult,
	type AdminTab
} from '$lib/server/admin-common';
import {
	parseCreateSoulerForm,
	parseKeywordRows,
	parseSaveChaptersForm,
	parseSaveSoulerForm,
	parseSoulerIdForm
} from '$lib/server/admin-forms';
import { getAgentApiBaseUrl } from '$lib/server/agent';
import { createAvatarResolver, ensureAvatarPath, normalizeWikiId } from '$lib/server/avatar';
import type { AdminSoulerChapter, AdminSoulerDetail, AdminSoulerListItem } from '$lib/types';

type SoulerListRow = {
	id: string;
	checked: boolean;
	wiki_id: string | null;
	souler_profile:
		| {
				name: string;
				lang: string;
		  }[]
		| null;
};

type SoulerDetailRow = {
	id: string;
	checked: boolean;
	wiki_id: string | null;
	avatar: string | null;
};

type ProfileRow = {
	name: string;
	lang: string;
	introduction: string | null;
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

export async function fetchSoulerListByStatus(locals: App.Locals, checked: boolean) {
	const { data: rowsRaw } = await locals.supabase
		.from('soulers')
		.select('id, checked, wiki_id, souler_profile!inner(name, lang)')
		.eq('checked', checked)
		.eq('souler_profile.lang', 'zh')
		.order('updated_at', { ascending: false });

	const rows = (rowsRaw ?? []) as SoulerListRow[];
	const avatarResolver = createAvatarResolver(locals);
	const avatarByWikiId = await avatarResolver.map(rows.map((row) => row.wiki_id));

	return rows.map((row): AdminSoulerListItem => {
		const wikiId = normalizeWikiId(row.wiki_id);
		const profile = row.souler_profile?.[0];
		return {
			id: row.id,
			name: profile?.name?.trim() || '未命名人物',
			lang: profile?.lang?.trim() || 'zh',
			checked: row.checked,
			imageUrl: wikiId ? (avatarByWikiId.get(wikiId) ?? null) : null
		};
	});
}

export async function fetchSoulerCounts(locals: App.Locals) {
	const [unchecked, checked] = await Promise.all([
		locals.supabase
			.from('soulers')
			.select('id', { count: 'exact', head: true })
			.eq('checked', false),
		locals.supabase.from('soulers').select('id', { count: 'exact', head: true }).eq('checked', true)
	]);

	return {
		unchecked: unchecked.count ?? 0,
		checked: checked.count ?? 0
	};
}

export async function fetchSoulerDetail(locals: App.Locals, soulerId: string, lang = 'zh') {
	const { data: soulerRaw } = await locals.supabase
		.from('soulers')
		.select('id, checked, wiki_id, avatar')
		.eq('id', soulerId)
		.maybeSingle();

	if (!soulerRaw) {
		return null;
	}

	const souler = soulerRaw as SoulerDetailRow;
	const normalizedLang = lang === 'en' ? 'en' : 'zh';
	const [{ data: profileRaw }, { data: keywordRaw }, { data: chaptersRaw }, { data: aliasesRaw }] =
		await Promise.all([
			locals.supabase
				.from('souler_profile')
				.select('name, lang, introduction')
				.eq('souler_id', soulerId)
				.eq('lang', normalizedLang)
				.maybeSingle(),
			locals.supabase
				.from('souler_keyword')
				.select('weight, keywords!inner(word, language)')
				.eq('souler_id', soulerId)
				.eq('keywords.language', normalizedLang)
				.order('weight', { ascending: false })
				.limit(30),
			locals.supabase
				.from('chapters')
				.select('id, seq, title, subtitle, task, active')
				.eq('souler_id', soulerId)
				.eq('lang', normalizedLang)
				.order('seq', { ascending: true }),
			locals.supabase
				.from('souler_aliases')
				.select('alias')
				.eq('souler_id', soulerId)
				.order('alias', { ascending: true })
		]);

	const profile = profileRaw as ProfileRow | null;
	const wikiId = normalizeWikiId(souler.wiki_id);
	const avatarResolver = createAvatarResolver(locals);
	const keywords = ((keywordRaw ?? []) as KeywordRow[])
		.map((item) => {
			const keywordItem = Array.isArray(item.keywords) ? item.keywords[0] : item.keywords;
			return {
				word: keywordItem?.word?.trim() ?? '',
				weight: Math.max(0, Math.min(1, Number(item.weight ?? 0.5)))
			};
		})
		.filter((item) => item.word);

	return {
		id: souler.id,
		name: profile?.name?.trim() || '',
		lang: normalizedLang,
		introduction: profile?.introduction ?? '',
		checked: souler.checked,
		canonicalName: '',
		wikidata: wikiId ?? '',
		imageUrl: await avatarResolver.get(wikiId),
		aliases: ((aliasesRaw ?? []) as { alias: string }[]).map((row) => row.alias),
		keywords,
		chapters: (chaptersRaw ?? []) as AdminSoulerChapter[]
	} satisfies AdminSoulerDetail;
}

export async function createSouler(
	formData: FormData,
	accessToken: string
): Promise<
	AdminActionResult<{
		action: 'createSouler';
		name: string;
		language: string;
		id?: string;
		requestId?: string;
		status?: string;
	}>
> {
	const { name, lang } = parseCreateSoulerForm(formData);
	if (!name) {
		return {
			ok: false,
			status: 400,
			data: { action: 'createSouler', message: '请输入 souler 名字。', name, language: lang }
		};
	}

	const response = await fetch(`${getAgentApiBaseUrl()}/v1/${lang}/soulers/resolve`, {
		method: 'POST',
		headers: {
			authorization: `Bearer ${accessToken}`,
			'content-type': 'application/json'
		},
		body: JSON.stringify({ name })
	});
	const payload = (await response.json().catch(() => null)) as {
		status?: string;
		soulerId?: string;
		requestId?: string;
		error?: string;
	} | null;

	if (!response.ok || !payload) {
		return {
			ok: false,
			status: response.status || 400,
			data: {
				action: 'createSouler',
				message: payload?.error || '创建请求失败。',
				name,
				language: lang
			}
		};
	}

	return {
		ok: true,
		data: {
			action: 'createSouler',
			name,
			language: lang,
			id: payload.soulerId,
			requestId: payload.requestId,
			status: payload.status
		}
	};
}

export async function saveSouler(
	locals: App.Locals,
	formData: FormData
): Promise<AdminActionResult<{ action: 'saveSouler'; soulerId: string; tab?: AdminTab }>> {
	const parsed = parseSaveSoulerForm(formData);
	if (!parsed.soulerId || !parsed.name) {
		return {
			ok: false,
			status: 400,
			data: { action: 'saveSouler', message: '请填写人物名。', soulerId: parsed.soulerId }
		};
	}

	const keywords = parseKeywordRows(formData);
	if (!keywords.ok) {
		return {
			ok: false,
			status: 400,
			data: { action: 'saveSouler', message: keywords.message, soulerId: parsed.soulerId }
		};
	}

	const aliasResult = await saveAliases(locals, parsed.soulerId, parsed.aliases);
	if (!aliasResult.ok) {
		return {
			ok: false,
			status: 400,
			data: { action: 'saveSouler', message: aliasResult.message, soulerId: parsed.soulerId }
		};
	}

	const { error: soulerError } = await locals.supabase
		.from('soulers')
		.update({
			wiki_id: parsed.wikidata || null,
			checked: parsed.checked
		})
		.eq('id', parsed.soulerId);

	if (soulerError) {
		return {
			ok: false,
			status: 400,
			data: { action: 'saveSouler', message: soulerError.message, soulerId: parsed.soulerId }
		};
	}

	const { error: profileError } = await locals.supabase.from('souler_profile').upsert(
		{
			souler_id: parsed.soulerId,
			lang: parsed.lang,
			name: parsed.name,
			introduction: parsed.introduction
		},
		{ onConflict: 'souler_id,lang' }
	);
	if (profileError) {
		return {
			ok: false,
			status: 400,
			data: { action: 'saveSouler', message: profileError.message, soulerId: parsed.soulerId }
		};
	}

	const { data: currentKeywordRows, error: currentKeywordError } = await locals.supabase
		.from('souler_keyword')
		.select('keyword_id, keywords!inner(language)')
		.eq('souler_id', parsed.soulerId)
		.eq('keywords.language', parsed.lang);
	if (currentKeywordError) {
		return {
			ok: false,
			status: 400,
			data: {
				action: 'saveSouler',
				message: currentKeywordError.message,
				soulerId: parsed.soulerId
			}
		};
	}

	const currentKeywordIds = ((currentKeywordRows ?? []) as { keyword_id: string }[]).map(
		(row) => row.keyword_id
	);
	if (currentKeywordIds.length > 0) {
		const { error: clearKeywordError } = await locals.supabase
			.from('souler_keyword')
			.delete()
			.eq('souler_id', parsed.soulerId)
			.in('keyword_id', currentKeywordIds);
		if (clearKeywordError) {
			return {
				ok: false,
				status: 400,
				data: {
					action: 'saveSouler',
					message: clearKeywordError.message,
					soulerId: parsed.soulerId
				}
			};
		}
	}

	if (keywords.rows.length > 0) {
		const { data: keywordRowsRaw, error: keywordUpsertError } = await locals.supabase
			.from('keywords')
			.upsert(
				keywords.rows.map((item) => ({
					word: item.word,
					language: parsed.lang
				})),
				{ onConflict: 'word,language' }
			)
			.select('id, word');

		if (keywordUpsertError) {
			return {
				ok: false,
				status: 400,
				data: {
					action: 'saveSouler',
					message: keywordUpsertError.message,
					soulerId: parsed.soulerId
				}
			};
		}

		const keywordByWord = new Map(
			((keywordRowsRaw ?? []) as { id: string; word: string }[]).map((row) => [
				row.word.trim().toLowerCase(),
				row.id
			])
		);
		const relationRows = keywords.rows
			.map((item) => ({
				souler_id: parsed.soulerId,
				keyword_id: keywordByWord.get(item.word.toLowerCase()) ?? '',
				weight: item.weight
			}))
			.filter((row) => row.keyword_id);

		if (relationRows.length > 0) {
			const { error } = await locals.supabase.from('souler_keyword').insert(relationRows);
			if (error) {
				return {
					ok: false,
					status: 400,
					data: { action: 'saveSouler', message: error.message, soulerId: parsed.soulerId }
				};
			}
		}
	}

	return {
		ok: true,
		data: { action: 'saveSouler', soulerId: parsed.soulerId, tab: parsed.tab }
	};
}

async function saveAliases(locals: App.Locals, soulerId: string, aliases: string[]) {
	const { data: allAliasesRaw, error } = await locals.supabase
		.from('souler_aliases')
		.select('souler_id, alias');
	if (error) {
		return { ok: false as const, message: error.message };
	}

	const normalizedDesired = new Map(aliases.map((alias) => [normalizeNameKey(alias), alias]));
	for (const row of (allAliasesRaw ?? []) as { souler_id: string; alias: string }[]) {
		if (row.souler_id === soulerId) {
			continue;
		}
		const aliasKey = normalizeNameKey(row.alias);
		if (normalizedDesired.has(aliasKey)) {
			return { ok: false as const, message: `Alias 已被其他人物使用：${row.alias}` };
		}
	}

	const current = ((allAliasesRaw ?? []) as { souler_id: string; alias: string }[]).filter(
		(row) => row.souler_id === soulerId
	);
	const currentKeys = new Map(current.map((row) => [normalizeNameKey(row.alias), row.alias]));
	const aliasesToAdd = Array.from(normalizedDesired.entries())
		.filter(([key, alias]) => currentKeys.get(key) !== alias)
		.map(([, alias]) => alias);
	const aliasesToRemove = current
		.filter((row) => normalizedDesired.get(normalizeNameKey(row.alias)) !== row.alias)
		.map((row) => row.alias);

	if (aliasesToAdd.length > 0) {
		const { error: insertError } = await locals.supabase.from('souler_aliases').insert(
			aliasesToAdd.map((alias) => ({
				souler_id: soulerId,
				alias
			}))
		);
		if (insertError) {
			return { ok: false as const, message: insertError.message };
		}
	}

	if (aliasesToRemove.length > 0) {
		const { error: deleteError } = await locals.supabase
			.from('souler_aliases')
			.delete()
			.eq('souler_id', soulerId)
			.in('alias', aliasesToRemove);
		if (deleteError) {
			return { ok: false as const, message: deleteError.message };
		}
	}

	return { ok: true as const };
}

export async function saveChapters(
	locals: App.Locals,
	formData: FormData
): Promise<AdminActionResult<{ action: 'saveChapters'; soulerId: string; tab?: AdminTab }>> {
	const parsed = parseSaveChaptersForm(formData);
	if (!parsed.soulerId) {
		return {
			ok: false,
			status: 400,
			data: { action: 'saveChapters', message: '缺少 souler_id。', soulerId: parsed.soulerId }
		};
	}

	for (let index = 0; index < parsed.chapterIds.length; index += 1) {
		const chapterId = parsed.chapterIds[index];
		const title = parsed.titles[index] ?? '';
		const subtitle = parsed.subtitles[index] ?? '';
		const task = parsed.tasks[index] ?? '';
		const active = parsed.activeIds.has(chapterId);

		if (!title || !subtitle || !task) {
			return {
				ok: false,
				status: 400,
				data: {
					action: 'saveChapters',
					message: `第 ${index + 1} 条章节缺少必填字段。`,
					soulerId: parsed.soulerId
				}
			};
		}

		const { error } = await locals.supabase
			.from('chapters')
			.update({ title, subtitle, task, active })
			.eq('id', chapterId)
			.eq('souler_id', parsed.soulerId)
			.eq('lang', parsed.lang);

		if (error) {
			return {
				ok: false,
				status: 400,
				data: { action: 'saveChapters', message: error.message, soulerId: parsed.soulerId }
			};
		}
	}

	return {
		ok: true,
		data: { action: 'saveChapters', soulerId: parsed.soulerId, tab: parsed.tab }
	};
}

export async function deleteSouler(
	locals: App.Locals,
	formData: FormData
): Promise<AdminActionResult<{ action: 'deleteSouler'; soulerId: string; tab?: AdminTab }>> {
	const { soulerId, tab } = parseSoulerIdForm(formData);
	if (!soulerId) {
		return {
			ok: false,
			status: 400,
			data: { action: 'deleteSouler', message: '缺少 souler_id。', soulerId }
		};
	}

	const { data: deletedRows, error } = await locals.supabase
		.from('soulers')
		.delete()
		.eq('id', soulerId)
		.select('id');

	if (error) {
		return {
			ok: false,
			status: 400,
			data: { action: 'deleteSouler', message: error.message, soulerId }
		};
	}

	if (!deletedRows || deletedRows.length === 0) {
		return {
			ok: false,
			status: 404,
			data: { action: 'deleteSouler', message: '人物不存在或无法删除。', soulerId }
		};
	}

	return {
		ok: true,
		data: { action: 'deleteSouler', soulerId, tab }
	};
}

export async function uploadAvatar(
	locals: App.Locals,
	formData: FormData
): Promise<AdminActionResult<{ action: 'uploadAvatar'; soulerId: string; tab?: AdminTab }>> {
	const { soulerId, tab } = parseSoulerIdForm(formData);
	const avatar = formData.get('avatar');
	if (!soulerId) {
		return {
			ok: false,
			status: 400,
			data: { action: 'uploadAvatar', message: '缺少 souler_id。', soulerId }
		};
	}

	const { data: soulerRaw, error: soulerError } = await locals.supabase
		.from('soulers')
		.select('wiki_id')
		.eq('id', soulerId)
		.maybeSingle();

	if (soulerError || !soulerRaw) {
		return {
			ok: false,
			status: 404,
			data: { action: 'uploadAvatar', message: '人物不存在。', soulerId }
		};
	}

	const wikiId = normalizeWikiId((soulerRaw as { wiki_id: string | null }).wiki_id);
	if (!wikiId) {
		return {
			ok: false,
			status: 400,
			data: {
				action: 'uploadAvatar',
				message: '请先填写 Wikidata（wiki_id）再上传头像。',
				soulerId
			}
		};
	}

	if (!(avatar instanceof File) || avatar.size <= 0) {
		return {
			ok: false,
			status: 400,
			data: { action: 'uploadAvatar', message: '请选择头像文件。', soulerId }
		};
	}
	if (!avatar.type.startsWith('image/')) {
		return {
			ok: false,
			status: 400,
			data: { action: 'uploadAvatar', message: '头像文件必须是图片。', soulerId }
		};
	}
	if (avatar.size > MAX_AVATAR_BYTES) {
		return {
			ok: false,
			status: 400,
			data: { action: 'uploadAvatar', message: '头像不能超过 5MB。', soulerId }
		};
	}

	const filePath = ensureAvatarPath(wikiId);
	const { error: uploadError } = await locals.supabase.storage
		.from(AVATAR_BUCKET)
		.upload(filePath, avatar, {
			contentType: avatar.type || undefined,
			upsert: true
		});

	if (uploadError) {
		return {
			ok: false,
			status: 400,
			data: { action: 'uploadAvatar', message: uploadError.message, soulerId }
		};
	}

	const { error } = await locals.supabase
		.from('soulers')
		.update({ avatar: filePath })
		.eq('id', soulerId);

	if (error) {
		return {
			ok: false,
			status: 400,
			data: { action: 'uploadAvatar', message: error.message, soulerId }
		};
	}

	return {
		ok: true,
		data: { action: 'uploadAvatar', soulerId, tab }
	};
}
