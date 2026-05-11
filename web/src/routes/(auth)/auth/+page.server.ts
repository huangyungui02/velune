import { fail, redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';

function normalizeEmail(value: FormDataEntryValue | null) {
	return typeof value === 'string' ? value.trim().toLowerCase() : '';
}

function readPassword(value: FormDataEntryValue | null) {
	return typeof value === 'string' ? value : '';
}

function logAuthError(action: 'login' | 'signup', error: { status?: number; code?: string; message: string }) {
	console.error(`auth ${action} failed`, {
		status: error.status,
		code: error.code,
		message: error.message
	});
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
		const email = normalizeEmail(formData.get('email'));
		const password = readPassword(formData.get('password'));

		if (!email || !password) {
			return fail(400, { message: '请输入邮箱和密码。', email, mode: 'login' });
		}

		const { error } = await locals.supabase.auth.signInWithPassword({ email, password });

		if (error) {
			logAuthError('login', error);
			return fail(400, { message: error.message, email, mode: 'login' });
		}

		redirect(303, '/explore');
	},
	signup: async ({ request, locals }) => {
		const formData = await request.formData();
		const email = normalizeEmail(formData.get('email'));
		const password = readPassword(formData.get('password'));
		const passwordConfirm = readPassword(formData.get('passwordConfirm'));

		if (!email || !password || !passwordConfirm) {
			return fail(400, { message: '请填写邮箱、密码和重复密码。', email, mode: 'signup' });
		}

		if (password.length < 6) {
			return fail(400, { message: '密码至少需要 6 位。', email, mode: 'signup' });
		}

		if (password !== passwordConfirm) {
			return fail(400, { message: '两次输入的密码不一致。', email, mode: 'signup' });
		}

		const { data, error } = await locals.supabase.auth.signUp({
			email,
			password
		});

		if (error) {
			logAuthError('signup', error);
			return fail(400, { message: error.message, email, mode: 'signup' });
		}

		if (data.session) {
			redirect(303, '/explore');
		}

		const { error: signInError } = await locals.supabase.auth.signInWithPassword({
			email,
			password
		});
		if (signInError) {
			logAuthError('login', signInError);
			return fail(400, {
				message:
					'当前 Supabase 项目仍开启了邮箱确认。请在 Supabase Auth 设置里关闭 Confirm email，才能实现注册后直接登录。',
				email,
				mode: 'signup'
			});
		}

		redirect(303, '/explore');
	}
};
