import type { PublicSoulerDetail } from '$lib/types';

const details = new Map<string, PublicSoulerDetail>();

export function readSoulerDetail(soulerId: string) {
	return details.get(soulerId) ?? null;
}

export function writeSoulerDetail(detail: PublicSoulerDetail) {
	details.set(detail.souler.id, detail);
	return detail;
}

export function touchSoulerChapterHistory(
	soulerId: string,
	chapterId: string,
	sessionId: string,
	messageCount: number
) {
	const detail = details.get(soulerId);
	if (!detail) {
		return;
	}

	details.set(soulerId, {
		...detail,
		chapters: detail.chapters.map((chapter) =>
			chapter.id === chapterId
				? {
						...chapter,
						sessionId,
						latestHistory: {
							id: sessionId,
							updatedAt: new Date().toISOString(),
							messageCount
						}
					}
				: chapter
		)
	});
}
