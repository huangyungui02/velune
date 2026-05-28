import { json } from '@sveltejs/kit';
import { fetchFeaturedSections } from '$lib/server/explore';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = async ({ locals }) => {
	const { session, user } = await locals.safeGetSession();
	if (!session || !user) {
		return json({ error: 'Unauthorized' }, { status: 401 });
	}

	const featuredSections = await fetchFeaturedSections(locals);

	return json({
		exploreLang: 'zh',
		featuredSections
	});
};
