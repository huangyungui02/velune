import { browser } from '$app/environment';

const MAX_ENTRIES = 120;
const routeStack: string[] = [];

function normalizeRoute(url: URL | string) {
	if (typeof url === 'string') {
		return url;
	}
	return `${url.pathname}${url.search}`;
}

export function pushRoute(url: URL | string) {
	if (!browser) {
		return;
	}

	const route = normalizeRoute(url);
	if (!route) {
		return;
	}

	if (routeStack[routeStack.length - 1] === route) {
		return;
	}

	routeStack.push(route);
	if (routeStack.length > MAX_ENTRIES) {
		routeStack.splice(0, routeStack.length - MAX_ENTRIES);
	}
}

export function hasPreviousRoute(current: URL | string) {
	const currentRoute = normalizeRoute(current);
	for (let i = routeStack.length - 2; i >= 0; i -= 1) {
		if (routeStack[i] !== currentRoute) {
			return true;
		}
	}
	return false;
}
