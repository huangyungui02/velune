import type { SupabaseClient, User } from '@supabase/supabase-js';
import type { BookshelfItem } from '$lib/types';

type SafeAuthSession = {
	access_token: string;
};

// See https://svelte.dev/docs/kit/types#app.d.ts
// for information about these interfaces
declare global {
	namespace App {
		// interface Error {}
		interface Locals {
			supabase: SupabaseClient;
			safeGetSession: () => Promise<{
				session: SafeAuthSession | null;
				user: User | null;
			}>;
		}
		interface PageData {
			user?: User | null;
			bookshelf?: BookshelfItem[];
		}
		// interface PageState {}
		// interface Platform {}
	}
}

export {};
