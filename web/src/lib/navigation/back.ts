import { browser } from '$app/environment';
import { goto } from '$app/navigation';
import { resolve } from '$app/paths';
import { hasPreviousRoute } from '$lib/stores/navigation-stack';

type BackOptions = {
	fallbackHref: string;
	preferHistoryBack?: boolean;
};

export async function goBack({ fallbackHref, preferHistoryBack = true }: BackOptions) {
	if (
		browser &&
		preferHistoryBack &&
		window.history.length > 1 &&
		hasPreviousRoute(`${window.location.pathname}${window.location.search}`)
	) {
		window.history.back();
		return;
	}

	if (fallbackHref.startsWith('/')) {
		await goto(resolve(fallbackHref as '/'), { keepFocus: true });
		return;
	}

	window.location.assign(fallbackHref);
}
