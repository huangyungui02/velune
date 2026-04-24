import type { Session, SupabaseClient, User } from '@supabase/supabase-js';
import type { BookshelfItem } from '$lib/types';

// See https://svelte.dev/docs/kit/types#app.d.ts
// for information about these interfaces
declare global {
	namespace App {
		// interface Error {}
		interface Locals {
			supabase: SupabaseClient;
			safeGetSession: () => Promise<{
				session: Session | null;
				user: User | null;
			}>;
		}
		interface PageData {
			session: Session | null;
			user: User | null;
			bookshelf?: BookshelfItem[];
		}
		// interface PageState {}
		// interface Platform {}
	}
}

export {};
