import { redirect } from '@sveltejs/kit';
import { getAgentApiBaseUrl } from '$lib/server/agent';
import { isAdminUser } from '$lib/server/roles';
import type { AdminSoulerChapter, AdminSoulerDetail, AdminSoulerListItem } from '$lib/types';

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
	wiki_id: string | null;
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

type ChapterRow = AdminSoulerChapter;

type CanonicalizeResponse = {
	canonical_name?: string;
	error?: string;
};

export type AdminTab = 'unchecked' | 'checked' | 'create';

export const AVATAR_BUCKET = 'avatars';
export const MAX_AVATAR_BYTES = 5 * 1024 * 1024;

export function normalizeText(value: FormDataEntryValue | null) {
	return typeof value === 'string' ? value.trim() : '';
}

export function normalizeLang(value: FormDataEntryValue | null) {
	const raw = normalizeText(value).toLowerCase();
	return raw || 'zh';
}

export function normalizeNameKey(value: string) {
	return value.trim().toLowerCase();
}

export function normalizeAdminTab(value: string | null): AdminTab {
	const raw = (value ?? '').trim().toLowerCase();
	if (raw === 'checked') {
		return 'checked';
	}
	if (raw === 'create') {
		return 'create';
	}
	return 'unchecked';
}

export function resolveImageUrl(rawPath: string | null) {
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

export function clampWeight(value: number) {
	if (!Number.isFinite(value)) {
		return 0.5;
	}
	return Math.max(0, Math.min(1, Number(value.toFixed(4))));
}

export function inferFileExt(filename: string) {
	const cleaned = filename.trim().toLowerCase();
	const dotIndex = cleaned.lastIndexOf('.');
	if (dotIndex < 0) {
		return 'jpg';
	}

	const ext = cleaned.slice(dotIndex + 1).replace(/[^a-z0-9]/g, '');
	return ext || 'jpg';
}

export async function assertAdmin(locals: App.Locals) {
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

export async function fetchSoulerLists(locals: App.Locals) {
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

export async function fetchSoulerDetail(locals: App.Locals, soulerId: string) {
	const { data: soulerRaw } = await locals.supabase
		.from('soulers')
		.select('id, name, lang, bio, checked, canonical_name, wiki_id, image_path')
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
		.limit(30);

	const keywords = ((keywordRaw ?? []) as KeywordRow[])
		.map((item) => {
			const keywordItem = Array.isArray(item.keywords) ? item.keywords[0] : item.keywords;
			return {
				word: keywordItem?.word?.trim() ?? '',
				weight: clampWeight(Number(item.weight ?? 0.5))
			};
		})
		.filter((item) => item.word);

	const { data: chaptersRaw } = await locals.supabase
		.from('chapters')
		.select('id, seq, title, subtitle, role, task')
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
		wikidata: souler.wiki_id?.trim() || '',
		imageUrl: resolveImageUrl(souler.image_path),
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

export async function canonicalizeWithLlm(accessToken: string, lang: string, name: string): Promise<string> {
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

export function adminNoticeText(code: string | null) {
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
