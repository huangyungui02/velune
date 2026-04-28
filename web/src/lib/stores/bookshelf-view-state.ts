import type { BookshelfItem } from '$lib/types';

type BookshelfViewState = {
	items: BookshelfItem[] | null;
};

const bookshelfViewState: BookshelfViewState = {
	items: null
};

export function readBookshelfViewState() {
	return {
		items: bookshelfViewState.items
	};
}

export function writeBookshelfViewState(items: BookshelfItem[]) {
	bookshelfViewState.items = items;
}
