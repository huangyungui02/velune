type AvatarRow = {
	wiki_id: string;
	image_path: string | null;
};

export function normalizeWikiId(value: string | null | undefined) {
	const wikiId = value?.trim() ?? '';
	return wikiId || null;
}

export function resolveImageUrl(rawPath: string | null) {
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

export async function fetchAvatarMap(locals: App.Locals, rawWikiIds: (string | null | undefined)[]) {
	const wikiIds = [...new Set(rawWikiIds.map(normalizeWikiId).filter(Boolean))] as string[];
	if (wikiIds.length === 0) {
		return new Map<string, string | null>();
	}

	const { data: avatarRowsRaw } = await locals.supabase
		.from('souler_avatars')
		.select('wiki_id, image_path')
		.in('wiki_id', wikiIds);

	const avatarByWikiId = new Map<string, string | null>();
	for (const row of (avatarRowsRaw ?? []) as AvatarRow[]) {
		const wikiId = normalizeWikiId(row.wiki_id);
		if (!wikiId) {
			continue;
		}

		avatarByWikiId.set(wikiId, resolveImageUrl(row.image_path));
	}

	return avatarByWikiId;
}
