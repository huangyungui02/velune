import { error } from '@sveltejs/kit';
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

export const load: PageServerLoad = async ({ locals, params }) => {
	const soulerId = params.soulerId;
	const chapterId = params.chapterId;

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

	return {
		souler: soulerRaw as SoulerRow,
		chapter: chapterRaw as ChapterRow
	};
};
