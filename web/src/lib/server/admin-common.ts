import { redirect } from '@sveltejs/kit';
import { isAdminUser } from '$lib/server/roles';

export type AdminTab = 'unchecked' | 'checked' | 'create' | 'sections';

export type AdminActionResult<T = Record<string, unknown>> =
	| {
			ok: true;
			data: T;
	  }
	| {
			ok: false;
			status: number;
			data: T & {
				message: string;
			};
	  };

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
	if (raw === 'sections') {
		return 'sections';
	}
	return 'unchecked';
}

export function normalizeSectionKey(value: FormDataEntryValue | null) {
	const normalized = normalizeText(value)
		.toLowerCase()
		.replace(/[\s_]+/g, '-')
		.replace(/[^a-z0-9-]/g, '-')
		.replace(/-+/g, '-')
		.replace(/^-+|-+$/g, '');

	return normalized.slice(0, 64);
}

export function clampWeight(value: number) {
	if (!Number.isFinite(value)) {
		return 0.5;
	}
	return Math.max(0, Math.min(1, Number(value.toFixed(4))));
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
		case 'deleted':
			return '人物已删除，关联数据已清理。';
		case 'section-created':
			return '精选分组已创建。';
		case 'section-saved':
			return '精选分组已保存。';
		case 'section-deleted':
			return '精选分组已删除。';
		case 'section-item-added':
			return '人物已加入分组。';
		case 'section-items-saved':
			return '分组排序已保存。';
		case 'section-item-removed':
			return '人物已移出分组。';
		default:
			return '';
	}
}
