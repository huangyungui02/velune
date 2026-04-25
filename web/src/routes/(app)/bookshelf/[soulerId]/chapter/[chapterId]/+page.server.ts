import { error } from '@sveltejs/kit';
import type { ConversationMessage } from '$lib/types';
import type { PageServerLoad } from './$types';

type SoulerRow = {
	id: string;
	name: string;
};

type ChapterRow = {
	id: string;
	seq: number;
	title: string;
	subtitle: string;
};

type SessionRow = {
	id: string;
	souler_id: string;
	chapter_id: string | null;
};

type MessageRow = ConversationMessage;

export const load: PageServerLoad = async ({ locals, params, url }) => {
	const soulerId = params.soulerId;
	const chapterId = params.chapterId;
	const routeSessionId = url.searchParams.get('session')?.trim() || null;

	const { data: soulerRaw, error: soulerError } = await locals.supabase
		.from('soulers')
		.select('id, name')
		.eq('id', soulerId)
		.single();

	if (soulerError || !soulerRaw) {
		error(404, '人物不存在');
	}

	const { data: chapterRaw, error: chapterError } = await locals.supabase
		.from('chapters')
		.select('id, seq, title, subtitle')
		.eq('id', chapterId)
		.eq('souler_id', soulerId)
		.single();

	if (chapterError || !chapterRaw) {
		error(404, '章节不存在');
	}

	let initialSessionId: string | null = null;
	let initialMessages: ConversationMessage[] = [];

	if (routeSessionId) {
		const { data: sessionRaw } = await locals.supabase
			.from('sessions')
			.select('id, souler_id, chapter_id')
			.eq('id', routeSessionId)
			.maybeSingle();

		const session = sessionRaw as SessionRow | null;
		const isValidSession =
			session &&
			session.souler_id === soulerId &&
			session.chapter_id === chapterId;

		if (isValidSession) {
			const { data: messageRows } = await locals.supabase
				.from('messages')
				.select('role, content')
				.eq('session_id', routeSessionId)
				.order('created_at', { ascending: true });

			initialSessionId = routeSessionId;
			initialMessages = (messageRows ?? []) as MessageRow[];
		}
	}

	return {
		souler: soulerRaw as SoulerRow,
		chapter: chapterRaw as ChapterRow,
		initialSessionId,
		initialMessages
	};
};
