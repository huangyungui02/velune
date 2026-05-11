import { createSupabaseServerClient } from '$lib/server/supabase';
import type { Handle } from '@sveltejs/kit';

export const handle: Handle = async ({ event, resolve }) => {
	event.locals.supabase = createSupabaseServerClient(event);
	const sessionPromise = event.locals.supabase.auth.getSession();
	let safeSessionPromise: ReturnType<typeof event.locals.safeGetSession> | undefined;

	event.locals.safeGetSession = () => {
		safeSessionPromise ??= (async () => {
			const {
				data: { session },
				error: sessionError
			} = await sessionPromise;

			if (sessionError || !session) {
				return { session: null, user: null };
			}

			const {
				data: { user },
				error
			} = await event.locals.supabase.auth.getUser();

			if (error || !user) {
				return { session: null, user: null };
			}

			return {
				session: {
					access_token: session.access_token
				},
				user
			};
		})();

		return safeSessionPromise;
	};

	await sessionPromise;

	return resolve(event, {
		filterSerializedResponseHeaders: (name) => {
			return name === 'content-range' || name === 'x-supabase-api-version';
		}
	});
};
