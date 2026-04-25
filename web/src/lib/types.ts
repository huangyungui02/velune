export type BookshelfItem = {
	id: string;
	soulerId: string;
	soulerName: string;
	lastSessionId: string | null;
	lastChapterId: string | null;
	lastSessionTitle: string;
	updatedAt: string;
	imageUrl: string | null;
};

export type ExploreSoulerItem = {
	id: string;
	name: string;
	imageUrl: string | null;
	tags: string[];
};

export type SoulerChapter = {
	id: string;
	seq: number;
	title: string;
	subtitle: string;
};

export type AdminSoulerKeyword = {
	word: string;
	weight: number;
};

export type AdminSoulerChapter = {
	id: string;
	seq: number;
	title: string;
	subtitle: string;
	role: string;
	task: string;
};

export type AdminSoulerListItem = {
	id: string;
	name: string;
	lang: string;
	checked: boolean;
	imageUrl: string | null;
};

export type AdminSoulerDetail = {
	id: string;
	name: string;
	lang: string;
	bio: string;
	checked: boolean;
	canonicalName: string;
	wikidata: string;
	imageUrl: string | null;
	keywords: AdminSoulerKeyword[];
	chapters: AdminSoulerChapter[];
};

export type ConversationMessage = {
	role: 'assistant' | 'user';
	content: string;
};
