import { error, redirect } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ locals, params }) => {
  if (!locals.user) {
    redirect(303, `/login?redirectTo=/folio/${params.id}/experience`);
  }
  if (!locals.supabase) error(503, 'Supabase 尚未配置。');

  const { data, error: queryError } = await locals.supabase
    .from('folios')
    .select('id,folio_translations(lang,title)')
    .eq('id', params.id)
    .eq('is_public', true)
    .maybeSingle();

  if (queryError) error(500, queryError.message);
  if (!data) error(404, 'Folio 不存在');

  const translation = data.folio_translations?.find((item) => item.lang === 'zh');
  return {
    folio: {
      id: data.id,
      title: translation?.title ?? 'Folio 体验'
    }
  };
};
