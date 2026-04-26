import { redirect } from '@sveltejs/kit';
import {
	assertAdmin,
	fetchDiscoverSectionCount,
	fetchSoulerLists,
	normalizeAdminTab
} from '$lib/server/admin';
import type { LayoutServerLoad } from './$types';

export const load: LayoutServerLoad = async ({ locals, url }) => {
	const adminContext = await assertAdmin(locals);
	if (!adminContext) {
		redirect(303, '/bookshelf');
	}

	const lists = await fetchSoulerLists(locals);
	const discoverSectionCount = await fetchDiscoverSectionCount(locals);

	return {
		userEmail: adminContext.user.email ?? '',
		activeTab: normalizeAdminTab(url.searchParams.get('tab')),
		uncheckedSoulers: lists.unchecked,
		checkedSoulers: lists.checked,
		discoverSectionCount
	};
};
