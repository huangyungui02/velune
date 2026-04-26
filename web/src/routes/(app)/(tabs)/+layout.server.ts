import { fetchExploreInitial, resolveExploreLang } from '$lib/server/explore';
import type { LayoutServerLoad } from './$types';

export const load: LayoutServerLoad = async ({ locals, parent, request }) => {
	const parentData = await parent();
	const exploreLang = resolveExploreLang(parentData.user, request.headers.get('accept-language'));
	const exploreInitial = await fetchExploreInitial(locals, exploreLang);

	return {
		exploreInitial
	};
};
