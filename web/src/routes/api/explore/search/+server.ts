import { json } from '@sveltejs/kit';
import { searchCheckedSoulers } from '$lib/server/souler-search';
import type { RequestHandler } from './$types';

function normalizeLimit(raw: string | null) {
	const value = Number.parseInt(raw ?? '24', 10);
	if (!Number.isFinite(value) || value < 1) {
		return 24;
	}
	return Math.min(value, 50);
}

export const GET: RequestHandler = async ({ locals, url }) => {
	const { session, user } = await locals.safeGetSession();
	if (!session || !user) {
		return json({ error: 'Unauthorized' }, { status: 401 });
	}

	const query = url.searchParams.get('q') ?? '';
	const limit = normalizeLimit(url.searchParams.get('limit'));
	const items = await searchCheckedSoulers(locals, { query, limit });

	return json({ items });
};
