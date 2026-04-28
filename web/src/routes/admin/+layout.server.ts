import { redirect } from '@sveltejs/kit';
import {
	assertAdmin,
	fetchDiscoverSectionCount,
	fetchSoulerCounts,
	fetchSoulerListByStatus,
	normalizeAdminTab
} from '$lib/server/admin';
import type { LayoutServerLoad } from './$types';

export const load: LayoutServerLoad = async ({ locals, url }) => {
	const adminContext = await assertAdmin(locals);
	if (!adminContext) {
		redirect(303, '/bookshelf');
	}

	const activeTab = normalizeAdminTab(url.searchParams.get('tab'));
	const [soulerCounts, discoverSectionCount, visibleSoulers] = await Promise.all([
		fetchSoulerCounts(locals),
		fetchDiscoverSectionCount(locals),
		activeTab === 'unchecked'
			? fetchSoulerListByStatus(locals, false)
			: activeTab === 'checked'
				? fetchSoulerListByStatus(locals, true)
				: []
	]);

	return {
		userEmail: adminContext.user.email ?? '',
		activeTab,
		visibleSoulers,
		uncheckedSoulerCount: soulerCounts.unchecked,
		checkedSoulerCount: soulerCounts.checked,
		discoverSectionCount
	};
};
