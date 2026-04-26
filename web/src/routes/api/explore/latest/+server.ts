import { json } from '@sveltejs/kit';
import { fetchLatestSoulersPage } from '$lib/server/explore';
import type { RequestHandler } from './$types';

function normalizePage(raw: string | null) {
	const value = Number.parseInt(raw ?? '1', 10);
	if (!Number.isFinite(value) || value < 1) {
		return 1;
	}
	return value;
}

export const GET: RequestHandler = async ({ locals, url }) => {
	const { session, user } = await locals.safeGetSession();
	if (!session || !user) {
		return json({ error: 'Unauthorized' }, { status: 401 });
	}

	const page = normalizePage(url.searchParams.get('page'));
	const payload = await fetchLatestSoulersPage(locals, page);
	return json(payload);
};
