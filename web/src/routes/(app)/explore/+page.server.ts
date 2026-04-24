import type { PageServerLoad } from './$types';
import type { ExploreSoulerItem } from '$lib/types';

type SoulerRow = {
	id: string;
	name: string;
	image_path: string | null;
};

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

export const load: PageServerLoad = async ({ locals }) => {
	const { data: soulersRaw } = await locals.supabase
		.from('soulers')
		.select('id, name, image_path')
		.order('name', { ascending: true });

	const soulers = (soulersRaw ?? []) as SoulerRow[];

	const items: ExploreSoulerItem[] = soulers.map((souler) => ({
		id: souler.id,
		name: souler.name?.trim() || '未命名人物',
		imageUrl: resolveImageUrl(souler.image_path)
	}));

	return {
		soulers: items
	};
};
