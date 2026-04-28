import {
	fetchFeaturedSections,
	fetchLatestSoulersPage,
	resolveExploreLang
} from '$lib/server/explore';
import type { PageServerLoad } from './$types';

function normalizeTab(raw: string | null) {
	return raw === 'latest' ? 'latest' : 'featured';
}

function normalizePage(raw: string | null) {
	const value = Number.parseInt(raw ?? '1', 10);
	if (!Number.isFinite(value) || value < 1) {
		return 1;
	}
	return value;
}

export const load: PageServerLoad = async ({ locals, parent, request, url }) => {
	const { user } = await parent();
	const exploreLang = resolveExploreLang(user, request.headers.get('accept-language'));
	const activeTab = normalizeTab(url.searchParams.get('tab'));

	if (activeTab === 'latest') {
		return {
			exploreLang,
			exploreFeaturedSections: null,
			exploreLatest: await fetchLatestSoulersPage(
				locals,
				normalizePage(url.searchParams.get('page'))
			)
		};
	}

	return {
		exploreLang,
		exploreFeaturedSections: await fetchFeaturedSections(locals, exploreLang),
		exploreLatest: null
	};
};
