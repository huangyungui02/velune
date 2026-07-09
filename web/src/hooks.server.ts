import { env } from '$env/dynamic/public';
import { createServerClient } from '@supabase/ssr';
import type { Handle } from '@sveltejs/kit';

export const handle: Handle = async ({ event, resolve }) => {
  const url = env.PUBLIC_SUPABASE_URL;
  const key = env.PUBLIC_SUPABASE_PUBLISHABLE_KEY;

  event.locals.supabase =
    url && key
      ? createServerClient(url, key, {
          cookies: {
            getAll: () => event.cookies.getAll(),
            setAll: (cookiesToSet) => {
              for (const { name, value, options } of cookiesToSet) {
                event.cookies.set(name, value, { ...options, path: '/' });
              }
            }
          }
        })
      : null;

  const { data, error } = event.locals.supabase
    ? await event.locals.supabase.auth.getUser()
    : { data: { user: null }, error: null };

  event.locals.user = error ? null : data.user;

  return resolve(event, {
    filterSerializedResponseHeaders: (name) =>
      name === 'content-range' || name === 'x-supabase-api-version'
  });
};
