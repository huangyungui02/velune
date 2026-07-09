import { env } from '$env/dynamic/public';
import { createServerClient } from '@supabase/ssr';
import type { Handle } from '@sveltejs/kit';

export const handle: Handle = async ({ event, resolve }) => {
  const url = env.PUBLIC_SUPABASE_URL;
  const key = env.PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  const authHeaders = new Headers();

  event.locals.supabase =
    url && key
      ? createServerClient(url, key, {
          cookies: {
            getAll: () => event.cookies.getAll(),
            setAll: (cookiesToSet, headers) => {
              for (const { name, value, options } of cookiesToSet) {
                event.cookies.set(name, value, {
                  ...options,
                  path: '/',
                  secure: event.url.protocol === 'https:'
                });
              }
              for (const [name, value] of Object.entries(headers)) {
                authHeaders.set(name, value);
              }
            }
          }
        })
      : null;

  const { data, error } = event.locals.supabase
    ? await event.locals.supabase.auth.getUser()
    : { data: { user: null }, error: null };

  event.locals.user = error ? null : data.user;

  const response = await resolve(event, {
    filterSerializedResponseHeaders: (name) =>
      name === 'content-range' || name === 'x-supabase-api-version'
  });

  for (const [name, value] of authHeaders) {
    response.headers.set(name, value);
  }

  return response;
};
