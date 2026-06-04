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

export type Loadable<T> =
	| {
			status: 'idle' | 'loading';
			data: T | null;
			error: '';
	  }
	| {
			status: 'ready';
			data: T;
			error: '';
	  }
	| {
			status: 'error';
			data: T | null;
			error: string;
	  };

export type ExploreSoulerItem = {
	id: string;
	name: string;
	imageUrl: string | null;
	tags: string[];
};

export type ExploreSection = {
	id: string;
	title: string;
	subtitle: string;
	soulers: ExploreSoulerItem[];
};

export type SoulerChapter = {
	id: string;
	seq: number;
	title: string;
	subtitle: string;
	sessionId?: string | null;
	latestHistory?: ChapterHistoryItem | null;
};

export type PublicSoulerDetail = {
	souler: {
		id: string;
		name: string;
		introduction: string;
		imageUrl: string | null;
		checked: boolean;
	};
	keywords: string[];
	chapters: SoulerChapter[];
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
	task: string;
	active: boolean;
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
	introduction: string;
	checked: boolean;
	canonicalName: string;
	wikidata: string;
	imageUrl: string | null;
	aliases: string[];
	keywords: AdminSoulerKeyword[];
	chapters: AdminSoulerChapter[];
};

export type AdminDiscoverSectionListItem = {
	id: string;
	lang: string;
	title: string;
	subtitle: string;
	sortOrder: number;
	isActive: boolean;
	itemCount: number;
	updatedAt: string;
};

export type AdminDiscoverSectionItem = {
	soulerId: string;
	soulerName: string;
	lang: string;
	sortOrder: number;
	imageUrl: string | null;
};

export type AdminDiscoverSectionSoulerOption = {
	id: string;
	name: string;
	lang: string;
	imageUrl: string | null;
};

export type AdminDiscoverSectionDetail = {
	id: string;
	lang: string;
	title: string;
	subtitle: string;
	sortOrder: number;
	isActive: boolean;
	items: AdminDiscoverSectionItem[];
	availableSoulers: AdminDiscoverSectionSoulerOption[];
};

export type ConversationMessage = {
	id?: string;
	role: 'assistant' | 'user';
	content: string;
};

export type AiReplyLength = 'concise' | 'standard';

export type ChapterHistoryItem = {
	id: string;
	updatedAt: string;
	messageCount: number;
};
