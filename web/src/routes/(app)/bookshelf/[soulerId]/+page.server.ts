import { error } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';
import type { SoulerChapter } from '$lib/types';

type SoulerRow = {
	id: string;
	name: string;
	bio: string | null;
	image_path: string | null;
};

type KeywordRow = {
	weight: number;
	keywords:
		| {
				word: string;
		  }[]
		| {
				word: string;
		  }
		| null;
};

type ChapterRow = SoulerChapter;

function resolveImageUrl(rawPath: string | null) {
	if (!rawPath) {
		return null;
	}

	const value = rawPath.trim();
	if (!value) {
		return null;
	}

	if (value.startsWith('http://') || value.startsWith('https://') || value.startsWith('/')) {
		return value;
	}

	return null;
}

export const load: PageServerLoad = async ({ locals, params }) => {
	const soulerId = params.soulerId;

	const { data: soulerRaw, error: soulerError } = await locals.supabase
		.from('soulers')
		.select('id, name, bio, image_path')
		.eq('id', soulerId)
		.single();

	if (soulerError || !soulerRaw) {
		error(404, '人物不存在');
	}

	const souler = soulerRaw as SoulerRow;

	const { data: keywordRaw } = await locals.supabase
		.from('souler_keyword')
		.select('weight, keywords!inner(word)')
		.eq('souler_id', soulerId)
		.order('weight', { ascending: false })
		.limit(10);

	const keywords = ((keywordRaw ?? []) as KeywordRow[])
		.map((item) => {
			if (!item.keywords) {
				return '';
			}

			const row = Array.isArray(item.keywords) ? item.keywords[0] : item.keywords;
			return row?.word?.trim() ?? '';
		})
		.filter(Boolean);

	const { data: chaptersRaw } = await locals.supabase
		.from('chapters')
		.select('id, seq, title, subtitle')
		.eq('souler_id', soulerId)
		.order('seq', { ascending: true });

	const chapters = (chaptersRaw ?? []) as ChapterRow[];

	return {
		souler: {
			id: souler.id,
			name: souler.name,
			bio: souler.bio ?? '',
			imageUrl: resolveImageUrl(souler.image_path)
		},
		keywords,
		chapters
	};
};
