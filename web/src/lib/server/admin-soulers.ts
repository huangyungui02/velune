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
import { createAvatarResolver, ensureAvatarPath, normalizeWikiId } from '$lib/server/avatar';
import { completeJson, type JsonSchema } from '$lib/server/llm';
import type { AdminSoulerChapter, AdminSoulerDetail, AdminSoulerListItem } from '$lib/types';

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
	introduction: string | null;
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

type CanonicalizeResponse = {
	canonical_name?: string;
};

const CANONICAL_NAME_SCHEMA: JsonSchema = {
	type: 'object',
	properties: {
		canonical_name: {
			type: 'string'
		}
	},
	required: ['canonical_name'],
	additionalProperties: false
};

const CANONICAL_NAME_PROMPT = {
	en:
		'## Task\n' +
		'Given a person name, return a canonical person name, as JSON format.\n\n' +
		'## Example Input\n' +
		'Nietzsche\n\n' +
		'## Example Output\n' +
		'{"canonical_name":"Friedrich Nietzsche"}',
	zh:
		'## Task\n' +
		'将给定人物名，返回为规范人物名，以JSON格式返回。\n' +
		'请使用大众最熟知的名字（例如：庄子而非庄周）。\n\n' +
		'## Example Input\n' +
		'尼采\n\n' +
		'## Example Output\n' +
		'{"canonical_name":"弗里德里希·尼采"}'
} as const;

export async function fetchSoulerListByStatus(locals: App.Locals, checked: boolean) {
	const { data: rowsRaw } = await locals.supabase
		.from('soulers')
		.select('id, name, lang, checked, wiki_id')
		.eq('checked', checked)
		.order('name', { ascending: true });

	const rows = (rowsRaw ?? []) as SoulerListRow[];
	const avatarResolver = createAvatarResolver(locals);
	const avatarByWikiId = await avatarResolver.map(rows.map((row) => row.wiki_id));

	return rows.map((row): AdminSoulerListItem => {
		const wikiId = normalizeWikiId(row.wiki_id);
		return {
			id: row.id,
			name: row.name?.trim() || '未命名人物',
			lang: row.lang?.trim() || 'zh',
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

export async function fetchSoulerDetail(locals: App.Locals, soulerId: string) {
	const { data: soulerRaw } = await locals.supabase
		.from('soulers')
		.select('id, name, lang, introduction, checked, canonical_name, wiki_id')
		.eq('id', soulerId)
		.maybeSingle();

	if (!soulerRaw) {
		return null;
	}

	const souler = soulerRaw as SoulerDetailRow;
	const wikiId = normalizeWikiId(souler.wiki_id);
	const avatarResolver = createAvatarResolver(locals);

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
				weight: Math.max(0, Math.min(1, Number(item.weight ?? 0.5)))
			};
		})
		.filter((item) => item.word);

	const { data: chaptersRaw } = await locals.supabase
		.from('chapters')
		.select('id, seq, title, subtitle, task')
		.eq('souler_id', soulerId)
		.order('seq', { ascending: true });

	const chapters = (chaptersRaw ?? []) as AdminSoulerChapter[];
	const detail: AdminSoulerDetail = {
		id: souler.id,
		name: souler.name?.trim() || '',
		lang: souler.lang?.trim() || 'zh',
		introduction: souler.introduction ?? '',
		checked: souler.checked,
		canonicalName: souler.canonical_name?.trim() || '',
		wikidata: wikiId ?? '',
		imageUrl: await avatarResolver.get(wikiId),
		keywords,
		chapters
	};

	return detail;
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

export async function canonicalizeWithLlm(lang: string, name: string): Promise<string> {
	const cleanedName = name.trim();
	if (!cleanedName) {
		throw new Error('Souler name cannot be empty');
	}
	if (cleanedName.length > 128) {
		throw new Error('Souler name is too long');
	}

	const prompt = lang === 'zh' ? CANONICAL_NAME_PROMPT.zh : CANONICAL_NAME_PROMPT.en;
	const payload = await completeJson<CanonicalizeResponse>(
		[
			{ role: 'system', content: prompt },
			{ role: 'user', content: cleanedName }
		],
		{
			schemaName: 'canonical_souler_name',
			schema: CANONICAL_NAME_SCHEMA,
			temperature: 0.25
		}
	);

	const canonicalName = payload?.canonical_name?.trim() ?? '';
	if (!canonicalName) {
		throw new Error('canonical name 为空');
	}

	return canonicalName;
}

export async function createSouler(
	locals: App.Locals,
	formData: FormData
): Promise<
	AdminActionResult<{ action: 'createSouler'; name: string; language: string; id?: string }>
> {
	const { name, lang } = parseCreateSoulerForm(formData);
	if (!name) {
		return {
			ok: false,
			status: 400,
			data: { action: 'createSouler', message: '请输入 souler 名字。', name, language: lang }
		};
	}

	const duplicateByName = await findPotentialDuplicate(locals, lang, name);
	if (duplicateByName) {
		return {
			ok: false,
			status: 409,
			data: {
				action: 'createSouler',
				message: `已存在重复人物：${duplicateByName.name || duplicateByName.id}`,
				name,
				language: lang
			}
		};
	}

	let canonicalName: string;
	try {
		canonicalName = await canonicalizeWithLlm(lang, name);
	} catch (err) {
		return {
			ok: false,
			status: 400,
			data: {
				action: 'createSouler',
				message: err instanceof Error ? err.message : 'canonical name 生成失败',
				name,
				language: lang
			}
		};
	}

	const duplicateByCanonical = await findPotentialDuplicate(locals, lang, canonicalName);
	if (duplicateByCanonical) {
		return {
			ok: false,
			status: 409,
			data: {
				action: 'createSouler',
				message: `canonical 重复：${duplicateByCanonical.name || duplicateByCanonical.id}`,
				name,
				language: lang
			}
		};
	}

	const { data: insertedRaw, error } = await locals.supabase
		.from('soulers')
		.insert({ name, canonical_name: canonicalName, lang, checked: false })
		.select('id')
		.single();

	if (error || !insertedRaw) {
		return {
			ok: false,
			status: 400,
			data: {
				action: 'createSouler',
				message: error?.message || '创建失败。',
				name,
				language: lang
			}
		};
	}

	return {
		ok: true,
		data: { action: 'createSouler', name, language: lang, id: (insertedRaw as { id: string }).id }
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

	const { error: soulerError } = await locals.supabase
		.from('soulers')
		.update({
			name: parsed.name,
			canonical_name: parsed.canonicalName || null,
			introduction: parsed.introduction,
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

	const { error: clearKeywordError } = await locals.supabase
		.from('souler_keyword')
		.delete()
		.eq('souler_id', parsed.soulerId);

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
			.update({ title, subtitle, task })
			.eq('id', chapterId)
			.eq('souler_id', parsed.soulerId);

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
		.from('souler_avatars')
		.upsert({ wiki_id: wikiId, image_path: filePath }, { onConflict: 'wiki_id' });

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
