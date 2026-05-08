import { redirect } from '@sveltejs/kit';
import type { RequestHandler } from './$types';

export const POST: RequestHandler = async ({ locals }) => {
	const { session } = await locals.safeGetSession();

	if (!session) {
		redirect(303, '/auth');
	}

	const { error } = await locals.supabase.rpc('delete_own_account');

	if (error) {
		redirect(303, '/settings?deleteAccount=failed');
	}

	await locals.supabase.auth.signOut();
	redirect(303, '/auth');
};
