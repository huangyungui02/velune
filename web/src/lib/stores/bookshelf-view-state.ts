import type { BookshelfItem } from '$lib/types';

type BookshelfViewState = {
	items: BookshelfItem[] | null;
	refreshToken: number;
	dataToken: number;
};

const bookshelfViewState: BookshelfViewState = {
	items: null,
	refreshToken: 0,
	dataToken: 0
};

const bookshelfRefreshEvent = 'velune:bookshelf-refresh-requested';

export function readBookshelfViewState() {
	return {
		items: bookshelfViewState.items,
		refreshToken: bookshelfViewState.refreshToken,
		dataToken: bookshelfViewState.dataToken
	};
}

export function writeBookshelfViewState(items: BookshelfItem[]) {
	bookshelfViewState.items = items;
	bookshelfViewState.dataToken = bookshelfViewState.refreshToken;
}

export function requestBookshelfRefresh() {
	bookshelfViewState.refreshToken += 1;
	if (typeof window === 'undefined') {
		return;
	}
	window.dispatchEvent(
		new CustomEvent(bookshelfRefreshEvent, {
			detail: { refreshToken: bookshelfViewState.refreshToken }
		})
	);
}

export function hasPendingBookshelfRefresh() {
	return bookshelfViewState.refreshToken > bookshelfViewState.dataToken;
}

export function listenForBookshelfRefresh(
	listener: (refreshToken: number) => void | Promise<void>
) {
	const handler = (event: Event) => {
		const refreshToken =
			event instanceof CustomEvent && typeof event.detail?.refreshToken === 'number'
				? event.detail.refreshToken
				: bookshelfViewState.refreshToken;
		void listener(refreshToken);
	};

	window.addEventListener(bookshelfRefreshEvent, handler);
	return () => window.removeEventListener(bookshelfRefreshEvent, handler);
}
