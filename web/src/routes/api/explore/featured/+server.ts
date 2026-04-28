import { json } from '@sveltejs/kit';
import { fetchFeaturedSections, resolveExploreLang } from '$lib/server/explore';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = async ({ locals, request }) => {
	const { session, user } = await locals.safeGetSession();
	if (!session || !user) {
		return json({ error: 'Unauthorized' }, { status: 401 });
	}

	const exploreLang = resolveExploreLang(user, request.headers.get('accept-language'));
	const featuredSections = await fetchFeaturedSections(locals, exploreLang);

	return json({
		exploreLang,
		featuredSections
	});
};
