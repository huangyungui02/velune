import { redirect } from '@sveltejs/kit';
import type { LayoutServerLoad } from './$types';
import type { BookshelfItem } from '$lib/types';

type ResonanceRow = {
	id: string;
	souler_id: string;
	souler_name: string | null;
	last_session_title: string | null;
	updated_at: string;
};

type SoulerCoverRow = {
	id: string;
	image_path: string | null;
};

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

export const load: LayoutServerLoad = async ({ locals }) => {
	const { session, user } = await locals.safeGetSession();

	if (!session || !user) {
		redirect(303, '/auth');
	}

	const { data: resonancesRaw } = await locals.supabase
		.from('resonances_with_souler')
		.select('id, souler_id, souler_name, last_session_title, updated_at')
		.order('updated_at', { ascending: false })
		.limit(80);

	const resonances = (resonancesRaw ?? []) as ResonanceRow[];
	const soulerIds = [...new Set(resonances.map((item) => item.souler_id).filter(Boolean))];

	const imageBySoulerId = new Map<string, string | null>();
	if (soulerIds.length > 0) {
		const { data: soulersRaw } = await locals.supabase
			.from('soulers')
			.select('id, image_path')
			.in('id', soulerIds);

		const soulers = (soulersRaw ?? []) as SoulerCoverRow[];
		for (const souler of soulers) {
			imageBySoulerId.set(souler.id, resolveImageUrl(souler.image_path));
		}
	}

	const bookshelf: BookshelfItem[] = resonances.map((item) => ({
		id: item.id,
		soulerId: item.souler_id,
		soulerName: item.souler_name?.trim() || '未命名人物',
		lastSessionTitle: item.last_session_title?.trim() || '',
		updatedAt: item.updated_at,
		imageUrl: imageBySoulerId.get(item.souler_id) ?? null
	}));

	return {
		session,
		user,
		bookshelf
	};
};
