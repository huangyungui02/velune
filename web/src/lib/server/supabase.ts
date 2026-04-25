import { createServerClient } from '@supabase/ssr';
import { env as publicEnv } from '$env/dynamic/public';
import type { RequestEvent } from '@sveltejs/kit';

const missingEnvError =
	'Missing PUBLIC_SUPABASE_URL or PUBLIC_SUPABASE_PUBLISHABLE_KEY in environment variables.';

export function createSupabaseServerClient(event: RequestEvent) {
	const supabaseUrl = publicEnv.PUBLIC_SUPABASE_URL;
	const supabaseAnonKey = publicEnv.PUBLIC_SUPABASE_PUBLISHABLE_KEY;

	if (!supabaseUrl || !supabaseAnonKey) {
		throw new Error(missingEnvError);
	}

	return createServerClient(supabaseUrl, supabaseAnonKey, {
		cookies: {
			getAll: () => event.cookies.getAll(),
			setAll: (cookiesToSet) => {
				for (const { name, value, options } of cookiesToSet) {
					event.cookies.set(name, value, {
						...options,
						// SvelteKit defaults secure=true for non-localhost hosts.
						// In LAN dev over http://192.168.x.x, Secure cookies are dropped by browsers.
						secure: options.secure ?? event.url.protocol === 'https:',
						path: options.path ?? '/'
					});
				}
			}
		}
	});
}
