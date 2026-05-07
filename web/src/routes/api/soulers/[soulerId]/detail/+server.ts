import { error, json } from '@sveltejs/kit';
import { fetchPublicSoulerDetail } from '$lib/server/public-soulers';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = async ({ locals, params }) => {
	const detail = await fetchPublicSoulerDetail(locals, params.soulerId);
	if (!detail) {
		error(404, '人物不存在');
	}

	return json(detail);
};
