import { json } from '@sveltejs/kit';
import { assertAdmin, searchDiscoverSectionCandidates } from '$lib/server/admin';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = async ({ locals, params, url }) => {
	if (!(await assertAdmin(locals))) {
		return json({ error: 'Forbidden' }, { status: 403 });
	}

	const sectionId = params.sectionId?.trim() ?? '';
	const query = url.searchParams.get('q') ?? '';
	const soulers = await searchDiscoverSectionCandidates(locals, sectionId, query);
	if (!soulers) {
		return json({ error: 'Section not found' }, { status: 404 });
	}

	return json({ soulers });
};
