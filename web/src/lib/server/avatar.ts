type AvatarRow = {
	wiki_id: string;
	image_path: string | null;
};

const AVATAR_BUCKET = 'avatars';

export function normalizeWikiId(value: string | null | undefined) {
	const wikiId = value?.trim() ?? '';
	return wikiId || null;
}

export function normalizeImagePath(rawPath: string | null) {
	if (!rawPath) {
		return null;
	}

	const value = rawPath.trim();
	if (!value) {
		return null;
	}

	return value;
}

export function resolveImageUrl(locals: App.Locals, rawPath: string | null) {
	const imagePath = normalizeImagePath(rawPath);
	if (!imagePath) {
		return null;
	}

	// Backward compatibility for old rows that may still store direct URLs.
	if (
		imagePath.startsWith('http://') ||
		imagePath.startsWith('https://') ||
		imagePath.startsWith('/')
	) {
		return imagePath;
	}

	const { data } = locals.supabase.storage.from(AVATAR_BUCKET).getPublicUrl(imagePath);
	const publicUrl = data.publicUrl?.trim() ?? '';
	if (!publicUrl) {
		return null;
	}

	return publicUrl;
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

		avatarByWikiId.set(wikiId, resolveImageUrl(locals, row.image_path));
	}

	return avatarByWikiId;
}

export function ensureAvatarPath(wikiId: string) {
	const wikiSegment = wikiId.replace(/[^a-zA-Z0-9._-]/g, '_');
	return `soulers/${wikiSegment}.png`;
}
