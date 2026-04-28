import { error } from '@sveltejs/kit';
import { fetchChapterConversation } from '$lib/server/public-soulers';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ locals, params, url }) => {
	const soulerId = params.soulerId;
	const chapterId = params.chapterId;
	const routeSessionId = url.searchParams.get('session')?.trim() || null;
	const conversation = await fetchChapterConversation(locals, soulerId, chapterId, routeSessionId);
	if (!conversation) {
		error(404, '章节不存在');
	}

	return conversation;
};
