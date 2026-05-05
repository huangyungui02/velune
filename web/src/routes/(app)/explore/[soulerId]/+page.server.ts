import { error } from '@sveltejs/kit';
import { fetchPublicSoulerDetail } from '$lib/server/public-soulers';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ locals, params }) => {
	const detail = await fetchPublicSoulerDetail(locals, params.soulerId);
	if (!detail) {
		error(404, '人物不存在');
	}

	return detail;
};
