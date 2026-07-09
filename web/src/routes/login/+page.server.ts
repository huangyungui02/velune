import { fail, redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function readCredentials(formData: FormData) {
  const email = String(formData.get('email') ?? '')
    .trim()
    .toLowerCase();
  const password = String(formData.get('password') ?? '');

  if (!EMAIL_PATTERN.test(email)) {
    return { error: '请输入有效的邮箱地址。', email };
  }

  if (password.length < 6) {
    return { error: '密码至少需要 6 位。', email };
  }

  return { email, password };
}

export const load: PageServerLoad = ({ locals, url }) => {
  if (locals.user) {
    redirect(303, '/');
  }

  const requestedRedirect = url.searchParams.get('redirectTo');

  return {
    mode: url.searchParams.get('mode') === 'register' ? 'register' : 'login',
    redirectTo:
      requestedRedirect?.startsWith('/') && !requestedRedirect.startsWith('//')
        ? requestedRedirect
        : '/'
  };
};

export const actions: Actions = {
  login: async ({ locals, request, url }) => {
    if (!locals.supabase) {
      return fail(503, { message: 'Supabase 尚未配置，请先设置环境变量。' });
    }

    const credentials = readCredentials(await request.formData());
    if ('error' in credentials) {
      return fail(400, { message: credentials.error, email: credentials.email });
    }

    const { data, error } = await locals.supabase.auth.signInWithPassword(credentials);
    if (error) {
      return fail(400, {
        message: '邮箱或密码不正确，请重新输入。',
        email: credentials.email
      });
    }

    locals.user = data.user;

    const requestedRedirect = url.searchParams.get('redirectTo');
    redirect(
      303,
      requestedRedirect?.startsWith('/') && !requestedRedirect.startsWith('//')
        ? requestedRedirect
        : '/'
    );
  },

  register: async ({ locals, request }) => {
    if (!locals.supabase) {
      return fail(503, { message: 'Supabase 尚未配置，请先设置环境变量。' });
    }

    const credentials = readCredentials(await request.formData());
    if ('error' in credentials) {
      return fail(400, { message: credentials.error, email: credentials.email });
    }

    const { data, error } = await locals.supabase.auth.signUp(credentials);

    if (error) {
      return fail(400, {
        message: error.message,
        email: credentials.email
      });
    }

    if (!data.session) {
      return fail(409, {
        message: 'Supabase 仍启用了邮箱确认，请在 Auth 设置中关闭 Confirm email。',
        email: credentials.email
      });
    }

    locals.user = data.user;

    redirect(303, '/');
  }
};
