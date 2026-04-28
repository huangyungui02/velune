import { fetchBookshelf } from '$lib/server/bookshelf';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ locals, parent }) => {
	const { user } = await parent();

	return {
		bookshelf: user ? await fetchBookshelf(locals, user.id) : []
	};
};
