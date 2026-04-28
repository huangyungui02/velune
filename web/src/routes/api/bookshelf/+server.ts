import { json } from '@sveltejs/kit';
import { fetchBookshelf } from '$lib/server/bookshelf';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = async ({ locals, url }) => {
	const { session, user } = await locals.safeGetSession();
	if (!session || !user) {
		return json({ error: 'Unauthorized' }, { status: 401 });
	}

	const refresh = url.searchParams.get('refresh') === '1';
	const bookshelf = await fetchBookshelf(locals, user.id, { refresh });
	return json({ bookshelf });
};
