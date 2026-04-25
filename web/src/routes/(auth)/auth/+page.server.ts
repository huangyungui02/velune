import { fail, redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';

function normalizeCredential(value: FormDataEntryValue | null) {
	return typeof value === 'string' ? value.trim() : '';
}

export const load: PageServerLoad = async ({ locals }) => {
	const { session } = await locals.safeGetSession();
	if (session) {
		redirect(303, '/explore');
	}
};

export const actions: Actions = {
	login: async ({ request, locals }) => {
		const formData = await request.formData();
		const email = normalizeCredential(formData.get('email'));
		const password = normalizeCredential(formData.get('password'));

		if (!email || !password) {
			return fail(400, { message: '请输入邮箱和密码。', email });
		}

		const { error } = await locals.supabase.auth.signInWithPassword({ email, password });

		if (error) {
			return fail(400, { message: error.message, email });
		}

		redirect(303, '/explore');
	},
	signup: async ({ request, locals, url }) => {
		const formData = await request.formData();
		const email = normalizeCredential(formData.get('email'));
		const password = normalizeCredential(formData.get('password'));

		if (!email || !password) {
			return fail(400, { message: '请输入邮箱和密码。', email });
		}

		const { data, error } = await locals.supabase.auth.signUp({
			email,
			password,
			options: {
				emailRedirectTo: `${url.origin}/explore`
			}
		});

		if (error) {
			return fail(400, { message: error.message, email });
		}

		if (!data.session) {
			return {
				message: '注册成功，请前往邮箱完成验证后再登录。',
				email
			};
		}

		redirect(303, '/explore');
	}
};
