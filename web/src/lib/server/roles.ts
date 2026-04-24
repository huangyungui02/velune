import type { SupabaseClient } from '@supabase/supabase-js';

type UserRoleRow = {
	role: string;
};

export async function isAdminUser(supabase: SupabaseClient, userId: string) {
	const { data, error } = await supabase
		.from('user_roles')
		.select('role')
		.eq('user_id', userId)
		.eq('role', 'admin')
		.limit(1);

	if (error) {
		return false;
	}

	const roles = (data ?? []) as UserRoleRow[];
	return roles.some((row) => row.role === 'admin');
}
