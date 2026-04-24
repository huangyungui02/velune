export type BookshelfItem = {
	id: string;
	soulerId: string;
	soulerName: string;
	lastSessionTitle: string;
	updatedAt: string;
	imageUrl: string | null;
};

export type ExploreSoulerItem = {
	id: string;
	name: string;
	imageUrl: string | null;
};

export type SoulerChapter = {
	id: string;
	seq: number;
	title: string;
	subtitle: string;
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
	imageUrl: string | null;
	keywords: string[];
	chapters: SoulerChapter[];
};

export type ConversationMessage = {
	role: 'assistant' | 'user';
	content: string;
};
