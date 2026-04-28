import type { BookshelfItem } from '$lib/types';

type BookshelfViewState = {
	items: BookshelfItem[] | null;
};

const bookshelfViewState: BookshelfViewState = {
	items: null
};

function cloneBookshelf(items: BookshelfItem[]) {
	return items.map((item) => ({ ...item }));
}

export function readBookshelfViewState() {
	return {
		items: bookshelfViewState.items ? cloneBookshelf(bookshelfViewState.items) : null
	};
}

export function writeBookshelfViewState(items: BookshelfItem[]) {
	bookshelfViewState.items = cloneBookshelf(items);
}
